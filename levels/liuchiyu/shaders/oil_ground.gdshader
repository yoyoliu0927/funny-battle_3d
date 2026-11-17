shader_type spatial;
// 油畫風的地面：筆觸是預先畫好的貼圖（levels/liuchiyu/tools/bake_textures.gd 產生），shader 只負責：
// 低頻的大塊光斑決定哪裡疊暖色筆觸、遠處筆觸淡成純色、陡坡換成岩石色，光影用三階 ramp。
// 貼圖由 levels/liuchiyu/oil_textures.gd 設成這個 shader 的預設值，材質不用自己設。
#include "res://levels/liuchiyu/shaders/toon_light.gdshaderinc"

uniform sampler2D shade_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sun_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// 照片掃描的落葉地面（Poly Haven brown_mud_leaves_01，CC0）：只拿它的「形狀」——哪裡是葉子、哪裡是泥土、明暗，
// 顏色全部換成秋天的調色盤、明暗切成幾階平塗，所以看起來是畫的，但葉子的形狀和疊法是真的。
uniform sampler2D photo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_photo = 1.0;       // 1 = 用照片當形狀，0 = 用預先畫好的筆觸貼圖
uniform float photo_tile = 3.2;      // 一張照片鋪多少公尺
uniform float tile = 8.0;            // 一張筆觸貼圖鋪多少公尺
uniform vec3 far_shade : source_color = vec3(0.37, 0.21, 0.15);     // 遠處（看不清筆觸）的陰影底色
uniform vec3 far_sun : source_color = vec3(0.84, 0.56, 0.17);       // 遠處光斑的顏色
uniform vec3 rock : source_color = vec3(0.24, 0.13, 0.14);

uniform float night = 0.0;           // 1 = 晚上：不管原本什麼顏色，都換成同一組由深到淺的藍綠色
uniform vec3 night_dark : source_color = vec3(0.40, 0.56, 0.66);
uniform vec3 night_mid : source_color = vec3(0.66, 0.81, 0.87);
uniform vec3 night_light : source_color = vec3(0.94, 0.99, 0.99);
vec3 night_ramp(vec3 c) {
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	vec3 r = mix(night_dark, night_mid, smoothstep(0.12, 0.42, l));
	return mix(r, night_light, smoothstep(0.42, 0.80, l));
}
uniform vec2 origin = vec2(0.0);    // 島的原點在這一小關座標裡的位置（x, z）
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp.xz -= origin;        // 筆觸跟著島走：同一塊地不管從哪一小關看，畫出來都一樣
}

void fragment() {
	vec2 p = wp.xz;
	// 一次讀出四個頻率的雜訊：R = 光斑（約 50 公尺一塊），G = 讓貼圖轉個方向、不要一眼看出重複
	vec4 nz = texture(noise_tex, p / 200.0);
	float sun_patch = smoothstep(0.50, 0.66, nz.r * 0.8 + nz.b * 0.2);
	// 兩種擺法的貼圖（一般、轉 90 度）按大塊雜訊切換，拼接的痕跡就不明顯
	vec2 uv = p / tile;
	vec2 uv2 = vec2(uv.y, -uv.x) * 1.13 + 0.37;
	float alt = step(0.5, nz.g);
	vec3 shade = mix(texture(shade_tex, uv).rgb, texture(shade_tex, uv2).rgb, alt);
	vec4 sun = texture(sun_tex, mix(uv, uv2, alt) + 0.21);
	// 光斑裡：筆觸的亂數（alpha）小於門檻的那幾筆才畫，越靠近光斑中心畫越多筆
	float sun_m = smoothstep(0.03, 0.0, sun.a - sun_patch * 0.6);
	// 筆觸的顏色往遠處的平塗色靠一點：地面安靜一點，主角是樹上和飄下來的落葉
	shade = mix(shade, far_shade, 0.35);
	vec3 col = mix(shade, mix(sun.rgb, far_sun, 0.3), sun_m);
	col = mix(col, far_sun, sun_patch * 0.15);
	if (use_photo > 0.5) {
		vec2 puv = mix(p, vec2(p.y, -p.x) + 1.7, alt) / photo_tile;
		vec3 ph = texture(photo_tex, puv).rgb;
		float leaf = smoothstep(-0.03, 0.04, ph.g - ph.r);       // 照片裡綠色的地方 = 葉子
		float lum = dot(ph, vec3(0.3, 0.55, 0.15));
		float step3 = floor(clamp(lum * 4.2, 0.0, 2.99)) / 2.0;   // 明暗切成三階
		// 葉子：每一大塊區域換一種秋天的顏色（暗紅、鏽橘、金黃），光斑裡偏亮
		vec3 la = mix(vec3(0.42, 0.14, 0.09), vec3(0.62, 0.28, 0.08), smoothstep(0.35, 0.65, nz.b));
		vec3 lb = mix(vec3(0.80, 0.44, 0.10), vec3(0.92, 0.70, 0.22), smoothstep(0.30, 0.70, nz.g));
		vec3 leaf_col = mix(la, lb, clamp(step3 * 0.7 + sun_patch * 0.6, 0.0, 1.0));
		vec3 soil = mix(far_shade * 0.75, far_shade * 1.1, step3);
		col = mix(soil, leaf_col, leaf);
	}
	// 遠處淡成純色，就不會閃爍、也比較乾淨
	float far = smoothstep(26.0, 60.0, length(VERTEX));
	col = mix(col, mix(far_shade, far_sun, sun_patch * 0.8), far);

	// 陡坡畫成深色的岩石
	float steep = smoothstep(0.3, 0.7, COLOR.b);
	col = mix(col, rock * (0.9 + 0.5 * nz.a), steep * 0.85);

	// 整體壓暗、降一點彩度，站在上面的角色才看得清楚
	float luma = dot(col, vec3(0.3, 0.55, 0.15));
	ALBEDO = mix(mix(col, vec3(luma), 0.08) * 0.72, night_ramp(col * 2.6), night);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
