shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// 河和瀑布：跟海同一張預先畫好的水面貼圖（water.png），順著水流方向拉長、往下游滑，
// 再換成三階平塗的藍＋白色水花。UV.x = 橫跨河面（0～1），UV.y = 沿著河走了幾公尺；
// COLOR.r = 1 的地方是瀑布（比較白、流得比較快）。
uniform sampler2D water_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float night = 0.0;
uniform vec3 day_deep : source_color = vec3(0.12, 0.32, 0.44);
uniform vec3 day_mid : source_color = vec3(0.22, 0.47, 0.58);
uniform vec3 day_light : source_color = vec3(0.50, 0.72, 0.76);
uniform vec3 day_foam : source_color = vec3(0.94, 0.97, 0.94);
uniform vec3 night_deep : source_color = vec3(0.03, 0.10, 0.18);
uniform vec3 night_mid : source_color = vec3(0.07, 0.20, 0.31);
uniform vec3 night_light : source_color = vec3(0.20, 0.42, 0.54);
uniform vec3 night_foam : source_color = vec3(0.62, 0.84, 0.90);
uniform float flow = 1.0;            // 流速
uniform float width = 3.6;           // 河多寬（公尺），花紋的粗細跟著河寬走

void fragment() {
	float fall = COLOR.r;
	vec3 deep = mix(day_deep, night_deep, night);
	vec3 mid = mix(day_mid, night_mid, night);
	vec3 light = mix(day_light, night_light, night);
	vec3 foam = mix(day_foam, night_foam, night);
	float speed = mix(1.4, 6.5, fall) * flow;
	// 換成公尺：橫向 = 河寬，縱向 = 沿河的距離；花紋順著水流拉長三倍
	vec2 m = vec2(UV.x * width, UV.y);
	vec4 a = texture(water_tex, vec2(m.x / 3.0, (m.y - TIME * speed) / 9.0));
	vec4 b = texture(water_tex, vec2(m.x / 2.2 + 0.37, (m.y - TIME * speed * 1.3) / 6.0 + 0.5));
	float h = (a.r + b.r) * 0.5 + (a.b - 0.5) * 0.3;
	// 靠兩岸的地方、還有瀑布，白色的水花比較多
	float edge = smoothstep(0.30, 0.48, abs(UV.x - 0.5));
	float white = max(fall * 0.75, edge * 0.5);
	float w = fwidth(h) + 0.004;
	vec3 col = mix(deep, mid, smoothstep(0.42 - w, 0.42 + w, h + fall * 0.2));
	col = mix(col, light, smoothstep(0.62 - w, 0.62 + w, h + white * 0.2));
	float line = max(a.g, b.g);
	float lw = fwidth(line) + 0.02;
	float lm = smoothstep(0.55 - lw, 0.55 + lw, line + white * 0.3);
	col = mix(col, mix(light, foam, clamp(white * 1.4 + 0.2, 0.0, 1.0)), lm * clamp(0.4 + white, 0.0, 1.0));
	ALBEDO = col;
}
