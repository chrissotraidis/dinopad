"""Portable private generation for the pinned base DinoPad runtime."""
import concurrent.futures
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]


def identity():
    paths = [ROOT / 'dependencies.lock.json', ROOT / 'CMakeLists.txt', ROOT / 'tools/normalize_rom.py']
    for folder, suffixes in (('apple/module', ('.h', '.cpp')), ('patches', ('.patch',)),
                             ('cmake', ('.cmake', '.txt', '.manifest'))):
        paths.extend(path for path in (ROOT / folder).rglob('*') if path.suffix in suffixes)
    paths.extend(ROOT / 'scripts' / name for name in (
        'module_build.py', 'module-identity.py', 'build-game-module.py',
        'setup-module-source.py', 'apply-module-patches.py'))
    digest = hashlib.sha256()
    for path in sorted(paths, key=lambda p: p.relative_to(ROOT).as_posix()):
        digest.update(path.relative_to(ROOT).as_posix().encode() + b'\0')
        digest.update(path.read_bytes().replace(b'\r\n', b'\n') + b'\0')
    return digest.hexdigest()


def normalize_rom(data):
    spec = importlib.util.spec_from_file_location('dino_rom_normalizer', ROOT / 'tools/normalize_rom.py')
    normalizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(normalizer)
    normalized = normalizer.normalize(data)
    if normalizer.detect_byte_order(data) == 'unknown' or hashlib.md5(normalized).hexdigest() != normalizer.SUPPORTED_ROM_MD5:
        raise ValueError('Supply the supported unmodified December 2000 Dinosaur Planet prototype ROM.')
    return normalized


def export_files(source, destination, paths):
    # Source verification admits only pinned files and exact patch additions.
    # Include those additions too; git archive alone cannot see a new patch file.
    source = source.resolve()
    listing = subprocess.check_output(['git', '-C', str(source), 'ls-files', '-z', '--cached',
                                      '--others', '--exclude-standard', '--', *paths])
    for name in dict.fromkeys(listing.decode('utf-8').strip('\0').split('\0')):
        if not name:
            continue
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError(f'Unsafe source path: {name}')
        current = source / relative
        if current.is_symlink() or current.resolve() != current:
            raise ValueError(f'Preserving source symlink: {current}')
        if current.is_dir():  # A gitlink is prepared and exported separately.
            continue
        if not current.is_file():
            raise ValueError(f'Verified source input is missing: {current}')
        out = destination / relative
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(current.read_bytes())


def run_python_script(script, *args, cwd, env):
    # PadMint's embedded Python isolates the script directory. Add only this
    # pinned helper's sibling directory; don't inherit user Python packages.
    run(sys.executable, '-I', '-X', 'utf8', '-B', '-c',
        'import os,runpy,sys;p=sys.argv.pop(1);sys.path.insert(0,os.path.dirname(p));'
        'runpy.run_path(p,run_name="__main__")', script, *args, cwd=cwd, env=env)


def make_flags(makefile, name):
    text = makefile.read_text().replace('\\\n', ' ')
    variables = dict(re.findall(r'^(\w+)\s*(?::=|=)\s*(.*)$', text, re.M))
    value = variables[name]
    value = re.sub(r'\$\((\w+)\)', lambda match: variables.get(match[1], '$'), value)
    if '$' in value:
        raise ValueError(f'Review the changed pinned patch Makefile variable: {name}')
    return shlex.split(value)


def patch_sources(folder):
    text = (folder / 'Makefile').read_text().replace('\\\n', ' ')
    lines = re.findall(r'^C_SRCS\s*(?::=|\+=|=)\s*(.*)$', text, re.M)
    sources = []
    for line in lines:
        match = re.fullmatch(r'\$\(wildcard ([^)]+)\)', line)
        if not match:
            raise ValueError('Review the changed pinned patch source list')
        for pattern in shlex.split(match[1]):
            if Path(pattern).is_absolute() or '..' in Path(pattern).parts:
                raise ValueError('Patch sources must stay inside their private build folder')
            sources.extend(sorted(folder.glob(pattern)))
    if not sources:
        raise ValueError('The pinned patch Makefile selected no C sources')
    return list(dict.fromkeys(sources))


def check_generated(folder):
    record = json.loads((folder / 'module-inputs.json').read_text())
    if record.get('contract') != identity() or record.get('outputs') != output_hashes(folder):
        raise ValueError('Generated inputs changed or became stale; rebuild with your supported ROM.')
    required = ('RecompiledFuncs/lookup.cpp', 'RecompiledFuncs/recomp_overlays.inl', 'rsp/aspMain.cpp',
                'RecompiledPatches/patches.c', 'RecompiledPatches/patches_bin.c')
    if not all((folder / name).is_file() for name in required) or not list((folder / 'RecompiledFuncs').glob('*.c')):
        raise ValueError('Generated module inputs are incomplete')
    return record


