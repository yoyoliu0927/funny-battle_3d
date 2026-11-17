shader_type spatial;
render_mode unshaded, fog_disabled;
// 海（水池、遠處的小水池也用這個）：跟地面同一種做法——形狀來自預先畫好的水面貼圖
// （levels/liuchiyu/tools/bake_textures.gd 產生的 water.png：R = 波浪高低、G = 網狀光紋、B = 大塊明暗），
// shader 只把它換成幾階平塗的顏色：深、中、淺三階的藍，朝太陽／月亮的反光帶裡光紋變成亮金色，
// 靠岸的地方光紋變成白色浪花。兩張貼圖往不同方向慢慢滑，疊起來就是會動的水面。遠處淡成平塗。
uniform sampler2D water_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float night = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 day_deep : source_color = vec3(0.10, 0.27, 0.40);
uniform vec3 day_mid : source_color = vec3(0.19, 0.42, 0.54);
uniform vec3 day_light : source_color = vec3(0.31, 0.55, 0.63);
uniform vec3 day_glint : source_color = vec3(1.0, 0.92, 0.70);
uniform vec3 day_foam : source_color = vec3(0.93, 0.96, 0.93);
uniform vec3 night_deep : source_color = vec3(0.03, 0.09, 0.16);
uniform vec3 night_mid : source_color = vec3(0.06, 0.17, 0.27);
uniform vec3 night_light : source_color = vec3(0.14, 0.32, 0.44);
uniform vec3 night_glint : source_color = vec3(0.55, 0.74, 0.86);
uniform vec3 night_foam : source_color = vec3(0.50, 0.74, 0.80);
uniform vec3 day_haze : source_color = vec3(0.80, 0.84, 0.82);
uniform vec3 night_haze : source_color = vec3(0.04, 0.12, 0.17);
uniform float flow = 1.0;            // 流動的速度
uniform float scale = 12.0;          // 一張水面貼圖鋪多少公尺
uniform vec2 center = vec2(0.0);     // 島（或水池）的中心（世界座標 x, z），讓每一片水的花紋錯開
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_cam = CAMERA_POSITION_WORLD - wp;
	float dist = length(to_cam);
	vec3 v = to_cam / dist;
	// 水面把視線往上反射，越對準太陽／月亮越亮：一條反光的路
	vec3 r = reflect(-v, vec3(0.0, 1.0, 0.0));
	float glint = pow(max(dot(r, normalize(sun_dir)), 0.0), 14.0);
	float shore = 1.0 - COLOR.r;          // 1 = 貼著岸邊，0 = 外海
	vec3 deep = mix(day_deep, night_deep, night);
	vec3 mid = mix(day_mid, night_mid, night);
	vec3 light = mix(day_light, night_light, night);
	vec3 gl = mix(day_glint, night_glint, night);
	vec3 foam = mix(day_foam, night_foam, night);
	// 兩張貼圖往不同方向滑（第二張轉了一個角度、放大將近三倍），疊起來從遠處看也不會看出是同一張一直重複
	vec2 p = wp.xz + center * 0.37;
	float t = TIME * flow;
	vec4 a = texture(water_tex, p / scale + vec2(t * 0.012, t * 0.005));
	vec4 b = texture(water_tex, vec2(p.y * 0.8 - p.x * 0.6, p.x * 0.8 + p.y * 0.6) / (scale * 2.7) + vec2(-t * 0.004, t * 0.006));
	float h = (a.r + b.r) * 0.5 + (a.b - 0.5) * 0.35 + shore * 0.12;
	// 三階平塗的藍（交界用螢幕上的寬度抗鋸齒，遠近都一樣俐落）
	float w = fwidth(h) + 0.004;
	vec3 col = mix(deep, mid, smoothstep(0.44 - w, 0.44 + w, h));
	col = mix(col, light, smoothstep(0.62 - w, 0.62 + w, h + glint * 0.25));
	// 網狀光紋：兩張的光紋取比較亮的那條。反光帶裡變亮金色，靠岸變白色浪花，其他地方只是淡淡的淺藍
	float line = max(a.g, b.g * 0.7);
	float lw = fwidth(line) + 0.02;
	float lm = smoothstep(0.55 - lw, 0.55 + lw, line);
	vec3 lc = mix(light, gl, smoothstep(0.08, 0.35, glint));
	lc = mix(lc, foam, smoothstep(0.45, 0.7, shore));
	float la = clamp(0.35 + glint * 1.5 + shore * 0.9, 0.0, 1.0);
	// 遠處：貼圖的細節淡掉，只剩平塗的顏色和反光
	float detail = 1.0 - smoothstep(60.0, 150.0, dist);
	// 光紋比色塊更早淡掉（遠處的網格最容易看出重複）
	col = mix(col, lc, lm * la * (1.0 - smoothstep(25.0, 80.0, dist)));
	col = mix(col, mix(mid, gl, glint * 0.6), (1.0 - detail) * 0.5);
	// 自己算遠處的霧（場景的霧會把低處的海整片蓋掉）：越遠越接近地平線的顏色
	col = mix(col, mix(day_haze, night_haze, night), (1.0 - exp(-dist * 0.0035)) * 0.9);
	ALBEDO = col;
}
