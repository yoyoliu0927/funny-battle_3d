extends RefCounted
## 劉起佑版共用的夜空美術：每個小關的 world.gd 在 _build_extra() 呼叫 NightSky.apply(self)。
## 只改這個場景自己的 WorldEnvironment（先 duplicate，不會影響到別人的關卡）。

const SKY_SHADER := preload("res://levels/liuchiyu/shaders/star_sky.gdshader")

static func apply(world: Node) -> void:
	var main := world.get_parent()
	if main == null:
		return
	var we := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env: Environment = we.environment.duplicate()
		var mat := ShaderMaterial.new()
		mat.shader = SKY_SHADER
		var sky := Sky.new()
		sky.sky_material = mat
		env.sky = sky
		# 夜晚：環境光偏藍、暗一點，但還看得清楚場上
		env.ambient_light_color = Color(0.42, 0.50, 0.85)
		env.ambient_light_energy = 0.75
		env.fog_light_color = Color(0.07, 0.11, 0.32)
		env.fog_sun_scatter = 0.0
		env.fog_sky_affect = 0.0
		env.glow_intensity = 0.6
		env.glow_hdr_threshold = 0.9
		env.adjustment_saturation = 1.2
		we.environment = env
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		# 太陽換成月光：冷色、弱一點
		sun.light_color = Color(0.70, 0.78, 1.0)
		sun.light_energy = 1.0
