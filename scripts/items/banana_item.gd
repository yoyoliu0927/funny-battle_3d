extends "res://scripts/items/item.gd"
## 香蕉皮：丟在地上，走過去的人（家豪和敵人都會）踩到就滑倒，躺 bt.SLIP_TIME 秒。
## 敵人的 can_slip = false 就不會踩到（例如坐著的老闆）。

const PEEL_RADIUS := 0.55      # 走到這麼近就會踩到

var peels: Array = []          # {pos, node}

func _init() -> void:
	id = "banana"
	name = "香蕉皮"
	tutorial = "丟在路上，走過去踩到就會滑倒，躺在地上好一陣子。\n小心，家豪自己也會踩到。"
	color = Color(1.0, 0.9, 0.25)
	radius = 0.5
	cooldown = 4.0

func reset(_bt) -> void:
	peels.clear()

func cast(bt, p: Vector3) -> void:
	var node := Node3D.new()
	node.position = p + Vector3(0, 0.02, 0)
	node.rotation.y = float(peels.size()) * 1.3
	var yel := StandardMaterial3D.new()
	yel.albedo_color = Color(1.0, 0.88, 0.22)
	yel.roughness = 0.6
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.45, 0.3, 0.12)
	var mid := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.09
	cm.height = 0.34
	mid.mesh = cm
	mid.material_override = yel
	mid.rotation.x = 0.35
	mid.position.y = 0.12
	node.add_child(mid)
	var tip := MeshInstance3D.new()
	var tipm := CylinderMesh.new()
	tipm.top_radius = 0.03
	tipm.bottom_radius = 0.045
	tipm.height = 0.08
	tip.mesh = tipm
	tip.material_override = brown
	tip.position = Vector3(0, 0.29, 0.06)
	tip.rotation.x = 0.35
	node.add_child(tip)
	for k in 3:
		var flap := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.085
		fm.height = 0.42
		flap.mesh = fm
		flap.material_override = yel
		var a := k * TAU / 3.0
		flap.position = Vector3(cos(a) * 0.17, 0.04, sin(a) * 0.17)
		flap.scale = Vector3(1.0, 1.0, 0.35)
		flap.rotation = Vector3(0, -a, 0)
		flap.rotate_object_local(Vector3.FORWARD, PI * 0.5 - 0.15)
		node.add_child(flap)
	bt.fx_root.add_child(node)
	peels.append({"pos": p, "node": node})

## 走路中的角色踩到香蕉皮就滑倒
func step(bt, _dt: float) -> void:
	if peels.is_empty():
		return
	for f in bt.all_fighters():
		if not f.can_slip or not f.alive() or f.air > 0.3:
			continue
		if f.state in ["slip", "fly", "hop", "land", "drown"]:
			continue
		if bt.moved_this_step(f) < 0.004:
			continue   # 沒在走路
		for k in range(peels.size() - 1, -1, -1):
			var pl: Dictionary = peels[k]
			if bt.flat_dist(f.pos, pl.pos) < PEEL_RADIUS:
				(pl.node as Node3D).queue_free()
				peels.remove_at(k)
				bt.make_slip(f, "香蕉皮")
				break