def build_generators(source, work, jobs, env):
    suffix = '.exe' if os.name == 'nt' else ''
    host = work / ('host-' + platform.system().lower() + '-' + platform.machine().lower())
    run('cmake', '--fresh', '-S', ROOT / 'cmake/module-host-tools', '-B', host, '-G', 'Ninja',
        '-DCMAKE_BUILD_TYPE=Release', f'-DDINOPAD_SOURCE={source}', env=env)
    run('cmake', '--build', host, '--target', 'N64RecompCLI', 'RSPRecomp', 'DinoPadGeneratorTest',
        '--parallel', jobs, env=env)
    run(host / ('DinoPadGeneratorTest' + suffix), env=env)
    return host / ('N64Recomp' + suffix), host / ('RSPRecomp' + suffix)


def generate(source, rom, work, llvm, jobs, env):
    compiler, linker = patch_tools(llvm, env)
    n64, rsp = build_generators(source, work, jobs, env)
    inputs = {'contract': identity(), 'rom': hashlib.sha256(rom).hexdigest(),
              'tools': {str(tool): sha256(tool) for tool in (n64, rsp, compiler, linker)}}
    generated = work / 'generated'
    if generated.is_dir():
        try:
            if check_generated(generated).get('inputs') == inputs:
                return generated
        except (OSError, ValueError):
            pass
    with tempfile.TemporaryDirectory(prefix='generation-', dir=work) as temporary:
        stage = Path(temporary) / 'source'
        export_files(source, stage, ['dino.toml', 'aspMain.toml', 'patches.toml', 'patches', 'include',
                                    'src/runtime/overlays.cpp', 'src/runtime/patches.cpp'])
        bridge = source / 'lib/dino-recomp-decomp-bridge'
        export_files(bridge, stage / 'lib/dino-recomp-decomp-bridge', ['.'])
        decomp = bridge / 'dinosaur-planet'
        headers = subprocess.check_output(['git', '-C', str(decomp), 'ls-files', 'src/*.h', 'src/**/*.h'], text=True).splitlines()
        export_files(decomp, stage / 'lib/dino-recomp-decomp-bridge/dinosaur-planet', ['include', 'tools/dino',
                     'tools/recomp_rom_patcher.py', *headers])
        export_files(source / 'lib/rt64', stage / 'lib/rt64', ['include'])
        (stage / 'baserom.z64').write_bytes(rom)
        patcher = stage / 'lib/dino-recomp-decomp-bridge/dinosaur-planet/tools/recomp_rom_patcher.py'
        run_python_script(patcher, 'baserom.z64', '--output', 'baserom.patched.z64', cwd=stage, env=env)
        (stage / 'rsp').mkdir(exist_ok=True)
        run(n64, 'dino.toml', cwd=stage, env=env)
        run(rsp, 'aspMain.toml', cwd=stage, env=env)
        patches = stage / 'patches'
        sources = patch_sources(patches)
        flags = make_flags(patches / 'Makefile', 'CFLAGS') + make_flags(patches / 'Makefile', 'CPPFLAGS')
        objects = [patches / 'build' / path.relative_to(patches).with_suffix('.o') for path in sources]
        for obj in objects:
            obj.parent.mkdir(parents=True, exist_ok=True)
        def compile_patch(pair):
            path, obj = pair
            run(compiler, *flags, path.relative_to(patches).as_posix(), '-c', '-o',
                obj.relative_to(patches).as_posix(), cwd=patches, env=env)
        with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
            list(pool.map(compile_patch, zip(sources, objects)))
        run(linker, *[obj.relative_to(patches).as_posix() for obj in objects],
            *make_flags(patches / 'Makefile', 'LDFLAGS'), '-o', 'build/patches.elf', cwd=patches, env=env)
        run(n64, 'patches.toml', cwd=stage, env=env)
        embed_patch((patches / 'build/patches.bin').read_bytes(), stage / 'RecompiledPatches')
        for path in stage.rglob('*'):
            if path.is_file() and path.suffix in ('.c', '.cpp', '.h', '.hpp', '.inl', '.toml', '.ld'):
                path.write_bytes(path.read_bytes().replace(b'\r\n', b'\n'))
        record = {'contract': identity(), 'inputs': inputs, 'outputs': output_hashes(stage)}
        (stage / 'module-inputs.json').write_bytes((json.dumps(record, indent=2) + '\n').encode('utf-8'))
        check_generated(stage)
        if generated.exists():
            preserved = generated.with_name('generated.recovered-' + uuid.uuid4().hex[:12])
            generated.rename(preserved)
            print(f'Preserved previous generated inputs: {preserved}', flush=True)
        stage.rename(generated)
    return generated


def run(*args, cwd=ROOT, env=None):
    subprocess.run([str(arg) for arg in args], cwd=cwd, env=env, check=True)


