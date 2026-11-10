// 單色卡通材質（替身角色用），與場景相同的柔和兩階光影
shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
