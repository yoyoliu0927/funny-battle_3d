shader_type spatial;
// 寫實地面：三組照片掃描貼圖（草地落葉、泥地、岩石）依頂點權重混合。
// 地形沒有 UV，所以用世界座標貼；每組貼兩種尺寸再混合，遠看比較不會有重複感。

uniform sampler2D g_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D g_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D g_arm : filter_linear_mipmap, repeat_enable;
uniform sampler2D m_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D m_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D m_arm : filter_linear_mipmap, repeat_enable;
uniform sampler2D r_diff : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D r_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D r_arm : filter_linear_mipmap, repeat_enable;
uniform float tile_size = 3.2;      // 一張貼圖鋪幾公尺
uniform float brightness = 1.0;
uniform float bump = 1.4;
uniform vec3 grass_tint : source_color = vec3(0.86, 1.0, 0.70);

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vnoise(p) * 0.6 + vnoise(p * 2.3 + 7.0) * 0.3 + vnoise(p * 5.1 + 3.0) * 0.1; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz / tile_size;
	vec2 uv2 = vec2(uv.y, -uv.x) * 0.37 + 0.31;
	float mixn = smoothstep(0.35, 0.65, fbm(wp.xz * 0.21));

	vec3 gd = mix(texture(g_diff, uv).rgb, texture(g_diff, uv2).rgb, mixn) * grass_tint;
	// 只有草地的顏色貼兩種尺寸，其他貼一次就好（省效能）
	vec3 gn = texture(g_nor, uv).rgb;
	vec3 ga = texture(g_arm, uv).rgb;
	vec3 md = texture(m_diff, uv * 0.8).rgb;
	vec3 mn = texture(m_nor, uv * 0.8).rgb;
	vec3 ma = texture(m_arm, uv * 0.8).rgb;
	vec3 rd = texture(r_diff, uv * 0.6).rgb;
	vec3 rn = texture(r_nor, uv * 0.6).rgb;
	vec3 ra = texture(r_arm, uv * 0.6).rgb;

	// 泥地沿著貼圖的明暗長出不規則的邊，不是一條平滑的漸層
	float lum = dot(gd, vec3(0.33));
	float mud = smoothstep(0.35, 0.65, COLOR.g * 1.25 + (fbm(wp.xz * 0.9) - 0.5) * 0.5 - lum * 0.6 + 0.12);
	float rock = smoothstep(0.3, 0.7, COLOR.b + (fbm(wp.xz * 1.3) - 0.5) * 0.3);

	vec3 col = mix(gd, md, mud);
	vec3 nor = mix(gn, mn, mud);
	vec3 arm = mix(ga, ma, mud);
	col = mix(col, rd, rock);
	nor = mix(nor, rn, rock);
	arm = mix(arm, ra, rock);

	// 大範圍的明暗、乾濕變化
	float macro = fbm(wp.xz * 0.07 + 11.0);
	col *= mix(0.78, 1.12, macro);
	col = mix(col, col * vec3(1.08, 1.0, 0.82), smoothstep(0.5, 0.9, fbm(wp.xz * 0.13 + 40.0)) * (1.0 - mud));

	ALBEDO = col * brightness;
	ROUGHNESS = clamp(arm.g - mud * 0.12, 0.55, 1.0);
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.6;
	SPECULAR = 0.25;
	TANGENT = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	NORMAL_MAP = nor;
	// 遠處把凹凸收掉，免得變成一片雜訊
	NORMAL_MAP_DEPTH = bump * clamp(1.0 - (-VERTEX.z - 12.0) / 40.0, 0.25, 1.0);
}
