shader_type spatial;
// 寫實水面：兩層流動的波紋法線、近岸透明、深處深綠，反射天空。
uniform sampler2D ripple : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec3 shallow : source_color = vec3(0.22, 0.26, 0.17);
uniform vec3 deep : source_color = vec3(0.05, 0.10, 0.09);
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wp.xz * 0.22;
	vec3 n1 = texture(ripple, uv + TIME * vec2(0.012, 0.007)).rgb;
	vec3 n2 = texture(ripple, uv * 2.3 - TIME * vec2(0.009, 0.015)).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = 0.35;
	TANGENT = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);

	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float thick = clamp((VERTEX.z - v.z / v.w) / 1.1, 0.0, 1.0);
	ALBEDO = mix(shallow, deep, thick);
	ALPHA = mix(0.5, 0.97, smoothstep(0.0, 0.45, thick));
	ROUGHNESS = 0.03;
	METALLIC = 0.4;       // 讓水面多反射一點天空
	SPECULAR = 1.0;
}
