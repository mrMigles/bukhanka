shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
uniform float wetness = 0.0;
uniform float detail_strength = 1.0;
uniform sampler2D ground_detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D tracks : filter_linear, repeat_disable;
uniform vec2 track_origin = vec2(-10000.0);
uniform vec3 vehicle = vec3(0.0);
uniform float vehicle_heading = 0.0;
vec4 trail(vec2 p) {
 vec2 uv=(p-track_origin)/128.0;
 if(any(lessThan(uv,vec2(0)))||any(greaterThan(uv,vec2(1)))) return vec4(0);
 return texture(tracks,uv);
}
void vertex() {
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y-=trail(world_pos.xz).r*0.22;
}
void fragment() {
 vec3 detail=texture(ground_detail,world_pos.xz*0.25).rgb;
 float gravel=mix(0.5,detail.r,detail_strength);
 float mud=1.0-step(0.38,COLOR.r);
 float pool=smoothstep(0.62,0.82,detail.g)*mud*wetness;
 ALBEDO=COLOR.rgb*(0.80+(0.22-mud*0.12)*gravel+detail.g*0.10)*(1.0-wetness*0.22);
 ALBEDO=mix(ALBEDO,vec3(0.17,0.15,0.11),pool*0.6);
 ALBEDO+=vec3(0.07,0.055,0.025)*detail.b*(1.0-mud);
 float rut=trail(world_pos.xz).r;
 ALBEDO=mix(ALBEDO,vec3(0.14,0.105,0.065),rut*0.70);
 vec2 p=world_pos.xz-vehicle.xz;
 vec2 under=vec2(cos(vehicle_heading)*p.x-sin(vehicle_heading)*p.y,sin(vehicle_heading)*p.x+cos(vehicle_heading)*p.y)/vec2(1.6,2.7);
 float contact=(1.0-smoothstep(0.2,1.0,length(under)))*(1.0-smoothstep(1.0,3.0,abs(world_pos.y-vehicle.y)));
 ALBEDO*=1.0-contact*0.22;
 ROUGHNESS=mix(mix(0.88,0.30,wetness),0.18,pool);
 SPECULAR=0.4;
 NORMAL_MAP=vec3(0.5+(gravel-0.5)*0.13,0.5+(detail.g-0.5)*0.08,1.0);
 NORMAL_MAP_DEPTH=0.3;
}
