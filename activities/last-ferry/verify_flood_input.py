"""Known-route deliberate warned failure and safe aftermath; public real inputs only."""
import sys,json,argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/play_mcp'))
from server import PlayService
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--identity',choices=['he','xu'],default='he')
parser.add_argument('--late-gauge',action='store_true',help='Xu first inspects gauge only after flooding')
parser.add_argument('--tie-awning',action='store_true',help='Tie shelter awning through real movement before dangerous signals')
parser.add_argument('--evac-pack',action='store_true',help='Carry neighbour bedding through dry lane to bridgehead')
parser.add_argument('--bridge-exit',action='store_true',help='Cancel then confirm safe departure at bridgehead after delivery')
parser.add_argument('--decline-help-exit',action='store_true',help='Leave at bridgehead without accepting any evacuation parcel')
parser.add_argument('--first-step-water',action='store_true',help='Visit stone steps and reload visible first-intrusion water before second warning')
args=parser.parse_args()
if args.bridge_exit and not args.evac_pack:parser.error('--bridge-exit requires --evac-pack')
if args.late_gauge and args.identity!='xu':parser.error('--late-gauge requires --identity xu')
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
def lane_go(x,y):
    for tx,ty in [(player_x(),540),(x,540),(x,y)]:
        for axis,target in [('x',tx),('y',ty)]:
            for _ in range(35):
                p=obs()['visible'][0]['player_screen'];d=target-p[axis]
                if abs(d)<10:break
                key((('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w')),min(80,max(2,int(abs(d)/2))))
            else:raise AssertionError(('lane blocked',p))
def player_x():return obs()['visible'][0]['player_screen']['x']
def gauge_visit(expected):
    go(100,550);key('e');lane_go(650,320)
    o=obs();assert any(expected in t['title'] for t in o['visible'][0]['objects']),o
    if args.late_gauge:
        assert '首次查看施工水尺：水线越过上格' in '\n'.join(o['texts']),o
        click('保存');click('读取');click('确认');click('记录');journal=obs()
        text='\n'.join(journal['texts'])
        assert text.count('首次查看施工水尺：水线越过上格')==1,text
        assert '回访施工水尺' not in text and '首次查看施工水尺：蓝字' not in text and '首次查看施工水尺：新水线' not in text,text
        key('esc')
    lane_go(745,350);key('e');go(450,575);key('e')
