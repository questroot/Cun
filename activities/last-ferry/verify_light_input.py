"""Known-route genuine-input regression: apprentice order, lamp repair and morning.
Contains route spoilers; not for independent blind players. No state injection.
Runs in an isolated game/save and stops only its own process in finally.
"""
import argparse
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--render',action='store_true')
args=parser.parse_args()
s=PlayService()
def obs():return s.call('observe',{})
def key(k,n=1):return s.call('action',{'kind':'key','key':k,'frames':n})
def click(prefix):
    o=obs();b=next((b for b in o['buttons'] if b['text'].startswith(prefix)),None)
    for _ in range(8):
        if b:break
        down=next((v for v in o['buttons'] if v['text']=='向下翻阅' and not v['disabled']),None)
        if not down:break
        s.call('action',{'kind':'click','button_id':down['id']});o=obs();b=next((v for v in o['buttons'] if v['text'].startswith(prefix)),None)
    assert b,(prefix,o)
    return s.call('action',{'kind':'click','button_id':b['id']})
def walk(axis,target):
    for _ in range(16):
        p=obs()['visible'][0]['player_screen'];d=target-p[axis]
        if abs(d)<10:return
        key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(100,max(2,int(abs(d)/2))))
    raise AssertionError(('blocked',axis,target,p))
def go(x,y):
    # Stay below the furniture while crossing the shelter.
    walk('y',400);walk('x',x);walk('y',y)
def inspect(x,y):
    go(x,y);key('e');click('现场检查')
try:
    s.call('launch',{'project':'last-ferry','headless':not args.render});click('阿禾 ·')
    go(320,385);key('e');click('向陶婶借手提黄灯')
    go(420,275);s.call('action',{'kind':'mouse','x':420,'y':235});click('确认');kept=obs();assert '今晚未交' in json.dumps(kept,ensure_ascii=False)
    assert kept['visible'][0]['visible_wick']['appearance']=='柜台干货格留存的灯芯',kept
    walk('x',750);walk('y',390);key('e')
    go(455,465);key('e');click('亲口说明这卷');explained=obs();assert '你也会自己拿主意了' in json.dumps(explained,ensure_ascii=False);key('escape')
    inspect(125,290);inspect(250,395);inspect(550,275);inspect(620,425)
    go(455,465);key('e');click('问他：黄灯底座');click('问他：小满以前');click('提出解释：等候');click('提议只把今晚');key('escape')
    go(250,395)
    s.call('action',{'kind':'mouse','x':250,'y':360});s.call('action',{'kind':'mouse','x':250,'y':360})
    go(550,275);s.call('action',{'kind':'mouse','x':550,'y':240})
    click('准备好了');click('确认');go(620,425)
    s.call('action',{'kind':'mouse','x':620,'y':390});click('确认')
    lit=obs();assert '入夜' in '\n'.join(lit['texts']) and '次日尾声' not in '\n'.join(lit['texts']),lit
    go(750,565);key('e');go(590,445);key('e');click('站到周伯身旁')
    rung=obs();assert '听见了' in json.dumps(rung,ensure_ascii=False),rung
    click('不替他们补话');silent=obs();assert '今夜没有新客' in json.dumps(silent,ensure_ascii=False)
    click('再看看岸');click('今夜到这里');click('确认')
    dawn=obs();assert '次日尾声' in '\n'.join(dawn['texts']),dawn
    go(115,565);key('e');go(95,565);key('e');go(320,385);key('e');click('擦干提柄')
    returned=obs();assert '没烫着吧' in json.dumps(returned,ensure_ascii=False),returned
    key('i');assert '手提黄灯：' not in '\n'.join(obs()['texts']);key('escape')
    go(450,565);key('e');click('离开这段体验');click('确认');left=obs()
    assert '旅途记录' in json.dumps(left,ensure_ascii=False) and any('返回身份选择' in b['text'] for b in left['buttons']),left
    out=s.run_dir/'shore-evidence.json';out.write_text(json.dumps({'order_kept':kept,'order_explained':explained,'lit_still_night':lit,'rung':rung,'silence':silent,'dawn':dawn,'lamp_returned':returned,'formal_departure':left,'method':'normal opening, real visible button/key/mouse inputs only'},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:s.stop()
