import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
s=PlayService()
def obs():return s.call('observe',{})
def key(k,n=1):return s.call('action',{'kind':'key','key':k,'frames':n})
def click(t):
    o=obs(); b=next((b for b in o['buttons'] if b['text'].startswith(t)),None);assert b,(t,o)
    return s.call('action',{'kind':'click','button_id':b['id']})
def go(x,y):
    for axis,target in [('y',400),('x',x),('y',y)]:
        for _ in range(18):
            p=obs()['visible'][0]['player_screen'];d=target-p[axis]
            if abs(d)<10:break
            key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(100,max(2,int(abs(d)/2))))
        else:raise AssertionError(('blocked',axis,target,p))
def mouse(x,y):return s.call('action',{'kind':'mouse','x':x,'y':y})
# Known-route input regression, not an independent player or image-quality verdict.
try:
    s.call('launch',{'project':'last-ferry','headless':True});click('许宁 ·')
    go(695,270);key('e');click('翻看照片');photo=obs();assert '新棚启用前' in json.dumps(photo,ensure_ascii=False)
    go(450,575);key('e');go(750,390);key('e');go(750,565);key('e')
    for x,y,label in [(165,485,'沿树根'),(330,510,'数矮阶'),(485,445,'蹲下看')]:
        go(x,y);mouse(x,y-40);assert not obs()['visible'][0]['modal_open'],obs()
    go(460,335);key('e');click('拿照片到现场');click('保存');click('读取');click('确认')
    assert not any(b['text'].startswith('收起照片') for b in obs()['buttons']),obs()
    key('e');click('拿照片到现场');assert 'held_photo' in obs()['visible'][0],obs()
    click('收起照片');assert 'held_photo' not in obs()['visible'][0],obs()
    key('e');click('拿照片到现场');go(115,565);key('e');assert 'held_photo' not in obs()['visible'][0],obs()
    go(750,565);key('e');go(460,335);key('e');click('拿照片到现场')
    key('e');wrong=obs();assert '缆绳槽' in json.dumps(wrong,ensure_ascii=False)
    go(485,445);key('e');right=obs();assert '旧照片拍摄的岸上' in json.dumps(right,ensure_ascii=False) and not right['visible'][0]['modal_open'],right
    go(115,565);key('e');go(455,465);key('e');click('告诉他亲眼核对');zhou=obs()
    assert '新棚是我跟人一起挪的' in json.dumps(zhou,ensure_ascii=False) and '不能替她说' in json.dumps(zhou,ensure_ascii=False),zhou
    assert any(b['text'].startswith('问他：小满以前') for b in zhou['buttons']),zhou
    out=s.run_dir/'photo-evidence.json';out.write_text(json.dumps({'photo':photo,'wrong':wrong,'comparison':right,'zhou_response':zhou,'method':'normal opening actual key and mouse controls only'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:s.stop()

