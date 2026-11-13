// 地圖邊緣雪簷底下的岩壁：一層一層的暖棕→紫灰（cliff_strata.png），靠近海面的地方被打濕、帶海的顏色；朝上的岩台積一點雪。
// UV = 岩層貼圖座標，UV2.x = 離頂面幾公尺，COLOR = 每層岩石的明暗。
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D strata_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 col_top : source_color = vec3(0.86, 0.50, 0.30);
uniform vec3 col_mid : source_color = vec3(0.66, 0.37, 0.36);
uniform vec3 col_low : source_color = vec3(0.40, 0.28, 0.46);
uniform vec3 mist_color : source_color = vec3(0.86, 0.90, 1.0);
uniform vec3 snow_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float mist_start = 1.5;      // 離頂面幾公尺開始帶海的顏色
uniform float mist_range = 1.6;

varying vec3 wn;
varying float depth_m;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	depth_m = UV2.x;      // 離島頂幾公尺
}

void fragment() {
	vec3 tex = texture(strata_tex, UV).rgb;
	vec3 base = mix(col_top, col_mid, smoothstep(0.2, 1.6, depth_m));
	base = mix(base, col_low, smoothstep(1.4, 3.2, depth_m));
	vec3 c = base * (0.42 + tex * 0.95) * COLOR.rgb;
	c = mix(c, snow_color, smoothstep(0.45, 0.75, wn.y) * 0.9);
	float mist = smoothstep(mist_start, mist_start + mist_range, depth_m);
	ALBEDO = mix(c, mist_color, mist * 0.55);
	ROUGHNESS = 1.0;
	// 海面往上反的光：朝下的面和靠近海面的地方帶一點海的顏色
	EMISSION = mist_color * (mist * 0.22 + clamp(-wn.y, 0.0, 1.0) * 0.14);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.15, 0.25, ndl) * 0.75 + clamp(ndl, 0.0, 1.0) * 0.25;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
