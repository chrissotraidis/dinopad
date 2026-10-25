"""Exercise the shell's real normalization step using synthetic reviewed bytes."""
import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('normalize_rom', ROOT / 'tools/normalize_rom.py')
normalize = importlib.util.module_from_spec(spec)
spec.loader.exec_module(normalize)


@unittest.skipIf(os.name == 'nt', 'The existing static shell route runs on Mac')
class GenerateBaseRomTests(unittest.TestCase):
    def test_all_advertised_orders_reach_patcher_as_verified_big_endian(self):
        canonical = normalize._make_test_rom('z64')
        for order in ('z64', 'v64', 'n64'):
            with self.subTest(order=order), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                original = normalize._make_test_rom(order)
                result, source, output = self.run_to_patch(root, original, canonical)
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertIn('== 2. Patch ROM', result.stdout)
                self.assertEqual(source.read_bytes(), original)
                self.assertEqual(output.read_bytes(), canonical)

    def test_wrong_revision_preserves_existing_private_copy(self):
        canonical = normalize._make_test_rom('z64')
        with tempfile.TemporaryDirectory() as folder:
            result, source, output = self.run_to_patch(Path(folder), canonical + b'wrong revision', canonical,
                                                       previous=b'preserved previous private copy')
            self.assertEqual(result.returncode, 4, result.stderr)
            self.assertIn('UNSUPPORTED-REVISION', result.stdout)
            self.assertNotIn('== 2. Patch ROM', result.stdout)
            self.assertEqual(source.read_bytes(), canonical + b'wrong revision')
            self.assertEqual(output.read_bytes(), b'preserved previous private copy')

    def run_to_patch(self, root, original, accepted, previous=None):
        (root / 'scripts').mkdir()
        for name in ('generate-base.sh', 'build-jobs.sh'):
            shutil.copy2(ROOT / 'scripts' / name, root / 'scripts' / name)
        (root / 'tools').mkdir()
        # Only the accepted fingerprint changes for this synthetic fixture.
        # Production argument parsing, byte-order conversion and file I/O run.
        (root / 'tools/normalize_rom.py').write_text(
            'import importlib.util,sys\n'
            f's=importlib.util.spec_from_file_location("normalizer", {str(ROOT / "tools/normalize_rom.py")!r})\n'
            'm=importlib.util.module_from_spec(s);s.loader.exec_module(m)\n'
            f'm.SUPPORTED_ROM_MD5={hashlib.md5(accepted).hexdigest()!r}\n'
            'sys.exit(m.main(sys.argv))\n')
        tools = root / 'build-tools'
        for name in ('N64Recomp', 'toolchains/mips-clang/nrs_bin/clang'):
            path = tools / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('#!/bin/sh\nexit 99\n')
            path.chmod(0o755)
        patcher = root / 'ref/dino-recomp/lib/dino-recomp-decomp-bridge/dinosaur-planet/tools/recomp_rom_patcher.py'
        patcher.parent.mkdir(parents=True)
        patcher.write_text('raise SystemExit(23)\n')
        source = root / 'original with spaces.rom'
        source.write_bytes(original)
        output = root / 'generated/rom/baserom.z64'
        if previous is not None:
            output.parent.mkdir(parents=True)
            output.write_bytes(previous)
        bins = root / 'bin'
        bins.mkdir()
        (bins / 'python3.13').symlink_to(sys.executable)
        for name in ('dirname', 'mkdir'):
            (bins / name).symlink_to(shutil.which(name))
        env = dict(os.environ, PATH=str(bins), DINOPAD_MAX_JOBS='1')
        env.pop('BASH_ENV', None)
        result = subprocess.run(['/bin/bash', str(root / 'scripts/generate-base.sh'), '--rom', str(source)],
                                cwd=root, env=env, capture_output=True, text=True, timeout=20)
        return result, source, output


if __name__ == '__main__':
    unittest.main()
