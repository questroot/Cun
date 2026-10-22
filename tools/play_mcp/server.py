"""Standard MCP stdio server. Python standard library only; stdout is protocol only."""
from __future__ import annotations
import argparse
import atexit
import json
import math
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = Path(__file__).resolve().parent / '.runtime'
MAX_BYTES = 65536
VERSIONS = ('2024-11-05', '2025-03-26')
KEYS = ['up','down','left','right','enter','escape','esc','space','tab','w','a','s','d','e','j','k','l','i','m','b','c','1','2','3','4']
# Explicit repository-owned projects only; no caller supplied filesystem paths.
PROJECTS = {
    'card-demo': ('card-demo', '灵伴回合冒险 MVP', 'scripts/ai_play_bridge.gd'),
    'last-ferry': ('activities/last-ferry/game', '末班渡船', 'ai_play_bridge.gd'),
    'atmosphere-demo': ('shared/godot/atmosphere2d', '公共2D环境氛围演示', 'scripts/ai_play_bridge.gd'),
}

def schema(props=None, required=None):
    return {'type':'object','properties':props or {},'required':required or [],'additionalProperties':False}

TOOLS = [
    {'name':'catalog','description':'List explicitly allowed local game projects. No files or hidden game state.','inputSchema':schema()},
    {'name':'launch','description':'Start one owned isolated allowed project. No user saves or user processes.','inputSchema':schema({'project':{'type':'string','enum':list(PROJECTS)},'headless':{'type':'boolean'}},['project'])},
    {'name':'observe','description':'Read visible scene UI text and buttons only; no hidden game state.','inputSchema':schema()},
    {'name':'action','description':'Send visible button click or bounded physical input; no game-manager APIs.','inputSchema':{'oneOf':[
        schema({'kind':{'const':'click'},'button_id':{'type':'string'}},['kind','button_id']),
        schema({'kind':{'const':'key'},'key':{'type':'string','enum':KEYS},'frames':{'type':'integer','minimum':1,'maximum':120}},['kind','key']),
        schema({'kind':{'const':'key'},'key':{'type':'string','enum':KEYS},'duration_ms':{'type':'integer','minimum':1,'maximum':1000}},['kind','key','duration_ms']),
        schema({'kind':{'const':'mouse'},'x':{'type':'number','minimum':0},'y':{'type':'number','minimum':0},'button':{'enum':['left','right','wheel_up','wheel_down']},'frames':{'type':'integer','minimum':1,'maximum':120}},['kind','x','y'])], 'type':'object'}},
    {'name':'stop','description':'Stop only the subprocess launched by this server, preserving isolated evidence.','inputSchema':schema()},
]

