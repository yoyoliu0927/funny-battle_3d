// 選關地圖的海：卡通風格的青藍色海面，淺處透出底下的沙，帶一點緩慢的波紋亮線
shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform vec3 deep : source_color = vec3(0.24, 0.52, 0.60);
uniform vec3 light_c : source_color = vec3(0.55, 0.80, 0.80);
// 只有島附近的淺海半透明（看得到底下的沙），外海不透明，避免看到地形網格的邊
uniform vec2 island_center = vec2(0.0, 3.0);
uniform vec2 island_radius = vec2(25.0, 11.0);

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uv = wpos.xz * 0.35;
	float w = n2(uv + vec2(TIME * 0.05, TIME * 0.03)) * 0.6 + n2(uv * 2.3 - vec2(TIME * 0.04, 0.0)) * 0.4;
	float sparkle = smoothstep(0.72, 0.78, w);
	ALBEDO = mix(deep, light_c, sparkle * 0.6 + w * 0.15);
	vec2 q = (wpos.xz - island_center) / island_radius;
	ALPHA = mix(0.78, 1.0, smoothstep(0.95, 1.25, length(q)));
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += (smoothstep(-0.12, 0.18, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2) * ATTENUATION * LIGHT_COLOR / PI;
}
