shader_type spatial;
render_mode cull_disabled, unshaded;
// 外圍森林「葉片樹」的一片葉子（共用；從要塞大關的 fort_leaf 搬來，最早參考劉起佑大關的 oil_leaf）：
// 兩頭尖的葉形用數學算（不讀貼圖），顏色是每片自己的實例顏色——
// 種樹時已經依照朝不朝太陽把亮面、暗面的顏色算好，所以這裡不打光。
varying vec3 inst;
varying float rnd;

void vertex() {
	inst = pow(COLOR.rgb, vec3(2.2));
	rnd = fract(MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z * 1.3);
}

void fragment() {
	vec2 f = UV - 0.5;
	// 葉形：中間寬、兩頭收尖
	float x = f.x / 0.46;
	if (abs(f.y) > 0.30 * (1.0 - x * x) + 0.01 * rnd) {
		discard;
	}
	// 葉柄到葉尖一點點深淺，每片亮度稍微不同
	ALBEDO = inst * (0.9 + 0.12 * f.x + 0.12 * (rnd - 0.5));
}
