"""Synthetic portable backend checks: no original game data or SDK required."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


build = load('dino_module_build_tests', ROOT / 'scripts/module_build.py')
setup = load('dino_module_setup_tests', ROOT / 'scripts/setup-module-source.py')


class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='DinoPad source test ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'upstream'
        self.source.mkdir()
        self.git('init', '-q')
        for name in ('a.txt', 'b.txt'):
            (self.source / name).write_text('original\n')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                 'commit', '-qm', 'Synthetic fixture')
        self.pin = self.git('rev-parse', 'HEAD').strip()
        (self.root / 'scripts').mkdir()
        shutil.copyfile(ROOT / 'scripts/apply-module-patches.py', self.root / 'scripts/apply-module-patches.py')
        self.patches = self.root / 'patches/upstream'
        self.patches.mkdir(parents=True)
        (self.patches / '0001.patch').write_text(
            '--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-original\n+first\n'
            '--- /dev/null\n+++ b/added.txt\n@@ -0,0 +1 @@\n+new source\n')
        (self.patches / '0002.patch').write_text(
            '--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-first\n+final\n')
        for patcher in (mock.patch.object(setup, 'ROOT', self.root),
                        mock.patch.object(setup, 'MODULES', ()),
                        mock.patch.object(setup, 'lock_entry', return_value={'commit': self.pin, 'submodules': {}})):
            patcher.start()
            self.addCleanup(patcher.stop)

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args], text=True)

    def apply(self):
        setup.verify(self.source, verify_only=False)

    def test_exact_prefix_is_updated_and_second_run_is_read_only(self):
        (self.source / 'a.txt').write_bytes(b'first\r\n')
        self.apply()
        self.assertEqual((self.source / 'a.txt').read_text(), 'final\n')
        self.assertEqual((self.source / 'added.txt').read_text(), 'new source\n')
        before = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.source.glob('*.txt')}
        setup.select_source(self.source)
        self.assertEqual(before, {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.source.glob('*.txt')})

    def test_read_only_cache_refuses_missing_patches_without_writing(self):
        with self.assertRaisesRegex(ValueError, 'not fully applied'):
            setup.select_source(self.source)
        self.assertEqual((self.source / 'a.txt').read_text(), 'original\n')
        self.assertFalse((self.source / 'added.txt').exists())

    def test_modified_patch_owned_file_preserves_entire_source(self):
        (self.source / 'a.txt').write_text('personal edit\n')
        with self.assertRaisesRegex(ValueError, 'Preserving unexpected'):
            self.apply()
        self.assertEqual((self.source / 'a.txt').read_text(), 'personal edit\n')
        self.assertFalse((self.source / 'added.txt').exists())

    def test_unrelated_tracked_and_untracked_edits_are_preserved(self):
        for name in ('b.txt', 'personal.txt'):
            with self.subTest(name=name):
                (self.source / name).write_text('personal edit\n')
                with self.assertRaisesRegex(ValueError, 'Preserving unexpected source changes'):
                    self.apply()
                self.assertEqual((self.source / 'a.txt').read_text(), 'original\n')
                self.assertEqual((self.source / name).read_text(), 'personal edit\n')
                if name == 'b.txt':
                    (self.source / name).write_text('original\n')

    def test_wrong_source_pin_is_preserved(self):
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                 'commit', '--allow-empty', '-qm', 'Another source revision')
        with self.assertRaisesRegex(ValueError, 'different revision'):
            self.apply()
        self.assertEqual((self.source / 'a.txt').read_text(), 'original\n')

    @unittest.skipIf(os.name == 'nt', 'Windows symlink creation needs additional host privileges')
    def test_source_export_refuses_symlinked_parent_directory(self):
        nested = self.source / 'nested'
        nested.mkdir()
        (nested / 'file.h').write_text('pinned bytes\n')
        self.git('add', 'nested/file.h')
        external = self.root / 'preserve sibling'
        nested.rename(external)
        nested.symlink_to(external, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Preserving source symlink'):
            build.export_files(self.source, self.root / 'exported', ['nested/file.h'])
        self.assertEqual((external / 'file.h').read_text(), 'pinned bytes\n')

    def test_export_includes_exact_patch_additions_without_git_metadata(self):
        self.apply()
        destination = self.root / 'exported'
        build.export_files(self.source, destination, ['.'])
        self.assertEqual(sorted(p.name for p in destination.iterdir()), ['a.txt', 'added.txt', 'b.txt'])
        self.assertEqual((destination / 'added.txt').read_text(), 'new source\n')


class GenerationTests(unittest.TestCase):
    def test_windows_compiler_filter_keeps_x64_and_arm_routes_eligible(self):
        with tempfile.TemporaryDirectory(prefix='DinoPad VS test ') as temporary:
            programs = Path(temporary)
            installer = programs / 'Microsoft Visual Studio/Installer/vswhere.exe'
            installer.parent.mkdir(parents=True)
            installer.touch()
            x64, arm = programs / 'older x64', programs / 'newer ARM only'
            x64_cl = x64 / 'VC/Tools/MSVC/14.44/bin/Hostx64/x64/cl.exe'
            arm_cl = arm / 'VC/Tools/MSVC/14.45/bin/Hostarm64/arm64/cl.exe'
            for path in (x64_cl, arm_cl):
                path.parent.mkdir(parents=True)
                path.touch()
            for machine, available_arm, expected in (('AMD64', True, x64_cl),
                                                      ('ARM64', True, arm_cl),
                                                      ('ARM64', False, x64_cl)):
                with self.subTest(machine=machine, available_arm=available_arm):
                    def installations(command, **kwargs):
                        return str(arm if available_arm and '-requiresAny' in command else x64)
                    env = {'ProgramFiles(x86)': str(programs), 'PATH': 'original'}
                    with mock.patch.object(build, 'os', SimpleNamespace(name='nt', environ=env)), \
                            mock.patch.object(build.platform, 'machine', return_value=machine), \
                            mock.patch.object(build.subprocess, 'check_output', side_effect=installations), \
                            mock.patch.object(build.subprocess, 'run', return_value=SimpleNamespace(stdout='Path=prepared\n')) as run, \
                            mock.patch.object(build.shutil, 'which', side_effect=[None, str(expected)]):
                        prepared = build.generator_environment()
                    self.assertIn(str(arm if expected == arm_cl else x64), run.call_args.args[0])
                    self.assertIn('" arm64 >nul' if expected == arm_cl else '" x64 >nul', run.call_args.args[0])
                    self.assertEqual(prepared['PATH'], 'prepared')

    def test_pinned_python_helper_has_sibling_imports_and_preserves_arguments(self):
        with tempfile.TemporaryDirectory(prefix='DinoPad Python helper ') as temporary:
            folder = Path(temporary)
            helper = folder / 'helper folder'
            helper.mkdir()
            (helper / 'sibling.py').write_text('VALUE = "sibling imported"\n')
            script = helper / 'patcher.py'
            script.write_text('import json,sys\nfrom pathlib import Path\nfrom sibling import VALUE\n'
                              'Path("result.json").write_text(json.dumps([VALUE, sys.argv]))\n')
            build.run_python_script(script, 'input with spaces.z64', '--output', 'out.z64', cwd=folder, env=os.environ)
            self.assertEqual(json.loads((folder / 'result.json').read_text()),
                             ['sibling imported', [str(script), 'input with spaces.z64', '--output', 'out.z64']])
            self.assertFalse((helper / '__pycache__').exists())

    def test_make_flags_and_source_order_match_pinned_make_semantics(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            (folder / 'src/core').mkdir(parents=True)
            for name in ('src/z.c', 'src/a.c', 'src/core/b.c'):
                (folder / name).touch()
            makefile = folder / 'Makefile'
            makefile.write_text('BUILD_DIR = build\nCFLAGS := -target mips \\\n -mips2 -O2\n'
                                'LDFLAGS := -Map $(BUILD_DIR)/patches.map --emit-relocs\n'
                                'C_SRCS := $(wildcard src/*.c)\nC_SRCS += $(wildcard src/core/*.c)\n')
            self.assertEqual(build.make_flags(makefile, 'CFLAGS'), ['-target', 'mips', '-mips2', '-O2'])
            self.assertEqual(build.make_flags(makefile, 'LDFLAGS'), ['-Map', 'build/patches.map', '--emit-relocs'])
            self.assertEqual([p.relative_to(folder).as_posix() for p in build.patch_sources(folder)],
                             ['src/a.c', 'src/z.c', 'src/core/b.c'])

    def test_changed_make_syntax_requires_deliberate_review(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            makefile = folder / 'Makefile'
            makefile.write_text('CFLAGS := $(UNKNOWN)\nC_SRCS := $(shell echo source.c)\n')
            with self.assertRaisesRegex(ValueError, 'Review the changed'):
                build.make_flags(makefile, 'CFLAGS')
            with self.assertRaisesRegex(ValueError, 'Review the changed'):
                build.patch_sources(folder)

    def test_generated_ledger_refuses_changed_or_missing_files(self):
        with tempfile.TemporaryDirectory() as temporary, mock.patch.object(build, 'identity', return_value='contract'):
            folder = Path(temporary)
            for name in ('RecompiledFuncs/lookup.cpp', 'RecompiledFuncs/recomp_overlays.inl', 'rsp/aspMain.cpp',
                         'RecompiledPatches/patches.c', 'RecompiledPatches/patches_bin.c', 'RecompiledFuncs/synthetic.c'):
                path = folder / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('synthetic fixture\n')
            (folder / 'module-inputs.json').write_text(json.dumps({'contract': 'contract', 'outputs': build.output_hashes(folder)}))
            build.check_generated(folder)
            (folder / 'RecompiledFuncs/synthetic.c').write_text('edited generated code\n')
            with self.assertRaisesRegex(ValueError, 'changed or became stale'):
                build.check_generated(folder)

    def test_unapproved_rom_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'supported unmodified'):
            build.normalize_rom(b'\x80\x37\x12\x40' + bytes(32))


if __name__ == '__main__':
    unittest.main()
