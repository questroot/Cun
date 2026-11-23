shader_type canvas_item;
// Source-alpha edge receiver: follows existing grass/root silhouette, never fills transparent gaps.
uniform float cover=0.0;
varying vec4 layer_tint;
void vertex(){layer_tint=COLOR;}
void fragment(){
 vec4 source=texture(TEXTURE,UV);
 vec2 texel=TEXTURE_PIXEL_SIZE;
 float open_above=1.0-texture(TEXTURE,UV-vec2(0.0,texel.y)).a;
 float open_above2=1.0-texture(TEXTURE,UV-vec2(0.0,texel.y*2.0)).a;
 // Restrict to lower foreground vegetation; no invented tree-canopy snow from flattened sprites.
 float ground_band=smoothstep(0.86,0.92,UV.y);
 // This carrier has brown grass and dark tree silhouettes; explicit carrier mask, not auto semantic inference.
 float grass=smoothstep(0.18,0.30,source.r)*smoothstep(0.025,0.10,source.r-source.b);
 ground_band*=grass;
 float cap=clamp(open_above+open_above2*smoothstep(0.35,0.85,cover)*0.55,0.0,1.0);
 float settled=cap*ground_band*smoothstep(0.05,0.65,cover)*source.a;
 COLOR=vec4(mix(source.rgb,vec3(0.80,0.86,0.89),settled),source.a)*layer_tint;
}
