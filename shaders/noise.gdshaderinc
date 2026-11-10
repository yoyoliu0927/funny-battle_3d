// 共用的程序化雜訊（用來打散貼圖重複感、做大範圍斑駁）
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1,0,0)), f.x),
	               mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
	               mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}
// 降低貼圖對比：往平均亮度靠攏
vec3 soften(vec3 c, float contrast) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(l), c, 0.85) * contrast + vec3(l) * (1.0 - contrast);
}
vec3 unpack_n(vec3 t) { return t * 2.0 - 1.0; }

