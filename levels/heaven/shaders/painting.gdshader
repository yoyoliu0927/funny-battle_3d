// 畫門裡的畫：一幅會動的山水——幾層慢慢橫移的遠山、一輪淡日、底下的雲霧。有人穿過去的時候整幅亮一下（flash）。
shader_type spatial;
render_mode unshaded;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float seed = 1.0;
uniform float flash = 0.0;
uniform vec3 paper : source_color = vec3(0.96, 0.92, 0.80);
uniform vec3 ink_far : source_color = vec3(0.56, 0.72, 0.72);
uniform vec3 ink_mid : source_color = vec3(0.30, 0.50, 0.54);
uniform vec3 ink_near : source_color = vec3(0.12, 0.26, 0.32);
uniform vec3 sun_c : source_color = vec3(0.92, 0.36, 0.22);

float hill(float u, float sp, float sc, float sd) {
	float x = u * sc + TIME * sp + sd;
	return 0.5 + 0.5 * sin(x) * 0.6 + 0.4 * (texture(noise_tex, vec2(x * 0.11, sd * 0.13)).r - 0.5);
}

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	vec3 c = paper;
	// 淡日
	float sd = length((uv - vec2(0.68, 0.26)) * vec2(1.0, 1.25));
	c = mix(c, sun_c, 1.0 - smoothstep(0.10, 0.115, sd));
	// 三層山（遠的慢、近的快）
	float h1 = 0.42 + 0.20 * hill(uv.x, 0.05, 5.0, seed);
	c = mix(c, ink_far, 1.0 - smoothstep(h1 - 0.006, h1 + 0.006, y));
	float h2 = 0.28 + 0.22 * hill(uv.x, 0.10, 7.0, seed + 3.0);
	c = mix(c, ink_mid, 1.0 - smoothstep(h2 - 0.006, h2 + 0.006, y));
	float h3 = 0.12 + 0.20 * hill(uv.x, 0.18, 9.0, seed + 7.0);
	c = mix(c, ink_near, 1.0 - smoothstep(h3 - 0.006, h3 + 0.006, y));
	// 山腳的霧
	float fog = texture(noise_tex, uv * vec2(1.4, 0.5) + vec2(TIME * 0.03, seed)).r;
	c = mix(c, paper, smoothstep(0.30, 0.0, y) * (0.55 + 0.45 * fog));
	// 畫裡面往外透的光（一直有一點；有人穿過去時大亮）
	float glow = 0.10 + 0.06 * sin(TIME * 2.0 + seed);
	c += vec3(1.0, 0.92, 0.70) * (glow + flash * 1.4);
	ALBEDO = c;
}
