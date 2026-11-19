// 小河：鋪在地面上的一條水。順著河流動的幾道亮線、岸邊一條淺色。UV.x 橫向 0～1、UV.y 沿河的公尺數。不吃光。
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.06, 0.26, 0.32);
uniform vec3 light_c : source_color = vec3(0.40, 0.72, 0.72);
uniform float width = 3.0;

void fragment() {
	float side = abs(UV.x - 0.5) * 2.0;
	float n = texture(noise_tex, vec2(UV.x * width * 0.25, UV.y * 0.08 - TIME * 0.03)).r;
	float n2 = texture(noise_tex, vec2(UV.x * width * 0.6 + 0.4, UV.y * 0.05 - TIME * 0.05)).g;
	vec3 c = mix(light_c, deep, smoothstep(1.0, 0.25, side + (n - 0.5) * 0.4));
	// 順流的亮線
	float streak = smoothstep(0.62, 0.70, n2) * (1.0 - smoothstep(0.70, 0.80, n2));
	c += vec3(0.9, 1.0, 0.96) * streak * 0.30 * (1.0 - side);
	// 岸邊：淺色的一條，再外面淡出（跟地面接起來不要一刀切）
	c = mix(c, light_c * 1.2, smoothstep(0.78, 0.92, side + (n - 0.5) * 0.15) * 0.7);
	ALBEDO = c;
	ALPHA = 1.0 - smoothstep(0.90, 1.0, side);
}
