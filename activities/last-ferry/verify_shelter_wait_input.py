"""Known-route normal-input shelter fixture; no screenshots/state injection."""
import sys,json,time,hashlib,traceback
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/play_mcp'))
from server import PlayService

def run(route):
 s=PlayService();rows=[];points={};samples=[];r={'route':route,'source_hashes':{n:hashlib.sha256((ROOT/'activities/last-ferry/game'/n).read_bytes()).hexdigest() for n in ['main.gd','story_state.gd']}}
 def call(n,a):
  row={'name':n,'arguments':a,'start_unix':time.time()};t=time.perf_counter()
  try:
   if route=='carry-rope' and n=='action':assert sum(x['name']=='action' for x in rows)<120,'120 action ceiling reached'
   v=s.call(n,a);row['result']=v;return v
  except Exception as e:row['error']=repr(e);raise
  finally:row['elapsed_ms']=(time.perf_counter()-t)*1000;rows.append(row)
 def obs():
  o=call('observe',{})
  if o.get('visible') and 'visible_waiting' in o['visible'][0]:samples.append({'time':time.time(),'waiting':o['visible'][0]['visible_waiting']})
  return o
 def w():return obs()['visible'][0]
 def key(k,ms=None):return call('action',dict(kind='key',key=k,**({'duration_ms':ms} if ms else {'frames':1})))
 def click(p):
  o=obs();b=next(b for b in o['buttons'] if b['text'].startswith(p));return call('action',{'kind':'click','button_id':b['id']})
 def walk(axis,target):
  speed=200.;cap=400;prev=None
  for _ in range(28):
   p=w()['player_screen'];d=target-p[axis]
   if abs(d)<8:return
   if prev is not None and prev*d<0:cap=max(30,cap//2)
   ms=min(cap,max(20,int(abs(d)/speed*800)));k=('d' if d>0 else 'a') if axis=='x' else ('s' if d>0 else 'w');key(k,ms);q=w()['player_screen'];dist=abs(q[axis]-p[axis]);speed=max(80.,min(800.,dist/(ms/1000))) if dist>1 else speed;prev=d
  raise AssertionError(('blocked movement',axis,target,q))
 def go(x,y):walk('y',520);walk('x',x);walk('y',y)
 def snap(label):o=obs();points[label]=o;return o['visible'][0]
 def manifest(base):
  files={str(p.relative_to(base)).replace('\\\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(base.rglob('*')) if p.is_file() and p.suffix.lower() in ('.png','.svg','.webp','.jpg','.ttf','.tres','.wav','.ogg') and '.godot' not in p.parts}
  return {'files':files,'sha256':hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()}
 def pause_moving(label):
  before=snap(label+'_moving')['visible_waiting'];assert '收脚坐着' not in before['zhou']['appearance'],'NPC already seated before motion pause'
  click('记录');assert 'visible_waiting' not in w();key('d',250);key('esc');after=snap(label+'_resumed')['visible_waiting']
  # Opening/closing processes may each advance one render frame, not 250ms of motion.
  a,b=before['zhou'],after['zhou'];assert ((a['x']-b['x'])**2+(a['y']-b['y'])**2)**0.5<12,'wait advances while modal open'
 def settle(label):
  for _ in range(60):
   v=w();wait=v['visible_waiting'];samples.append({'time':time.time(),'waiting':wait})
   if '收脚坐着' in wait['zhou']['appearance']:return
   key('d',30);key('a',30)
  raise AssertionError('NPC never seated '+label)
 try:
  call('launch',{'project':'last-ferry','headless':False});r['copy_hashes']={n:hashlib.sha256((s.run_dir/'project'/n).read_bytes()).hexdigest() for n in r['source_hashes']};assert r['copy_hashes']==r['source_hashes']
  r['source_resources']=manifest(ROOT/'activities/last-ferry/game');r['copy_resources']=manifest(s.run_dir/'project');assert r['source_resources']==r['copy_resources'],'resource manifest mismatch'
  click('许宁 ·');go(450,575);key('e');go(750,390);key('e');snap('entry')
  if route=='carry-rope':
   for update in range(3):
    current=w()
    if current['modal_open']:key('esc');current=w()
    chair=current['visible_waiting']['chair'];go(chair['x']+45,chair['y']+30)
    current=w();chair=current['visible_waiting']['chair'];p=current['player_screen']
    if ((p['x']-chair['x'])**2+(p['y']-chair['y'])**2)**0.5>64:continue
    bounds=chair['bounds'];call('action',{'kind':'mouse','x':bounds['x']+bounds['width']/2,'y':bounds['y']+bounds['height']/2,'button':'left'})
    current=w()
    if 'visible_chair_drop_outline' in current:break
    if current['modal_open']:key('esc')
   assert 'visible_chair_drop_outline' in w(),'chair not acquired in three target updates'
   go(690,380);held=snap('held_at_rope');assert 'visible_chair_drop_outline' in held
   # Actual world click on the publicly observed rope, not E (E means drop while carrying).
   rope=next(o for o in held['objects'] if '松绳' in o['title'])
   call('action',{'kind':'mouse','x':rope['x'],'y':rope['y'],'button':'left'})
   o=obs();points['rope_attempt_while_carried']=o
   grip=next((b for b in o['buttons'] if b['text'].startswith('握住绳端')),None)
   if grip:
    call('action',{'kind':'click','button_id':grip['id']});points['grip_attempt_response']=obs();r['held_attempt']='grip button clicked; inspect narrative for refusal'
   else:r['held_attempt']='world rope clicked but grip UI unavailable; no backend refusal claimed'
   if w()['modal_open']:key('esc')
   after=snap('held_after_attempt');assert 'visible_chair_drop_outline' in after,'rope attempt lost carried chair';assert after['visible_awning']==held['visible_awning'],'rope attempt altered awning'
   key('e');dropped=snap('dropped');assert 'visible_chair_drop_outline' not in dropped
   # Stay beside the rope, sidestep the dropped solid before normal E interaction if needed.
   walk('x',750);walk('y',350);key('e');click('握住绳端');before=snap('free_grip')['visible_awning'];key('s',120);after=snap('free_pull')['visible_awning'];assert after['lower_edge_y']<before['lower_edge_y'],'free hands failed to grip/pull'
   r['ok']=True
   return True
  # No intervention must leave the eastern exit reachable.
  go(750,565);key('e');assert w()['location']=='旧石阶';snap('unassisted_exit');go(115,565);key('e');assert w()['location']=='候船棚'
  if route=='A':
   go(690,380);key('e');click('握住绳端');before=snap('rope_gripped')['visible_awning'];key('s',600);after=snap('actually_pulled')['visible_awning'];assert after['lower_edge_y']<before['lower_edge_y'];key('e');v=snap('tied');assert 'visible_dry_patch' in v
   pause_moving('A')
   go(750,520);settle('A');snap('A_seated')
  else:
   chair=w()['visible_waiting']['chair'];go(chair['x'],chair['y']+50);key('e');assert 'visible_chair_drop_outline' in w();go(540,478);key('e');v=snap('wet_placement');assert 'visible_chair_drop_outline' not in v and '右棚沿仍滴水' in v['visible_waiting']['drips']
   key('e');assert 'visible_chair_drop_outline' in w();go(380,368);key('e');snap('left_dry_placement');pause_moving('B');walk('x',300);walk('y',520);walk('x',250);settle('B');snap('B_seated')
  seated=w()['visible_waiting'];z=seated['zhou'];go(z['x']+65,z['y']);call('action',{'kind':'mouse','x':z['x'],'y':z['y']-23,'button':'left'});talk=snap('moved_zhou_talk');assert talk['modal_open'],'moved NPC not talkable by near click';key('esc')
  click('保存');click('读取');click('确认');snap('restored');assert 'visible_chair_drop_outline' not in w()
  before_modal=w()['visible_waiting'];click('记录');assert 'visible_waiting' not in w();key('d',100);key('esc');assert w()['visible_waiting']==before_modal;snap('after_modal')
  # Stationary current-target buttons must survive ordinary process frames.
  o=obs();key('d');key('a');o2=obs();points['button_stability_before']=o;points['button_stability_after']=o2
  ids=lambda v:{b['text']:b['id'] for b in v['buttons']}
  assert ids(o)==ids(o2),'stationary target buttons rebuilt'
  click('当前目标');key('esc')
  # Public NPC sample speed envelope; allow observation transport/frame slack.
  moving=0
  for a,b in zip(samples,samples[1:]):
   x,y=a['waiting']['zhou'],b['waiting']['zhou'];dist=((x['x']-y['x'])**2+(x['y']-y['y'])**2)**0.5
   if dist>0.1:moving+=1
   assert dist<=75*(b['time']-a['time']+0.15)+4,'NPC position jumps beyond movement envelope'
  assert moving>=2,'insufficient continuous NPC movement samples'
  r['npc_moving_sample_pairs']=moving
  r['ok']=True
 except Exception:r['ok']=False;r['failure']=traceback.format_exc();print(r['failure'],flush=True)
 finally:
  try:r['stop']=call('stop',{})
  finally:
   s.stop();r.update(receipts=rows,checkpoints=points,npc_samples=samples)
   if s.run_dir:
    out=s.run_dir/('shelter-'+route+'-evidence.json');out.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'route':route,'ok':r['ok'],'evidence':str(out),'calls':len(rows)},ensure_ascii=False),flush=True)
 return r['ok']
if __name__=='__main__':
 routes=['carry-rope'] if '--carry-rope-only' in sys.argv else ['A','B']
 outcomes=[run(route) for route in routes];sys.exit(0 if all(outcomes) else 1)
