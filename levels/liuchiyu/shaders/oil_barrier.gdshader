shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// 小關分界的柵欄：浮在半空中、會發光的一排木樁和兩條橫桿，慢慢上下飄。
// 白天是金黃色，晚上是藍白色。open 從 0 變到 1 的時候，木樁一根一根熄掉 = 這裡可以過了。
uniform vec3 tint : source_color = vec3(1.0, 0.76, 0.22);
uniform vec3 night_tint : source_color = vec3(0.62, 0.86, 1.0);
uniform float night = 0.0;
uniform float open = 0.0;
uniform float height = 2.2;          // 柵欄多高（公尺），要跟網格一樣
uniform float spacing = 1.1;         // 木樁的間距

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

void vertex() {
	// 整排慢慢上下飄，每一段飄的時間稍微錯開
	VERTEX.y += sin(TIME * 1.3 + UV.x * 0.45) * 0.12;
}

void fragment() {
	float id = floor(UV.x / spacing);
	vec2 p = vec2((fract(UV.x / spacing) - 0.5) * spacing, UV.y * height);
	float r = hash(id + 3.0);
	// 一根木樁：直的一條，頂端是尖的
	float top = height - 0.28 - r * 0.12;
	float d = seg(p, vec2(0.0, 0.22), vec2(0.0, top));
	d = min(d, min(seg(p, vec2(0.0, top + 0.14), vec2(-0.07, top)), seg(p, vec2(0.0, top + 0.14), vec2(0.07, top))) + 0.02);
	// 兩條橫桿
	float rail = min(abs(p.y - height * 0.34), abs(p.y - height * 0.68)) + 0.012;
	d = min(d - 0.035, rail);
	float core = smoothstep(0.035, 0.008, d);          // 亮亮的本體
	float halo = exp(-max(d, 0.0) * 16.0) * 0.45;       // 外面一圈光
	float pulse = 0.82 + 0.18 * sin(TIME * (1.1 + r) + id);
	float lit = step(open * 1.05, hash(id + 11.0));    // 打開的時候一根一根熄掉
	// 上下邊緣淡掉，不要看到面片的邊
	float fade = smoothstep(0.0, 0.07, UV.y) * smoothstep(1.0, 0.93, UV.y);
	vec3 c = mix(tint, night_tint, night);
	ALBEDO = mix(c, vec3(1.0), core * 0.55) * (1.7 + 0.5 * night) * pulse;
	ALPHA = clamp(core + halo, 0.0, 1.0) * lit * fade * (1.0 - open * 0.4);
}
