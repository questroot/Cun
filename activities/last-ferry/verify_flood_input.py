"""Known-route deliberate warned failure and safe aftermath; public real inputs only."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
s=PlayService()
def obs():return s.call('observe',{})
def key(k,n=1):return s.call('action',{'kind':'key','key':k,'frames':n})
def click(t):
    o=obs();b=next((b for b in o['buttons'] if b['text'].startswith(t)),None);assert b,(t,o)
    return s.call('action',{'kind':'click','button_id':b['id']})
def go(x,y):
    for axis,target in [('y',400),('x',x),('y',y)]:
        for _ in range(18):
            p=obs()['visible'][0]['player_screen'];d=target-p[axis]
            if abs(d)<10:break
            key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(100,max(2,int(abs(d)/2))))
        else:raise AssertionError(('blocked',axis,target,p))
try:
    s.call('launch',{'project':'last-ferry','headless':True});click('阿禾 ·');click('准备好了');click('确认')
    for _ in range(2):
        go(750,390);key('e');go(250,395);key('e');click('危险：举白灯');click('确认')
    flooded=obs();assert '次日尾声' in '\n'.join(flooded['texts']) and '侵入 2 / 2' in '\n'.join(flooded['texts']),flooded
    go(620,510);key('e');click('问老葛今早');ge=obs();assert '撤离包' in json.dumps(ge,ensure_ascii=False),ge
    go(750,390);key('e');shelter=obs();titles=[o['title'] for o in shelter['visible'][0]['objects']]
    click('保存');click('读取');click('确认');shelter=obs()
    assert any(o['x']==705 and o['y']==522 for o in shelter['visible'][0]['obstacles']),shelter
    assert 'sealed_equipment' in shelter['visible'][0] and 'visible_equipment' not in shelter['visible'][0],shelter
    assert '撤离后封起的灯钟与停航告示' in titles and not any(t in titles for t in ['白罩船灯','去旧石阶','周伯']),titles
    go(750,495);key('s',80);assert obs()['visible'][0]['player_screen']['y']<522,obs()
    go(455,470);key('e');click('看看这里今早');notice=obs();assert '普通渡船停航' in json.dumps(notice,ensure_ascii=False),notice
    go(95,565);key('e');go(450,565);key('e');click('离开这段体验');click('确认');left=obs();assert '旅途记录' in json.dumps(left,ensure_ascii=False),left
    out=s.run_dir/'flood-evidence.json';out.write_text(json.dumps({'flood':flooded,'ge':ge,'shelter':shelter,'notice':notice,'departure':left,'method':'two explicitly confirmed signals, no injected state'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:s.stop()
