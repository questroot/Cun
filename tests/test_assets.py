import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('assets_tool', Path(__file__).resolve().parents[1] / 'tools/assets.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'art').mkdir()
        (self.root / 'art/a.png').write_bytes(b'sample')
        self.data = {'version': 1, 'assets': []}
        m.scan(self.root, self.data, 'art')

    def test_scan_is_idempotent_and_preserves_metadata(self):
        self.data['assets'][0]['notes'] = 'approved note'
        original = copy.deepcopy(self.data)
        self.assertEqual(m.scan(self.root, self.data, 'art'), 0)
        self.assertEqual(self.data, original)

    def test_missing_and_changed_files(self):
        p = self.root / 'art/a.png'
        p.write_bytes(b'changed')
        self.assertTrue(m.validate(self.root, self.data)[0])
        p.unlink()
        self.assertTrue(m.validate(self.root, self.data)[0])

    def test_unknown_license_is_release_error(self):
        self.assertFalse(m.validate(self.root, self.data)[0])
        self.assertTrue(m.validate(self.root, self.data, True)[0])
        a = self.data['assets'][0]
        a.update(source='https://example.org/original', author='team', license='CC0-1.0', status='approved')
        self.assertFalse(m.validate(self.root, self.data, True)[0])

    def test_duplicate_hash_is_warning(self):
        (self.root / 'art/b.png').write_bytes(b'sample')
        m.scan(self.root, self.data, 'art')
        self.assertTrue(any('内容重复' in w for w in m.validate(self.root, self.data)[1]))

    def test_invalid_registry(self):
        self.data['assets'].append(copy.deepcopy(self.data['assets'][0]))
        self.assertTrue(any('重复 ID' in e for e in m.validate(self.root, self.data)[0]))
        self.data['assets'][0]['tags'] = [1]
        self.assertTrue(any('tags' in e for e in m.validate(self.root, self.data)[0]))
        self.data['assets'][0]['name'] = 1
        self.assertTrue(any('类型' in e for e in m.validate(self.root, self.data)[0]))

    def test_path_escape(self):
        for path in ('../outside', 'C:/secret', '/tmp/file', 'art/../../escape', 'art\\a.png'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                m.safe_path(self.root, path)

    def test_catalog_escapes_metadata_and_uses_relative_preview(self):
        self.data['assets'][0]['name'] = '<script>alert(1)</script>'
        out = self.root / 'assets/catalog.html'
        m.catalog(self.root, self.data, out)
        page = out.read_text(encoding='utf-8')
        self.assertIn('&lt;script&gt;', page)
        self.assertNotIn('<script>alert(1)</script>', page)
        self.assertIn('../art/a.png', page)
        self.assertIn('function filter()', page)

    def test_cli_lifecycle_and_non_destructive_removal(self):
        base = ['--root', str(self.root)]
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(m.main(base + ['scan', 'art']), 0)
            manifest = self.root / 'assets/registry.json'
            asset_id = m.load(manifest)['assets'][0]['id']
            self.assertEqual(m.main(base + ['set', asset_id, '--tags', 'ui, pet', '--status', 'approved']), 0)
            self.assertEqual(m.load(manifest)['assets'][0]['tags'], ['ui', 'pet'])
            (self.root / 'art/a.png').write_bytes(b'new')
            self.assertEqual(m.main(base + ['refresh', asset_id]), 0)
            self.assertEqual(m.load(manifest)['assets'][0]['status'], 'review')
            self.assertEqual(m.main(base + ['check']), 0)
            self.assertEqual(m.main(base + ['catalog']), 0)
            self.assertEqual(m.main(base + ['set', asset_id, '--status', 'illegal']), 1)
            self.assertEqual(m.main(base + ['remove', asset_id]), 0)
            self.assertTrue((self.root / 'art/a.png').exists())
            self.assertEqual(m.load(manifest)['assets'], [])

    def test_cli_rejects_missing_manifest_and_overwrite(self):
        base = ['--root', str(self.root)]
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(m.main(base + ['check']), 1)
            self.assertEqual(m.main(base + ['scan', 'art']), 0)
            unrelated = self.root / 'page.html'
            unrelated.write_text('original user content', encoding='utf-8')
            self.assertEqual(m.main(base + ['catalog', '--output', 'page.html']), 1)
            self.assertEqual(unrelated.read_text(encoding='utf-8'), 'original user content')
            self.assertEqual(m.main(base + ['catalog', '--output', '../escape.html']), 1)
            self.assertEqual(m.main(base + ['remove', 'nonexistent']), 1)

    def test_schema_version_rejected(self):
        p = self.root / 'registry.json'
        p.write_text(json.dumps({'version': 2, 'assets': []}), encoding='utf-8')
        with self.assertRaises(ValueError): m.load(p)


if __name__ == '__main__':
    unittest.main()
