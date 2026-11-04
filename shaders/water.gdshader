shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, diffuse_lambert;

// Низкополигональный океан: волны в вершинах, цвет по глубине, отблеск.

uniform vec4 shallow : source_color = vec4(0.10, 0.24, 0.30, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.05, 0.10, 1.0);
uniform float wave_height : hint_range(0.0, 2.0) = 0.35;
uniform float wave_speed : hint_range(0.0, 3.0) = 1.0;
uniform float storm : hint_range(0.0, 1.0) = 0.0;

varying float v_wave;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = sin(wp.x * 0.25 + t) * 0.5
		+ sin(wp.z * 0.3 + t * 1.3) * 0.5
		+ sin((wp.x + wp.z) * 0.15 - t * 0.7) * 0.4;
	VERTEX.y += h * wave_height * (1.0 + storm * 2.0);
	v_wave = h;
}

void fragment() {
	float band = clamp(v_wave * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, band);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = shallow.rgb * (fres * 0.3 + 0.03);
	ROUGHNESS = 0.2;
	METALLIC = 0.0;
}