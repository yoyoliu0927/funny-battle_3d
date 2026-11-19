// 洞裡面：水潭／錦鯉池是深色的水（一圈一圈的波紋、幾片亮的反光）；星洞是往下看的星空（stars = 1）。不吃光。
// 模型的半徑是 1（跟冰雪島的冰洞口一樣），所以 radius 用模型自己的座標。
shader_type spatial;
render_mode unshaded;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.06, 0.26, 0.32);
uniform vec3 light_c : source_color = vec3(0.40, 0.72, 0.72);
uniform float stars = 0.0;
uniform float radius = 1.12;
uniform float brightness = 1.0;

varying vec3 lp;
varying vec3 wp;

void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = lp.xz / radius;
	float d = length(q);
	float n = texture(noise_tex, wp.xz * 0.16 + vec2(TIME * 0.02, -TIME * 0.015)).r;
	// 水：中心深、岸邊淺；一圈一圈往外的波紋
	float ring = sin(d * 15.0 - TIME * 1.4 + n * 5.0);
	float lines = smoothstep(0.86, 0.97, ring) * (0.35 + 0.65 * n) * smoothstep(0.1, 0.5, d);
	vec3 water = mix(light_c, deep, smoothstep(1.0, 0.2, d + (n - 0.5) * 0.3));
	water += vec3(0.9, 1.0, 0.95) * lines * 0.22;
	water = mix(water, light_c * 1.15, smoothstep(0.82, 0.97, d + (n - 0.5) * 0.12) * 0.6);
	// 星空：慢慢轉的漩渦裡有一點一點的星星，中心最黑
	float a = atan(q.y, q.x) + TIME * 0.25 + (1.0 - d) * 2.4;
	vec2 sw = vec2(cos(a), sin(a)) * d;
	float neb = texture(noise_tex, sw * 0.7 + 0.3).r;
	vec3 voidc = mix(deep, light_c, smoothstep(0.45, 0.85, neb) * smoothstep(0.15, 0.9, d) * 0.7);
	float star = smoothstep(0.90, 0.98, texture(noise_tex, sw * 4.1 + 0.17).b) * (0.6 + 0.4 * sin(TIME * 3.0 + neb * 40.0));
	voidc += vec3(1.0, 0.95, 0.8) * star;
	voidc = mix(voidc, vec3(1.0, 0.86, 0.5), smoothstep(0.88, 1.0, d) * 0.7);
	ALBEDO = mix(water, voidc, stars) * brightness;
}
