"""Known-route real-engine MCP stdio integration, not independent gameplay."""
import json
from pathlib import Path
import subprocess
import sys


def main():
    receipts=[]
    process=subprocess.Popen([sys.executable,str(Path(__file__).with_name('server.py'))],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8')
    seq=0
    def rpc(method,params=None,notify=False):
        nonlocal seq
        seq+=1
        request={'jsonrpc':'2.0','method':method,'params':params or {}}
        if not notify:request['id']=seq
        process.stdin.write(json.dumps(request)+'\n');process.stdin.flush()
        if notify:return
        response=json.loads(process.stdout.readline());receipts.append({'request':request,'response':response})
        assert response.get('id')==seq and 'error' not in response,response
        return response['result']
    def tool(name,args):
        result=rpc('tools/call',{'name':name,'arguments':args})
        assert not result.get('isError'),result
        return json.loads(result['content'][0]['text'])
    try:
        rpc('initialize',{'protocolVersion':'2025-03-26','capabilities':{},'clientInfo':{'name':'duration-integration','version':'1'}})
        rpc('notifications/initialized',notify=True)
        tool('launch',{'project':'card-demo','headless':True})
        observation=tool('observe',{})
        tool('action',{'kind':'click','button_id':next(b['id'] for b in observation['buttons'] if b['text'].startswith('进入福地'))})
        result=tool('action',{'kind':'key','key':'a','duration_ms':100})
        assert 100<=result['input_timing']['held_wall_ms']<1000,result
        print(json.dumps({'ok':True,'input_timing':result['input_timing']},ensure_ascii=False))
    finally:
        try:tool('stop',{})
        finally:
            process.stdin.close()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait()
            output=Path(__file__).parent/'.runtime'/'stdio-duration-evidence.json'
            output.parent.mkdir(exist_ok=True)
            output.write_text(json.dumps(receipts,ensure_ascii=False,indent=2),encoding='utf-8')
    assert process.returncode==0,process.stderr.read()

if __name__=='__main__':main()
