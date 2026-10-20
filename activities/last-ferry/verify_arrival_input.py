"""Known-route optional arrival, return for luggage, placement and persistence; genuine inputs."""
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
    s.call('launch',{'project':'last-ferry','headless':True});click('许宁到埠前段')
    assert not any(b['text'].startswith('准备好了') for b in obs()['buttons']),obs()
    go(570,370);key('e');click('请他指');assert '桥修好以后' in json.dumps(obs(),ensure_ascii=False),obs()
    click('保存');click('读取');click('确认');assert obs()['visible'][0]['location']=='桥头落客点',obs()
    go(745,540);key('e');assert any(b['text'].startswith('准备好了') for b in obs()['buttons']),obs()
    go(100,550);key('e');assert obs()['visible'][0]['location']=='桥头落客点',obs()
    s.call('action',{'kind':'mouse','x':305,'y':360});assert 'carried_luggage' not in obs()['visible'][0],obs()
    go(305,400);s.call('action',{'kind':'mouse','x':305,'y':360});assert 'carried_luggage' in obs()['visible'][0],obs()
    go(745,540);key('e');go(590,550);s.call('action',{'kind':'mouse','x':590,'y':510});placed=obs();assert 'carried_luggage' not in placed['visible'][0],placed
    click('保存');click('读取');click('确认');loaded=obs();assert any(o['title']=='门内自己的行李箱' for o in loaded['visible'][0]['objects']),loaded
    key('e');assert not any(b['text'].startswith('把自己的行李') for b in obs()['buttons']),obs();key('escape')
    key('e');click('重新提起');assert 'carried_luggage' in obs()['visible'][0],obs()
    go(100,550);key('e');assert 'carried_luggage' in obs()['visible'][0],obs()
    click('保存');click('读取');click('确认');assert 'carried_luggage' in obs()['visible'][0],obs()
    go(745,540);key('e');go(590,550);s.call('action',{'kind':'mouse','x':590,'y':510});assert 'carried_luggage' not in obs()['visible'][0],obs()
    go(600,290);key('e');click('停下脚步');key('e');click('端起搪瓷盆')
    go(450,380);key('e');click('把盆放在新湿痕');basin=obs();assert basin['visible'][0]['visible_basin']['appearance']=='接住滴水',basin
    go(695,270);key('e');click('翻看照片');photo=obs();assert '新棚启用前' in json.dumps(photo,ensure_ascii=False),photo
    go(100,550);key('e');go(305,400);key('e');assert any(b['text']=='行李已留在旧屋门内' for b in obs()['buttons']),obs()
    out=s.run_dir/'arrival-evidence.json';out.write_text(json.dumps({'placed':placed,'loaded':loaded,'basin':basin,'photo':photo},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:s.stop()
