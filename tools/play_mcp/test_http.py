"""NON-MCP HTTP convenience transport smoke test."""
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
import urllib.request
import urllib.error

with socket.socket() as reserved:
    reserved.bind(('127.0.0.1',0))
    port = reserved.getsockname()[1]
token = secrets.token_hex(32)
server_path = Path(__file__).with_name('server.py')
log_path = server_path.parent/'.runtime/http-test.log'
log_path.parent.mkdir(exist_ok=True)
with log_path.open('wb') as log:
    process = subprocess.Popen([sys.executable,str(server_path),'--http-port',str(port)],env=dict(os.environ,CUN_PLAY_HTTP_TOKEN=token),stdout=log,stderr=subprocess.STDOUT)
    try:
        deadline=time.monotonic()+5
        while True:
            try:
                socket.create_connection(('127.0.0.1',port),timeout=.2).close(); break
            except OSError:
                if time.monotonic()>deadline: raise
                time.sleep(.1)
        def call(auth,body):
            request=urllib.request.Request('http://127.0.0.1:'+str(port)+'/tool',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+auth,'Content-Type':'application/json'})
            with urllib.request.urlopen(request,timeout=3) as response:
                return json.load(response)
        assert call(token,{'name':'catalog','arguments':{}})['result']['projects'][0]['id']=='card-demo'
        assert not call(token,{'name':'launch','arguments':{'project':'../../evil'}})['ok']
        try:
            call('wrong',{'name':'catalog'})
            raise AssertionError('invalid token accepted')
        except urllib.error.HTTPError as exc:
            assert exc.code==403
        print('HTTP convenience proxy: catalog / path rejection / token rejection passed (not MCP transport)')
    finally:
        process.terminate(); process.wait(timeout=5)
