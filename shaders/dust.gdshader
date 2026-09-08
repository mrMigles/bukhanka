shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void fragment() {
 float a = 1.0 - smoothstep(0.12, 0.5, distance(UV, vec2(0.5)));
 ALBEDO = vec3(0.48, 0.43, 0.32);
 ALPHA = a * 0.16;
}
