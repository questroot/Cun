"""Generated art postprocess only. No repaint, geometric art or invented frames.
Run with bundled Python/Pillow/numpy. Originals remain byte-identical.
"""
from pathlib import Path
import hashlib,json,shutil
from PIL import Image
import numpy as np
P=Path(__file__).resolve().parent
RECEIPTS=[
 {'id':'background','imageRequestId':'image-e0aa28f0-edbf-433f-88b1-350d2959e3d4','sha256':'9ff4b7de31b1e3010111895c38d362a457a58abf4bcbef26fd1e9282937b80f5','size':[1448,1086],'bytes':2263667},
 {'id':'props','imageRequestId':'image-2f200457-ff68-4398-9060-431b56cec6cd','sha256':'e0cd48623258611d526f932029519fbbbb66c004ea713af201aa7ebfddc0544a','size':[1536,1024],'bytes':1555362},
 {'id':'actors','imageRequestId':'image-9504e817-1a00-493f-9bb0-ec0eb20f8a73','sha256':'d8888dfba3bee00ad8a31d2c1f12cdfe5216a804be5ce3fc95b4a4a5a11e9fff','size':[1536,1024],'bytes':1807655}]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
for r in RECEIPTS:
 dst=P/(r['id']+'_source.png')
 if not dst.exists():
  raise FileNotFoundError(f'Expected delivered original {dst.name}; restore the source with SHA256 {r["sha256"]}. No private attachment-store fallback.')
 assert sha(dst)==r['sha256']
 r.update(provider='gpt',model='gpt-image-2.5',path=dst.name,attachmentId='sha256:'+r['sha256'])
# Inspect alpha values; threshold is explicit cleanup, not an art quality claim.
for kind in ['props','actors']:
 a=np.array(Image.open(P/(kind+'_source.png')).convert('RGBA'))[:,:,3]
 print(kind,'alpha distribution',[(t,int((a>=t).sum())) for t in [1,16,64,128,200,240,250,255]])
# Actual visually identified independent object windows; NOT blind equal-cell cropping.
PROP_WINDOWS=[
 ('post',[140,15,230,355],[16,260]),('beam',[375,160,770,220],[694,20]),
 ('table',[805,85,1120,305],[100,70]),('stool',[1270,140,1410,275],[40,28]),
 ('awning',[10,430,390,620],[160,85]),('white_lamp',[515,365,690,640],[40,48]),
 ('warm_lamp',[900,365,1075,640],[40,48]),('yellow_lamp',[1305,405,1430,615],[40,48]),
 ('bell',[120,715,320,960],[44,38]),('rope',[575,675,625,1000],[4,195]),
 ('shade',[875,745,1065,985],[28,36]),('hook',[1300,730,1425,950],[16,30])]
# Alpha>=200 eliminates native low-alpha streaks; keep RGB and native alpha in accepted pixels.
# No recoloring, silhouette drawing, per-frame identity repair, or invented animation.
THRESHOLD=200
records=[]
def cut(kind,name,box,target):
 im=Image.open(P/(kind+'_source.png')).convert('RGBA').crop(box)
 a=np.array(im); old=a[:,:,3].copy(); a[:,:,3]=np.where(old>=THRESHOLD,old,0)
 out=Image.fromarray(a); bounds=out.getbbox()
 if not bounds: return None
 out=out.crop(bounds)
 path=P/(name+'.png'); out.save(path)
 rec={'id':name,'path':path.name,'source':kind+'_source.png','source_window':box,'alpha_threshold':THRESHOLD,'crop_in_window':list(bounds),'size':list(out.size),'sha256':sha(path),'removed_alpha_pixels':int(((old>0)&(old<THRESHOLD)).sum()),'status':'QC_PENDING','target_size':target,'occlusion':'alpha silhouette only; shadows supplied by runtime'}
 records.append(rec); return rec
for name,box,target in PROP_WINDOWS: cut('props',name,box,target)
for row,actor in enumerate(['protagonist','zhou']):
 for col,direction in enumerate(['S','E','N','W']):
  rec=cut('actors',actor+'_'+direction,[col*384,row*512,(col+1)*384,(row+1)*512],[None,76])
  rec.update(direction=direction,actor=actor,clip='stand_static',frames=1,loop=False,foot_anchor=[rec['size'][0]/2,rec['size'][1]],world_foot_offset=[0,24 if row==0 else 20])
# All actor views use ONE shared scale, not separate frame fitting.
heights=[r['size'][1] for r in records if r.get('actor')]
scale=76/max(heights)
for r in records:
 if r.get('actor'):
  r['uniform_scale']=scale;r['display_size']=[round(x*scale,4) for x in r['size']]
