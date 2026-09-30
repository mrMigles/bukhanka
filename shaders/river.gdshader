shader_type spatial;
render_mode cull_disabled;
uniform vec3 vehicle = vec3(0.0,-10000.0,0.0);
uniform float disturbance = 0.0;
uniform float sim_time = 0.0;
uniform float effects_strength = 1.0;
uniform vec3 sky_tint = vec3(0.45,0.62,0.69);
uniform vec4 rings[16];
uniform float ring_heights[16];
uniform int ripple_count = 0;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 flow=wp.xz*0.75+vec2(sim_time*0.16,-sim_time*1.3)*effects_strength;
 float n=0.5+sin(flow.y*1.7+sin(flow.x*1.3)*1.4)*0.22+sin(flow.y*3.1+flow.x*0.7)*0.12;
 float foam=smoothstep(0.76,0.86,n)*0.12;
 float wake=(1.0-smoothstep(0.0,6.0,length(wp.xz-vehicle.xz)))*disturbance;
 float ripple=0.0;
 // Expired waves and distant water never pay for the ring calculations.
 if(ripple_count>0 && effects_strength>0.0 && distance(wp.xz,vehicle.xz)<12.0){
  for(int i=0;i<16;i++){
   if(i>=ripple_count)break;
   float d=length(wp.xz-rings[i].xy),age=rings[i].z;
   float band=abs(d-age*2.6);
   if(band<0.8)ripple+=sin((d-age*2.6)*8.0)*(1.0-smoothstep(0.0,0.8,band))*max(0.0,1.0-age/3.0)*rings[i].w*step(abs(wp.y-ring_heights[i]),0.6);
  }
 }
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.0);
 ALBEDO=mix(vec3(0.04,0.25,0.29),vec3(0.17,0.49,0.42),n*0.55);
 ALBEDO=mix(ALBEDO,sky_tint,fresnel*0.6);
 ALBEDO=mix(vec3(0.35,0.43,0.30),ALBEDO,smoothstep(0.0,0.22,COLOR.r));
 ALBEDO=mix(ALBEDO,vec3(0.85,0.95,0.91),clamp(foam+wake*0.18+abs(ripple)*0.36,0.0,0.8));
 NORMAL_MAP=vec3(0.5+sin(flow.y*2.0+n)*0.035+ripple*0.06,0.5+cos(flow.x*2.7-n)*0.03,1.0);
 ROUGHNESS=0.23+foam*0.5; SPECULAR=0.48;
}
