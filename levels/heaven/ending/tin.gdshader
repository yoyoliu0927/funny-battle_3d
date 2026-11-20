// 鐵皮屋的浪板：灰藍色、一條一條的波浪
shader_type spatial;

uniform vec3 tint : source_color = vec3(0.50, 0.55, 0.62);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wave = sin((wp.x + wp.z) * 11.0);
	float rust = smoothstep(0.55, 0.9, sin(wp.x * 1.7 + wp.y * 2.3) * sin(wp.z * 1.3 - wp.y * 3.1));
	ALBEDO = mix(tint * (0.84 + 0.16 * wave), vec3(0.42, 0.30, 0.24), rust * 0.35);
	ROUGHNESS = 0.55;
	METALLIC = 0.35;
}
