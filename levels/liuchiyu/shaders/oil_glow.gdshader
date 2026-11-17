shader_type spatial;
// 晚上的提示光：可以互動的東西身上有一條一條往上飄的極光光帶（綠 → 青 → 一點紫），疊加在原本的顏色上
render_mode unshaded, blend_add, depth_draw_never, fog_disabled;

uniform float strength = 1.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	// 光帶：沿著高度一條一條，左右被慢慢扭動，整體往上飄
	float wob = sin(wp.x * 0.7 + t * 0.5) * 1.5 + sin(wp.z * 0.6 - t * 0.4) * 1.5;
	float band = smoothstep(0.25, 1.0, sin(wp.y * 1.3 - t * 1.6 + wob));
	float fine = 0.75 + 0.25 * sin(wp.y * 6.0 + wob * 2.0 - t * 3.0);     // 光帶裡細細的筆觸
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);       // 輪廓邊緣比較亮
	vec3 c = mix(vec3(0.12, 1.0, 0.50), vec3(0.20, 0.62, 1.0), 0.5 + 0.5 * sin(wp.y * 0.5 + t * 0.7));
	c = mix(c, vec3(0.62, 0.38, 1.0), 0.35 * smoothstep(0.5, 1.0, sin(wp.x * 0.4 + wp.y * 0.3 + t * 0.3)));
	float pulse = 0.72 + 0.28 * sin(t * 2.2);
	ALBEDO = c * (0.05 + 0.50 * band * fine + 0.30 * rim * (0.4 + 0.6 * band)) * pulse * strength;
}
