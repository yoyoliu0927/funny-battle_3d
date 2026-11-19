// 仙境地圖的頂面：白玉台（人會滑的地方）＋雲毯＋雲階＋雲洞挖空，一個著色器畫完。
// 台子、雲洞的位置由 heaven_world.gd 傳進來（跟冰雪島的 island_top.gdshader 用同一組參數名字，所以冰雪島的程式可以直接設）。
// 雲堆、雲洞口的模型也用這個著色器（沒有台子就只畫雲）。
shader_type spatial;

uniform int lake_count = 0;
uniform vec4 lakes[4];            // 白玉台：中心 x, z, 半徑 x, z
uniform int hole_count = 0;
uniform vec4 holes[8];            // 雲洞：中心 x, z, 挖空的半徑
uniform sampler2D vein_tex : repeat_enable, filter_linear_mipmap_anisotropic;    // R 粗紋 G 細紋 B 雲霧（玉的紋理）
uniform sampler2D cloud_tex : repeat_enable, filter_linear_mipmap_anisotropic;   // R 起伏 G 紋路 B 顆粒
uniform vec3 cloud_lit : source_color = vec3(0.97, 0.98, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.70, 0.82, 0.90);
uniform vec3 jade_pale : source_color = vec3(0.90, 0.96, 0.92);
uniform vec3 jade_mid : source_color = vec3(0.66, 0.86, 0.80);
uniform vec3 jade_deep : source_color = vec3(0.34, 0.60, 0.58);
uniform vec3 trim_c : source_color = vec3(0.92, 0.78, 0.36);      // 台子邊上的鑲邊（金或朱紅）
uniform vec3 sky_tint : source_color = vec3(0.80, 0.92, 1.0);
uniform float jade_glow = 0.16;
uniform float jade_lit = 0.85;
uniform float center_lift = 0.0;
uniform vec4 stairs = vec4(0.0);  // 雲階：x0, x1, z0（腳下）, z1（最高）；全 0＝沒有
uniform float stair_steps = 6.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	// ---- 雲洞：挖空，洞口外一圈比較亮
	float hole_edge = 0.0;
	for (int i = 0; i < hole_count; i++) {
		float dist = length(p - holes[i].xy);
		float rr = holes[i].z;
		if (dist < rr) {
			discard;
		}
		hole_edge = max(hole_edge, 1.0 - smoothstep(0.0, 0.9, dist - rr));
	}
	// ---- 在不在白玉台上（橢圓；邊緣是整齊的，這是人蓋的台子）
	float e = 9.0;
	vec2 lc = vec2(0.0);
	vec2 lr = vec2(1.0);
	for (int i = 0; i < lake_count; i++) {
		float ei = length((p - lakes[i].xy) / lakes[i].zw);
		if (ei < e) {
			e = ei;
			lc = lakes[i].xy;
			lr = lakes[i].zw;
		}
	}
	float fw = max(fwidth(e), 0.0005);
	float jade = 1.0 - smoothstep(1.0 - fw, 1.0 + fw, e);

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec2 par = -V.xz / max(V.y, 0.3);

	// ---- 白玉：溫潤的淡色，裡面有幾縷深色的雲絮和很淡的紋；一圈一圈同心的刻線；邊上一道鑲邊
	vec2 uv = p / 11.0;
	float wisp = texture(vein_tex, uv * 0.6 + par * 0.06).b;
	float vein = texture(vein_tex, uv * 0.9 + 0.21).r;
	float fine = texture(vein_tex, uv * 1.7 + 0.53).g;
	vec3 jc = mix(jade_pale, jade_mid, smoothstep(0.25, 0.85, wisp));
	jc = mix(jc, jade_deep, smoothstep(0.55, 0.95, wisp) * 0.35);
	jc = mix(jc, jade_pale * 1.04, clamp(vein * 0.5 + fine * 0.18, 0.0, 1.0));
	// 同心的刻線（每隔一段一圈細線）和十二道放射線：像一塊大玉璧
	float ring_w = fwidth(e) * 1.6 + 0.004;
	float rings = 0.0;
	for (int k = 1; k <= 3; k++) {
		float at = float(k) * 0.25;
		rings = max(rings, 1.0 - smoothstep(0.0, ring_w, abs(e - at)));
	}
	vec2 q = (p - lc) / lr;
	float ang = atan(q.y, q.x);
	float spoke = 1.0 - smoothstep(0.0, 0.012 / max(e, 0.2), abs(fract(ang / 6.2831853 * 12.0 + 0.5) - 0.5));
	spoke *= step(0.25, e) * step(e, 0.75);
	jc = mix(jc, jade_deep, max(rings, spoke) * 0.38);
	// 鑲邊：最外面一圈（寬的）＋裡面一條細線
	float band = smoothstep(0.900, 0.915, e) * (1.0 - smoothstep(0.965, 0.98, e));
	float band2 = smoothstep(0.870, 0.876, e) * (1.0 - smoothstep(0.884, 0.890, e));
	// 鑲邊上的回紋（一格一格）
	float key = step(0.5, fract(ang / 6.2831853 * 96.0)) * step(0.925, e) * step(e, 0.952);
	vec3 trim = mix(trim_c, trim_c * 0.62, key);
	jc = mix(jc, trim, max(band, band2));
	// 反光帶：幾條斜斜的亮帶跟著鏡頭滑動
	float s = dot(p, vec2(0.46, 0.28)) + V.x * 1.6 + V.z * 0.9;
	float f = fract(s * 0.105);
	float sheen = smoothstep(0.0, 0.02, f) * smoothstep(0.12, 0.09, f);
	sheen *= smoothstep(0.38, 0.62, texture(cloud_tex, p * 0.045 + 0.71).r);
	jc += sheen * 0.10;
	float fres = pow(1.0 - clamp(V.y, 0.0, 1.0), 4.0);
	jc = mix(jc, sky_tint, fres * 0.45);
	jc = mix(jc, vec3(1.0), hole_edge * hole_edge * 0.5);
	jc += vec3(0.6, 0.7, 1.0) * center_lift * (1.0 - smoothstep(0.15, 0.80, e));
	// 台子邊緣在雲上的影子
	float edge_shadow = smoothstep(1.0, 1.02, e) * (1.0 - smoothstep(1.02, 1.12, e));

	// ---- 雲毯：軟軟的一團一團，亮面近白、凹處帶環境色
	float puff = texture(cloud_tex, p * 0.035).r;
	float puff2 = texture(cloud_tex, p * 0.09 + 0.31).r;
	float h = puff * 0.65 + puff2 * 0.35;
	vec3 cc = mix(cloud_shade, cloud_lit, smoothstep(0.30, 0.68, h));
	cc = mix(cc, cloud_shade * 0.86, smoothstep(0.35, -0.5, wnrm.y));     // 邊緣垂下來的底面暗一點
	cc = mix(cc, cloud_shade * 0.78, edge_shadow * 0.7);
	cc = mix(cc, cloud_lit, hole_edge * 0.35 * (1.0 - jade));
	// 用起伏貼圖歪一下法線：平平的雲看起來是鼓起來的
	float da = texture(cloud_tex, (p + vec2(0.7, 0.0)) * 0.035).r - puff;
	float db = texture(cloud_tex, (p + vec2(0.0, 0.7)) * 0.035).r - puff;
	vec3 nw = normalize(wnrm + vec3(-da, 0.0, -db) * 7.0 * clamp(wnrm.y, 0.0, 1.0) * (1.0 - jade));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// ---- 雲階：斜坡畫成一階一階的玉階（每階前緣一條鑲邊色的線，踏面由淺到深）
	float on_st = 0.0;
	if (stairs.x != stairs.y) {
		float zk = (p.y - stairs.z) / (stairs.w - stairs.z);
		float inx = smoothstep(stairs.x - 0.05, stairs.x + 0.05, p.x) * (1.0 - smoothstep(stairs.y - 0.05, stairs.y + 0.05, p.x));
		on_st = inx * step(0.0, zk) * step(zk, 1.0) * (1.0 - jade);
		float st = fract(zk * stair_steps);
		vec3 sc = mix(jade_pale, jade_mid, st * 0.55);
		sc = mix(sc, trim_c, 1.0 - smoothstep(0.0, 0.10, st));          // 每一階的前緣
		sc = mix(sc, jade_deep, smoothstep(0.90, 1.0, st) * 0.6);         // 上一階投下來的影子
		float side_e = min(p.x - stairs.x, stairs.y - p.x);
		sc = mix(sc, trim_c * 0.85, 1.0 - smoothstep(0.10, 0.16, side_e)); // 兩側的邊
		cc = mix(cc, sc, on_st);
	}

	float solid = max(jade, on_st);
	ALBEDO = mix(cc, jc * jade_lit, jade);
	ROUGHNESS = mix(1.0, 0.30, jade);
	ROUGHNESS = mix(ROUGHNESS, 0.5, on_st);
	SPECULAR = mix(0.10, 0.45, solid);
	EMISSION = jc * jade_glow * jade + cc * 0.10 * (1.0 - solid);
}
