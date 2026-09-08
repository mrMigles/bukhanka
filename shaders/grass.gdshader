shader_type spatial;
render_mode cull_disabled;
uniform vec3 vehicle = vec3(0);
varying float tip;
varying float variation;
void vertex(){vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;variation=sin(p.x*.47+p.z*.21)*.08;tip=VERTEX.y;vec2 away=p.xz-vehicle.xz;float push=1.0-smoothstep(1.2,3.2,length(away));VERTEX.xz+=(normalize(away+vec2(0.01))*push*0.9+vec2(sin(TIME*1.8+p.x*0.6),cos(TIME+p.z*0.4))*0.12)*tip;VERTEX.y-=tip*push*0.65;}
void fragment(){ALBEDO=mix(vec3(0.10,0.20,0.08),vec3(0.34,0.43,0.16),clamp(tip,0.0,1.0))*(1.0+variation);ROUGHNESS=0.95;}
