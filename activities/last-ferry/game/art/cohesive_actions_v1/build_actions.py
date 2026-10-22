"""Reproduce six true generated action key-pose cutouts, never invent animation."""
from pathlib import Path
import json,hashlib,shutil
from PIL import Image
import numpy as np
P=Path(__file__).resolve().parent
DIGEST='19aa360fc89a635539bc7659ed49843200b3f6f567f55a1d3157d3b3307f9364'
src=P/'actions_source.png'
if not src.exists():raise FileNotFoundError(f'Restore delivered actions_source.png with SHA256 {DIGEST}; private attachment stores are not build inputs.')
assert hashlib.sha256(src.read_bytes()).hexdigest()==DIGEST
im=Image.open(src).convert('RGBA')
# Manually observed isolated windows, absolute raw-image socket coordinates.
# Common scale for ALL poses: young standing body ~=490 source pixels ->76 logical.
SCALE=76/490
POSES=[
 ('zhou_drag_E',[130,10,515,455],[285,430],None,[[395,284],[492,246]],[[190,425],[350,426]]),
 ('zhou_seated_E',[640,25,925,455],[810,443],[717,295],[[818,283],[865,247]],[[800,440],[869,400]]),
 ('zhou_half_squat_E',[1095,35,1460,455],[1230,438],[1180,292],[[1335,278],[1413,230]],[[1200,432],[1267,374]]),
 ('protagonist_carry_S',[145,475,430,990],[302,973],None,[[248,727],[342,720]],[[245,965],[369,969]]),
 ('protagonist_carry_E',[680,475,950,990],[782,976],None,[[900,650],[905,722]],[[731,909],[805,968]]),
 ('protagonist_carry_N',[1125,475,1410,990],[1270,971],None,[[1162,648],[1376,653]],[[1220,963],[1326,947]])]
rows=[]
board=Image.new('RGBA',(960,640),(181,186,182,255))
for i,(name,box,foot,seat,hands,feet) in enumerate(POSES):
 arr=np.array(im.crop(box)); alpha=arr[:,:,3].copy();arr[:,:,3]=np.where(alpha>=200,alpha,0)
 out=Image.fromarray(arr);bounds=out.getbbox();assert bounds
 out=out.crop(bounds);out.save(P/(name+'.png'))
 ox,oy=box[0]+bounds[0],box[1]+bounds[1]
 def local(pt):return [pt[0]-ox,pt[1]-oy] if pt else None
 f=local(foot);s=local(seat);hs=[local(pt) for pt in hands]
 record={'id':name,'path':name+'.png','source_window':box,'crop_in_window':list(bounds),'source_offset':[ox,oy],'source_size':list(out.size),'sha256':hashlib.sha256((P/(name+'.png')).read_bytes()).hexdigest(),'scale':SCALE,'foot_anchor':f,'seat_anchor':s,'hand_sockets':hs,'foot_contacts':[local(pt) for pt in feet],'suggested_display_rect_relative_to_foot':[-f[0]*SCALE,-f[1]*SCALE,out.width*SCALE,out.height*SCALE],'anchor_confidence':'MANUAL_ESTIMATE_REQUIRES_REAL_STOOL_ALIGNMENT','frames':1,'loop':False,'duration':None,'status':'KEY_POSE_CANDIDATE_NOT_INTEGRATED','world_foot_offset':[0,20 if name.startswith('zhou') else 24],'no_baked_stool':True,'defects':['Approximate textual identity/style only; elder has new moustache/beard absent in previous standing sheet.','Camera shallower than requested overhead70deg; integration perspective QC required.','Sockets estimated on visible palms/seat, not proven actual gripping or supported sitting.']}
 if 'carry_N' in name: record['defects'].append('Rear view hand visibility limited; exact forward reach depth ambiguous.')
 if 'seated' in name: record['seat_relative_display']=[(s[0]-f[0])*SCALE,(s[1]-f[1])*SCALE]
 rows.append(record)
 view=out.copy();view.thumbnail((280,280),Image.Resampling.LANCZOS);board.alpha_composite(view,((i%3)*320+(320-view.width)//2,(i//3)*320+(320-view.height)//2))
board.save(P/'qc_poses.png')
manifest={'schema':'shelter-action-keyposes-v1','status':'PARTIAL_KEYPOSES_NEED_ALIGNMENT_REVIEW','integrated':False,'provider':'gpt','model':'gpt-image-2.5','imageRequestId':'image-afac13b2-3304-4a2b-af0d-99676041ea2d','receipt':{'path':'actions_source.png','sha256':DIGEST,'attachmentId':'sha256:'+DIGEST,'mediaType':'image/png','width':1536,'height':1024,'bytes':1846176},'generation_calls':1,'reference_conditioning':False,'source_alpha_extrema':im.getchannel('A').getextrema(),'operations':['byte-identical original copy and hash assertion','manual independent source windows','alpha below200 removed; native RGB/remaining alpha unchanged','tight crop only, no repaint and no per-pose scaling','one common display scale76/490'],'reproduce':'build_actions.py','poses':rows,'animation_limit':'Six static key poses only; drag/seated/half-squat are genuinely different generated anatomy. No walk gait cycle or sit transition frames. Runtime interpolation must not be called full animation.','runtime_contract':['Only one independent runtime stool; bind grips to authoritative chair, not predicted duplicate.','Seated pelvis socket must align real chair seat; ground feet and pelvis cannot both be assumed solved by translating without verification.','Actors world foot offsets player+(0,24), zhou+(0,20), collision untouched.','Use shared scale; do not enlarge seated pose to standing visible height.','Interrupt poses on actual movement/reversal; no baked motion/root movement.'],'missing':['walking gait frames','carry gait and pickup/drop transition frames','drag gait frames','full4-frame stand-to-sit transition','human verified identity continuity','verified hand/seat joint alignment'],'engine_tested':False,'human_accepted':False}
(P/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print([(r['id'],r['source_size'],r['foot_anchor'],r['hand_sockets']) for r in rows])
