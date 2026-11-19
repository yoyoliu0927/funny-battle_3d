// 仙境的地面：白玉地（人會滑的地方：長方形 courts ＋ 橢圓 lakes 拼起來）＋四周的地面＋步道＋雲階＋洞挖空，一個著色器畫完。
// 位置都由 heaven_world.gd 傳進來（lakes、holes 跟冰雪島的 island_top.gdshader 用同樣的名字，所以冰雪島的程式可以直接設）。
// 四周的地面每一關不一樣（草地、石板路、會反光的暗色石頭），靠 paving、sparkle 和顏色調。地面一直鋪到很遠，遠處融進霧的顏色。
shader_type spatial;

uniform int lake_count = 0;
uniform vec4 lakes[4];            // 橢圓的白玉地：中心 x, z, 半徑 x, z
uniform int court_count = 0;
uniform vec4 courts[6];           // 長方形的白玉地：中心 x, z, 半寬, 半深
uniform float court_r = 1.6;      // 長方形的圓角
uniform int hole_count = 0;
uniform vec4 holes[8];            // 洞：中心 x, z, 挖空的半徑
uniform int walk_count = 0;
uniform vec4 walks[8];            // 步道：起點 x, z → 終點 x, z
uniform float walk_half[8];       // 步道的半寬
uniform sampler2D vein_tex : repeat_enable, filter_linear_mipmap_anisotropic;    // R 粗紋 G 細紋 B 雲霧（玉的紋理）
uniform sampler2D grain_tex : repeat_enable, filter_linear_mipmap_anisotropic;   // R 起伏 G 紋路 B 顆粒
uniform vec3 ground_lit : source_color = vec3(0.50, 0.72, 0.62);
uniform vec3 ground_shade : source_color = vec3(0.26, 0.50, 0.50);
uniform vec3 ground_far : source_color = vec3(0.62, 0.84, 0.82);
uniform vec3 walk_c : source_color = vec3(0.78, 0.86, 0.80);
uniform float paving = 0.0;       // 四周的地面畫不畫石板縫（0＝草地，1＝整齊的石板路）
uniform float sparkle = 0.0;      // 地面上星星點點的反光（星空那一關）
uniform vec3 jade_pale : source_color = vec3(0.90, 0.96, 0.92);
uniform vec3 jade_mid : source_color = vec3(0.66, 0.86, 0.80);
uniform vec3 jade_deep : source_color = vec3(0.34, 0.60, 0.58);
uniform vec3 trim_c : source_color = vec3(0.92, 0.78, 0.36);      // 白玉地邊上的鑲邊（金或朱紅）
uniform vec3 sky_tint : source_color = vec3(0.80, 0.92, 1.0);
uniform float jade_glow = 0.16;
uniform float jade_lit = 0.85;
uniform float center_lift = 0.0;
uniform vec4 stairs = vec4(0.0);  // 雲階：x0, x1, z0（腳下）, z1（最高）；全 0＝沒有
uniform float stair_steps = 6.0;
uniform float snow_z = 999.0;     // 這條線以南（z 比較大）是雪地，往北慢慢融成青綠；999＝沒有雪
uniform vec3 snow_c : source_color = vec3(0.94, 0.97, 1.0);
uniform vec3 snow_shade_c : source_color = vec3(0.66, 0.80, 0.90);
uniform float ink_lines = 0.0;    // 地面上水墨的勾線（像畫在紙上的山水）
uniform int walk_style = 0;       // 1＝星空長廊：深色的路面、兩邊發光的金邊、一路往前流動的箭頭
uniform vec3 walk_body : source_color = vec3(0.17, 0.17, 0.27);
uniform vec3 mist_c : source_color = vec3(1.0, 0.76, 0.34);
uniform float mist = 0.0;         // 地面上飄的霧氣
uniform float mist_far = 0.0;     // 1＝霧只在遠處（近處的地面保持乾淨）

varying vec3 wpos;
varying vec3 wnrm;

