// 遠景地面：被霧吃掉的大平面
shader_type spatial;
uniform vec3 color : source_color = vec3(0.46, 0.52, 0.5);
void fragment() { ALBEDO = color; ROUGHNESS = 1.0; }