class PlayService:
    def __init__(self):
        self.process = None
        self.port = None
        self.token = None
        self.run_dir = None
        self.log = None
        self.lock = threading.Lock()
        atexit.register(self.stop)

    def call(self, name, args):
        if not isinstance(args, dict):
            raise ValueError('arguments must be object')
        allowed = {'catalog':set(), 'launch':{'project','headless'}, 'observe':set(), 'stop':set(), 'action':{'kind','button_id','key','frames','duration_ms','x','y','button'}}
        if not isinstance(name,str) or name not in allowed or set(args) - allowed[name]:
            raise ValueError('unknown tool or argument')
        with self.lock:
            if name == 'catalog':
                return {'projects':[{'id':ident,'title':spec[1]} for ident,spec in PROJECTS.items() if (ROOT/spec[0]/'project.godot').is_file()]}
            if name == 'launch':
                return self.launch(args)
            if name == 'stop':
                return self.stop()
            if name == 'action':
                self.validate_action(args)
            return self.bridge(name, args)

    @staticmethod
    def validate_action(args):
        kind = args.get('kind')
        fields = {'click':{'kind','button_id'}, 'key':{'kind','key','frames','duration_ms'}, 'mouse':{'kind','x','y','button','frames'}}
        if not isinstance(kind, str) or kind not in fields or set(args)-fields[kind]:
            raise ValueError('unsupported action or fields')
        if 'duration_ms' in args:
            if kind != 'key' or 'frames' in args or type(args['duration_ms']) is not int or not 1 <= args['duration_ms'] <= 1000:
                raise ValueError('duration_ms requires key, integer 1..1000 and no frames')
        frames = args.get('frames',1)
        if type(frames) is not int or not 1 <= frames <= 120:
            raise ValueError('frames must be integer 1..120')
        if kind == 'key' and args.get('key') not in KEYS:
            raise ValueError('key not allowed')
        if kind == 'click' and (not isinstance(args.get('button_id'),str) or len(args['button_id']) > 64):
            raise ValueError('invalid button_id')
        if kind == 'mouse':
            if args.get('button','left') not in ('left','right','wheel_up','wheel_down'):
                raise ValueError('invalid mouse button')
            for axis in ('x','y'):
                value = args.get(axis)
                if type(value) not in (float,int) or not math.isfinite(value) or not 0 <= value <= 16384:
                    raise ValueError('invalid coordinate')

    def launch(self, args):
        project_id = args.get('project')
        if not isinstance(project_id,str) or project_id not in PROJECTS or type(args.get('headless',False)) is not bool:
            raise ValueError('only allowed project ids and boolean headless accepted')
        if self.process and self.process.poll() is None:
            raise ValueError('owned game already running')
        engine = ROOT / '.local/godot/Godot_v4.7.2-stable_win64_console.exe'
        source = ROOT / PROJECTS[project_id][0]
        if not engine.is_file() or not (source/'project.godot').is_file():
            raise ValueError('trusted engine or project unavailable')
        if not (source/PROJECTS[project_id][2]).is_file():
            raise ValueError('bridge Autoload integration required: script missing')
        # Reject links/reparse points before copying a project into the owned area.
        for base, dirs, files in os.walk(source):
            dirs[:] = [d for d in dirs if d not in ('.godot','.git','.test-output')]
            for item in [Path(base), *(Path(base)/n for n in dirs+files)]:
                if item.is_symlink() or (hasattr(item,'is_junction') and item.is_junction()):
                    raise ValueError('linked project paths are not allowed')
        self.run_dir = RUNTIME / uuid.uuid4().hex
        project = self.run_dir/'project'
        shutil.copytree(source, project, ignore=shutil.ignore_patterns('.godot','.git','.test-output','*.tmp'))
        # Only this COPY receives the isolation override. Original project/config is untouched.
        with (project/'override.cfg').open('w',encoding='utf-8') as f:
            f.write('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CunPlay/'+self.run_dir.name+'"\n')
        env = dict(os.environ)
        user = self.run_dir/'user'
        user.mkdir()
        for key in ('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','HOME','USERPROFILE'):
            env[key] = str(user)
        self.token = secrets.token_hex(32)
        with socket.socket() as reserved:
            reserved.bind(('127.0.0.1',0))
            self.port = reserved.getsockname()[1]
        env['CUN_PLAY_PORT'] = str(self.port)
        env['CUN_PLAY_TOKEN'] = self.token
        self.log = (self.run_dir/'engine.log').open('wb')
        try:
            # Import fresh copy so cached resources cannot reference another workspace.
            imported = subprocess.run([str(engine),'--headless','--path',str(project),'--editor','--import'], env=env, stdout=self.log, stderr=subprocess.STDOUT, timeout=90)
            self.log.flush()
            import_log = (self.run_dir/'engine.log').read_text(encoding='utf-8',errors='replace')
            if imported.returncode or 'ERROR:' in import_log or 'SCRIPT ERROR:' in import_log:
                raise RuntimeError('Godot import failed; see owned engine.log')
            command = [str(engine),'--path',str(project),'--log-file',str(self.run_dir/'godot.log')]
            if args.get('headless',False):
                command.extend(['--headless','--resolution','1280x720'])
            self.process = subprocess.Popen(command,env=env,stdout=self.log,stderr=subprocess.STDOUT)
            deadline = time.monotonic()+20
            while time.monotonic() < deadline:
                if self.process.poll() is not None:
                    raise RuntimeError('Godot exited before bridge ready; see owned engine.log')
                try:
                    observed = self.bridge('observe',{})
                    return {'project':project_id,'pid':self.process.pid,'isolated':True,'run_dir':str(self.run_dir.relative_to(ROOT)),'observation':observed}
                except (OSError,ValueError):
                    time.sleep(.1)
            raise RuntimeError('bridge startup timed out; Autoload integration required')
        except Exception:
            self.stop()
            raise

    def bridge(self, method, params):
        if not self.process or self.process.poll() is not None:
            raise ValueError('no owned running game')
        payload = json.dumps({'token':self.token,'method':method,'params':params},ensure_ascii=False).encode()+b'\n'
        with socket.create_connection(('127.0.0.1',self.port),timeout=6) as connection:
            connection.settimeout(6)
            connection.sendall(payload)
            data = bytearray()
            while b'\n' not in data:
                block = connection.recv(min(4096,MAX_BYTES+1-len(data)))
                if not block:
                    raise ValueError('bridge closed without response')
                data.extend(block)
                if len(data)>MAX_BYTES:
                    raise ValueError('bridge response too long')
        response = json.loads(data.split(b'\n',1)[0])
        if not response.get('ok'):
            raise ValueError(response.get('error','bridge error'))
        return response['result']

    def stop(self):
        process = self.process
        stopped = False
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
            stopped = True
        self.process = None
        self.token = None
        self.port = None
        if self.log:
            self.log.close()
            self.log = None
        return {'stopped':stopped,'scope':'only owned game process'}

