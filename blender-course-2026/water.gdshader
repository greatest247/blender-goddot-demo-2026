shader_type spatial;

uniform vec4 water_color : source_color = vec4(0.0, 0.35, 0.7, 1.0);
uniform sampler2D normal_map : repeat_enable;
uniform float wave_speed = 0.05;
uniform float wave_height = 0.1;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.5;
uniform float uv_tiling = 4.0;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 2.0 + TIME) * wave_height;
	VERTEX.y += cos(VERTEX.z * 2.0 + TIME) * wave_height;
}

void fragment() {
	vec2 tiled_uv = UV * uv_tiling;
	vec2 uv1 = tiled_uv + vec2(TIME * wave_speed, 0.0);
	vec2 uv2 = tiled_uv - vec2(0.0, TIME * wave_speed);
	vec3 n = (texture(normal_map, uv1).rgb + texture(normal_map, uv2).rgb) * 0.5;

	// Fresnel: more reflective at grazing angles, like real water
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	ALBEDO = water_color.rgb;
	ALPHA = 1.0;
	NORMAL_MAP = n;
	ROUGHNESS = 0.05;
	METALLIC = clamp(reflection_strength + fresnel * 0.5, 0.0, 1.0);
}