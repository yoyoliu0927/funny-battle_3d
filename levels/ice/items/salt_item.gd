extends "res://scripts/items/item.gd"
## 鹽：撒在冰面上，2 秒後那一塊厚冰會被融成薄冰。
## 薄冰撐得住家豪、撐不住人：等於自己做一個陷阱。
## 準備階段撒的鹽，開打後才開始計時。

const MELT_TIME := 2.0
const SPOT_R := 1.25

var piles: Array = []          # {pos, node, t}

func _init() -> void:
	id = "salt"
	name = "鹽"
	tutorial = "撒在冰面上，2 秒後那一塊冰會被融成薄冰。\n薄冰撐得住家豪，人一踩就破。"
	color = Color(0.95, 0.97, 1.0)
	radius = SPOT_R
	cooldown = 0.15   # 有次數限制，不另外設冷卻

func reset(_bt) -> void:
	piles.clear()

func placement_error(bt, p: Vector3) -> String:
	if not bt.world.on_ice(p.x, p.z):
		return "鹽要撒在冰面上"
	if bt.world.in_water(p.x, p.z):
		return "不能撒在水裡"
	if bt.world.thin_at(p.x, p.z, -0.3) >= 0:
		return "這裡已經是薄冰了"
	for q in piles:
		if bt.flat_dist(q.pos, p) < SPOT_R * 1.6:
			return "太靠近上一把鹽了"
	return ""

func cast(bt, p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.7, 0.8)
	m.emission_energy_multiplier = 0.4
	var grain := BoxMesh.new()
	grain.size = Vector3(0.06, 0.05, 0.06)
	for i in 26:
		var a := i * 2.39996
		var r := 0.1 + sqrt(float(i)) * 0.2
		var g := MeshInstance3D.new()
		g.mesh = grain
		g.material_override = m
		g.position = Vector3(cos(a) * r, 0.06, sin(a) * r)
		g.rotation.y = a
		node.add_child(g)
	bt.fx_root.add_child(node)
	piles.append({"pos": p, "node": node, "t": 0.0})

func step(bt, dt: float) -> void:
	for i in range(piles.size() - 1, -1, -1):
		var q: Dictionary = piles[i]
		q.t += dt
		var node := q.node as Node3D
		node.scale = Vector3.ONE * (1.0 - 0.5 * clampf(q.t / MELT_TIME, 0.0, 1.0))
		if q.t < MELT_TIME:
			continue
		node.queue_free()
		piles.remove_at(i)
		bt.world.add_thin(Vector2(q.pos.x, q.pos.z), SPOT_R, bt.fx_root)
		bt.toast("冰變薄了！", 1.0)
		bt.log_event("鹽把冰融成了薄冰")
