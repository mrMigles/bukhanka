shader_type spatial;
render_mode cull_disabled;
uniform vec4 rings[16];
uniform float ring_heights[16];
uniform int ripple_count = 0;
uniform vec3 vehicle = vec3(0.0,-10000.0,0.0);
uniform float effects_strength = 1.0;
uniform float sim_time = 0.0;
uniform vec3 sky_tint = vec3(0.45,0.62,0.69);
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float t=sim_time*effects_strength;
 float ripple=0.0;
 if(ripple_count>0 && effects_strength>0.0 && distance(wp.xz,vehicle.xz)<12.0){
 for(int i=0;i<16;i++){if(i>=ripple_count)break;float d=length(wp.xz-rings[i].xy);float age=rings[i].z;float band=abs(d-age*2.0);if(band<.8)ripple+=sin((d-age*2.0)*8.0)*(1.0-smoothstep(0.0,.8,band))*max(0.0,1.0-age/4.0)*rings[i].w*step(abs(wp.y-ring_heights[i]),.6);}
 }
 float n=sin(wp.x*1.3+t*.8)*sin(wp.z*.9-t*.5);
 float edge=1.0-smoothstep(0.0,0.14,COLOR.r);
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.0);
 ALBEDO=mix(vec3(.12,.43,.37),vec3(.025,.15,.21),COLOR.r);
 ALBEDO=mix(ALBEDO,sky_tint,fresnel*.6);
 ALBEDO+=vec3(.24,.29,.24)*(edge*.35+abs(ripple)*.18);
 NORMAL_MAP=vec3(.5+n*.055+ripple*.04,.5+cos(wp.z*1.7+t)*.035,1.0);
 ROUGHNESS=.22+edge*.18; METALLIC=0.0; SPECULAR=.42;
}
