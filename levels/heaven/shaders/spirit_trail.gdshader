// 鳳羽靈光的尾巴：一條越往後越細越淡的金色光帶。UV.x 0（頭）～1（尾），UV.y 橫向 0～1。
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.97, 0.80);
uniform vec3 gold : source_color = vec3(1.0, 0.70, 0.22);
uniform float strength = 1.0;

void fragment() {
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float along = pow(1.0 - UV.x, 1.4);
	float shimmer = 0.75 + 0.25 * sin(UV.x * 40.0 - TIME * 9.0);
	float c = pow(across, 2.5);
	ALBEDO = mix(gold, core, c) * (pow(across, 0.8) * along * shimmer) * strength;
}
