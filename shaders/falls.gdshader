shader_type spatial;
render_mode cull_disabled;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){VERTEX.x+=sin(UV.y*5.0+TIME*3.0)*.035;}
void fragment(){
 vec2 flow=UV-vec2(0.0,TIME*2.4);
 float n=noise(flow*vec2(5.0,1.3));
 float fine=noise(flow*vec2(14.0,3.0)+vec2(2.3,TIME*.4));
 float foam=smoothstep(.35,.88,n*.6+fine*.5);
 ALBEDO=mix(vec3(.14,.40,.43),vec3(.80,.89,.86),foam);
 NORMAL_MAP=vec3(.5+(n-.5)*.12,.5+(fine-.5)*.06,1.0);
 ROUGHNESS=.26+foam*.30; SPECULAR=.35;
}