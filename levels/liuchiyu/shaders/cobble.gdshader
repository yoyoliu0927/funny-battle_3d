// 劉起佑版：磨舊的石板地。遊玩範圍裡貼石板貼圖（Poly Haven: monastery_stone_floor），
// 外面慢慢變成深色的濕泥地和青苔
shader_type spatial;

uniform sampler2D diff_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nor_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 play_min = vec2(-12.0, -12.0);
uniform vec2 play_max = vec2(12.0, 14.0);
uniform float tile_size = 4.6;          // 貼圖一格鋪幾公尺
uniform float brightness = 3.0;
uniform float bump = 2.4;
uniform vec3 warm_tint : source_color = vec3(1.0, 0.86, 0.72);
uniform vec3 cool_tint : source_color = vec3(0.80, 0.84, 0.98);
uniform vec3 earth : source_color = vec3(0.115, 0.125, 0.15);
uniform vec3 moss : source_color = vec3(0.16, 0.24, 0.21);

varying vec3 wp;

float h1(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h1(i), h1(i + vec2(1, 0)), f.x), mix(h1(i + vec2(0, 1)), h1(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 地形沒有 UV，直接用世界座標鋪貼圖；切線方向跟著給，凹凸貼圖才會對
	TANGENT = vec3(1.0, 0.0, 0.0);
	BINORMAL = vec3(0.0, 0.0, -1.0);
}

void fragment() {
	vec2 p = wp.xz;
	vec2 uv = p / tile_size;
	vec3 d = texture(diff_tex, uv).rgb;
	float ao = texture(ao_tex, uv).r;
	float rough = texture(rough_tex, uv).r;

	// 大範圍的顏色變化，蓋掉貼圖重複的感覺：有的地方偏暖、有的偏冷、有的比較髒
	float big = n2(p * 0.16 + 3.0);
	float mid = n2(p * 0.55 + 11.0);
	vec3 col = d * brightness * mix(warm_tint, cool_tint, smoothstep(0.35, 0.70, big));
	col *= mix(0.82, 1.12, mid);
	col *= mix(0.25, 1.0, ao * ao);

	// 遊玩範圍外：石板漸漸消失，變成泥地和青苔
	vec2 out_v = max(max(play_min - p, p - play_max), vec2(0.0));
	float outside = smoothstep(0.6, 4.0, length(out_v) + (n2(p * 0.9) - 0.5) * 2.4);
	float lum = dot(d, vec3(0.33)) * 3.0;
	vec3 ground = mix(earth, moss, smoothstep(0.45, 0.70, n2(p * 0.55 + 20.0))) * mix(0.7, 1.25, lum);
	col = mix(col, ground, outside);
	// 陡的地方是深色岩石
	col = mix(col, vec3(0.13, 0.12, 0.17) * mix(0.7, 1.3, lum), COLOR.b);

	ALBEDO = col;
	NORMAL_MAP = texture(nor_tex, uv).rgb;
	NORMAL_MAP_DEPTH = bump * (1.0 - outside * 0.5);
	// 有些地方積了一點水，比較會反光
	float wet = smoothstep(0.55, 0.80, n2(p * 0.35 + 40.0));
	ROUGHNESS = clamp(rough * mix(0.95, 0.55, wet) + outside * 0.2, 0.25, 1.0);
	SPECULAR = 0.4;
}
