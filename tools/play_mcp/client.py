"""One-shot client for the NON-MCP local HTTP convenience proxy."""
import argparse
import json
import os
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('tool',choices=['catalog','launch','observe','action','stop'])
parser.add_argument('arguments',nargs='?',default='{}',help='JSON object')
parser.add_argument('--port',type=int,default=8765)
options = parser.parse_args()
token = os.environ.get('CUN_PLAY_HTTP_TOKEN','')
if len(token)<32 or not 1 <= options.port <= 65535:
    parser.error('valid port and CUN_PLAY_HTTP_TOKEN >=32 characters required')
request = urllib.request.Request('http://127.0.0.1:'+str(options.port)+'/tool',data=json.dumps({'name':options.tool,'arguments':json.loads(options.arguments)}).encode(),headers={'Content-Type':'application/json','Authorization':'Bearer '+token})
with urllib.request.urlopen(request,timeout=150) as response:
    print(response.read().decode('utf-8'))
