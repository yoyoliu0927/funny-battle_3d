// 場上的模型（Kenney 素材包、本組 Blender 做的木頭和道具）共用的卡通材質：
// 原本的顏色（貼圖或單色）＋柔和的兩階光影＋靠近地面變暗一點（東西像是站在雪地上）＋一點筆觸細節（snow_soft.png），
// 跟平塗的雪地、冰面放在一起才不會顯得沒畫完。另外三個開關：
//   tree_shade  雪松：每一層樹葉的底部一圈深綠、積雪的下緣一條亮邊（ice_world.gd 載入時算好放在頂點色裡：R = 在這一層的高度 0~1，G = 1 是雪）
//   dark_body   企鵝：把素材包裡灰藍色的身體改成接近黑色（白肚子、橘色的嘴和腳不動）
//   rim         輪廓光：夜裡站在深色籠子前面也看得出剪影
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 emission_c : source_color = vec3(0.0);
uniform sampler2D detail_tex : repeat_enable, filter_linear_mipmap;
uniform float detail = 0.14;
uniform float ground_shade = 0.34;      // 最底下暗多少
uniform float ground_h = 1.2;           // 離地多高就不暗了（公尺）
uniform float tree_shade = 0.0;
uniform float dark_body = 0.0;
uniform vec3 body_color : source_color = vec3(0.07, 0.08, 0.12);
uniform float rim = 0.0;
uniform vec3 rim_color : source_color = vec3(0.75, 0.88, 1.0);
instance uniform float base_y = -1000.0;   // 這個模型站的地面高度（ice_world.gd 放模型時填）

varying vec3 wp;
varying vec3 wn;
varying float hy;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	hy = wp.y - base_y;
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * tint.rgb;
	if (dark_body > 0.5) {
		float lum = dot(a, vec3(0.3, 0.59, 0.11));
		float sat = max(a.r, max(a.g, a.b)) - min(a.r, min(a.g, a.b));
		a = mix(a, body_color, (1.0 - smoothstep(0.42, 0.58, lum)) * (1.0 - smoothstep(0.12, 0.25, sat)));
	}
	if (tree_shade > 0.5) {
		float t = COLOR.r;
		if (COLOR.g > 0.5) {
			// 雪：整體帶一點藍，下緣一條亮邊
			a = mix(a * vec3(0.86, 0.92, 1.0), vec3(1.0), 1.0 - smoothstep(0.03, 0.20, t));
		} else {
			// 樹葉、樹幹：這一層的底部一圈深色，往上亮一點
			a *= mix(0.55, 1.0, smoothstep(0.04, 0.36, t)) * (1.0 + 0.10 * t);
		}
	}
	vec3 w = abs(wn);
	w /= (w.x + w.y + w.z);
	float fine = texture(detail_tex, wp.zy * 0.55).g * w.x + texture(detail_tex, wp.xz * 0.55).g * w.y + texture(detail_tex, wp.xy * 0.55).g * w.z;
	float big = texture(detail_tex, wp.xz * 0.11 + wp.y * 0.17).r;
	a *= 1.0 - fine * detail + (big - 0.5) * detail * 1.2;
	a *= mix(1.0 - ground_shade, 1.0, smoothstep(0.0, ground_h, hy));
	ALBEDO = a;
	ROUGHNESS = 1.0;
	float fr = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	EMISSION = emission_c + rim_color * fr * rim;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float t = smoothstep(-0.12, 0.22, ndl) * 0.8 + clamp(ndl, 0.0, 1.0) * 0.2;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
