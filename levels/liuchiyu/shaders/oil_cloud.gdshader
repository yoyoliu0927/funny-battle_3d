shader_type spatial;
render_mode unshaded, shadows_disabled;
// 烏雲：跟天空的雲同一種畫法——一小塊一小塊平塗的色塊，只分三四階明暗（上面受光比較亮，底下暗），
// 只是顏色換成黑灰色。
uniform vec3 lit : source_color = vec3(0.56, 0.58, 0.64);
uniform vec3 mid : source_color = vec3(0.38, 0.40, 0.46);
uniform vec3 shade : source_color = vec3(0.23, 0.24, 0.30);
uniform float dab = 2.4;             // 色塊多大（越大色塊越小）
varying vec3 wp;
varying vec3 wn;

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 把位置切成一格一格，每一格只有一個顏色 = 一筆平塗
	vec3 cell = floor(wp * dab + vec3(0.0, TIME * 0.05, 0.0));
	vec3 r = hash3(cell);
	float l = clamp(wn.y * 0.5 + 0.5 + (r.x - 0.5) * 0.45, 0.0, 1.0);
	l = floor(l * 4.0 + 0.5) / 4.0;
	vec3 c = mix(shade, mid, smoothstep(0.0, 0.5, l));
	c = mix(c, lit, smoothstep(0.5, 1.0, l));
	ALBEDO = c;
}
