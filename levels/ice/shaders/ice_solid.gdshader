// 實心的冰（碎冰塊、冰洞口的破冰、冰柱、浮冰、冰雕、冰台座）：裡面深藍綠、邊緣淺，表面有細細的白裂紋（ice_cracks.png），
// 自己帶一點光，暖色光下也還是藍的。
shader_type spatial;

uniform sampler2D crack_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 inner : source_color = vec3(0.12, 0.52, 0.80);
uniform vec3 outer : source_color = vec3(0.80, 0.96, 1.0);
uniform float glow = 0.30;
uniform float frost_top = 0.5;      // 朝上的面結霜（變白）的程度
uniform float crack_amount = 0.35;

varying vec3 wn;
varying vec3 wp;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fr = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.6);
	vec3 c = mix(inner, outer, clamp(fr * 0.85 + 0.12, 0.0, 1.0));
	// 三個方向各貼一次裂紋，依面的朝向混合（方塊每一面都有紋路，不會被拉長）
	vec3 w = abs(wn);
	w /= (w.x + w.y + w.z);
	float cr = texture(crack_tex, wp.zy * 0.45).r * w.x + texture(crack_tex, wp.xz * 0.45).r * w.y + texture(crack_tex, wp.xy * 0.45).r * w.z;
	c = mix(c, vec3(0.95, 0.99, 1.0), cr * crack_amount);
	c = mix(c, vec3(0.92, 0.97, 1.0), smoothstep(0.55, 0.95, wn.y) * frost_top);
	ALBEDO = c;
	ROUGHNESS = 0.14;
	SPECULAR = 0.7;
	EMISSION = c * glow;
}
