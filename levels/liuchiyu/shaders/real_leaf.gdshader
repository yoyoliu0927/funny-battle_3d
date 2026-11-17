shader_type spatial;
render_mode cull_disabled;
// 寫實的葉子和草：照片貼圖加上透明遮罩（葉子的形狀），背光時會透光，風吹會輕輕晃。
uniform sampler2D diff : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D nor : hint_normal, filter_linear_mipmap;
uniform sampler2D arm : filter_linear_mipmap;
uniform sampler2D alpha_tex : filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float sway = 0.03;
uniform float through = 0.55;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = sway * clamp(VERTEX.y * 2.0, 0.0, 1.5);
	VERTEX.x += sin(TIME * 1.3 + w.x * 0.7 + w.z * 0.5) * k;
	VERTEX.z += cos(TIME * 1.1 + w.z * 0.8) * k * 0.6;
}

void fragment() {
	ALPHA = texture(alpha_tex, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	vec3 c = texture(diff, UV).rgb * tint;
	vec3 a = texture(arm, UV).rgb;
	ALBEDO = c;
	ROUGHNESS = max(a.g, 0.45);
	AO = a.r;
	SPECULAR = 0.3;
	NORMAL_MAP = texture(nor, UV).rgb;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	BACKLIGHT = c * through * 2.0;
}
