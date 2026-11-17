// 劉起佑版：畫面四周壓暗，帶一點紫
shader_type canvas_item;

uniform float strength = 0.55;

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 1.12);
	float v = smoothstep(0.34, 0.86, length(p));
	COLOR = vec4(0.05, 0.02, 0.10, v * strength);
}
