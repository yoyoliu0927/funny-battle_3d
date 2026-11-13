// 冰雪島地圖的頂面：雪地＋結冰的湖＋結冰的小溪＋湖岸結霜＋冰洞挖空，一個著色器畫完（雪和冰的交界不會有接縫）。
// 湖、小溪、冰洞的位置由 ice_world.gd 傳進來；雪堆模型也用這個著色器（沒有湖就只畫雪）。
// 質感來自兩張貼圖：ice_cracks.png（裂紋／刮痕／冰層雲霧）和 snow_soft.png（雪丘／風紋／雪粒）。
shader_type spatial;

uniform int lake_count = 0;
uniform vec4 lakes[4];            // 中心 x, z, 半徑 x, z
uniform int hole_count = 0;
uniform vec4 holes[8];            // 中心 x, z, 挖空的半徑（洞口的破冰邊緣是模型，蓋在這個圓上面）
uniform int creek_count = 0;
uniform vec4 creeks[3];           // 小溪：起點 x, z → 終點 x, z（終點那一頭比較寬，通常接到湖）
uniform sampler2D crack_tex : repeat_enable, filter_linear_mipmap_anisotropic;   // R 裂紋 G 刮痕 B 深處雲霧
uniform sampler2D snow_tex : repeat_enable, filter_linear_mipmap_anisotropic;    // R 起伏 G 風紋 B 雪粒
uniform vec3 snow_lit : source_color = vec3(0.97, 0.98, 1.0);
uniform vec3 snow_shade : source_color = vec3(0.76, 0.85, 0.99);
uniform vec3 ice_deep : source_color = vec3(0.05, 0.33, 0.66);
uniform vec3 ice_mid : source_color = vec3(0.20, 0.66, 0.86);
uniform vec3 ice_pale : source_color = vec3(0.70, 0.93, 0.98);
uniform vec3 sky_tint : source_color = vec3(0.80, 0.92, 1.0);
uniform float ice_glow = 0.22;      // 冰自己發的光（暖色光、陰影裡也還是藍綠色）
uniform float ice_lit = 0.75;       // 冰吃多少場景的光
uniform float sparkle = 1.0;
uniform float drift_amount = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

