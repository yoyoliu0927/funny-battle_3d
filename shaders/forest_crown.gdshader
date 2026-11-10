// 森林樹冠：每棵樹的顏色來自 MultiMesh，朝上的面亮、底下暗
shader_type spatial;
render_mode specular_disabled;

varying float up;

void vertex() { up = NORMAL.y; }

void fragment() {
	vec3 base = COLOR.rgb;
	ALBEDO = base * mix(0.7, 1.12, smoothstep(-0.4, 0.8, up));
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
