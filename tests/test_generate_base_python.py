"""Exercise Python selection through the real entrypoint, without game data."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "generate-base.sh"


class GenerateBasePythonTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        shutil.copy2(SCRIPT, self.root / "scripts" / SCRIPT.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "python-probes"
        (self.bin / "dirname").symlink_to(shutil.which("dirname"))

    def interpreter(self, name, version=None, failure=False):
        path = self.bin / name
        if version is None and not failure:
            path.symlink_to(sys.executable)
            return
        # Run the production probe under a simulated version. This checks its
        # actual >=3.9 comparison, not a canned result for a named interpreter.
        code = "import sys; sys.version_info = %r; exec(sys.argv[1])" % (version,)
        path.write_text(
            "#!/bin/bash\n"
            "echo '%s' >> \"$PROBE_LOG\"\n" % name
            + ("exit 17\n" if failure else
               "exec \"$TEST_PYTHON\" -c \"$SIMULATED_PROBE_%s\" \"$2\"\n" % name.replace(".", "_"))
        )
        path.chmod(0o755)
        return code

    def run_script(self, candidates=(), arguments=()):
        env = dict(os.environ, PATH=str(self.bin), PROBE_LOG=str(self.log),
                   TEST_PYTHON=sys.executable)
        for name, version, failure in candidates:
            code = self.interpreter(name, version, failure)
            if code is not None:
                env["SIMULATED_PROBE_" + name.replace(".", "_")] = code
        result = subprocess.run(
            ["/bin/bash", str(self.root / "scripts" / SCRIPT.name), *arguments],
            env=env, text=True, capture_output=True, timeout=10,
        )
        # Every tested stop precedes generated outputs, ROM access or tools.
        self.assertFalse((self.root / "generated").exists())
        self.assertFalse((self.root / "build-tools").exists())
        return result

    def assert_tools_gate(self, result):
        self.assertEqual(result.returncode, 1)
        self.assertIn("MIPS clang missing", result.stderr)
        self.assertNotIn("need Python", result.stderr)

    def test_generic_current_python_is_accepted(self):
        self.assert_tools_gate(self.run_script([("python3", None, False)]))

    def test_generic_minimum_and_future_versions(self):
        for version in ((3, 9, 0), (3, 14, 0)):
            with self.subTest(version=version):
                self.assert_tools_gate(self.run_script([("python3", version, False)]))

    def test_old_generic_python_is_rejected(self):
        result = self.run_script([("python3", (3, 8, 20), False)])
        self.assertEqual(result.returncode, 1)
        self.assertIn("need Python >= 3.9", result.stderr)
        self.assertNotIn("MIPS clang", result.stderr)

    def test_no_python_is_rejected(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn("need Python >= 3.9", result.stderr)

    def test_existing_versioned_preference_is_preserved(self):
        self.assert_tools_gate(self.run_script([
            ("python3.13", (3, 13, 0), False),
            ("python3.12", (3, 12, 0), False),
            ("python3", (3, 14, 0), False),
        ]))
        self.assertEqual(self.log.read_text().splitlines(), ["python3.13"])

    def test_bad_versioned_candidates_fall_back(self):
        self.assert_tools_gate(self.run_script([
            ("python3.13", (3, 8, 0), False),
            ("python3.12", None, True),
            ("python3", (3, 9, 6), False),
        ]))
        self.assertEqual(self.log.read_text().splitlines(),
                         ["python3.13", "python3.12", "python3"])

    def test_argument_validation_still_precedes_python(self):
        result = self.run_script([("python3", (3, 9, 6), False)], ["--rom"])
        self.assertEqual(result.returncode, 2)
        self.assertIn("--rom requires a path", result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
