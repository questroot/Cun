"""Known-route optional arrival, return for luggage, placement and persistence; genuine inputs."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
s=PlayService()
receipts=[]
def call(name,arguments):
    record={'name':name,'arguments':arguments}
    receipts.append(record)
    try:
        result=s.call(name,arguments)
        record['result']=result
        return result
    except Exception as error:
        record['error']={'type':type(error).__name__,'message':str(error)}
        raise
    finally:
        if s.run_dir:
            (s.run_dir/'arrival-input-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2),encoding='utf-8')
def obs():return call('observe',{})
def key(k,n=1):return call('action',{'kind':'key','key':k,'frames':n})
def click(t):
    o=obs();b=next((b for b in o['buttons'] if b['text'].startswith(t)),None);assert b,(t,o)
    return call('action',{'kind':'click','button_id':b['id']})
def go(x,y):
    for axis,target in [('y',400),('x',x),('y',y)]:
        for _ in range(18):
            p=obs()['visible'][0]['player_screen'];d=target-p[axis]
            if abs(d)<10:break
            key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(100,max(2,int(abs(d)/2))))
        else:raise AssertionError(('blocked',axis,target,p))
lane_visits=0
cart_moved=False
def lane_to(dest):
    global lane_visits,cart_moved
    lane_visits+=1
    assert obs()['visible'][0]['location']=='修桥绕行巷',obs()
    click('保存');click('读取');click('确认')
    assert not any(b['text'].startswith('准备好了') for b in obs()['buttons']),obs()
    barrier=obs()['visible'][0]['visible_barrier'];assert barrier['x']==390 and barrier['height']==220,barrier
    if dest=='house' and not cart_moved:
        key('w',100);key('d',120);key('d',120)
        blocked=obs()['visible'][0]['player_screen'];assert blocked['x']<390 and 280<blocked['y']<500,blocked
        if lane_visits==1:key('a',35)
        if lane_visits>1:
            key('e');click('握住车把');assert '正握住车把' in json.dumps(obs(),ensure_ascii=False),obs()
            grip=obs()['visible'][0];call('action',{'kind':'key','key':'a','duration_ms':150});pulled=obs()['visible'][0]
            assert pulled['player_screen']['x']<grip['player_screen']['x'] and abs(pulled['player_screen']['y']-grip['player_screen']['y'])<0.01,(grip,pulled)
            assert abs((pulled['visible_cart']['x']-grip['visible_cart']['x'])-(pulled['player_screen']['x']-grip['player_screen']['x']))<0.1,(grip,pulled)
            key('e')
            partial=obs();cart=next(o for o in partial['visible'][0]['objects'] if '空手推车' in o['title']);partial_x=cart['x'];assert 260<partial_x<350,partial;assert abs(partial['visible'][0]['visible_cart']['x']-partial_x-80)<0.1,partial;assert '正握住车把' not in json.dumps(partial,ensure_ascii=False),partial
            click('保存');click('读取');click('确认')
            assert next(o for o in obs()['visible'][0]['objects'] if '空手推车' in o['title'])['x']==partial_x,obs()
            key('e');click('握住车把');click('保存');click('读取');click('确认')
            before_y=obs()['visible'][0]['player_screen']['y'];key('s',8);assert obs()['visible'][0]['player_screen']['y']>before_y+3,obs()
            key('w',8);key('e');click('握住车把');key('a',120);key('a',60);key('e');cart_moved=True
            assert '缺口已通' in obs()['visible'][0]['visible_barrier']['appearance'],obs()
            for axis,target in [('y',540),('x',500),('y',400)]:
                for _ in range(30):
                    p=obs()['visible'][0]['player_screen'];d=target-p[axis]
                    if abs(d)<10:break
                    key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(80,max(2,int(abs(d)/2))))
            assert obs()['visible'][0]['player_screen']['x']>480,obs()
            key('a',120);crossed=obs()['visible'][0]['player_screen'];assert crossed['x']<385 and 380<crossed['y']<420,crossed
            key('d',120);assert obs()['visible'][0]['player_screen']['x']>480,obs()
    x,y=(745,350) if dest=='house' else (100,540)
    for axis,target in [('y',540),('x',x),('y',y)]:
        for _ in range(30):
            p=obs()['visible'][0]['player_screen'];d=target-p[axis]
            if abs(d)<10:break
            key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(80,max(2,int(abs(d)/2))))
        else:raise AssertionError(('lane blocked',p))
    key('e')
try:
    call('launch',{'project':'last-ferry','headless':True});click('许宁到埠前段')
    assert not any(b['text'].startswith('准备好了') for b in obs()['buttons']),obs()
    go(570,370);key('e');click('请他指');assert '桥修好以后' in json.dumps(obs(),ensure_ascii=False),obs()
    click('保存');click('读取');click('确认');assert obs()['visible'][0]['location']=='桥头落客点',obs()
    go(745,540);key('e');lane_to('house');assert any(b['text'].startswith('准备好了') for b in obs()['buttons']),obs()
    go(100,550);key('e');lane_to('arrival');assert obs()['visible'][0]['location']=='桥头落客点',obs()
    call('action',{'kind':'mouse','x':305,'y':360});assert 'carried_luggage' not in obs()['visible'][0],obs()
    go(305,400);call('action',{'kind':'mouse','x':305,'y':360});assert 'carried_luggage' in obs()['visible'][0],obs()
    go(745,540);key('e');lane_to('house');go(590,550);call('action',{'kind':'mouse','x':590,'y':510});placed=obs();assert 'carried_luggage' not in placed['visible'][0],placed
    click('保存');click('读取');click('确认');loaded=obs();assert any(o['title']=='门内自己的行李箱' for o in loaded['visible'][0]['objects']),loaded
    key('e');assert not any(b['text'].startswith('把自己的行李') for b in obs()['buttons']),obs();key('escape')
    key('e');click('重新提起');assert 'carried_luggage' in obs()['visible'][0],obs()
    go(100,550);key('e');lane_to('arrival');assert 'carried_luggage' in obs()['visible'][0],obs()
    click('保存');click('读取');click('确认');assert 'carried_luggage' in obs()['visible'][0],obs()
    go(745,540);key('e');lane_to('house');go(590,550);call('action',{'kind':'mouse','x':590,'y':510});assert 'carried_luggage' not in obs()['visible'][0],obs()
    go(600,290);key('e');click('停下脚步');key('e');click('端起搪瓷盆')
    go(450,380);key('e');click('把盆放在新湿痕');basin=obs();assert basin['visible'][0]['visible_basin']['appearance']=='接住滴水',basin
    key('e');click('重新端起接水');assert obs()['visible'][0]['visible_basin']['appearance']=='端在手上',obs()
    key('e');click('把盆放在新湿痕');assert obs()['visible'][0]['visible_basin']['appearance']=='接住滴水',obs()
    go(450,550);key('e');go(260,370);key('e');click('旧屋还在漏水');assert '老葛' in json.dumps(obs(),ensure_ascii=False),obs()
    go(620,430);key('e');click('说说旧屋漏点');assert '没有报价' in json.dumps(obs(),ensure_ascii=False),obs()
    key('e');assert not any(b['text'].startswith('说说旧屋漏点') for b in obs()['buttons']),obs();click('已约明早');assert '记着呢' in json.dumps(obs(),ensure_ascii=False),obs()
    click('保存');click('读取');click('确认');go(100,440);key('e');go(600,290);key('e');click('看看记下');assert '梁缝没有变小' in json.dumps(obs(),ensure_ascii=False),obs()
    go(695,270);key('e');click('翻看照片');photo=obs();assert '新棚启用前' in json.dumps(photo,ensure_ascii=False),photo
    go(100,550);key('e');lane_to('arrival');go(305,400);key('e');assert any(b['text']=='行李已留在旧屋门内' for b in obs()['buttons']),obs()
    key('escape');go(745,540);key('e');lane_to('house');go(450,550);key('e');go(620,430)
    click('准备好了');click('确认');click('保存');click('读取');click('确认');key('e')
    assert not any(b['text'].startswith('说说旧屋漏点') for b in obs()['buttons']),obs()
    click('已约明早');assert '记着呢' in json.dumps(obs(),ensure_ascii=False),obs()
    out=s.run_dir/'arrival-evidence.json';out.write_text(json.dumps({'placed':placed,'loaded':loaded,'basin':basin,'photo':photo},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:call('stop',{})
