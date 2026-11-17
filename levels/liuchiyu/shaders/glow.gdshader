// 劉起佑版：會發光的東西（窗戶、燈泡、燈籠）。亮度超過 1，靠畫面的 glow 暈開
shader_type spatial;
render_mode unshaded;

uniform vec3 tint : source_color = vec3(1.0, 0.72, 0.36);
uniform float energy = 3.0;

void fragment() {
	// 中間亮、邊緣稍暗，像隔著髒玻璃
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint * pow(COLOR.rgb, vec3(2.2)) * energy * mix(0.75, 1.0, f);
}
