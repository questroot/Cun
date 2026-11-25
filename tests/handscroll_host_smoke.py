"""Windows-only smoke test of the real host. Never sends a valid launch request or opens a game."""
import http.client
import os
from pathlib import Path
import re
import subprocess
import unittest
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'nt', 'Windows PowerShell host')
class Handscroll(unittest.TestCase):
    def setUp(self):
        self.process = subprocess.Popen([
            'powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', str(ROOT / 'launcher/Handscroll.ps1')], cwd=ROOT,
            env={**os.environ, 'CUN_HANDSCROLL_NO_BROWSER': '1'},
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        self.addCleanup(self.cleanup)
        line = self.process.stdout.readline().decode('ascii', 'replace')
        self.assertTrue(line.startswith('Cun handscroll lobby: '), line)
        self.url = urlsplit(line.strip().split()[-1]); self.assertEqual(self.url.hostname, '127.0.0.1')

    def cleanup(self):
        self.process.terminate(); self.process.wait(10); self.process.stdout.close()

    def request(self, method, path, headers=None, body=None):
        conn = http.client.HTTPConnection(self.url.hostname, self.url.port, timeout=5)
        try:
            conn.request(method, path, headers=headers or {}, body=body)
            res = conn.getresponse(); return res.status, res.read().decode('utf-8')
        finally:
            conn.close()

    def test_page_and_readonly_contract(self):
        status, html = self.request('GET', '/'); self.assertEqual(status, 200)
        self.assertIn('山海行卷', html)
        token = re.search(r'name="cun-mirror-token" content="([0-9a-f]+)"', html)[1]
        games = re.search(r'name="cun-mirror-games" content="([a-z ]*)"', html)[1].split()
        self.assertEqual(set(games), {'city', 'fudi', 'water', 'ferry'})
        self.assertEqual(self.request('GET', '/status')[0], 403)
        authenticated = {'X-Cun-Token': token}
        self.assertEqual(self.request('GET', '/status', authenticated), (200, '{"state":"idle"}'))
        self.assertEqual(self.request('GET', '/status?id=missing', authenticated)[0], 404)
        self.assertEqual(self.request('GET', '/', {'Host': 'not-the-lobby.invalid'})[0], 403)
        self.assertEqual(self.request('POST', '/launch', {**authenticated, 'Origin':'https://example.invalid'})[0], 403)
        self.assertEqual(self.request('GET', '/status', authenticated)[1], '{"state":"idle"}')


if __name__ == '__main__':
    unittest.main()
