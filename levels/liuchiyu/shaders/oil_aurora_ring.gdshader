shader_type spatial;
// 晚上的提示：一圈極光圍住可以互動的東西。畫法和天空裡的極光一樣（oil_sky.gdshader）：
// 一整片連續的光幕，下緣是一條會上下起伏的弧線，再用很細的直筆觸決定每個地方往上拉多長，
// 所以上緣是參差的尖頭、裡面有一絲一絲的直紋，整圈會上下搖擺。
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float strength = 1.0;
varying vec3 lp;

vec3 hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash3(i).x, hash3(i + vec3(1, 0, 0)).x, f.x);
	float b = mix(hash3(i + vec3(0, 1, 0)).x, hash3(i + vec3(1, 1, 0)).x, f.x);
	float c = mix(hash3(i + vec3(0, 0, 1)).x, hash3(i + vec3(1, 0, 1)).x, f.x);
	float d = mix(hash3(i + vec3(0, 1, 1)).x, hash3(i + vec3(1, 1, 1)).x, f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	lp = VERTEX;
	// 光幕不是正圓，慢慢扭
	float ang = atan(VERTEX.z, VERTEX.x);
	VERTEX.xz *= 1.0 + 0.10 * sin(ang * 3.0 + TIME * 0.5) + 0.05 * sin(ang * 5.0 - TIME * 0.35);
}

void fragment() {
	float a = atan(lp.z, lp.x);
	float e = lp.y + 0.5;            // 0 = 底、1 = 頂
	vec2 cc = vec2(cos(a), sin(a));
	// 下緣：上下起伏的弧線（這就是「上下搖擺」）
	float e0 = 0.14 + 0.09 * sin(a * 2.0 + TIME * 0.9) + 0.05 * sin(a * 5.0 - TIME * 1.3);
	float base_len = 0.30 + 0.40 * vnoise(vec3(cc * 3.0, TIME * 0.3));
	float tone = vnoise(vec3(cc * 1.3 + 5.0, TIME * 0.08));
	// 兩層細筆觸（粗的、細的）：每一筆有自己的長度和亮度
	float streak_len = 0.0;
	float streak_b = 0.0;
	float edge = 0.0;
	for (int k = 0; k < 2; k++) {
		float w = k == 0 ? 0.11 : 0.036;
		float id = floor(a / w);
		vec3 r = hash3(vec3(id, float(k) * 5.0 + 3.0, 1.0));
		float flick = 0.8 + 0.2 * sin(TIME * (1.0 + 2.0 * r.z) + id);
		streak_len += (k == 0 ? 0.65 : 0.35) * (0.25 + 1.5 * r.y * r.y) * flick;
		streak_b += (k == 0 ? 0.6 : 0.4) * (0.40 + 0.60 * r.x);
		edge += (r.z - 0.5) * (k == 0 ? 0.05 : 0.025);
	}
	float d = e - e0 - edge;
	float len = base_len * streak_len;
	float t = d / len;
	float body = step(0.0, d) * pow(clamp(1.0 - t, 0.0, 1.0), 1.7) * streak_b;
	float d0 = e - e0;
	float halo = (d0 > 0.0 ? exp(-d0 / (base_len * 0.55)) : exp(d0 * 30.0)) * 0.14;
	float inten = (body + halo) * smoothstep(1.0, 0.8, e);
	// 顏色：以綠色為主，有些段落是青色；最下緣偏白，頂端帶一點藍紫
	float tt = clamp(d0 / (base_len * 1.2), 0.0, 1.0);
	vec3 ac = mix(vec3(0.22, 1.0, 0.14), vec3(0.03, 0.95, 0.70), smoothstep(0.40, 0.60, tone));
	ac = mix(ac, vec3(0.03, 0.85, 0.36), smoothstep(0.20, 0.50, tt) * 0.6);
	ac = mix(ac, vec3(0.04, 0.62, 0.80), smoothstep(0.55, 0.95, tt) * 0.5);
	ac = mix(ac, vec3(0.22, 0.26, 0.85), smoothstep(0.85, 1.0, tt) * 0.35);
	ac = mix(ac, vec3(0.80, 1.0, 0.88), smoothstep(0.14, 0.0, tt) * step(0.0, d) * 0.30);
	ALBEDO = ac * inten * 1.7 * strength;
}
