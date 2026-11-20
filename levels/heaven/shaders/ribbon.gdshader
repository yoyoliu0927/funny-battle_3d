// 紅綢帶：兩頭掛著、中間垂下來的一條布，會輕輕飄。兩面都畫；邊上一條金線。
shader_type spatial;
render_mode cull_disabled;

uniform vec3 silk : source_color = vec3(0.86, 0.14, 0.12);
uniform vec3 gold : source_color = vec3(0.98, 0.80, 0.36);

void vertex() {
	float k = sin(UV.x * 3.14159);                       // 兩頭固定、中間飄得最多
	VERTEX.y += sin(TIME * 1.3 + UV.x * 9.0) * 0.10 * k;
	VERTEX.x += sin(TIME * 0.9 + UV.x * 6.0) * 0.14 * k;
	VERTEX.z += cos(TIME * 1.1 + UV.x * 7.0 + UV.y * 2.0) * 0.16 * k;
}

void fragment() {
	float edge = smoothstep(0.10, 0.06, UV.y) + smoothstep(0.90, 0.94, UV.y);
	float fold = 0.85 + 0.15 * sin(UV.x * 40.0 + UV.y * 3.0);
	ALBEDO = mix(silk * fold, gold, clamp(edge, 0.0, 1.0));
	ROUGHNESS = 0.6;
	EMISSION = silk * 0.18;
}
