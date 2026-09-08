shader_type spatial;
render_mode cull_disabled;
uniform vec3 vehicle = vec3(0.0,-10000.0,0.0);
uniform float disturbance = 0.0;
uniform float sim_time = 0.0;
uniform vec3 sky_tint = vec3(0.45,0.62,0.69);
uniform vec4 rings[16];
uniform float ring_heights[16];
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 flow=wp.xz*0.75+vec2(sim_time*0.16,-sim_time*1.3);
 float n=noise(flow)+noise(flow*2.3)*0.4;
 float foam=pow(max(0.0,sin(n*8.0+wp.z*0.9-sim_time*3.0)),24.0)*0.09;
 float wake=exp(-length(wp.xz-vehicle.xz)*0.35)*disturbance;
 float ripple=0.0;
 for(int i=0;i<16;i++){float d=length(wp.xz-rings[i].xy),age=rings[i].z;ripple+=sin((d-age*2.6)*8.0)*exp(-abs(d-age*2.6)*2.0)*max(0.0,1.0-age/3.0)*rings[i].w*step(abs(wp.y-ring_heights[i]),.6);}
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.0);
 ALBEDO=mix(vec3(0.035,0.22,0.24),vec3(0.13,0.46,0.43),n*0.4);
 ALBEDO=mix(ALBEDO,sky_tint,fresnel*0.5);
 ALBEDO=mix(vec3(0.30,0.39,0.29),ALBEDO,smoothstep(0.0,0.22,COLOR.r));
 ALBEDO=mix(ALBEDO,vec3(0.8,0.9,0.85),clamp(foam+wake*0.18+abs(ripple)*0.36,0.0,0.8));
 NORMAL_MAP=normalize(vec3(sin(flow.y*2.0+n)*0.06+ripple*0.12,cos(flow.x*2.7-n)*0.05,1.0))*0.5+0.5;
 ROUGHNESS=0.36+foam*0.5; METALLIC=0.0; SPECULAR=0.28; 
}
