// 鳳凰形狀的金光（模型是一片展翅的剪影）：結局從家豪背後升起的大鳳凰、百鳥、引路的靈光都用這個。
// 加亮、不吃光；由下往上流動的金橘色，邊緣和羽毛之間留暗縫，才看得出形狀（不會糊成一片白）。
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform float strength = 0.62;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float flow = 0.5 + 0.5 * sin(lp.y * 5.0 - TIME * 4.0 + abs(lp.x) * 2.0);
	// 羽毛：從中線往兩邊一道一道
	float feather = 0.62 + 0.38 * smoothstep(0.2, 0.8, 0.5 + 0.5 * sin(abs(lp.x) * 13.0 - lp.y * 4.0));
	vec3 c = mix(vec3(1.0, 0.36, 0.05), vec3(1.0, 0.78, 0.30), flow);
	c = mix(c, vec3(1.0, 0.92, 0.62), smoothstep(0.75, 1.0, flow) * 0.5);
	ALBEDO = c * feather * strength;
}
