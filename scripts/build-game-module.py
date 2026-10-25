#!/usr/bin/env python3
"""Build only the private base-game iOS module with PadMint's pinned tools."""
import argparse
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from module_build import ROOT, check_patch_tools, generate, generator_environment, normalize_rom, run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', type=Path, required=True)
    parser.add_argument('--toolchain', type=Path)
    parser.add_argument('--source-dir', type=Path, help='Read-only prepared public source cache with exact pins and patches')
    parser.add_argument('--llvm', type=Path, default=os.environ.get('PADMINT_LLVM_ROOT'))
    parser.add_argument('--build-dir', type=Path, default=ROOT / 'tmp/module')
    parser.add_argument('--generate-only', action='store_true')
    parser.add_argument('--jobs', type=int, choices=range(1, 17), default=4)
    args = parser.parse_args()
    if not args.generate_only:
        if not args.toolchain or not args.toolchain.is_file():
            parser.error('--toolchain must name PadMint’s existing iOS module toolchain')
        include = args.toolchain.parent / 'usr/include'
        if not all((include / name).is_file() for name in ('assert.h', 'sys/mman.h')):
            parser.error('Update PadMint and recreate its SDK with the portable-module header support.')
    if not args.llvm or not args.llvm.is_dir():
        parser.error('PadMint must supply PADMINT_LLVM_ROOT, or pass --llvm with its LLVM folder')
    if args.rom.stat().st_size > 64 * 1024 * 1024:
        parser.error('Supply the supported Dinosaur Planet cartridge ROM, not a disc image.')
    rom = normalize_rom(args.rom.read_bytes())
    check_patch_tools(args.llvm.resolve(), os.environ)
    env = generator_environment()
    spec = importlib.util.spec_from_file_location('dino_module_source', ROOT / 'scripts/setup-module-source.py')
    setup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(setup)
    source = setup.select_source(args.source_dir)
    work = args.build_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    generated = generate(source, rom, work, args.llvm.resolve(), args.jobs, env)
    if args.generate_only:
        return
    run('cmake', '--fresh', '-S', ROOT / 'cmake/game-module', '-B', work / 'module', '-G', 'Ninja',
        f'-DCMAKE_TOOLCHAIN_FILE={args.toolchain.resolve()}', '-DCMAKE_BUILD_TYPE=Release',
        f'-DDINOPAD_GENERATED={generated}', f'-DDINOPAD_SOURCE={source}',
        f'-DPython3_EXECUTABLE={sys.executable}', env=env)
    run('cmake', '--build', work / 'module', '--parallel', args.jobs, env=env)
    print(f'Private module: {work / "module/DinoPadGame.dylib"}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