def configure_output():
    # The bundled interpreter ignores PYTHONUTF8; redirected logs still need
    # to accept non-English player paths without turning success into failure.
    if os.name == 'nt':
        for stream in (sys.stdout, sys.stderr):
            if hasattr(stream, 'reconfigure'):
                stream.reconfigure(encoding='utf-8')


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def generator_environment():
    env = dict(os.environ)
    if os.name != "nt" or shutil.which("cl", path=env.get("PATH")):
        return env
    installer = Path(env.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
    if not installer.is_file():
        raise ValueError("Install Visual Studio Build Tools with Desktop development with C++ and a Windows SDK, then try again.")
    native_arm = platform.machine().lower() in ("arm64", "aarch64")
    components = ["Microsoft.VisualStudio.Component.VC.Tools.x86.x64"]
    if native_arm:
        components.append("Microsoft.VisualStudio.Component.VC.Tools.ARM64")
    installation = subprocess.check_output([str(installer), "-latest", "-products", "*",
                                            *(["-requiresAny"] if native_arm else []), "-requires", *components,
                                            "-property", "installationPath", "-utf8"], text=True, encoding="utf-8").strip()
    versions = sorted((Path(installation) / "VC/Tools/MSVC").glob("*"), reverse=True)
    arm = native_arm and any(
        (version / "bin/Hostarm64/arm64/cl.exe").is_file() for version in versions)
    arch = "arm64" if arm else "x64"
    if not any((version / f"bin/Host{arch}/{arch}/cl.exe").is_file() for version in versions):
        raise ValueError(f"Visual Studio is missing its {arch} C++ compiler; add Desktop development with C++ and a Windows SDK.")
    script = Path(installation) / "VC/Auxiliary/Build/vcvarsall.bat"
    command = subprocess.list2cmdline([env.get("COMSPEC", "cmd.exe")]) + f' /d /u /s /c ""{script}" {arch} >nul && set"'
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-16-le", check=True, env=env)
    for line in result.stdout.splitlines():
        key, separator, value = line.partition("=")
        if separator and key:
            existing = next((name for name in env if name.casefold() == key.casefold()), key)
            env[existing] = value
    if not shutil.which("cl", path=env.get("Path", env.get("PATH"))):
        raise ValueError("Visual Studio could not prepare its C++ compiler. Check the Windows SDK components.")
    return env


def patch_tools(llvm, env):
    suffix = ".exe" if os.name == "nt" else ""
    compiler = Path(env.get("PADMINT_MIPS_CC", str(llvm / ("bin/clang" + suffix))))
    linker = llvm / ("bin/ld.lld" + suffix)
    for tool in (compiler, linker):
        if not tool.is_file():
            raise ValueError(f"PadMint's patch tool is missing: {tool}")
    return compiler, linker


def check_patch_tools(llvm, env):
    """Check real MIPS2/o32 code generation before fetching or translating inputs."""
    compiler, linker = patch_tools(llvm, env)
    targets = subprocess.check_output([str(compiler), "--print-targets"], text=True, env=env)
    if not re.search(r"^\s*mips\s+-", targets, re.M):
        raise ValueError("This LLVM compiler has no MIPS backend. DinoPad needs PadMint's mips-clang tool "
                         "(PADMINT_MIPS_CC); its normal iOS compiler can remain unchanged.")
    with tempfile.TemporaryDirectory(prefix="DinoPad MIPS probe ") as temporary:
        folder = Path(temporary)
        source, obj, linked = folder / "probe.c", folder / "probe.o", folder / "linked.o"
        source.write_text("int dinopad_probe(int value) { return value * 3 + 7; }\n")
        run(compiler, "-target", "mips", "-mips2", "-mabi=32", "-mno-abicalls", "-G0",
            "-mno-odd-spreg", "-mno-check-zero-division", "-c", source, "-o", obj, env=env)
        run(linker, "-m", "elf32btsmip", "-r", obj, "-o", linked, env=env)
        header = linked.read_bytes()[:52]
        if (len(header) != 52 or header[:6] != b"\x7fELF\x01\x02" or header[18:20] != b"\0\x08"
                or int.from_bytes(header[36:40], "big") & 0xF000F000 != 0x10001000):
            raise ValueError("Patch tools did not produce the required big-endian MIPS2/o32 ELF")


def output_hashes(folder):
    return {path.relative_to(folder).as_posix(): sha256(path)
            for path in sorted(folder.rglob("*")) if path.is_file() and path.name != "module-inputs.json"}


def embed_patch(data, folder):
    folder.mkdir(parents=True, exist_ok=True)
    values = ','.join(str(byte if byte < 128 else byte - 256) for byte in data)
    source = ('#include <stddef.h>\n'
              f'extern const char dp_patches_bin[{len(data)}];\n'
              f'const char dp_patches_bin[{len(data)}] = {{{values}}};\n'
              'extern const size_t dp_patches_bin_size;\n'
              'const size_t dp_patches_bin_size = sizeof(dp_patches_bin);\n')
    (folder / 'patches_bin.c').write_bytes(source.encode('ascii'))
    (folder / 'patches_bin.h').write_bytes(
        ('#include <stddef.h>\n#ifdef __cplusplus\nextern "C" {\n#endif\n'
         f'extern const char dp_patches_bin[{len(data)}];\n'
         'extern const size_t dp_patches_bin_size;\n#ifdef __cplusplus\n}\n#endif\n').encode('ascii'))
