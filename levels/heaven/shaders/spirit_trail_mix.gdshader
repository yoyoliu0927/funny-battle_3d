// 鳳羽靈光的尾巴（白天的關卡）：一般的半透明混色——加亮的版本在淺色背景上只會變白。UV.x 0（頭）～1（尾），UV.y 橫向 0～1。
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.90, 0.45);
uniform vec3 gold : source_color = vec3(1.0, 0.52, 0.08);

void fragment() {
	float across = 1.0 - abs(UV.y - 0.5) * 2.0;
	float along = pow(1.0 - UV.x, 1.2);
	float shimmer = 0.8 + 0.2 * sin(UV.x * 40.0 - TIME * 9.0);
	ALBEDO = mix(gold, core, pow(across, 2.0));
	ALPHA = clamp(pow(across, 0.7) * along * shimmer * 0.95, 0.0, 1.0);
}
