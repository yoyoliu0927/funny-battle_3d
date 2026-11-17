// 森林樹冠：每棵樹的顏色來自 MultiMesh，朝上的面亮、底下暗
// 特寫鏡頭時，擋在「鏡頭 → 主角」連線上的樹冠會變成半透明（網點鏤空），才看得到主角
shader_type spatial;
render_mode specular_disabled;

uniform vec3 fade_a = vec3(0.0);     // 線段起點（鏡頭）
uniform vec3 fade_b = vec3(0.0);     // 線段終點（主角）
uniform float fade_radius = 3.0;     // 離連線多近算擋住
uniform float fade_amt : hint_range(0.0, 1.0) = 0.0;   // 0 = 不透明，1 = 擋住的部分鏤空一半

varying float up;
varying vec3 wpos;

void vertex() {
	up = NORMAL.y;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade_amt > 0.0) {
		vec3 ab = fade_b - fade_a;
		float t = clamp(dot(wpos - fade_a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
		float d = distance(wpos, fade_a + ab * t);
		// 離連線越近鏤空越多；離鏡頭太近的（t 很小）也一併鏤空
		float hole = (1.0 - smoothstep(fade_radius * 0.6, fade_radius, d)) * fade_amt;
		float checker = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
		if (hole > 0.85 || (hole > 0.15 && checker < 0.5)) {
			discard;
		}
	}
	vec3 base = COLOR.rgb;
	ALBEDO = base * mix(0.7, 1.12, smoothstep(-0.4, 0.8, up));
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