# Native background unchanged, extracted sources remain available.
manifest={'schema':'cohesive-neutral-kit-v1','status':'QC_PENDING','integrated':False,'generation_calls':3,'receipts':RECEIPTS,'background':{'path':'background_source.png','size':[1448,1086],'display_rect':[0,0,855,640],'scale_xy':[855/1448,640/1086],'walk_rect':[40,175,780,445],'status':'CANDIDATE','occlusion':'none; static margin structures not runtime collision'},'postprocess':{'script':'build_kit.py','alpha_cutoff':THRESHOLD,'operations':['byte-identical original copy with SHA256 assertion','manual independent-object crop windows','remove alpha<200; preserve all remaining RGB/native alpha','tight alpha crop; no resampling in delivered cutouts','single shared actor display scale'],'note':'Threshold cleanup can lose soft edges; every cutout needs read_image QC. No chromakey, no geometric drawing.'},'layers':records,'animation':'Only 8 generated static standing directions. No walking/carry/drag/sit frames. Motion module may move static art but cannot claim full animation.','reference_conditioning':False,'sampling_recommendation':'linear filtering at common logical scale; no nearest pseudo-pixelation','contact_shadows':'NOT BAKED; runtime separate ellipses, actor24x7 alpha<=.22; stool feet5x2','missing':['walk/carry/drag/sit animations','runtime ground wetness/reflection mask','occluder polygons validated against actual art','emissive masks','notice paper'],'engine_tested':False,'human_accepted':False}
manifest['status']='PARTIAL_NEUTRAL_KIT_REVIEW_REQUIRED'
manifest['background']['status']='READY_CANDIDATE_NOT_INTEGRATED'
manifest['background']['defects']=['Fixed side timber strips and top-center steps baked into static margin; not runtime structures. Steps lie above walk y175.','Slightly anisotropic mapping from4:3 source to855x640; no optical projection calibration.','Neutral base improved but painterly stone mottling remains; no claim of physically pure albedo.']
manifest['registration']={'mapping':'identity logical coords','points':[[95,570],[750,570],[400,355],[250,360],[385,375],[657.5,402.5]],'table_collision':[350,285,100,70],'awning_corners':[[575,195],[735,195],[735,270],[575,280]],'beam':[[76,190],[770,190]],'posts':[[80,190],[80,450],[770,190],[770,450]]}
for r in records:
 r['ready']=False
 r['status']='READY_STATIC_CANDIDATE'
 r['ready_for']='PM/frontend static placement review only; not full game integration'
 r['defects']=[]
 w,h=r['size']
 r['anchor']=[w/2,h]
 if r.get('actor'):
  r['ready']=True
  r['defects']=['Static pose only; no walk/carry/drag/sit frames.','Apparent overhead angle shallower than70deg and viewpoint differs by facing; review against background.','Shoulder silhouette near32 logical px; coat/arms can extend beyond34, do not enlarge collision.']
 elif r['id'] in ['post','beam']:
  r['status']='NOT_READY_PROPORTION_MISMATCH'
  r['defects']=['Generated aspect ratio does not match16x260 post /694x20 beam; stretching to target would distort brush/outline. Do not silently fit.']
 elif r['id'] in ['white_lamp','warm_lamp','yellow_lamp']:
  r['status']='CONDITIONAL_STATIC_ONLY'
  r['defects']=['Pale/yellow glass has painted value highlight; not an independent emissive mask. No glow pool baked but cannot prove truly unlit.','White/warm are different hood colors, not verified full story swapped/shade state set.']
 else:
  r['ready']=True
  r['defects']=['Static single view; exact final camera/footprint and sockets need placement verification.']
 if not r.get('actor'):
  tw,th=r['target_size']; r['suggested_uniform_scale']=tw/w
  r['suggested_display_size']=[tw,round(h*tw/w,4)]
 if r['id']=='table':
  r['world_anchor']=[400,355];r['collision_rect']=[350,285,100,70];r['ground_contact_y']=355
  r['defects'].append('At100px width visible height65.41px; collision remains100x70, not inferred from alpha.')
 if r['id']=='stool':
  r['anchor']=[w/2,h*.42];r['seat_anchor']=r['anchor'];r['grip_anchors']=[[w*.12,h*.42],[w*.88,h*.42]]
  r['foot_contacts']=[[w*.12,h*.95],[w*.85,h*.95]]
  r['collision_size']=[36,20]
  r['status']='CONDITIONAL_SEAT_SOCKET_REVIEW';r['ready']=False
  r['defects'].append('At40px width visible height35.41px rather than28; seat/grips estimated from art require real carry/sit verification.')
 if r['id']=='awning':
  r['anchor']=[0,0];r['deform_to']='runtime authoritative four-corner quadrilateral; source includes edge rods; not a rigid rect collider'
manifest['verification']={'raw_images_read':3,'cutout_contact_sheet_read':True,'native_alpha_present':True,'fake_checkerboard':False,'alpha_cleanup_note':'Raw contains low-alpha horizontal streaks. Threshold200 removes these; on neutral contact sheet no connecting streaks visible. Hardens soft silhouette edges; not a general segmentation proof.','independent_sources':True,'image_reference_input_supported':False,'shared_style':'text prompts only; approximate gouache palette/outline consistency, not guaranteed identical conditioning','engine_import':False,'gameplay':False}
# QC contact sheet: derived sprite pixels only, not a scene or production art.
preview=Image.new('RGBA',(960,720),(180,185,181,255))
for i,r in enumerate(records):
 sprite=Image.open(P/r['path']).convert('RGBA');sprite.thumbnail((165,150),Image.Resampling.LANCZOS)
 preview.alpha_composite(sprite,((i%5)*192+(192-sprite.width)//2,(i//5)*180+(180-sprite.height)//2))
preview.save(P/'qc_cutouts.png')
(P/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
print('CUTOUTS',[(r['id'],r['size']) for r in records])
