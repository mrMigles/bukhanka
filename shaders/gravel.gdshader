shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
uniform float wetness = 0.0;
uniform bool web_lite = false;
uniform sampler2D tracks : filter_linear, repeat_disable;
uniform vec2 track_origin = vec2(-10000.0);
uniform vec3 vehicle = vec3(0.0);
vec4 trail(vec2 p) { vec2 uv=(p-track_origin)/128.0; if(any(lessThan(uv,vec2(0)))||any(greaterThan(uv,vec2(1))))return vec4(0); return texture(tracks,uv); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; VERTEX.y-=trail(world_pos.xz).r*.22; }
void fragment() {
 float gravel = 0.5;
 if (!web_lite) gravel = mix(noise(world_pos.xz * 12.0), 0.5, clamp(length(fwidth(world_pos.xz)) * 6.0, 0.0, 1.0));
 float patch = noise(world_pos.xz * 0.7);
 float mud = 1.0 - step(0.38, COLOR.r);
 float pool = smoothstep(0.72, 0.90, patch) * mud * wetness;
 ALBEDO = COLOR.rgb * (0.60 + (0.20 - mud * 0.12) * gravel + patch * 0.12) * (1.0 - wetness * 0.25);
 ALBEDO = mix(ALBEDO, vec3(0.17, 0.15, 0.11), pool * 0.65);
 float rut=trail(world_pos.xz).r;
 ALBEDO=mix(ALBEDO,vec3(.12,.095,.06),rut*.70);
 float contact=(1.0-smoothstep(.2,1.0,length((world_pos.xz-vehicle.xz)/vec2(2,3))))*(1.0-smoothstep(1.0,3.0,abs(world_pos.y-vehicle.y)));
 ALBEDO*=1.0-contact*.30;
 ROUGHNESS = mix(mix(0.78, 0.29, wetness), 0.20, pool);
 SPECULAR = 0.38;
}
