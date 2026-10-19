import json
from pathlib import Path
import subprocess
import sys
import unittest
from server import MCP, PlayService, TOOLS

class Protocol(unittest.TestCase):
    def setUp(self):
        self.service = PlayService()
        self.mcp = MCP(self.service)
    def rpc(self, method, params=None, ident=1):
        return self.mcp.respond({'jsonrpc':'2.0','id':ident,'method':method,'params':params or {}})
    def handshake(self, version='2024-11-05'):
        answer = self.rpc('initialize',{'protocolVersion':version,'capabilities':{},'clientInfo':{'name':'test','version':'1'}})
        self.mcp.respond({'jsonrpc':'2.0','method':'notifications/initialized'})
        return answer
    def test_lifecycle(self):
        self.assertEqual(self.rpc('tools/list')['error']['code'],-32002)
        self.assertEqual(self.handshake()['result']['protocolVersion'],'2024-11-05')
        self.assertEqual(len(self.rpc('tools/list')['result']['tools']),5)
        self.assertFalse(self.rpc('tools/call',{'name':'catalog'})['result']['isError'])
        self.assertEqual(self.rpc('unknown')['error']['code'],-32601)
        self.assertEqual(self.rpc('ping')['result'],{})
    def test_versions(self):
        self.assertEqual(self.handshake('future')['result']['protocolVersion'],'2025-03-26')
    def test_invalid(self):
        self.assertEqual(self.mcp.respond([])['error']['code'],-32600)
        self.handshake()
        for args in ({'project':'../card-demo'}, {'project':'card-demo','script':'evil'}, {'project':'card-demo','headless':1}):
            self.assertTrue(self.rpc('tools/call',{'name':'launch','arguments':args})['result']['isError'])
        self.assertTrue(self.rpc('tools/call',{'name':'eval','arguments':{}})['result']['isError'])
        self.assertTrue(self.rpc('tools/call',{'name':'observe'})['result']['isError'])
    def test_input_boundaries(self):
        for args in ({'kind':'key','key':'escape','frames':121},{'kind':'key','key':'escape','frames':True},{'kind':'key','key':'F12'}, {'kind':'eval'}, {'kind':'click','button_id':'x','script':'foo'}, {'kind':'mouse','x':float('nan'),'y':1}, {'kind':'mouse','x':1,'y':-1}):
            with self.assertRaises(ValueError): self.service.validate_action(args)
        for args in ({'kind':'key','key':'enter','frames':120},{'kind':'click','button_id':'123'}, {'kind':'mouse','x':10,'y':20}):
            self.service.validate_action(args)
    def test_stdio_real_process(self):
        requests = [b'bad json\n', b'x'*65537+b'\n',json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2025-03-26'}}).encode()+b'\n', b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n', b'{"jsonrpc":"2.0","id":2,"method":"tools/list"}\n', b'{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"catalog","arguments":{}}}\n']
        proc = subprocess.run([sys.executable,str(Path(__file__).with_name('server.py'))],input=b''.join(requests),capture_output=True,timeout=10)
        self.assertEqual(proc.returncode,0,proc.stderr)
        replies = [json.loads(line) for line in proc.stdout.splitlines()]
        self.assertEqual(len(replies),5)
        self.assertEqual(replies[0]['error']['code'],-32700)
        self.assertEqual(replies[1]['error']['code'],-32600)
        self.assertEqual(replies[2]['result']['protocolVersion'],'2025-03-26')
        self.assertEqual([t['name'] for t in replies[3]['result']['tools']],[t['name'] for t in TOOLS])
        self.assertFalse(replies[4]['result']['isError'])

if __name__ == '__main__': unittest.main(verbosity=2)
