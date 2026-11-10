extends "res://scripts/items/item.gd"
## 巨石：放在地上；放在斜坡上會順著坡滾下去，沿路撞到誰就傷誰。瞄準時會畫出預測的滾動路徑。
## 滾動完全照地形計算、沒有亂數，所以預測路徑和實際滾的一模一樣。
## 關卡想讓巨石撞到自己的機關（例如水塔），覆寫 battle 的 _on_rock_rolling()。

const ROCK_RADIUS := 0.9
const ROCK_HIT_RADIUS := 1.45  # 巨石中心離角色多近算撞到
const ROCK_MIN_HIT_SPEED := 1.5
const ROCK_CLEAR := 1.9        # 放置點這個距離內有人就不能放
const ROLL_GRAVITY := 9.0
const ROLL_RESIST := 3.2       # 滾動阻力（m/s²）；場地有 roll_resist(x, z) 的話用場地的
const ROLL_MAX_SPEED := 9.0
const SIM_DT := 1.0 / 60.0

var enemy_damage := 999.0      # 撞到敵人扣多少（999 = 一次就倒）
var bird_damage := 4.0         # 撞到家豪扣多少（最少會留 1 滴）
var rocks: Array = []          # {path, i, node, done, hit}

func _init() -> void:
	id = "rock"
	name = "巨石"
	tutorial = "一顆圓滾滾的大石頭。\n或許可以讓它自己滾起來？"
	color = Color(0.85, 0.85, 0.8)
	radius = ROCK_RADIUS
	cooldown = 8.0

func reset(_bt) -> void:
	rocks.clear()

func placement_error(bt, p: Vector3) -> String:
	if not bt.world.rock_ground(p.x, p.z):
		return "這裡放不了"
	for f in bt.all_fighters():
		if f.alive() and bt.flat_dist(f.pos, p) < ROCK_CLEAR:
			return "那裡有人，巨石放不下去"
	for r in rocks:
		if not r.done:
			return "上一顆巨石還在滾"
	return ""

func preview_path(bt, p: Vector3) -> PackedVector3Array:
	return simulate(bt, p)

func cast(bt, p: Vector3) -> void:
	var rock := MeshInstance3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + rocks.size()
	rock.mesh = bt.world.make_rock_mesh(rng, 3, 0.08)
	rock.material_override = bt.world._rock_material
	rock.scale = Vector3.ONE * ROCK_RADIUS
	var path := simulate(bt, p)
	rock.position = path[0] if path.size() > 0 else p
	bt.fx_root.add_child(rock)
	rocks.append({"path": path, "i": 0, "node": rock, "done": path.size() < 2, "hit": []})

## 從 start 放下巨石，預測它每個物理幀的位置（和實際滾動完全一樣，用來畫路徑）
static func simulate(bt, start: Vector3, ball_radius := ROCK_RADIUS) -> PackedVector3Array:
	var world: Node = bt.world
	var pts := PackedVector3Array()
	var p := Vector2(start.x, start.z)
	var v := Vector2.ZERO
	var dt := SIM_DT
	var has_resist := world.has_method("roll_resist")
	pts.append(Vector3(p.x, world.height_at(p.x, p.y) + ball_radius, p.y))
	for i in 900:
		var g := Vector2(world.height_at(p.x + 0.15, p.y) - world.height_at(p.x - 0.15, p.y),
			world.height_at(p.x, p.y + 0.15) - world.height_at(p.x, p.y - 0.15)) / 0.3
		v += -g * ROLL_GRAVITY * dt
		var sp := v.length()
		var resist: float = world.roll_resist(p.x, p.y) if has_resist else ROLL_RESIST
		if sp > 0.0:
			v = v / sp * clampf(sp - resist * dt, 0.0, ROLL_MAX_SPEED)
		var np := p + v * dt
		if not world.rock_ground(np.x, np.y) or world.in_water(np.x, np.y) or bt.hits_obstacle(np) \
				or bt.fence_crossing(Vector3(p.x, 0, p.y), Vector3(np.x, 0, np.y)) != null:
			break
		p = np
		pts.append(Vector3(p.x, world.height_at(p.x, p.y) + ball_radius, p.y))
		if i > 20 and v.length() < 0.05:
			break
	return pts

func step(bt, dt: float) -> void:
	for r in rocks:
		if r.done:
			continue
		var path: PackedVector3Array = r.path
		var i: int = r.i + 1
		if i >= path.size():
			r.done = true
			continue
		r.i = i
		var prev := path[i - 1]
		var cur := path[i]
		var stp := cur - prev
		var node: Node3D = r.node
		node.position = cur
		var flat := Vector3(stp.x, 0, stp.z)
		if flat.length() > 0.0001:
			node.rotate(flat.normalized().cross(Vector3.UP).normalized(), -flat.length() / ROCK_RADIUS)
		var speed := flat.length() / dt
		if speed >= ROCK_MIN_HIT_SPEED:
			for f in bt.all_fighters():
				if f.alive() and not r.hit.has(f) and f.air < 0.5 and bt.flat_dist(f.pos, cur) < ROCK_HIT_RADIUS:
					r.hit.append(f)
					_hit(bt, f, cur, flat.normalized())
		# 關卡的機關（例如水塔）：回傳 true 代表巨石停在那裡
		if bt._on_rock_rolling(r, cur, speed):
			r.done = true
			continue
		if i == path.size() - 1:
			r.done = true
			if r.hit.is_empty():
				bt.log_event("巨石滾停了，沒撞到人")

func _hit(bt, f, p: Vector3, dir: Vector3) -> void:
	if f.immune_rock:
		return
	bt.noise_at(p)
	if f.is_bird:
		bt.log_event("巨石撞到家豪")
		bt.toast("糟糕，撞到家豪了！", 1.8)
		bt.hit_bird(minf(bird_damage, maxf(f.hp - 1.0, 0.0)), true, p - dir)
		return
	f.hp = maxf(f.hp - enemy_damage, 0.0)
	bt.log_event("巨石撞倒%s" % f.name)
	bt.toast("撞倒了！", 1.2)
	bt.aggro(f)
	f.heavy = false
	f.kb_vel = dir * 3.0
	bt.anim(f, "Death")
	f.set_state("dead" if f.hp <= 0.0 else "down")
