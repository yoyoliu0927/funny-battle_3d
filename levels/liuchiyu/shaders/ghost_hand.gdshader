shader_type spatial;
// 神的手：半透明、邊緣發光，裡面有一點點流動的光。
// depth_test_disabled：手永遠畫在最上面。不然鏡頭靠近樹幹、草、地面的時候，
// 那些東西會比手更靠近鏡頭、把手擋掉，移動時手就一下有一下沒有（閃爍）。
// 只畫正面（cull_back）、而且最後才畫（god_hands.gd 的 render_priority），手臂自己重疊的地方不會太亂。
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 body_color : source_color = vec4(0.94, 0.97, 1.0, 1.0);  // 手本身的顏色（很淡的白）
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);     // 邊緣的光（淡淡的金）
uniform sampler2D skin_tex : source_color, filter_nearest;              // 原本的皮膚貼圖（只淡淡地混一點進來）
uniform float skin_mix = 0.12;
uniform float body_alpha = 0.06;     // 中間的透明度（越小越透明）
uniform float rim_alpha = 0.45;      // 邊緣的透明度
uniform float rim_power = 2.2;
uniform float glow = 0.0;            // 施放道具時由腳本拉高，手會亮一下
uniform float fade = 1.0;            // 整體淡入淡出（過場時隱藏）

// 手臂自己的座標（骨架動完之後、還沒放進世界之前）：光帶跟著手走，玩家移動時不會掃過手臂
varying vec3 arm_pos;

void vertex() {
	arm_pos = VERTEX;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - facing, rim_power);
	vec3 skin = texture(skin_tex, UV).rgb;
	vec3 body = body_color.rgb * mix(vec3(1.0), skin * 1.6, skin_mix);
	// 沿著手臂慢慢流動的光帶（只跟時間有關；不要用世界座標，不然一移動就會閃）
	float flow = 0.5 + 0.5 * sin((arm_pos.y + arm_pos.z) * 9.0 - TIME * 1.6);
	flow = smoothstep(0.6, 1.0, flow) * 0.18;
	vec3 col = mix(body, rim_color.rgb, fres) + rim_color.rgb * (flow + glow * 0.4);
	ALBEDO = min(col, vec3(1.0));
	ALPHA = clamp(mix(body_alpha, rim_alpha, fres) + flow * 0.2 + glow * 0.15, 0.0, 1.0) * fade;
}
