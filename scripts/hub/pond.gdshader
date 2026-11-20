shader_type spatial;
render_mode unshaded, cull_disabled;
// 農莊池塘的水面：中間深、岸邊淺，白色的水紋慢慢流，偶爾閃一點亮點，邊緣淡出
// UV 是 (x / 池塘半徑x, z / 池塘半徑z)，所以 length(UV) = 0 在正中間、1 在岸邊

uniform vec4 shallow_col : source_color = vec4(0.45, 0.86, 0.84, 1.0);
uniform vec4 deep_col : source_color = vec4(0.10, 0.50, 0.72, 1.0);
uniform vec4 foam_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float r = length(UV);
	vec3 col = mix(deep_col.rgb, shallow_col.rgb, smoothstep(0.0, 1.0, r));
	// 水紋：兩層方向不同的細線
	float s1 = sin(UV.x * 13.0 + sin(UV.y * 6.0 + TIME * 0.7) * 1.4 + TIME * 0.6);
	float s2 = sin(UV.y * 11.0 - sin(UV.x * 5.0 - TIME * 0.5) * 1.2 - TIME * 0.45);
	float lines = smoothstep(0.93, 1.0, max(s1, s2)) * 0.22;
	// 岸邊的白色泡沫圈
	float edge = smoothstep(0.80, 0.97, r) * (0.5 + 0.2 * sin(r * 40.0 - TIME * 1.6));
	// 亮點
	vec2 g = floor(UV * 16.0 + vec2(TIME * 0.4, 0.0));
	float tw = step(0.985, hash(g)) * (0.5 + 0.5 * sin(TIME * 5.0 + hash(g + 3.0) * 6.28));
	col = mix(col, foam_col.rgb, clamp(edge + lines + tw * 0.6, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.985, 1.0, r);
}
