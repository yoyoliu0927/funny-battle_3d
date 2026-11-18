shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
// 油畫濾鏡（Kuwahara）：把畫面每個點換成附近「顏色最一致的那一塊」的平均色，
// 細節會糊成一塊一塊的顏料，邊緣卻還是清楚的。貼在鏡頭前面的一片全螢幕面上。
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// 每個方向取 (radius + 1) 個點、每個點隔 spread 個像素：3 × 3 × 4 = 36 次取樣，涵蓋的範圍跟原本
// 每個像素都取（5 × 5 × 4 = 100 次）一樣大。畫面取樣用線性過濾，隔著取也不會漏掉中間的顏色。
uniform int radius = 2;
uniform float spread = 2.0;
uniform float saturation = 1.06;
uniform float canvas = 0.05;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 px = spread / VIEWPORT_SIZE;
	vec3 m[4];
	vec3 s[4];
	for (int k = 0; k < 4; k++) { m[k] = vec3(0.0); s[k] = vec3(0.0); }
	for (int j = 0; j <= radius; j++) {
		for (int i = 0; i <= radius; i++) {
			vec2 o = vec2(float(i), float(j)) + 0.25;        // 落在像素中間偏一點：一次取樣就平均到旁邊幾個像素
			vec3 c;
			c = min(texture(screen, SCREEN_UV + vec2(-o.x, -o.y) * px).rgb, vec3(4.0)); m[0] += c; s[0] += c * c;
			c = min(texture(screen, SCREEN_UV + vec2(o.x, -o.y) * px).rgb, vec3(4.0)); m[1] += c; s[1] += c * c;
			c = min(texture(screen, SCREEN_UV + vec2(-o.x, o.y) * px).rgb, vec3(4.0)); m[2] += c; s[2] += c * c;
			c = min(texture(screen, SCREEN_UV + vec2(o.x, o.y) * px).rgb, vec3(4.0)); m[3] += c; s[3] += c * c;
		}
	}
	float n = float((radius + 1) * (radius + 1));
	float best = 1e9;
	vec3 col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 mean = m[k] / n;
		vec3 var = abs(s[k] / n - mean * mean);
		float v = var.r + var.g + var.b;
		if (v < best) { best = v; col = mean; }
	}
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(g), col, saturation);
	// 一點點畫布的顆粒
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	col *= 1.0 + (hash(cell) - 0.5) * canvas;
	ALBEDO = col;
}
