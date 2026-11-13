// 地圖邊緣雪簷底下的冰崖：一層一層的青綠色冰（cliff_strata.png 的層紋和裂縫），上面淺、往海面越來越深；
// 朝上的冰台積一點雪，靠近海面的地方帶海的顏色。冰自己帶一點光，黃昏和夜裡也看得出是冰。
// UV = 層紋貼圖座標，UV2.x = 離頂面幾公尺，COLOR = 每層的明暗。
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D strata_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 col_top : source_color = vec3(0.72, 0.95, 0.98);
uniform vec3 col_mid : source_color = vec3(0.22, 0.72, 0.88);
uniform vec3 col_low : source_color = vec3(0.06, 0.40, 0.68);
uniform vec3 sea_color : source_color = vec3(0.12, 0.52, 0.74);
uniform vec3 snow_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float glow = 0.25;
uniform float wet_start = 2.2;      // 離頂面幾公尺開始帶海的顏色
uniform float wet_range = 1.2;

varying vec3 wn;
varying float depth_m;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	depth_m = UV2.x;
}

void fragment() {
	float lum = texture(strata_tex, UV).g;
	vec3 base = mix(col_top, col_mid, smoothstep(0.1, 1.3, depth_m));
	base = mix(base, col_low, smoothstep(1.1, 3.0, depth_m));
	vec3 c = base * (0.62 + lum * 0.62) * COLOR.rgb;
	c = mix(col_low * 0.75, c, smoothstep(0.22, 0.55, lum));          // 層和層之間的縫：深藍，不是黑
	c = mix(c, snow_color, smoothstep(0.50, 0.80, wn.y) * 0.9);
	float wet = smoothstep(wet_start, wet_start + wet_range, depth_m);
	c = mix(c, sea_color, wet * 0.5);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * glow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.15, 0.25, ndl) * 0.75 + clamp(ndl, 0.0, 1.0) * 0.25;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
