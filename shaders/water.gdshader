shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 VERTEX.y += sin(world_pos.z * 0.55 + TIME * 1.5) * 0.10 + sin(world_pos.x * 1.4 + TIME) * 0.05;
}
void fragment() {
 float ripples = pow(0.5 + 0.5 * sin(world_pos.x * 2.0 + world_pos.z * 0.6 + TIME * 2.4), 16.0);
 ALBEDO = mix(vec3(0.04, 0.40, 0.43), vec3(0.40, 0.79, 0.77), ripples * 0.65);
 ROUGHNESS = 0.24;
 METALLIC = 0.32;
}
