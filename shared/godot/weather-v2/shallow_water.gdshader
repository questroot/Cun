shader_type spatial;
render_mode cull_disabled;
uniform float clock=0.0;
uniform float rain_intensity=0.0;
uniform float breeze=0.35;
uniform vec2 surface_size=vec2(2.3,4.7);
uniform float water_column=0.065; // Actual water plane minus solid bed top, in metres.
uniform int rain_ripple_count=0;
// x/z: actual surface hit; z: normalized age; w: bounded event scale.
uniform vec4 rain_ripples[12];
vec2 ripple_slope(vec2 p){
 vec2 slope=vec2(0.0);
 for(int i=0;i<12;i++){
  if(i>=rain_ripple_count){break;}
  vec4 event=rain_ripples[i];
  vec2 offset=p-event.xy;
  float r=length(offset);
  float front=r-(0.024+0.41*event.z)*event.w;
  float pulse=exp(-abs(front)*29.0)*sin(front*65.0);
  float envelope=smoothstep(0.0,0.1,event.z)*(1.0-smoothstep(0.42,1.0,event.z));
  slope+=offset/max(r,0.012)*pulse*envelope*0.12;
 }
 return clamp(slope,vec2(-0.22),vec2(0.22));
}
uniform bool diagnostic_old_noise=false;
uniform bool diagnostic_old_waves=false;
uniform bool diagnostic_old_displacement=false;
uniform sampler2D reflection_tex : filter_linear, repeat_disable;
uniform mat4 reflection_vp;
uniform bool has_reflection=false;
varying vec3 world;
// Avoid large-multiplier sine hashing in temporally sampled light patterns.
float hash(vec2 p){if(diagnostic_old_noise)return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 vec2 edge=min(UV,vec2(1.0)-UV)*surface_size;
 float distance_to_wall=min(edge.x,edge.y);
 // Inset bed depth plus uneven sediment, rather than a wide painted pale frame.
 float depth=max(0.0,water_column)*(1.0-0.12*noise(p*0.8));
 float shallows=exp(-distance_to_wall*13.0);
 vec2 drift=vec2(clock*0.035,-clock*0.023);
 float sediment=noise(p*14.0+noise(p*3.0));
 vec3 bed=mix(vec3(0.20,0.25,0.21),vec3(0.34,0.36,0.27),sediment);
 // Approximate refracted path to the bed; grazing views also gain Fresnel reflection below.
 float incidence=clamp(abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0);
 float cos_in_water=sqrt(1.0-(1.0-incidence*incidence)/(1.333*1.333));
 float transmission=exp(-depth*3.0/cos_in_water);
 vec3 water_tint=vec3(0.055,0.18,0.20);
 ALBEDO=mix(water_tint,bed,transmission*0.42+shallows*0.12);
 float moving_light=pow(max(0.0,sin(p.x*11.0+p.y*7.0+noise(p*2.0+drift)*4.0+clock*0.5)),12.0);
 ALBEDO+=vec3(0.10,0.14,0.12)*moving_light*transmission*0.16*(breeze+rain_intensity);
 // Fetch is short beside the solid rim. Dampen wind chop there without
 // suppressing actual drop contacts over the rest of the pool.
 float wind_fetch=mix(0.22,1.0,smoothstep(0.0,0.22,distance_to_wall));
 float amplitude=(0.002+breeze*0.10)*wind_fetch;
 float nx=sin(p.x*2.6+p.y*1.4-clock*0.38)+0.16*sin(p.y*6.0+clock*0.43);
 float ny=cos(p.y*3.0-p.x*0.9-clock*0.31)+0.14*sin(p.x*5.5-clock*0.47);
 if(diagnostic_old_waves){nx=sin(p.x*7.0+p.y*3.5-clock*0.8)+0.35*sin(p.y*19.0+clock*1.1);ny=cos(p.y*8.0-p.x*2.0-clock*0.62)+0.3*sin(p.x*17.0-clock*1.3);}
 vec2 rain_slope=ripple_slope(p)*smoothstep(0.0,0.11,distance_to_wall);
 // Slopes and hit locations are in world XZ, not the mesh UV tangent frame.
 // Keep highlights aligned with the same contact even if the receiver is yawed.
 vec2 world_tilt=vec2(nx,ny)*amplitude+rain_slope;
 vec3 tilted_world_normal=normalize(vec3(world_tilt.x,1.0,world_tilt.y));
 NORMAL=normalize(mat3(VIEW_MATRIX)*tilted_world_normal);
 ROUGHNESS=0.16+rain_intensity*0.12+shallows*0.08;
 SPECULAR=0.65;
 METALLIC=0.0;
 if(has_reflection){
  vec4 projected=reflection_vp*vec4(world,1.0);
  vec2 reflected_uv;

  // A few reflection texels of coherent drift distinguish breeze from mirror-calm.
   // Reflection displacement is separate from shading slope: breeze stays sub-texel.
    float reflection_displacement=(0.00008+breeze*0.0006+rain_intensity*0.0012)*wind_fetch;
    if(diagnostic_old_displacement){reflection_displacement=amplitude*0.10;}
     // Offset on the water plane, not fixed screen axes (world metres).
   vec2 shift_m=(vec2(nx,ny)*reflection_displacement+rain_slope*0.006)*4.0;
   projected+=reflection_vp*vec4(shift_m.x,0.0,shift_m.y,0.0);
   reflected_uv=projected.xy/max(projected.w,0.0001)*vec2(0.5,-0.5)+0.5;
  vec3 reflected_color=texture(reflection_tex,clamp(reflected_uv,vec2(0.002),vec2(0.998))).rgb;
  float fresnel=0.035+0.965*pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),5.0);
  float reflection_amount=clamp(0.18+fresnel*0.75,0.0,0.85)*(1.0-shallows*0.25);
  // Out-of-view reflection texels have no scene information. Return to the
   // water/bed shading instead of stretching the last reflected column.
   vec2 view_edge=min(reflected_uv,vec2(1.0)-reflected_uv);
   reflection_amount*=step(0.0001,projected.w)*smoothstep(0.002,0.024,min(view_edge.x,view_edge.y));
   ALBEDO*=1.0-reflection_amount;
  EMISSION=reflected_color*reflection_amount;
 }
}
