"""Real public inputs for partial awning pull, reload release and tying."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
s=PlayService();receipts=[]
def call(n,a={}):
    try:
        o=s.call(n,a);receipts.append({'name':n,'arguments':a,'result':o});return o
    except Exception as e:
        receipts.append({'name':n,'arguments':a,'error':str(e)});raise
def obs():return call('observe')
def key(k,ms=50):return call('action',{'kind':'key','key':k,'duration_ms':ms})
def click(t):
    o=obs();return call('action',{'kind':'click','button_id':next(b['id'] for b in o['buttons'] if b['text'].startswith(t))})
def go(x,y):
    for axis,t in [('y',480),('x',x),('y',y)]:
        for _ in range(35):
            p=obs()['visible'][0]['player_screen'];d=t-p[axis]
            if abs(d)<10:break
            key(('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w'),min(300,max(40,int(abs(d)*4))))
        else:raise AssertionError(('blocked',p))
try:
    call('launch',{'project':'last-ferry','headless':True});click('阿禾 ·');go(750,390);key('e');go(690,350);key('e');click('握住绳端')
    assert obs()['visible'][0]['visible_awning_post']['y']==420 and 'visible_dry_patch' not in obs()['visible'][0],obs()
    before=obs()['visible'][0]['visible_awning'];key('s',150);partial=obs()['visible'][0]['visible_awning'];assert before['rope_end_y']<partial['rope_end_y']<440,partial
    click('保存');click('读取');click('确认');loaded=obs()['visible'][0]['visible_awning'];assert loaded['rope_end_y']==partial['rope_end_y'],loaded
    key('s',100);assert obs()['visible'][0]['visible_awning']['rope_end_y']==loaded['rope_end_y'],'reload must release hand'
    y=obs()['visible'][0]['player_screen']['y'];key('e');click('握住绳端');key('e');assert '还没拉到木桩' in '\n'.join(obs()['texts']),obs()
    key('e');click('握住绳端');key('s',500);key('e');tied=obs();assert '棚绳系在木桩' in tied['visible'][0]['visible_awning']['appearance'],tied
    click('保存');click('读取');click('确认');assert '棚绳系在木桩' in obs()['visible'][0]['visible_awning']['appearance']
    dry=obs()['visible'][0]['visible_dry_patch'];go(dry['x']+dry['width']/2,dry['y']+dry['height']/2);p=obs()['visible'][0]['player_screen'];assert dry['x']<=p['x']<=dry['x']+dry['width'] and dry['y']<=p['y']<=dry['y']+dry['height'],p
    assert '肩头终于不再' in '\n'.join(obs()['texts']),obs()
    click('保存');click('读取');click('确认');click('记录');journal='\n'.join(obs()['texts']);assert journal.count('肩头终于不再')==1,journal
    key('esc')
    out=s.run_dir/'awning-evidence.json';out.write_text(json.dumps({'before':before,'partial':partial,'loaded':loaded,'tied':tied},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:
    try:call('stop')
    finally:
        s.stop()
        if s.run_dir:(s.run_dir/'awning-input-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2),encoding='utf-8')
