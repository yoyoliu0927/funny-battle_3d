// 場上的模型（Kenney 素材包、本組 Blender 做的木頭和道具）共用的卡通材質：
// 原本的顏色（貼圖或單色）＋柔和的兩階光影＋靠近地面變暗一點（東西像是站在雪地上）＋一點筆觸細節（snow_soft.png），
// 跟平塗的雪地、冰面放在一起才不會顯得沒畫完。
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 emission_c : source_color = vec3(0.0);
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;
uniform float detail = 0.14;
uniform float ground_shade = 0.34;      // 最底下暗多少
uniform float ground_h = 1.2;           // 離地多高就不暗了（公尺）

varying vec3 wp;
varying vec3 wn;
varying float hy;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	hy = wp.y - MODEL_MATRIX[3].y;
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * tint.rgb;
	vec3 w = abs(wn);
	w /= (w.x + w.y + w.z);
	float fine = texture(detail_tex, wp.zy * 0.55).g * w.x + texture(detail_tex, wp.xz * 0.55).g * w.y + texture(detail_tex, wp.xy * 0.55).g * w.z;
	float big = texture(detail_tex, wp.xz * 0.11 + wp.y * 0.17).r;
	a *= 1.0 - fine * detail + (big - 0.5) * detail * 1.2;
	a *= mix(1.0 - ground_shade, 1.0, smoothstep(0.0, ground_h, hy));
	ALBEDO = a;
	ROUGHNESS = 1.0;
	EMISSION = emission_c;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.22, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
