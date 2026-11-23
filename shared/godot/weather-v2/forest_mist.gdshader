shader_type canvas_item;
uniform float amount=0.0;
uniform vec3 air_color : source_color=vec3(0.66,0.73,0.75);
uniform float wind_travel=0.0;
uniform float sun_strength=0.0;
uniform vec3 sun_tint : source_color=vec3(1.0,0.77,0.45);
uniform float depth=1.0;
uniform int style=0; // 0 weather, 1 ground, 2 drifting local bank
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
// Signed distance is valid on either side of the density peak.
float gaussian(float d){return exp(-d*d);}
void fragment(){
 vec2 p=UV*vec2(3.4,2.3)+vec2(-wind_travel,depth*5.0);
 float variation=noise(p)*0.75+noise(p*2.1)*0.25;
 float height=1.0;
 float density=0.70+variation*0.12;
 if(style==1){height=smoothstep(0.40,0.94,UV.y);density=0.40+variation*0.24;}
 if(style==2){height=smoothstep(0.12,0.72,UV.y);density=smoothstep(0.26,0.72,variation)*0.8;}
 float optical_depth=amount*depth*height*density*1.7;
 // Existing canopy-gap aligned shafts in interleaved mist, not a full-screen glow overlay.
 float shaft_a=gaussian((UV.x-(0.18+UV.y*0.16))/0.055);
 float shaft_b=gaussian((UV.x-(0.69+UV.y*0.12))/0.085);
 float shafts=(shaft_a*0.65+shaft_b*0.45)*(1.0-UV.y*0.55)*sun_strength;
 COLOR=vec4(air_color+sun_tint*shafts*0.30,1.0-exp(-optical_depth));
}
