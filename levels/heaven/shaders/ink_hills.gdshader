// 遠山：一圈圍著地圖的布幕，山的輪廓在這裡算出來（幾層起伏疊在一起），山腳融進霧裡。水墨剪影，不吃光。
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, fog_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 ink : source_color = vec3(0.16, 0.36, 0.40);
uniform vec3 mist : source_color = vec3(0.74, 0.90, 0.88);
uniform float seed = 1.0;
uniform float ridge = 0.5;        // 山大概多高（0～1，佔布幕的高度）
uniform float peaks = 8.0;        // 一圈有幾座山

void fragment() {
	float u = UV.x;
	// 山的輪廓：幾個不同寬度的波疊起來（繞一圈要接得上，所以都用整數倍）
	float a = u * 6.2831853;
	float h = 0.0;
	h += (0.5 + 0.5 * sin(a * peaks + seed)) * 0.42;
	h += (0.5 + 0.5 * sin(a * (peaks * 2.0 + 1.0) + seed * 2.3)) * 0.26;
	h += (0.5 + 0.5 * sin(a * (peaks * 5.0 + 2.0) + seed * 4.1)) * 0.12;
	h += texture(noise_tex, vec2(u * 9.0 + seed, 0.37)).r * 0.20;
	// 尖一點：像一座一座的峰
	h = pow(h, 1.5) * ridge + 0.10;
	float y = UV.y;
	if (y > h) {
		discard;
	}
	// 山頂墨色最濃，往山腳淡出去（融進霧裡）；山身有一點直的皴紋
	float t = clamp(y / h, 0.0, 1.0);
	float stroke = texture(noise_tex, vec2(u * 60.0, y * 3.0)).g;
	vec3 c = mix(mist, ink, smoothstep(0.10, 0.95, t) * (0.85 + 0.15 * stroke));
	ALBEDO = c;
}
