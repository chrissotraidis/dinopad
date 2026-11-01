"""A selected target needs the exact notices of the components it compiles."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('inventory', ROOT / 'tools/validate_compiled_dependency_inventory.py')
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / 'ref/shared').mkdir(parents=True)
        (self.root / 'ref/shared/NOTICE').write_bytes(b'synthetic notice')
        (self.root / 'build').mkdir()
        self.manifest = self.root / 'manifest.json'
        self.data = {
            'schema_version': 1, 'basis': 'Synthetic fixture', 'inline_notice_assemblies': [],
            'targets': {name: {'build_dir': 'build', 'dependency_format': 'xcode-depfiles'}
                        for name in ('macos', 'ios-device')},
            'target_exclusions': {'macos': [], 'ios-device': ['desktop-only']},
            'components': [
                {'id': name, 'coverage_prefix': 'ref/' + folder, 'notice_source': 'ref/' + folder + '/NOTICE',
                 'notice_kind': 'file', 'sha256': hashlib.sha256(b'synthetic notice').hexdigest()}
                for name, folder in (('shared', 'shared'), ('desktop-only', 'desktop'))],
        }
        self.write()
        patcher = mock.patch.object(inventory, 'ROOT', self.root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def write(self):
        self.manifest.write_text(json.dumps(self.data))

    def test_ios_does_not_require_uncompiled_desktop_sources(self):
        with mock.patch.object(inventory, 'compiler_dependencies', return_value={'ref/shared/header.h'}):
            inventory.validate(self.manifest, 'ios-device')
            with self.assertRaisesRegex(ValueError, 'missing or outside'):
                inventory.validate(self.manifest, 'macos')
            with self.assertRaisesRegex(ValueError, 'missing or outside'):
                inventory.validate(self.manifest, None)

    def test_compiler_records_cannot_hide_an_excluded_component(self):
        with mock.patch.object(inventory, 'compiler_dependencies',
                               return_value={'ref/shared/header.h', 'ref/desktop/header.h'}):
            with self.assertRaisesRegex(ValueError, 'unexpected=.*desktop-only'):
                inventory.validate(self.manifest, 'ios-device')

    def test_required_notice_hash_still_must_match(self):
        (self.root / 'ref/shared/NOTICE').write_bytes(b'changed notice')
        with self.assertRaisesRegex(ValueError, 'notice source hash mismatch'):
            inventory.validate(self.manifest, 'ios-device')

    def test_excluded_paths_and_hash_schema_are_still_validated(self):
        for field, value in (('notice_source', '../outside'), ('sha256', 'invalid')):
            with self.subTest(field=field):
                original = self.data['components'][1][field]
                self.data['components'][1][field] = value
                self.write()
                with self.assertRaises(ValueError):
                    inventory.validate(self.manifest, 'ios-device')
                self.data['components'][1][field] = original


if __name__ == '__main__':
    unittest.main()
