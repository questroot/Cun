"""Known-route real-input handover investigation; contains solutions, not blind play."""
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
def text():return json.dumps(obs(),ensure_ascii=False)
def go(x,y):
    for axis,target in [('y',400),('x',x),('y',y)]:
        for _ in range(18):
            p=obs()['visible'][0]['player_screen'];d=target-p[axis]
            if abs(d)<10:break
            key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(100,max(2,int(abs(d)/2))))
        else:raise AssertionError(('blocked',axis,target,p))
try:
    s.call('launch',{'project':'last-ferry','headless':True});click('阿禾 ·')
    go(100,480);key('e');go(320,380);key('e');click('托住底板');assert '先问屋主' in text()
    go(550,445);key('e');click('问她：可以看');assert '别翻上面的家信' in text()
    go(320,380);key('e');click('托住底板');assert any(o['title']=='下层抽屉里的折单' for o in obs()['visible'][0]['objects']),obs()
    go(350,415);key('e');click('展开公用物件');document=obs();assert '暂夹铜件' in text()
    go(450,575);key('e');go(750,390);key('e');go(250,395);key('e');click('用记下的交接');assert '还没亲眼' in text()
    key('e');click('现场检查');go(550,275);key('e');click('现场检查')
    go(250,395);key('e');click('用记下的交接');assert '还不是谁在何时' in text()
    go(455,465);key('e');click('问交接补记');testimony=obs();assert '是我借的铜舌' in text() and '没有因此答应' in text()
    key('e');remaining=obs();assert any(b['text'].startswith('问他：小满以前') for b in remaining['buttons']),remaining
    out=s.run_dir/'handover-evidence.json';out.write_text(json.dumps({'document':document,'testimony':testimony,'method':'normal new game, public observation and actual inputs only'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:s.stop()
