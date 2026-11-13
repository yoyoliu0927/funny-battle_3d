// 冰洞裡的水：深藍綠，一圈一圈慢慢往外的波紋＋流動的波光線（sea_waves.png），貼著冰壁的地方有一圈淺色。
// 不吃光（黃昏也不會變成咖啡色）。模型的半徑是 1，所以 radius 用模型自己的座標。
shader_type spatial;
render_mode unshaded;

uniform sampler2D wave_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.02, 0.13, 0.22);
uniform vec3 teal : source_color = vec3(0.05, 0.38, 0.46);
uniform vec3 foam : source_color = vec3(0.62, 0.90, 0.95);
uniform float radius = 1.12;
uniform float brightness = 1.0;

varying vec3 lp;
varying vec3 wp;

void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = length(lp.xz) / radius;
	float n = texture(wave_tex, wp.xz * 0.11 + vec2(TIME * 0.02, -TIME * 0.015)).g;
	float lines_tex = texture(wave_tex, wp.xz * 0.16 + vec2(-TIME * 0.02, TIME * 0.012)).r;
	float ring = sin(d * 16.0 - TIME * 1.5 + n * 5.0);
	float lines = smoothstep(0.86, 0.97, ring) * (0.35 + 0.65 * n) * smoothstep(0.1, 0.5, d);
	vec3 c = mix(teal, deep, smoothstep(0.0, 0.8, 1.0 - d + (n - 0.5) * 0.4));
	c = mix(c, deep, 0.35);
	c += foam * (lines * 0.30 + lines_tex * 0.16);
	c = mix(c, foam, smoothstep(0.80, 0.95, d + (n - 0.5) * 0.12) * 0.55);
	ALBEDO = c * brightness;
}
