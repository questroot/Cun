shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float amount=0.0;
uniform float clock=0.0;
uniform vec2 wind_travel=vec2(0.0);
uniform bool diagnostic_static_mist=false;
uniform bool weather_volume=false;
float hash_mist(vec2 p){vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float mist_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash_mist(i),hash_mist(i+vec2(1,0)),f.x),mix(hash_mist(i+vec2(0,1)),hash_mist(i+vec2(1,1)),f.x),f.y);}
uniform vec3 air_color : source_color=vec3(0.61,0.69,0.71);
uniform vec3 lamp_position=vec3(-1.8,2.0,0.5);
uniform vec3 lamp_color : source_color=vec3(1.0,0.55,0.23);
uniform float lamp_energy=0.0;
uniform vec3 sun_direction=vec3(0.5,0.7,0.3);
uniform vec3 sun_color : source_color=vec3(1.0,0.75,0.45);
uniform float sun_energy=1.0;
uniform vec3 center=vec3(-4.5,0.8,0.8);
uniform float strength=0.32;
uniform vec3 extent=vec3(4.5,1.5,7.0);
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
// Signed distance is valid on either side of the density peak.
float gaussian(float d){return exp(-d*d);}
void fragment(){
 float depth=texture(scene_depth,SCREEN_UV).r;
 // Reverse-Z sky has depth zero. Use a finite distant ray endpoint rather
 // than discarding haze on background pixels or dividing an infinite point.
 // Compatibility NDC depth is [-1,1]; Forward+ uses [0,1].
 float ndc_z=mix(CLIP_SPACE_FAR,1.0,max(depth,0.00001));
 vec4 view_point=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,ndc_z,1.0);
 view_point/=view_point.w;
 vec3 endpoint=(INV_VIEW_MATRIX*view_point).xyz;
 // Per-pixel near-plane origin works with both orthographic and perspective cameras.
 vec4 near_point=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,1.0,1.0);
 near_point/=near_point.w;
 vec3 origin=(INV_VIEW_MATRIX*near_point).xyz;
 float ray_length=length(endpoint-origin);
 if(ray_length<=0.000001)discard;
 vec3 ray=(endpoint-origin)/ray_length;
 float surface_distance=min(ray_length,100.0);
 // Analytic ray/box bounds, then eight height-density evaluations; not light scattering.
 // Preserve each slab direction, including tiny negative components.
 vec3 direction_sign=mix(vec3(-1.0),vec3(1.0),step(vec3(0.0),ray));
 vec3 inverse_ray=direction_sign/max(abs(ray),vec3(0.000001));
 vec3 a=(center-extent-origin)*inverse_ray;
 vec3 b=(center+extent-origin)*inverse_ray;
 vec3 low=min(a,b),high=max(a,b);
 float entry=max(0.0,max(low.x,max(low.y,low.z)));
 float exit_distance=min(surface_distance,min(high.x,min(high.y,high.z)));
 // Weather haze occupies air above the receiver plane, never underground.
 // Clip the interval before sampling so eight samples cover the actual air span.
 if(weather_volume){
  if(ray.y < -0.000001)exit_distance=min(exit_distance,-origin.y/ray.y);
  else if(ray.y > 0.000001)entry=max(entry,-origin.y/ray.y);
  else if(origin.y<0.0)exit_distance=entry;
 }
 // Foreground geometry, sky rays missing the volume and empty air have no fog contribution.
 if(exit_distance<=entry || amount<=0.0 || strength<=0.0)discard;
 float interval=exit_distance-entry;
 float density_sum=0.0;
 float lamp_sum=0.0;
 for(int i=0;i<8;i++){
  vec3 p=origin+ray*(entry+interval*(float(i)+0.5)/8.0);
  vec3 local=(p-center)/extent;
  float boundary=(1.0-smoothstep(0.45,1.0,length(local.xz)))*(1.0-smoothstep(0.55,1.0,abs(local.y)));
  // Keep clear gaps above a shallow bank; no uniform opaque floor wash.
   // Suspended bank with a soft near-ground fade, rather than maximum density on the floor.
    float bank_height=0.65+0.18*sin(p.x*0.30+p.z*0.22);
    float height=gaussian((p.y-bank_height)/0.70)*smoothstep(0.02,0.25,p.y);
   float pocket=0.58+0.22*sin(p.x*0.38+p.z*0.61+clock*0.035)+0.20*cos(p.z*0.82-p.x*0.27);
   height*=smoothstep(0.18,0.75,pocket);
  float folds=0.8+0.12*sin(p.x*0.65+p.z*0.48+clock*0.08)+0.08*sin(p.z*1.2-clock*0.06);
  if(!diagnostic_static_mist){
    // Advect world-space density through fixed soft bounds, not a sliding screen overlay.
    vec2 drift=p.xz-wind_travel;
    vec2 warp=vec2(mist_noise(drift*0.23+clock*0.025),mist_noise(drift*0.23+17.0-clock*0.018));
    vec2 lane=vec2(drift.x*0.16,drift.y*0.38);
     float billow=mist_noise(lane+warp*0.25)*0.85+mist_noise(lane*2.0-warp*0.15)*0.15;
    float moving_height=0.65+0.08*sin(drift.x*0.18+drift.y*0.24);
    height=gaussian((p.y-moving_height)/0.85)*smoothstep(0.04,0.35,p.y);
    folds=mix(0.12,1.50,smoothstep(0.30,0.70,billow));
   }
   // Broad weather haze reaches upper silhouettes without the ground-bank peak.
   if(weather_volume)height=exp(-max(p.y,0.0)*0.16)*0.30;
   // Keep the authored enclosed house clear up to the roof; allow haze above it.
   vec2 outside_wall=max(abs(p.xz-vec2(0.0,-2.0))-vec2(4.7,3.0),vec2(0.0));
   float exterior=smoothstep(0.0,0.32,max(length(outside_wall),p.y-5.8));
   float density=boundary*height*folds*exterior;
  density_sum+=density;
  float distance_to_lamp=length(p-lamp_position);
  // Bounded light-proximity approximation, not shadowed volumetric scattering.
  lamp_sum+=density*pow(max(0.0,1.0-distance_to_lamp/5.0),2.0);
 }
 float opacity=1.0-exp(-interval*density_sum/8.0*amount*strength);
 // Mild directional forward lobe, artistic single-scattering approximation (no shadow map).
 float alignment=dot(ray,normalize(sun_direction));
 float forward_lobe=0.20+0.35*pow(max(0.0,alignment),4.0);
 ALBEDO=air_color+lamp_color*lamp_energy*lamp_sum/max(density_sum,0.001)*0.45+sun_color*sun_energy*forward_lobe*0.12;
 ALPHA=clamp(opacity,0.0,0.80);
}
