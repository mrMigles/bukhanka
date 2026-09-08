shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float progress = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	ALBEDO = mix(vec3(0.025, 0.10, 0.11), vec3(0.06, 0.85, 0.66), step(UV.x, progress));
}
