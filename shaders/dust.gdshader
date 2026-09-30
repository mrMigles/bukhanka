shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
 float a = 1.0 - smoothstep(0.08, 0.5, distance(UV, vec2(0.5)));
 ALBEDO = vec3(0.66, 0.56, 0.39);
 ALPHA = a * COLOR.a * 0.26;
}
