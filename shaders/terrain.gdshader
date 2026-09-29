shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tracks : filter_linear, repeat_disable;
uniform vec2 track_origin = vec2(-10000.0);
uniform float wetness = 0.0;
uniform bool web_lite = false;
uniform vec3 vehicle = vec3(0.0);
varying vec3 wp;
varying vec4 tint;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
vec4 trail(vec2 p) { vec2 uv=(p-track_origin)/128.0; if(any(lessThan(uv,vec2(0)))||any(greaterThan(uv,vec2(1))))return vec4(0); return texture(tracks,uv); }
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; VERTEX.y-=trail(wp.xz).r*0.22; tint=COLOR; }
void fragment() {
 float grain=0.5, patch=0.5, broad=noise(wp.xz*0.08);
 if (!web_lite) { grain=noise(wp.xz*14.0); patch=noise(wp.xz*0.55); }
 float grass=step(tint.r*1.05,tint.g)*step(tint.b,tint.g*0.92);
 float snow=smoothstep(0.63,0.88,min(tint.r,min(tint.g,tint.b)));
 vec4 mark=trail(wp.xz);
 vec3 color=tint.rgb*(0.70+patch*0.14+broad*0.12);
 color=mix(color,color*vec3(0.87,1.05,0.78),grass*grain*0.25);
 color*=1.0-wetness*(1.0-snow)*0.16;
 // A soft contact shadow follows the van even on the low-cost web renderer.
 vec2 under=(wp.xz-vehicle.xz)/vec2(2.0,3.0);
 float contact=(1.0-smoothstep(0.2,1.0,length(under)))*(1.0-smoothstep(1.0,3.0,abs(wp.y-vehicle.y)));
 color*=1.0-contact*0.30;
 ALBEDO=mix(color,mix(vec3(0.16,0.12,0.075),vec3(0.38,0.41,0.39),snow),mark.r*0.75);
 ROUGHNESS=mix(0.92,0.28,wetness*(1.0-snow)*(0.4+mark.r*0.6));
 NORMAL_MAP=normalize(vec3((grain-0.5)*0.14,(patch-0.5)*0.1,1.0))*0.5+0.5; NORMAL_MAP_DEPTH=0.45;
}
