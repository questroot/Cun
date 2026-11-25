"""Verify desktop build + repeatable cache without starting a game or accessing saves."""
import os
from pathlib import Path
import struct
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'nt', 'Windows desktop build')
class Handscroll(unittest.TestCase):
    def test_gui_executable(self):
        cmd = ['powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
               '-File', str(ROOT / 'launcher/Handscroll.ps1'), '-BuildOnly']
        def build():
            return Path(os.fsdecode(subprocess.check_output(cmd, cwd=ROOT, timeout=60).strip()))
        exe = build()
        self.assertEqual(exe.name, 'Cun.Handscroll.exe')
        self.assertEqual(exe.parents[1], ROOT / '.local/native-launcher')
        data = exe.read_bytes()
        pe = struct.unpack_from('<I', data, 60)[0]
        self.assertEqual(data[pe:pe+4], b'PE\x00\x00')
        self.assertEqual(struct.unpack_from('<H', data, pe+24+68)[0], 2, 'Windows GUI subsystem')
        before = exe.stat().st_mtime_ns
        self.assertEqual(build(), exe)
        self.assertEqual(exe.stat().st_mtime_ns, before)


if __name__ == '__main__':
    unittest.main()
