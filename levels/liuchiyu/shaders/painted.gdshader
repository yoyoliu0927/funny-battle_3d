// 劉起佑版：手繪感的木頭／灰泥材質——不均勻的刷色、木板縫、邊緣一圈暖色輪廓光
shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(0.4, 0.35, 0.4);
uniform float plank = 0.0;            // > 0：每公尺幾條木板（直的）
uniform vec3 rim_color : source_color = vec3(1.0, 0.55, 0.30);
uniform float rim = 0.5;
uniform float mottle = 0.35;
uniform float shingle = 0.0;          // > 0：每公尺幾排屋瓦

varying vec3 wp;
varying vec3 lp;

float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lp = VERTEX;
}

void fragment() {
	// 頂點／實體顏色是用螢幕上看到的顏色寫的，這裡轉成運算用的線性值
	vec3 c = albedo * pow(COLOR.rgb, vec3(2.2));
	float n = n3(wp * 0.9) * 0.55 + n3(wp * 3.1) * 0.30 + n3(wp * 9.0) * 0.15;
	c *= mix(1.0 - mottle, 1.0 + mottle * 0.45, n);
	if (plank > 0.0) {
		float u = atan(lp.x, lp.z) * 2.2 * plank + (lp.x + lp.z) * 0.15;
		float id = floor(u);
		float gap = smoothstep(0.0, 0.10, abs(fract(u) - 0.5) * 2.0 - 0.86);
		c *= mix(0.82, 1.08, fract(sin(id * 91.7) * 4375.5));
		c *= 1.0 - gap * 0.55;
	}
	if (shingle > 0.0) {
		float row = lp.y * shingle;
		float rid = floor(row);
		float u2 = atan(lp.x, lp.z) * 3.2 + rid * 0.5;
		float tid = floor(u2);
		c *= mix(0.74, 1.10, fract(sin(tid * 12.9 + rid * 78.2) * 43758.5));
		// 每排瓦的下緣有陰影，瓦跟瓦之間有細縫
		c *= 1.0 - smoothstep(0.0, 0.30, 0.30 - fract(row)) * 0.45;
		c *= 1.0 - smoothstep(0.90, 1.0, abs(fract(u2) - 0.5) * 2.0) * 0.30;
	}
	// 從上面流下來的雨痕、髒污
	float streak = n3(vec3(wp.x * 3.5, wp.y * 0.35, wp.z * 3.5));
	c *= mix(0.80, 1.05, smoothstep(0.25, 0.75, streak));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * c * fres * rim;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.20, 0.35, ndl) * 0.75 + clamp(ndl, 0.0, 1.0) * 0.25;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