// 這一點離小溪多遠（1 = 剛好在溪邊）
float creek_e(vec2 p, vec4 ck) {
	vec2 a = ck.xy;
	vec2 ab = ck.zw - a;
	float len = length(ab);
	vec2 dir = ab / max(len, 0.001);
	float t = clamp(dot(p - a, dir) / len, 0.0, 1.0);
	vec2 side = vec2(-dir.y, dir.x);
	vec2 q = a + ab * t + side * sin(t * len * 0.75) * 0.55;      // 彎彎曲曲的
	return length(p - q) / mix(0.55, 1.15, t);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	// ---- 冰洞：挖空，洞口外一圈是被敲碎的淺色冰
	float hole_edge = 0.0;
	for (int i = 0; i < hole_count; i++) {
		vec2 d = p - holes[i].xy;
		float dist = length(d);
		float rr = holes[i].z;
		if (dist < rr) {
			discard;
		}
		hole_edge = max(hole_edge, 1.0 - smoothstep(0.0, 0.75, dist - rr));
	}
	// ---- 這一點在不在湖裡（岸邊用雜訊打亂一點，不要完美的橢圓）
	float e = 9.0;
	for (int i = 0; i < lake_count; i++) {
		e = min(e, length((p - lakes[i].xy) / lakes[i].zw));
	}
	for (int i = 0; i < creek_count; i++) {
		e = min(e, 0.89 + 0.11 * creek_e(p, creeks[i]));         // 小溪窄，整條都偏白（結霜），跟會滑的湖面分得出來
	}
	float n_lo = texture(snow_tex, p * 0.031).r;
	float n_hi = texture(snow_tex, p * 0.13 + 0.37).r;
	float e2 = e + (n_lo - 0.5) * 0.07 + (n_hi - 0.5) * 0.035;
	float fw = max(fwidth(e2), 0.0005);
	float ice = 1.0 - smoothstep(1.0 - fw, 1.0 + fw, e2);
	float frost = smoothstep(0.80, 1.0, e2) * (0.65 + 0.35 * n_hi);

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec2 par = -V.xz / max(V.y, 0.3);

	// ---- 冰：中心深、岸邊淺；表面白裂紋，底下還有一層會跟著視角錯開的深色裂紋和雲霧（看起來有厚度）
	vec2 uv = p / 9.0;
	float crack_top = texture(crack_tex, uv).r;
	float scratch = texture(crack_tex, uv * 1.6 + 0.31).g;
	float crack_deep = texture(crack_tex, uv * 0.83 + par * 0.05 + 0.5).r;
	float cloud = texture(crack_tex, uv * 0.55 + par * 0.09).b;
	float shore = smoothstep(0.0, 0.95, e2);
	vec3 icec = mix(ice_mid, ice_deep, clamp(cloud * 0.85 + 0.15 - shore * 0.45, 0.0, 1.0));
	icec = mix(icec, ice_pale, shore * shore * 0.55);
	icec = mix(icec, ice_deep * 0.72, crack_deep * 0.5);
	icec = mix(icec, vec3(0.94, 0.99, 1.0), clamp(crack_top * 0.9 + scratch * 0.55, 0.0, 1.0));
	// 反光帶：幾條斜斜的亮帶，會跟著鏡頭滑動
	float s = dot(p, vec2(0.46, 0.28)) + V.x * 1.6 + V.z * 0.9;
	float f = fract(s * 0.105);
	float band = smoothstep(0.0, 0.015, f) * smoothstep(0.105, 0.09, f) + smoothstep(0.15, 0.158, f) * smoothstep(0.195, 0.187, f);
	band *= smoothstep(0.38, 0.62, texture(snow_tex, p * 0.045 + 0.71).r);
	icec += band * 0.20;
	float fres = pow(1.0 - clamp(V.y, 0.0, 1.0), 4.0);
	icec = mix(icec, sky_tint, fres * 0.55);
	icec = mix(icec, vec3(0.91, 0.96, 1.0), frost * 0.8);
	icec = mix(icec, vec3(0.86, 0.97, 1.0), hole_edge * hole_edge * 0.85);
	// 雪堤在冰上的影子：緊貼岸邊一條深色
	icec *= mix(1.0, 0.80, smoothstep(0.955, 1.0, e2) * ice);

	// ---- 雪：亮面近白、凹處偏藍，大起伏＋風紋＋亮晶晶
	float dune = texture(snow_tex, p * 0.036).r;
	float ripple = texture(snow_tex, p * 0.11).g;
	vec3 snowc = mix(snow_shade, snow_lit, smoothstep(0.28, 0.66, dune));
	snowc -= ripple * 0.035;
	// 雪簷的底面和垂下來的地方暗一點、藍一點：看得出雪有厚度
	snowc = mix(snowc, snow_shade * 0.80, smoothstep(0.35, -0.5, wnrm.y));
	float bank = 1.0 - smoothstep(1.0, 1.10, e2);
	snowc = mix(snowc, snow_shade * 0.93, bank * 0.55 * (1.0 - ice));
	// 用起伏貼圖歪一下法線：平平的雪地看起來有鼓起來的雪丘
	float dx = texture(snow_tex, (p + vec2(0.45, 0.0)) * 0.036).r - dune;
	float dz = texture(snow_tex, (p + vec2(0.0, 0.45)) * 0.036).r - dune;
	vec3 nw = normalize(wnrm + vec3(-dx, 0.0, -dz) * 5.5 * drift_amount * clamp(wnrm.y, 0.0, 1.0) * (1.0 - ice));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float sp = texture(snow_tex, p * 0.55).b;
	float tw = sin(dot(floor(p * 31.0), vec2(12.9898, 78.233)) + (V.x + V.z) * 55.0) * 0.5 + 0.5;
	float glint = sp * smoothstep(0.55, 1.0, tw) * sparkle * (1.0 - ice * (1.0 - frost));

	ALBEDO = mix(snowc, icec * mix(ice_lit, 1.0, frost), ice);
	ROUGHNESS = mix(1.0, 0.16, ice * (1.0 - frost * 0.75));
	SPECULAR = mix(0.12, 0.62, ice);
	EMISSION = icec * ice_glow * ice * (1.0 - frost * 0.8) + vec3(glint * 0.55);
}
