"""Run required build entrypoints with synthetic files and logged tool stubs."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STOP = 73
TOOL = r'''
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([name] + args) + "\n")
if name == "md5":
    print(os.environ.get("TEST_MD5", "49f7bb346ade39d1915c22e090ffd748"))
elif name == "make" or (name == "cmake" and "--build" in args):
    sys.exit(73)  # Stop before compiling anything or reaching downstream tools.
else:
    sys.exit(0)
'''


class BuildJobsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dinopad-jobs-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        for name in ("build-tools.sh", "generate-base.sh", "build-jobs.sh"):
            source = ROOT / "scripts" / name
            if source.exists():
                shutil.copy2(source, self.root / "scripts" / name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("cmake", "make", "md5", "curl", "tar"):
            target = self.bin / name
            target.write_text("#!" + sys.executable + "\n" + TOOL)
            target.chmod(0o755)
        (self.bin / "python3").symlink_to(sys.executable)
        self.log = self.root / "calls.jsonl"
        self.env = os.environ.copy()
        for key in ("DINOPAD_MAX_JOBS", "CMAKE_BUILD_PARALLEL_LEVEL", "BASH_ENV"):
            self.env.pop(key, None)
        self.env.update(PATH=str(self.bin) + ":/usr/bin:/bin", TEST_LOG=str(self.log))

    def generation_fixture(self):
        # These are stand-in files, not a supported ROM or real generated code.
        (self.root / "ref/dino-recomp/lib").mkdir(parents=True, exist_ok=True)
        for path in ("generated/rom/baserom.z64", "generated/rom/baserom.patched.z64",
                     "generated/patches/Makefile", "build-tools/N64Recomp",
                     "build-tools/toolchains/mips-clang/nrs_bin/clang",
                     "ref/dino-recomp/dino.toml", "ref/dino-recomp/aspMain.toml",
                     "ref/dino-recomp/patches.toml"):
            file = self.root / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("synthetic fixture\n")
            file.chmod(0o755)

    def run_script(self, name, **overrides):
        return subprocess.run(["/bin/bash", str(self.root / "scripts" / name)],
                              env=dict(self.env, **overrides), text=True,
                              capture_output=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] \
            if self.log.exists() else []

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes() if p.is_file() else None
                for p in self.root.rglob("*")}

    def assert_jobs(self, name, result, expected):
        self.assertEqual(result.returncode, STOP, result.stdout + result.stderr)
        calls = self.calls()
        if name == "build-tools.sh":
            build = next(c for c in calls if c[:2] == ["cmake", "--build"])
            self.assertEqual(build[build.index("--parallel") + 1], expected)
            self.assertEqual(build[build.index("--target") + 1:],
                             ["N64Recomp", "RSPRecomp", "OfflineModRecomp",
                              "RecompModMerger", "RecompModTool"])
        else:
            build = next(c for c in calls if c[0] == "make")
            self.assertEqual(build[build.index("-j") + 1], expected)
            self.assertEqual(build[1:3], ["-C", "generated/patches"])
            self.assertTrue(any(arg.startswith("CC=") for arg in build))
            self.assertTrue(any(arg.startswith("LD=") for arg in build))
        self.assertFalse(any(c[0] in ("curl", "tar") for c in calls))

    def test_standard_limit_reaches_host_tools(self):
        result = self.run_script("build-tools.sh", CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assert_jobs("build-tools.sh", result, "2")

    def test_standard_limit_reaches_patch_make(self):
        self.generation_fixture()
        result = self.run_script("generate-base.sh", CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assert_jobs("generate-base.sh", result, "2")

    def test_manual_override_precedes_standard_limit(self):
        self.generation_fixture()
        for name in ("build-tools.sh", "generate-base.sh"):
            for standard in ("2", "invalid"):
                with self.subTest(name=name, standard=standard):
                    if self.log.exists():
                        self.log.unlink()
                    result = self.run_script(name, DINOPAD_MAX_JOBS="3",
                                             CMAKE_BUILD_PARALLEL_LEVEL=standard)
                    self.assert_jobs(name, result, "3")

    def test_empty_or_unset_settings_retain_four_job_default(self):
        self.generation_fixture()
        for name in ("build-tools.sh", "generate-base.sh"):
            for settings in ({}, {"DINOPAD_MAX_JOBS": "",
                                   "CMAKE_BUILD_PARALLEL_LEVEL": ""}):
                with self.subTest(name=name, settings=settings):
                    if self.log.exists():
                        self.log.unlink()
                    self.assert_jobs(name, self.run_script(name, **settings), "4")

    def test_empty_manual_setting_uses_standard_limit(self):
        self.generation_fixture()
        for name in ("build-tools.sh", "generate-base.sh"):
            with self.subTest(name=name):
                if self.log.exists():
                    self.log.unlink()
                result = self.run_script(name, DINOPAD_MAX_JOBS="",
                                         CMAKE_BUILD_PARALLEL_LEVEL="1")
                self.assert_jobs(name, result, "1")

    def test_invalid_settings_stop_before_tools_or_output(self):
        for name in ("build-tools.sh", "generate-base.sh"):
            for variable in ("DINOPAD_MAX_JOBS", "CMAKE_BUILD_PARALLEL_LEVEL"):
                for value in ("0", "-1", "+2", "02", " 2", "2 ", "2\n", "many"):
                    with self.subTest(name=name, variable=variable, value=value):
                        before = self.snapshot()
                        result = self.run_script(name, **{variable: value})
                        self.assertEqual(result.returncode, 2, result.stderr)
                        self.assertIn(variable, result.stderr)
                        self.assertEqual(self.calls(), [])
                        self.assertEqual(self.snapshot(), before)

    def test_invalid_manual_setting_does_not_fall_back(self):
        for name in ("build-tools.sh", "generate-base.sh"):
            with self.subTest(name=name):
                result = self.run_script(name, DINOPAD_MAX_JOBS="0",
                                         CMAKE_BUILD_PARALLEL_LEVEL="2")
                self.assertEqual(result.returncode, 2)
                self.assertIn("DINOPAD_MAX_JOBS", result.stderr)
                self.assertEqual(self.calls(), [])

    def test_rom_fingerprint_failure_still_prevents_make(self):
        self.generation_fixture()
        result = self.run_script("generate-base.sh", CMAKE_BUILD_PARALLEL_LEVEL="2",
                                 TEST_MD5="unsupported synthetic fingerprint")
        self.assertEqual(result.returncode, 1)
        self.assertIn("ROM fingerprint mismatch", result.stderr)
        self.assertEqual([c[0] for c in self.calls()], ["md5"])

    def test_missing_toolchain_still_prevents_rom_setup(self):
        result = self.run_script("generate-base.sh", CMAKE_BUILD_PARALLEL_LEVEL="2")
        self.assertEqual(result.returncode, 1)
        self.assertIn("MIPS clang missing", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.root / "generated").exists())


if __name__ == "__main__":
    unittest.main()
