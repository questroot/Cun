shader_type canvas_item;
uniform float cover=0.0;
uniform vec3 illumination : source_color=vec3(1.0);
varying vec2 surface_pixel;
void vertex(){surface_pixel=VERTEX;}
float hash_snow(vec2 p){vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float snow_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash_snow(i),hash_snow(i+vec2(1,0)),f.x),mix(hash_snow(i+vec2(0,1)),hash_snow(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 // One continuous foreground surface, including the raised grass contact and lower ground.
 float deposit=0.68+0.32*snow_noise(surface_pixel*vec2(0.018,0.045));
 float local_depth=max(0.0,cover-(1.0-deposit)*0.32);
 float opacity=1.0-exp(-local_depth*6.0);
 float grain=snow_noise(surface_pixel*0.55);
 vec3 snow_color=vec3(0.83,0.89,0.92)+(grain-0.5)*0.035;
 COLOR=vec4(snow_color*illumination,opacity);
}
