shader_type spatial;
render_mode cull_disabled;
uniform float wind_strength = 1.0;
varying vec3 foliage_color;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float tip = smoothstep(1.5, 10.0, VERTEX.y);
    float gust = sin(TIME * 1.1 + world.x * 0.08 + world.z * 0.06);
    VERTEX.x += gust * tip * 0.22 * wind_strength;
    VERTEX.z += sin(TIME * 0.7 + world.z * 0.09) * tip * 0.12 * wind_strength;
    foliage_color = COLOR.rgb * (0.94 + tip * 0.12);
}
void fragment() {
    ALBEDO = foliage_color;
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
}