class MCP:
    def __init__(self, service):
        self.service = service
        self.initialized = False
        self.ready = False

    def respond(self, request):
        if not isinstance(request,dict) or request.get('jsonrpc') != '2.0' or not isinstance(request.get('method'),str):
            return {'jsonrpc':'2.0','id':request.get('id') if isinstance(request,dict) else None,'error':{'code':-32600,'message':'Invalid Request'}}
        method, ident = request['method'], request.get('id')
        if 'id' not in request:
            if method == 'notifications/initialized' and self.initialized:
                self.ready = True
            return None
        def result(value):
            return {'jsonrpc':'2.0','id':ident,'result':value}
        def error(code,message):
            return {'jsonrpc':'2.0','id':ident,'error':{'code':code,'message':message}}
        params = request.get('params',{})
        if not isinstance(params,dict):
            return error(-32602,'params must be object')
        if method == 'initialize':
            if self.initialized:
                return error(-32600,'Already initialized')
            requested = params.get('protocolVersion')
            version = requested if requested in VERSIONS else VERSIONS[-1]
            self.initialized = True
            return result({'protocolVersion':version,'capabilities':{'tools':{'listChanged':False}},'serverInfo':{'name':'cun-play','version':'1.0.0'},'instructions':'Player-visible isolated play only. No hidden-state or GM API.'})
        if method == 'ping':
            return result({})
        if not self.ready:
            return error(-32002,'Initialize and send notifications/initialized first')
        if method == 'tools/list':
            return result({'tools':TOOLS})
        if method == 'tools/call':
            try:
                value = self.service.call(params.get('name'), params.get('arguments',{}))
                return result({'content':[{'type':'text','text':json.dumps(value,ensure_ascii=False)}],'isError':False})
            except Exception as exc:
                return result({'content':[{'type':'text','text':str(exc)}],'isError':True})
        return error(-32601,'Method not found')

def stdio():
    sys.stdout.reconfigure(encoding='utf-8', newline='\n')
    sys.stderr.reconfigure(encoding='utf-8')
    service = PlayService()
    mcp = MCP(service)
    try:
        while True:
            line = sys.stdin.buffer.readline(MAX_BYTES+1)
            if not line:
                break
            if len(line)>MAX_BYTES:
                # Drain this oversized line without interpreting fragments as requests.
                while not line.endswith(b'\n'):
                    line = sys.stdin.buffer.readline(MAX_BYTES+1)
                    if not line:
                        break
                response = {'jsonrpc':'2.0','id':None,'error':{'code':-32600,'message':'Message too long'}}
            else:
                try:
                    response = mcp.respond(json.loads(line))
                except (ValueError,UnicodeError):
                    response = {'jsonrpc':'2.0','id':None,'error':{'code':-32700,'message':'Parse error'}}
                except Exception as exc:
                    print(str(exc),file=sys.stderr)
                    response = {'jsonrpc':'2.0','id':None,'error':{'code':-32603,'message':'Internal error'}}
            if response is not None:
                sys.stdout.write(json.dumps(response,ensure_ascii=False)+'\n')
                sys.stdout.flush()
    finally:
        service.stop()

def http_proxy(port, token):
    # Convenience only: this is NOT MCP Streamable HTTP or SSE transport.
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    service = PlayService()
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != '/tool' or self.headers.get('Authorization') != 'Bearer '+token or self.headers.get('Transfer-Encoding'):
                self.send_error(403)
                return
            try:
                size = int(self.headers.get('Content-Length','0'))
                if not 0 < size <= MAX_BYTES:
                    raise ValueError('invalid content length')
                self.connection.settimeout(10)
                request = json.loads(self.rfile.read(size))
                value = service.call(request['name'],request.get('arguments',{}))
                response = {'ok':True,'result':value}
            except Exception as exc:
                response = {'ok':False,'error':str(exc)}
            data = json.dumps(response,ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        def log_message(self, fmt, *args):
            print(fmt % args,file=sys.stderr)
    server = ThreadingHTTPServer(('127.0.0.1',port),Handler)
    try:
        server.serve_forever()
    finally:
        service.stop()
        server.server_close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--http-port',type=int,help='Non-MCP loopback convenience proxy')
    options = parser.parse_args()
    if options.http_port is not None:
        token = os.environ.get('CUN_PLAY_HTTP_TOKEN','')
        if len(token)<32 or not 1 <= options.http_port <= 65535:
            parser.error('HTTP requires port 1..65535 and CUN_PLAY_HTTP_TOKEN >=32 characters')
        http_proxy(options.http_port,token)
    else:
        stdio()
