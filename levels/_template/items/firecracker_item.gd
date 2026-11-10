extends "res://scripts/items/item.gd"
## 自訂道具範例：鞭炮。放下去 1 秒後炸開，附近的敵人嚇一跳愣住，還會聽到聲音趕過來。
## 想做新道具就照這個檔案改：_init() 設定名字和外觀，cast() 放東西，step() 每 1/60 秒更新。

const FUSE := 1.0              # 引信幾秒
const SCARE_RADIUS := 4.0      # 嚇到多遠的敵人

var bombs: Array = []          # {pos, node, t}

func _init() -> void:
	id = "firecracker"
	name = "鞭炮"
	tutorial = "放下去一秒後會炸開，附近的敵人會嚇一跳愣住。\n遠一點的敵人會聽到聲音跑過來。"
	color = Color(0.95, 0.25, 0.2)
	radius = SCARE_RADIUS
	cooldown = 5.0
	# icon = load("res://levels/_template/assets/firecracker.png")   # 有圖示的話這樣放

func reset(_bt) -> void:
	bombs.clear()

func cast(bt, p: Vector3) -> void:
	var node := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 0.4
	node.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.15, 0.12)
	node.material_override = m
	node.position = p + Vector3(0, 0.2, 0)
	bt.fx_root.add_child(node)
	bombs.append({"pos": p, "node": node, "t": 0.0})

func step(bt, dt: float) -> void:
	for i in range(bombs.size() - 1, -1, -1):
		var b: Dictionary = bombs[i]
		b.t += dt
		(b.node as Node3D).scale = Vector3.ONE * (1.0 + 0.15 * sin(b.t * 30.0))
		if b.t < FUSE:
			continue
		(b.node as Node3D).queue_free()
		bombs.remove_at(i)
		bt.toast("砰！", 0.8)
		bt.log_event("鞭炮炸開了")
		bt.noise_at(b.pos)
		for f in bt.enemies:
			if f.alive() and f.kind == "melee" and bt.flat_dist(f.pos, b.pos) < SCARE_RADIUS:
				f.kb_vel = Vector3.ZERO
				f.set_state("startled")
				bt.anim(f, "HitRecieve", 0.8)
				bt.log_event("%s被鞭炮嚇到" % f.name)
