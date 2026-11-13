// 營火的火焰：不吃光，會左右晃、往上竄；底部顏色深、尖端亮。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 base_c : source_color = vec3(1.0, 0.42, 0.08);
uniform vec3 tip_c : source_color = vec3(1.0, 0.82, 0.25);
uniform float speed = 1.0;
uniform float phase = 0.0;

varying float hy;

void vertex() {
	hy = VERTEX.y;
	float t = TIME * speed + phase;
	VERTEX.x += sin(t * 9.0 + VERTEX.y * 5.0) * 0.07 * VERTEX.y;
	VERTEX.z += cos(t * 7.3 + VERTEX.y * 4.0) * 0.06 * VERTEX.y;
	VERTEX.y *= 1.0 + sin(t * 11.0) * 0.10;
}

void fragment() {
	ALBEDO = mix(base_c, tip_c, smoothstep(0.1, 0.9, hy)) * 1.6;
}
