shader_type sky;
uniform float daylight = 1.0;
uniform float night = 0.0;
uniform float cloudiness = 0.0;
uniform float sky_time = 0.0;
uniform vec3 sun_direction = vec3(0.0,0.8,0.3);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 float up=max(EYEDIR.y,0.0);
 vec3 top=mix(vec3(.13,.31,.46),vec3(.23,.48,.66),daylight);
 vec3 horizon=mix(vec3(.83,.45,.29),vec3(.69,.80,.82),daylight);
 top=mix(top,vec3(.006,.013,.04),night);
 horizon=mix(horizon,vec3(.07,.11,.18),night);
 vec3 col=mix(horizon,top,pow(up,.45));
 float sunset=(1.0-smoothstep(.12,.65,daylight))*(1.0-night);
 float facing=pow(max(0.0,dot(normalize(EYEDIR.xz),normalize(sun_direction.xz))),4.0);
 col=mix(col,vec3(.92,.43,.20),exp(-up*9.0)*sunset*(.25+facing*.55));
 col=mix(col,vec3(.32,.26,.43),smoothstep(.15,.6,up)*sunset*.5);
 if(!AT_CUBEMAP_PASS){
  if(night>0.15){
  vec2 uv=SKY_COORDS*vec2(800.0,400.0);
  vec2 cell=floor(uv);vec2 f=fract(uv)-.5;
  float star=step(.991,hash(cell))*pow(max(0.0,1.0-length(f)*2.0),5.0);
  float band=exp(-pow(dot(EYEDIR,normalize(vec3(.35,.5,.7)))*8.0,2.0));
  float nebula=noise(SKY_COORDS*vec2(140.0,70.0))*.6+noise(SKY_COORDS*vec2(45.0,24.0))*.4;
  col+=(vec3(.73,.81,1.0)*star*2.5+vec3(.22,.19,.31)*band*nebula)*smoothstep(.30,.90,night)*(1.0-cloudiness)*smoothstep(0.0,.16,up);
  float moon=dot(EYEDIR,normalize(vec3(-.4,.48,.65)));
  col+=vec3(.76,.82,.86)*smoothstep(.9994,.99965,moon)*night*(1.0-cloudiness*.95);
  }
  float sun=dot(EYEDIR,sun_direction);
  col+=vec3(1.0,.67,.31)*smoothstep(.9994,.9997,sun)*(1.0-night)*(1.0-cloudiness);
  if(up>0.02){
  vec2 cloud_uv=EYEDIR.xz/max(.08,up)*.6+vec2(sky_time*.0012,sky_time*.0003);
  float cloud=smoothstep(.55,.85,noise(cloud_uv*3.0)+noise(cloud_uv*7.0)*.25)*(.22+cloudiness*.75)*smoothstep(.02,.2,up);
  vec3 cloud_color=mix(vec3(.84,.87,.85),vec3(.055,.075,.11),night);
  cloud_color=mix(cloud_color,vec3(1.0,.78,.56),sunset*facing*.4);
  col=mix(col,cloud_color,cloud*.9);
  }
 }
 COLOR=col;
}
