// 雲洞裡面：往下看，是一層慢慢打轉的雲，中心比較深（看得到底下是空的）。不吃光。
// 模型的半徑是 1（跟冰雪島的冰洞口一樣），所以 radius 用模型自己的座標。
shader_type spatial;
render_mode unshaded;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.20, 0.40, 0.50);
uniform vec3 light_c : source_color = vec3(0.86, 0.95, 0.96);
uniform float radius = 1.12;
uniform float brightness = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec2 q = lp.xz / radius;
	float d = length(q);
	float a = atan(q.y, q.x) + TIME * 0.35 + (1.0 - d) * 2.2;       // 越裡面轉得越多：一個漩渦
	vec2 sw = vec2(cos(a), sin(a)) * d;
	float n = texture(noise_tex, sw * 0.55 + 0.3).r * 0.6 + texture(noise_tex, sw * 1.3 - TIME * 0.02).r * 0.4;
	float depth = smoothstep(0.95, 0.15, d);
	vec3 c = mix(light_c, deep, depth * (0.55 + 0.45 * smoothstep(0.35, 0.65, n)));
	c = mix(c, deep * 0.6, smoothstep(0.45, 0.0, d) * 0.6);
	c = mix(c, light_c, smoothstep(0.82, 1.0, d + (n - 0.5) * 0.2));
	ALBEDO = c * brightness;
}
