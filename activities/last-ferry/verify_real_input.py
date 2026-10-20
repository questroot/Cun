"""Known-route regression using real MCP inputs, not blind play.

Run from any directory with Python 3. Godot is resolved by the shared service.
Creates only an isolated project/save; evidence stays in ignored MCP .runtime.
No external HTTP endpoint or credentials are needed. Always stops its owned game.
"""
import argparse
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--render', action='store_true', help='Use an ordinary game window; no screenshot capture.')
parser.add_argument('--boat-approach',action='store_true',help='Observe initial approach and reload before arrival')
parser.add_argument('--awning-after-closing',action='store_true',help='Tie awning after Zhou moves to old steps')
parser.add_argument('--tag-at-dawn',action='store_true',help='Carry ferry tag through departure and return it next morning; requires boat approach')
args = parser.parse_args()
if args.tag_at_dawn and not args.boat_approach: parser.error('--tag-at-dawn requires --boat-approach')
s=PlayService()
receipts=[]
original_call=s.call
def recorded_call(name,arguments):
    try:
        result=original_call(name,arguments);receipts.append({'name':name,'arguments':arguments,'result':result});return result
    except Exception as error:
        receipts.append({'name':name,'arguments':arguments,'error':str(error)});raise
s.call=recorded_call
def obs():return s.call('observe',{})
def key(k,n=1):return s.call('action',{'kind':'key','key':k,'frames':n})
def click(prefix):
    o=obs();b=next((b for b in o['buttons'] if b['text'].startswith(prefix)),None)
    for _ in range(8):
        if b: break
        down=next((v for v in o['buttons'] if v['text']=='向下翻阅'),None)
        if not down: break
        s.call('action',{'kind':'click','button_id':down['id']})
        o=obs();b=next((v for v in o['buttons'] if v['text'].startswith(prefix)),None)
    assert b,(prefix,o)
    return s.call('action',{'kind':'click','button_id':b['id']})
def walk(axis,target):
    for _ in range(16):
        p=obs()['visible'][0]['player_screen'];d=target-p[axis]
        if abs(d)<10:return
        key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(100,max(2,int(abs(d)/2))))
    raise AssertionError(('blocked',axis,target,p))
