shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tracks : filter_linear, repeat_disable;
uniform sampler2D ground_detail : filter_linear_mipmap, repeat_enable;
uniform vec2 track_origin = vec2(-10000.0);
uniform float wetness = 0.0;
uniform float detail_strength = 1.0;
uniform vec3 vehicle = vec3(0.0);
uniform float vehicle_heading = 0.0;
varying vec3 wp;
varying vec4 tint;
vec4 trail(vec2 p) {
 vec2 uv = (p-track_origin)/128.0;
 if(any(lessThan(uv,vec2(0)))||any(greaterThan(uv,vec2(1)))) return vec4(0);
 return texture(tracks,uv);
}
void vertex() {
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y-=trail(wp.xz).r*0.22;
 tint=COLOR;
}
void fragment() {
 // A tiny tiled texture replaces the old per-pixel procedural noise layers.
 vec3 detail=texture(ground_detail,wp.xz*0.25).rgb;
 float grain=mix(0.5,detail.r,detail_strength), patch=detail.g;
 float grass=step(tint.r*1.05,tint.g)*step(tint.b,tint.g*0.92);
 float snow=smoothstep(0.63,0.88,min(tint.r,min(tint.g,tint.b)));
 vec4 mark=trail(wp.xz);
 vec3 color=tint.rgb*(0.83+patch*0.16+grain*0.10);
 color=mix(color,color*vec3(0.94,1.08,0.78),grass*patch*0.35);
 color+=vec3(0.05,0.04,0.025)*detail.b*(1.0-grass)*(1.0-snow);
 color*=1.0-wetness*(1.0-snow)*0.16;
 vec2 p=wp.xz-vehicle.xz;
 vec2 under=vec2(cos(vehicle_heading)*p.x-sin(vehicle_heading)*p.y,sin(vehicle_heading)*p.x+cos(vehicle_heading)*p.y)/vec2(1.6,2.7);
 float contact=(1.0-smoothstep(0.2,1.0,length(under)))*(1.0-smoothstep(1.0,3.0,abs(wp.y-vehicle.y)));
 color*=1.0-contact*0.22;
 ALBEDO=mix(color,mix(vec3(0.19,0.14,0.09),vec3(0.38,0.41,0.39),snow),mark.r*0.75);
 ROUGHNESS=mix(0.94,0.30,wetness*(1.0-snow)*(0.4+mark.r*0.6));
 SPECULAR=0.25;
 NORMAL_MAP=vec3(0.5+(grain-0.5)*0.09,0.5+(patch-0.5)*0.08,1.0);
 NORMAL_MAP_DEPTH=0.35;
}
