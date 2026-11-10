// 風格化草叢：乾黃草為主，根部偏深，隨風輕擺
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 root_color : source_color = vec3(0.62, 0.47, 0.24);
uniform vec3 tip_color : source_color = vec3(0.93, 0.80, 0.52);
uniform float wind_strength = 0.1;

void vertex() {
	float h = UV.y;
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 1.4 + o.x * 0.21 + o.z * 0.17) * 0.7 + sin(TIME * 2.9 + o.x * 0.9) * 0.3;
	VERTEX.x += s * wind_strength * h * h;
	VERTEX.z += s * wind_strength * 0.5 * h * h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, smoothstep(0.0, 1.0, UV.y)) * COLOR.rgb;
	ROUGHNESS = 1.0;
}

// 風格化光照：柔和的兩階明暗、無高光
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
