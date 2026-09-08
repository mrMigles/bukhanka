shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
 vec2 px = SCREEN_PIXEL_SIZE * 3.0;
 vec3 c = texture(screen_texture, SCREEN_UV).rgb * 0.2;
 c += texture(screen_texture, SCREEN_UV+vec2(px.x,px.y)).rgb * 0.2;
 c += texture(screen_texture, SCREEN_UV+vec2(-px.x,px.y)).rgb * 0.2;
 c += texture(screen_texture, SCREEN_UV+vec2(px.x,-px.y)).rgb * 0.2;
 c += texture(screen_texture, SCREEN_UV-px).rgb * 0.2;
 COLOR = vec4(mix(c,vec3(.005,.035,.04),.25),1.0);
}
