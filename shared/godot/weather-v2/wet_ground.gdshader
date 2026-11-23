shader_type spatial;
render_mode cull_disabled;
uniform bool wet=false; // legacy bridge, new driver uses continuous values
uniform float wetness=0.0;
uniform float pooling=0.0;
uniform float clock=0.0;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float low=noise(p*0.65)*0.58+noise(p*1.6+17.2)*0.28+noise(p*4.5)*0.14;
 float threshold=mix(1.08,0.38,pooling);
 float water=smoothstep(threshold-0.035,threshold+0.045,low)*pooling;
 vec3 base=vec3(0.32,0.35,0.33);
 ALBEDO=mix(base,base*vec3(0.63,0.7,0.74),wetness);
 ALBEDO=mix(ALBEDO,vec3(0.12,0.21,0.23),water*0.65);
 ROUGHNESS=mix(0.92,0.52,wetness)*(1.0-water)+0.14*water;
 METALLIC=0.0;
}
