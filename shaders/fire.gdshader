shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex(){float h=clamp(VERTEX.y+.5,0.0,1.0);VERTEX.x+=sin(TIME*3.0+VERTEX.y*7.0)*.08*h;VERTEX.z+=cos(TIME*4.1+VERTEX.y*5.0)*.07*h;}
void fragment(){ALBEDO=mix(vec3(1.0,.74,.23),vec3(.91,.24,.04),clamp(VERTEX.y*.2+.3,0.0,1.0));}