try:
    s.call('launch',{'project':'last-ferry','headless':True});click('许宁到埠前段' if args.identity=='xu' else '阿禾 ·')
    if args.identity=='xu':
        go(745,540);key('e')
        if not args.late_gauge:
            lane_go(650,320);assert any('低处湿线' in t['title'] for t in obs()['visible'][0]['objects']),obs()
        lane_go(745,350);key('e');go(450,575);key('e')
    else: go(320,385);key('e');click('向陶婶借手提黄灯')
    click('准备好了');click('确认')
    for _ in range(2):
        go(750,390);key('e')
        if args.tie_awning and _==0:
            go(690,350);key('e');click('握住绳端')
            s.call('action',{'kind':'key','key':'s','duration_ms':600});key('e')
            assert '棚绳系在木桩，棚下干处' in obs()['visible'][0]['visible_awning']['appearance'],obs()
        go(250,395);key('e');click('危险：举白灯');click('确认')
        if args.first_step_water and _==0:
            go(750,390);key('e');go(750,565);key('e');water=obs()['visible'][0]['visible_step_water'];assert water['y']==310 and water['height']==34,water
            click('保存');click('读取');click('确认');assert obs()['visible'][0]['visible_step_water']==water,obs()
            go(115,565);key('e');go(95,565);key('e')
        if args.identity=='xu' and _==0 and not args.late_gauge:
            go(95,565);key('e');go(100,440);key('e');gauge_visit('中格')
    flooded=obs();assert '次日尾声' in '\n'.join(flooded['texts']) and '侵入 2 / 2' in '\n'.join(flooded['texts']),flooded
    if args.identity=='xu':
        go(100,480);key('e');gauge_visit('上格');go(100,480);key('e');go(320,380);key('e');click('留联络方式')
        assert '路和水势要先确认' in json.dumps(obs(),ensure_ascii=False),obs()
        go(450,575);key('e')
    else:
        go(320,385);key('e');click('擦干提柄');assert '领人过桥' in json.dumps(obs(),ensure_ascii=False),obs()
    go(620,510);key('e');click('问老葛今早');ge=obs();assert '撤离包' in json.dumps(ge,ensure_ascii=False),ge
    if args.decline_help_exit:
        assert 'visible_evac_pack' not in obs()['visible'][0],obs()
        go(100,550);key('e');lane_go(100,540);key('e');go(300,510);key('e');click('离开这段体验');click('取消')
        assert '旅途记录' not in '\n'.join(obs()['texts']),obs()
        key('e');click('离开这段体验');click('确认');assert '旅途记录' in '\n'.join(obs()['texts']),obs()
        print(json.dumps({'ok':True,'declined_help':True,'runtime':str(s.run_dir)},ensure_ascii=False));sys.exit(0)
    if args.evac_pack:
        key('e');click('接过扎好的');assert 'visible_evac_pack' in obs()['visible'][0],obs()
        key('e');click('这趟不能送');assert 'visible_evac_pack' not in obs()['visible'][0],obs()
        key('e');click('接过扎好的');click('保存');click('读取');click('确认');assert 'visible_evac_pack' in obs()['visible'][0],obs()
        go(100,550);key('e');dry_lane=obs()['visible'][0]['visible_dry_lane'];assert dry_lane['y']==510 and dry_lane['height']==60,dry_lane
        lane_go(100,dry_lane['y']+dry_lane['height']/2);key('e')
        bridge=obs();assert not any(('班车司机' in o['title'] or '自己的行李箱' in o['title']) for o in bridge['visible'][0]['objects']),bridge
        assert bridge['visible'][0]['visible_receiver_table']['width']==110,bridge
        if args.bridge_exit:
            go(300,510);key('e');click('离开这段体验');click('确认');assert '你还托着邻居' in '\n'.join(obs()['texts']) and '托着' in obs()['visible'][0]['visible_evac_pack']['appearance'],obs()
        go(570,370);key('e');click('按登记交给河街');assert 'visible_evac_pack' in obs()['visible'][0] and '还没看清' in '\n'.join(obs()['texts']),obs()
        key('e');click('托住包');assert '河街十二号' in '\n'.join(obs()['texts']) and '陈家' in obs()['visible'][0]['visible_evac_pack']['cloth_tag'],obs()
        key('e');click('按登记交给六码头');assert '不收住户被褥' in '\n'.join(obs()['texts']) and '托着' in obs()['visible'][0]['visible_evac_pack']['appearance'],obs()
        key('e');click('按登记交给河街');delivered=obs();assert '已交接' in delivered['visible'][0]['visible_evac_pack']['appearance'],delivered
        click('保存');click('读取');click('确认');assert '已交接' in obs()['visible'][0]['visible_evac_pack']['appearance'],obs()
        if args.bridge_exit:
            go(300,510);key('e');click('离开这段体验');click('取消');assert '旅途记录' not in '\n'.join(obs()['texts']),obs()
            key('e');click('离开这段体验');click('确认');assert '旅途记录' in '\n'.join(obs()['texts']),obs()
            print(json.dumps({'ok':True,'bridge_exit':True,'runtime':str(s.run_dir)},ensure_ascii=False));sys.exit(0)
        go(745,540);key('e');click('保存');click('读取');click('确认');click('记录');lane_journal='\n'.join(obs()['texts']);assert lane_journal.count('这里石料南侧的浅色人行带仍干')==1,lane_journal
        key('esc')
        if args.identity=='xu':
            lane_go(745,350);key('e');assert any('屋' in obs()['visible'][0]['location'] for _ in [0]),obs()
            go(100,550);key('e');assert 'visible_dry_lane' in obs()['visible'][0],obs()
        lane_go(745,550);key('e');assert not any(o['title']=='老葛扎好的邻居被褥包' for o in obs()['visible'][0]['objects']),obs()
    go(750,390);key('e');shelter=obs();titles=[o['title'] for o in shelter['visible'][0]['objects']]
    click('保存');click('读取');click('确认');shelter=obs()
    assert any(o['x']==705 and o['y']==522 for o in shelter['visible'][0]['obstacles']),shelter
    if args.tie_awning:
        awning=shelter['visible'][0]['visible_awning']
        assert awning['rope_end_y']==440 and '下面已漫水，不能避水' in awning['appearance'],awning
        assert not any('棚绳' in o['title'] for o in shelter['visible'][0]['objects']),shelter
    assert 'sealed_equipment' in shelter['visible'][0] and 'visible_equipment' not in shelter['visible'][0],shelter
    assert '撤离后封起的灯钟与停航告示' in titles and not any(t in titles for t in ['白罩船灯','去旧石阶','周伯']),titles
    go(750,495);key('s',80);assert obs()['visible'][0]['player_screen']['y']<522,obs()
    go(455,470);key('e');click('看看这里今早');notice=obs();assert '普通渡船停航' in json.dumps(notice,ensure_ascii=False),notice
    go(95,565);key('e');go(450,565);key('e');click('离开这段体验');click('确认');left=obs();assert '旅途记录' in json.dumps(left,ensure_ascii=False),left
    out=s.run_dir/'flood-evidence.json';out.write_text(json.dumps({'flood':flooded,'ge':ge,'shelter':shelter,'notice':notice,'departure':left,'method':'two explicitly confirmed signals, no injected state'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'ok':True,'evidence':str(out)},ensure_ascii=False))
finally:
    try:s.call('stop',{})
    finally:
        s.stop()
        if s.run_dir:(s.run_dir/'flood-input-receipts.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2),encoding='utf-8')