def go(x,y):walk('y',400);walk('x',x);walk('y',y)
def inspect(x,y):go(x,y);key('e');click('现场检查')
try:
    s.call('launch',{'project':'last-ferry','headless':not args.render});click('许宁 ·')
    go(600,290);key('e');click('停下脚步')
    key('e');click('端起搪瓷盆');go(450,380);key('e');click('把盆放在新湿痕');key('e');click('重新端起接水');assert obs()['visible'][0]['visible_basin']['appearance']=='端在手上',obs()
    go(320,375);key('e');click('坐一会儿');go(450,575);key('e')
    go(620,430);key('e');click('说说旧屋漏点');assert '明早量桥前' in json.dumps(obs(),ensure_ascii=False),obs()
    go(750,390);key('e')
    inspect(125,290);inspect(250,395);inspect(550,275);inspect(620,425)
    go(455,465);key('e');click('问他：黄灯底座');click('问他：小满以前');click('提出解释：等候');click('问他：小满以前');click('提议只把今晚')
    agreed=obs();assert '收的是这个' in json.dumps(agreed,ensure_ascii=False),agreed
    click('先不做');assert not obs()['visible'][0]['modal_open'],obs()
    click('准备好了');click('确认');go(750,565);key('e')
    if args.boat_approach:
        approaching=next(o for o in obs()['visible'][0]['objects'] if '正靠近' in o['title']);assert approaching['y']<295,approaching
        s.call('action',{'kind':'key','key':'d','duration_ms':250});moving=next(o for o in obs()['visible'][0]['objects'] if '夜船' in o['title']);assert approaching['y']<moving['y']<295,(approaching,moving)
        click('保存');click('读取');click('确认');assert any('正靠近' in o['title'] for o in obs()['visible'][0]['objects']),obs()
        s.call('action',{'kind':'key','key':'a','duration_ms':1000});s.call('action',{'kind':'key','key':'d','duration_ms':300});assert any(o['title']=='靠岸夜船' and o['y']==295 for o in obs()['visible'][0]['objects']),obs()
    if args.boat_approach:
        go(700,330);key('e');click('许宁独有：踏上');deck=obs();assert deck['visible'][0]['location']=='夜船·靠岸侧舷',deck
        go(685,440);key('e');click('听沈渡说明');assert 'visible_ferry_tag' in obs()['visible'][0],obs()
        key('e');click('还没决定');assert 'visible_ferry_tag' not in obs()['visible'][0] and any(o['title']=='舷边刻着字的木渡牌' for o in obs()['visible'][0]['objects']),obs()
        click('保存');click('读取');click('确认');assert 'visible_ferry_tag' not in obs()['visible'][0],obs()
        key('e');click('听沈渡说明');assert 'visible_ferry_tag' in obs()['visible'][0],obs()
        click('保存');click('读取');click('确认');assert obs()['visible'][0]['location']=='夜船·靠岸侧舷' and 'visible_ferry_tag' in obs()['visible'][0],obs()
        go(450,540);key('e');back_on_bank=obs();assert back_on_bank['visible'][0]['location']=='旧石阶' and any(o['title']=='靠岸夜船' for o in back_on_bank['visible'][0]['objects']),back_on_bank
        assert '次日尾声' not in '\n'.join(back_on_bank['texts']) and '侵入 0 / 2' in '\n'.join(back_on_bank['texts']),back_on_bank
    if args.boat_approach and not args.tag_at_dawn:
        go(115,565);key('e');go(175,355);key('e');click('把交班渡牌');returned_tag=obs();assert 'visible_ferry_tag' not in returned_tag['visible'][0] and any('挂回的旧渡牌' in o['title'] for o in returned_tag['visible'][0]['objects']),returned_tag
        click('保存');click('读取');click('确认');assert any('挂回的旧渡牌' in o['title'] for o in obs()['visible'][0]['objects']),obs()
        go(750,565);key('e')
    go(460,335);click('先站在干阶听河声');key('1');key('1');key('2');key('3')
    river=obs();assert not river['visible'][0]['modal_open'] and '我以为你听不出来了' in json.dumps(river,ensure_ascii=False),river
    key('e');click('问他：你希望')
    click('请周伯先辨认');click('听父女谈');click('明确问她');click('询问沈渡');click('经本人同意')
    go(115,565);key('e');go(455,465);key('e');click('转述本人意愿')
    go(750,565);key('e');go(460,335);key('e');click('把两岸的答复')
    started=obs();assert '次日尾声' not in '\n'.join(started['texts'])
    assert '当面挂回钟腹' in json.dumps(started,ensure_ascii=False),started
    if args.awning_after_closing:
        go(115,565);key('e');assert any('空凳' in o['title'] for o in obs()['visible'][0]['objects']),obs()
        go(690,350);key('e');click('握住绳端');s.call('action',{'kind':'key','key':'s','duration_ms':600});key('e');awning_closed=obs()
        assert '周伯的凳子空着' in '\n'.join(awning_closed['texts']) and '周伯挪了' not in '\n'.join(awning_closed['texts']),awning_closed
        assert '棚绳系在木桩' in awning_closed['visible'][0]['visible_awning']['appearance'],awning_closed
        go(750,565);key('e')
    go(590,445);key('e');click('留在干阶上');rung=obs();assert '那边也应了' in json.dumps(rung,ensure_ascii=False)
    key('escape');departed=obs();assert any(o['title']=='已离岸的夜船' for o in departed['visible'][0]['objects']),departed
    click('保存');key('d',8);click('读取');click('确认')
    restored=obs();assert restored['visible'][0]['player_screen']==departed['visible'][0]['player_screen'],restored
    assert '次日尾声' not in '\n'.join(restored['texts']) and any(o['title']=='已离岸的夜船' for o in restored['visible'][0]['objects']),restored
    key('e');click('船离岸后');click('不必等话');click('确认');dawn=obs();assert '次日尾声' in '\n'.join(dawn['texts']) and '结束渡程' in json.dumps(dawn,ensure_ascii=False)
    go(115,565);key('e')
    if args.tag_at_dawn:
        assert 'visible_ferry_tag' in obs()['visible'][0],obs()
        go(175,355);key('e');click('把交班渡牌');assert 'visible_ferry_tag' not in obs()['visible'][0],obs()
        click('保存');click('读取');click('确认');assert any('挂回的旧渡牌' in o['title'] for o in obs()['visible'][0]['objects']),obs()
    go(95,565);key('e');street_morning=obs();assert not any(o['title']=='围挡旁补鞋的老葛' for o in street_morning['visible'][0]['objects']),street_morning
    assert any('按约去许家' in o['title'] for o in street_morning['visible'][0]['objects']),street_morning
    go(100,440);key('e')
    assert any(o['title']=='门口等你招呼的老葛' for o in obs()['visible'][0]['objects']),obs()
    go(500,510);key('e');click('到门口招呼');assert '钥匙没有交出去' in json.dumps(obs(),ensure_ascii=False),obs()
    entering=next(o for o in obs()['visible'][0]['objects'] if '走向屋内' in o['title']);assert entering['x']<635,entering
    s.call('action',{'kind':'key','key':'d','duration_ms':300});progress=next(o for o in obs()['visible'][0]['objects'] if '老葛' in o['title']);assert entering['x']<progress['x']<635,(entering,progress)
    click('保存');click('读取');click('确认')
    resumed=next(o for o in obs()['visible'][0]['objects'] if '老葛' in o['title']);assert resumed['title']=='按约来勘看的老葛' and resumed['x']==635 and resumed['y']==490,resumed
    assert any(o['title']=='按约来勘看的老葛' for o in obs()['visible'][0]['objects']),obs()
    go(635,450);key('e');click('请他跟自己');go(510,395)
    s.call('action',{'kind':'key','key':'d','duration_ms':300});s.call('action',{'kind':'key','key':'a','duration_ms':300})
    click('保存');click('读取');click('确认')
    guide=next(o for o in obs()['visible'][0]['objects'] if '已看清漏点' in o['title']);assert guide['x']==565 and guide['y']==395,guide
    go(450,575);key('e');away=obs();assert not any(o['kind']=='npc' and '老葛' in o['title'] for o in away['visible'][0]['objects']),away
    go(100,440);key('e');guide=next(o for o in obs()['visible'][0]['objects'] if '已看清漏点' in o['title']);go(guide['x'],guide['y'])
    key('e');click('请他从干处');inspection=obs();assert '两项工序' in json.dumps(inspection,ensure_ascii=False),inspection
    completed_guest=next(o for o in inspection['visible'][0]['objects'] if '分项工序的老葛' in o['title']);assert (completed_guest['x'],completed_guest['y'])==(guide['x'],guide['y']),completed_guest
    click('保存');click('读取');click('确认');loaded_guest=next(o for o in obs()['visible'][0]['objects'] if '分项工序的老葛' in o['title']);assert (loaded_guest['x'],loaded_guest['y'])==(565,395),loaded_guest
    assert any(o['title']=='桌边的两项修屋工序纸' for o in obs()['visible'][0]['objects']),obs()
    go(400,410);key('e');click('展开工序纸');work_note=obs();assert '没有完工勾记' in json.dumps(work_note,ensure_ascii=False),work_note
    assert obs()['visible'][0]['visible_basin']['appearance']=='端在手上',obs();assert '盆还没有放回漏点' in json.dumps(work_note,ensure_ascii=False),work_note
    go(480,365);key('e');click('把端着的盆放回');assert obs()['visible'][0]['visible_basin']['appearance']=='接住滴水',obs()
    go(320,375);key('e');click('先请人看屋顶');morning=obs();assert '两项工序' in json.dumps(morning,ensure_ascii=False)
    basin=morning['visible'][0]['visible_basin'];assert basin['x']==450 and basin['y']==340 and basin['appearance']=='接住滴水',morning
    go(450,575);key('e');go(450,565);key('e');click('离开这段体验');click('确认')
    left=obs();assert '旅途记录' in json.dumps(left,ensure_ascii=False) and any('返回身份选择' in b['text'] for b in left['buttons']),left
    out=s.run_dir/'release-evidence.json';out.write_text(json.dumps({'begun':started,'rope_released':rung,'departed_world':departed,'restored_mid_scene':restored,'dawn':dawn,'morning_choice':morning,'formal_departure':left,'method':'normal opening, bounded MCP inputs only; coordinator knows route, not blind play'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:
    try:s.call('stop',{})
    finally:
        s.stop()
        if s.run_dir:(s.run_dir/'release-input-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2),encoding='utf-8')
