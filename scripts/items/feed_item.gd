extends "res://scripts/items/item.gd"
## 飼料：撒在地上，家豪會忍不住跑去吃（吃一把回血），可以用來帶路、拖時間。
## 家豪怎麼找飼料、吃多久，寫在 battle_base.gd 的家豪 AI 裡（bt.feeds）。

func _init() -> void:
	id = "feed"
	name = "飼料"
	tutorial = "撒在地上，家豪會忍不住跑去吃，吃一把回一點血。\n用它把家豪引到你想要的地方。"
	color = Color(1.0, 0.85, 0.3)
	radius = 0.6
	cooldown = 1.5

func cast(bt, p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/toon_color.gdshader")
	mat.set_shader_parameter("albedo", Color(0.98, 0.82, 0.32))
	var grain := SphereMesh.new()
	grain.radius = 0.05
	grain.height = 0.07
	grain.radial_segments = 6
	grain.rings = 3
	for i in 18:
		var a := i * 2.39996
		var r := 0.08 + sqrt(float(i)) * 0.11
		var g := MeshInstance3D.new()
		g.mesh = grain
		g.material_override = mat
		g.position = Vector3(cos(a) * r, 0.03, sin(a) * r)
		node.add_child(g)
	bt.fx_root.add_child(node)
	bt.feeds.append({"pos": p, "node": node})
