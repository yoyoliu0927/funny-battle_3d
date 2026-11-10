// 圓團狀綠色灌木
shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 dark : source_color = vec3(0.16, 0.38, 0.22);
uniform vec3 light_c : source_color = vec3(0.36, 0.58, 0.30);
varying vec3 lnrm;

void vertex() { lnrm = NORMAL; }

void fragment() {
	ALBEDO = mix(dark, light_c, smoothstep(-0.3, 0.8, lnrm.y)) * COLOR.rgb;
	ROUGHNESS = 1.0;
}

// 風格化光照：柔和的兩階明暗、無高光
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
