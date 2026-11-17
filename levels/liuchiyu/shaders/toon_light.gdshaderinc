// 少階 ramp 光影（像動畫的賽璐璐上色）：亮面、半影、暗面三階，交界只留一點點柔和的過渡。
// 用法：在 spatial shader 裡 #include "res://levels/liuchiyu/shaders/toon_light.gdshaderinc"，就會用這個 light()。
// 暗面只剩環境光（WorldEnvironment 的偏紫紅色），所以影子是有顏色的、不是黑的。
uniform float ramp_mid = 0.55;      // 半影那一階有多亮（0～1）
uniform float ramp_soft = 0.035;    // 階和階之間過渡的寬度

float toon_ramp(float x) {
	float a = smoothstep(0.08 - ramp_soft, 0.08 + ramp_soft, x);
	float b = smoothstep(0.42 - ramp_soft, 0.42 + ramp_soft, x);
	return a * ramp_mid + b * (1.0 - ramp_mid);
}

void light() {
	float x = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += toon_ramp(x) * LIGHT_COLOR / PI;
}
