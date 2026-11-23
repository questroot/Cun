shader_type canvas_item;
uniform float wetness=0.0;
uniform vec3 illumination : source_color=vec3(1.0);
uniform float pooling=0.0;
uniform int contact_count=0;
uniform vec4 contacts[8]; // ground-local pixels, normalized age, splash scale
// SnowBank owns the forest snow surface, including its edge and lighting.
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float water_at(vec2 ground_uv){
 vec2 p=ground_uv*vec2(272,16)*vec2(0.072,0.18);
 float field=noise(p)*0.65+noise(p*2.15+11.0)*0.35;
 float threshold=mix(1.0,0.36,pooling);
 return smoothstep(threshold-0.045,threshold+0.045,field)*pooling;
}
void fragment(){
 float water=water_at(UV);
 vec3 ground=vec3(0.188,0.22,0.227);
 ground=mix(ground,ground*0.65,wetness*0.65);
 ground=mix(ground,vec3(0.27,0.39,0.42),water*0.65);
 // The local water mask clips each moving ring at the irregular shore.
 float rings=0.0;
 for(int i=0;i<8;i++){
  if(i>=contact_count)break;
  vec4 hit=contacts[i];
  vec2 offset=(UV*vec2(1088.0,64.0)-hit.xy)*vec2(1.0,2.8);
  float front=length(offset)-(1.0+hit.z*10.0)*hit.w;
  if(abs(front)<1.7){
   vec2 hit_uv=hit.xy/vec2(1088.0,64.0);
   if(all(greaterThanEqual(hit_uv,vec2(0.0))) && all(lessThanEqual(hit_uv,vec2(1.0)))){
    rings+=(1.0-smoothstep(0.35,1.7,abs(front)))*(1.0-hit.z)*smoothstep(0.0,0.12,water_at(hit_uv));
   }
  }
 }
 ground+=vec3(0.24,0.29,0.30)*min(rings,1.0)*water;
 COLOR=vec4(ground*illumination,1.0);
}
