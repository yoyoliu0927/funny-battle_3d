// 一朵一朵的雲（模型）：不吃光，頂部亮、底部帶環境色，邊緣柔一點。
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 light_c : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade_c : source_color = vec3(0.72, 0.82, 0.98);

varying vec3 wn;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float fr = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 c = mix(shade_c, light_c, smoothstep(-0.35, 0.75, wn.y));
	ALBEDO = mix(c, light_c, fr * fr * 0.5);
}