float court_sd(vec2 p, vec4 ct) {
	vec2 q = abs(p - ct.xy) - (ct.zw - court_r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - court_r;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	// ---- 洞：挖空，洞口外一圈比較亮
	float hole_edge = 0.0;
	for (int i = 0; i < hole_count; i++) {
		float dist = length(p - holes[i].xy);
		float rr = holes[i].z;
		if (dist < rr) {
			discard;
		}
		hole_edge = max(hole_edge, 1.0 - smoothstep(0.0, 0.9, dist - rr));
	}
	// ---- 離白玉地的邊多遠（公尺，負的＝在裡面）：長方形和橢圓取最近的
	float sd = 99.0;
	for (int i = 0; i < court_count; i++) {
		sd = min(sd, court_sd(p, courts[i]));
	}
	float e_el = 9.0;          // 橢圓的「半徑比例」（給同心刻線用）
	vec2 el_c = vec2(0.0);
	vec2 el_r = vec2(1.0);
	for (int i = 0; i < lake_count; i++) {
		float ei = length((p - lakes[i].xy) / lakes[i].zw);
		if (ei < e_el) {
			e_el = ei;
			el_c = lakes[i].xy;
			el_r = lakes[i].zw;
		}
		sd = min(sd, (ei - 1.0) * min(lakes[i].z, lakes[i].w));
	}
	float fw = max(fwidth(sd), 0.002);
	float jade = 1.0 - smoothstep(-fw, fw, sd);
	float in_d = -sd;          // 往裡面幾公尺

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec2 par = -V.xz / max(V.y, 0.3);
	float cam_d = length(CAMERA_POSITION_WORLD - wpos);

	// ---- 白玉：溫潤的淡色，裡面有幾縷深色的雲絮和很淡的紋；大塊的方磚縫；邊上一道鑲邊
	vec2 uv = p / 11.0;
	float wisp = texture(vein_tex, uv * 0.6 + par * 0.06).b;
	float vein = texture(vein_tex, uv * 0.9 + 0.21).r;
	float fine = texture(vein_tex, uv * 1.7 + 0.53).g;
	vec3 jc = mix(jade_pale, jade_mid, smoothstep(0.25, 0.85, wisp));
	jc = mix(jc, jade_deep, smoothstep(0.55, 0.95, wisp) * 0.35);
	jc = mix(jc, jade_pale * 1.04, clamp(vein * 0.5 + fine * 0.18, 0.0, 1.0));
	// 方磚：每 2.4 公尺一道很淡的縫；每一塊深淺差一點點
	vec2 tile = p / 2.4;
	vec2 tf = abs(fract(tile) - 0.5);
	float tw = fwidth(tile.x) + fwidth(tile.y);
	float joint = 1.0 - smoothstep(0.0, 0.012 + tw, 0.5 - max(tf.x, tf.y));
	float tone = fract(sin(dot(floor(tile), vec2(12.9898, 78.233))) * 43758.5453);
	jc *= 0.965 + 0.07 * tone;
	jc = mix(jc, jade_deep, joint * 0.30 * (1.0 - smoothstep(30.0, 60.0, cam_d)));
	// 橢圓的白玉地：一圈一圈同心的刻線和十二道放射線（像一塊大玉璧；長方形的沒有）
	if (e_el < 1.0) {
		float ring_w = fwidth(e_el) * 1.6 + 0.004;
		float rings = 0.0;
		for (int k = 1; k <= 3; k++) {
			rings = max(rings, 1.0 - smoothstep(0.0, ring_w, abs(e_el - float(k) * 0.25)));
		}
		vec2 q = (p - el_c) / el_r;
		float ang = atan(q.y, q.x);
		float spoke = 1.0 - smoothstep(0.0, 0.012 / max(e_el, 0.2), abs(fract(ang / 6.2831853 * 12.0 + 0.5) - 0.5));
		spoke *= step(0.25, e_el) * step(e_el, 0.75);
		jc = mix(jc, jade_deep, max(rings, spoke) * 0.42);
	}
	// 鑲邊：離邊 0.25～0.75 公尺一條寬帶，再往裡 1.05 公尺一條細線；寬帶上一格一格的回紋
	float band = smoothstep(0.22, 0.27, in_d) * (1.0 - smoothstep(0.72, 0.77, in_d));
	float band2 = smoothstep(1.02, 1.05, in_d) * (1.0 - smoothstep(1.12, 1.15, in_d));
	float key = step(0.5, fract((p.x + p.y) * 0.9)) * step(0.36, in_d) * step(in_d, 0.62);
	jc = mix(jc, mix(trim_c, trim_c * 0.62, key), max(band, band2));
	// 反光帶：幾條斜斜的亮帶跟著鏡頭滑動
	float s = dot(p, vec2(0.46, 0.28)) + V.x * 1.6 + V.z * 0.9;
	float f = fract(s * 0.105);
	float sheen = smoothstep(0.0, 0.02, f) * smoothstep(0.12, 0.09, f);
	sheen *= smoothstep(0.38, 0.62, texture(grain_tex, p * 0.045 + 0.71).r);
	jc += sheen * 0.10;
	float fres = pow(1.0 - clamp(V.y, 0.0, 1.0), 4.0);
	jc = mix(jc, sky_tint, fres * 0.45);
	jc = mix(jc, vec3(1.0), hole_edge * hole_edge * 0.4);
	jc += vec3(0.6, 0.7, 1.0) * center_lift * (1.0 - smoothstep(0.15, 0.80, e_el));

	// ---- 四周的地面：兩個色階的大塊斑（草地的深淺、石板的新舊），加一層細顆粒
	float patch = texture(grain_tex, p * 0.028).r * 0.65 + texture(grain_tex, p * 0.075 + 0.31).r * 0.35;
	float grain = texture(grain_tex, p * 0.42).b;
	vec3 gc = mix(ground_shade, ground_lit, smoothstep(0.32, 0.66, patch));
	gc *= 0.94 + 0.12 * grain;
	// 石板路：錯開排的長方形石板，縫比較深
	if (paving > 0.0) {
		vec2 st = p / vec2(1.9, 1.1);
		st.x += step(1.0, mod(floor(st.y), 2.0)) * 0.5;
		vec2 sf = abs(fract(st) - 0.5);
		float sw = fwidth(st.x) + fwidth(st.y);
		float sj = 1.0 - smoothstep(0.0, 0.03 + sw, 0.5 - max(sf.x, sf.y));
		float stone = fract(sin(dot(floor(st), vec2(41.3, 17.7))) * 9137.31);
		gc = mix(gc, gc * (0.90 + 0.20 * stone), paving);
		gc = mix(gc, ground_shade * 0.66, sj * paving * (1.0 - smoothstep(26.0, 54.0, cam_d)));
	}
	// 水墨的筆觸：沿著深淺色塊的邊勾幾道淡墨線
	if (ink_lines > 0.0) {
		float lv = patch * 5.0;
		float line = 1.0 - smoothstep(0.0, fwidth(lv) * 1.4 + 0.02, abs(fract(lv) - 0.5));
		gc = mix(gc, ground_shade * 0.60, line * ink_lines * (1.0 - smoothstep(22.0, 46.0, cam_d)));
	}
	// 雪地：南邊積雪，往北一塊一塊融掉露出青綠（融雪的邊緣是一圈濕濕的深色）
	float snow = 0.0;
	if (snow_z < 900.0) {
		float sn_n = texture(grain_tex, p * 0.035 + 0.17).r - 0.5;
		float sd_s = p.y - snow_z + sn_n * 11.0;
		snow = smoothstep(-1.2, 1.2, sd_s);
		float drift = texture(grain_tex, p * 0.07 + 0.43).r;
		vec3 sn = mix(snow_shade_c, snow_c, smoothstep(0.28, 0.58, drift));
		gc = mix(gc, ground_shade * 0.78, (1.0 - smoothstep(0.0, 1.6, abs(sd_s + 1.2))) * 0.5);
		gc = mix(gc, sn, snow);
	}
	// 白玉地投在旁邊地上的影子（緊貼邊緣一圈）
	gc = mix(gc, ground_shade * 0.72, (1.0 - smoothstep(0.0, 0.9, sd)) * step(0.0, sd) * 0.55);
	gc = mix(gc, ground_lit, hole_edge * 0.25 * (1.0 - jade));
	// 星星點點的反光
	float tw2 = sin(dot(floor(p * 9.0), vec2(12.9898, 78.233)) + (V.x + V.z) * 30.0) * 0.5 + 0.5;
	float glint = smoothstep(0.86, 1.0, texture(grain_tex, p * 0.9).b) * smoothstep(0.55, 1.0, tw2) * sparkle;

	// ---- 步道：比地面亮一點的鋪面，兩邊各一條深色的邊石
	float walk = 0.0;
	float curb = 0.0;
	float w_best = 99.0;       // 最近那條步道：離邊多遠、沿路走了幾公尺、偏中線幾公尺
	float w_along = 0.0;
	float w_side = 0.0;
	for (int i = 0; i < walk_count; i++) {
		vec2 a = walks[i].xy;
		vec2 ab = walks[i].zw - a;
		float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		float d = length(p - (a + ab * t)) - walk_half[i];
		float wfw = max(fwidth(d), 0.002);
		walk = max(walk, 1.0 - smoothstep(-wfw, wfw, d));
		curb = max(curb, (1.0 - smoothstep(0.0, 0.05 + wfw, abs(d + 0.14) - 0.07)));
		if (d < w_best) {
			w_best = d;
			float len = length(ab);
			w_along = t * len;
			w_side = length(p - (a + ab * t));
		}
	}
	vec3 wc = walk_c * (0.92 + 0.14 * grain);
	vec2 wt = p / 1.2;
	vec2 wf = abs(fract(wt) - 0.5);
	float wj = 1.0 - smoothstep(0.0, 0.03 + fwidth(wt.x) + fwidth(wt.y), 0.5 - max(wf.x, wf.y));
	wc = mix(wc, walk_c * 0.70, wj * 0.6 * (1.0 - smoothstep(26.0, 54.0, cam_d)));
	wc = mix(wc, walk_c * 0.55, curb);
	float walk_glow = 0.0;
	if (walk_style == 1) {
		// 星空長廊：深色的石板路，兩邊各一條發光的金邊，中間一個一個往前流的箭頭
		wc = walk_body * (0.90 + 0.20 * grain);
		wc = mix(wc, walk_body * 0.62, wj * 0.7 * (1.0 - smoothstep(26.0, 54.0, cam_d)));
		float edge = smoothstep(-0.42, -0.36, w_best) * (1.0 - smoothstep(-0.14, -0.08, w_best));
		float edge_soft = smoothstep(-1.3, -0.3, w_best) * (1.0 - smoothstep(-0.14, 0.0, w_best));
		float cv = fract((w_along + w_side * 0.9 - TIME * 0.8) / 3.4);
		float chev = (1.0 - smoothstep(0.0, 0.035, abs(cv - 0.5) - 0.035)) * (1.0 - smoothstep(0.55, 0.62, w_side));
		walk_glow = edge * 1.5 + edge_soft * 0.22 + chev * 0.75;
		wc = mix(wc, walk_c, clamp(edge + chev * 0.8, 0.0, 1.0));
	}
	gc = mix(gc, wc, walk * (1.0 - jade));

	// ---- 雲階：斜坡畫成一階一階的玉階（每階前緣一條鑲邊色的線，踏面由淺到深）
	float on_st = 0.0;
	if (stairs.x != stairs.y) {
		float zk = (p.y - stairs.z) / (stairs.w - stairs.z);
		float inx = smoothstep(stairs.x - 0.05, stairs.x + 0.05, p.x) * (1.0 - smoothstep(stairs.y - 0.05, stairs.y + 0.05, p.x));
		on_st = inx * step(0.0, zk) * step(zk, 1.0) * (1.0 - jade);
		float st2 = fract(zk * stair_steps);
		vec3 sc = mix(jade_pale, jade_mid, st2 * 0.55);
		sc = mix(sc, trim_c, 1.0 - smoothstep(0.0, 0.10, st2));           // 每一階的前緣
		sc = mix(sc, jade_deep, smoothstep(0.90, 1.0, st2) * 0.6);          // 上一階投下來的影子
		float side_e = min(p.x - stairs.x, stairs.y - p.x);
		sc = mix(sc, trim_c * 0.85, 1.0 - smoothstep(0.10, 0.16, side_e));  // 兩側的邊
		gc = mix(gc, sc, on_st);
	}

	// ---- 遠處：融進霧的顏色（地面一直鋪出去，看不到盡頭）
	gc = mix(gc, ground_far, smoothstep(34.0, 110.0, cam_d) * 0.85);

	// 金色的霧氣：貼著地面慢慢流動，越遠越濃
	float mist_k = 0.0;
	if (mist > 0.0) {
		float m1 = texture(grain_tex, p * 0.018 + vec2(TIME * 0.006, TIME * 0.004)).r;
		float m2 = texture(grain_tex, p * 0.041 - vec2(TIME * 0.008, 0.0) + 0.37).r;
		mist_k = smoothstep(0.38, 0.72, m1 * 0.6 + m2 * 0.4) * mist * mix(0.35 + 0.65 * smoothstep(10.0, 60.0, cam_d), smoothstep(30.0, 70.0, cam_d), mist_far);
		mist_k *= (1.0 - jade) * (1.0 - walk * 0.6);
	}
	float solid = max(jade, on_st);
	float soft = max(solid, walk);
	ALBEDO = mix(gc, jc * jade_lit, jade);
	ROUGHNESS = mix(mix(1.0, 0.55, sparkle), 0.30, jade);
	ROUGHNESS = mix(ROUGHNESS, 0.5, on_st);
	SPECULAR = mix(mix(0.08, 0.5, sparkle), 0.45, solid);
	EMISSION = jc * jade_glow * jade + vec3(glint) * 0.9 * (1.0 - solid) + walk_c * 0.35 * walk * sparkle * (1.0 - jade) * float(walk_style == 0) + walk_c * walk_glow * walk * (1.0 - jade) + mist_c * mist_k * 0.55 + gc * 0.04 * (1.0 - soft);
}
