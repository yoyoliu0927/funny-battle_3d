extends "res://scripts/battle/battle_base.gd"
## 範例關：農場大門（給大家照著做的完整範例，不屬於任何人的大關）
##
## 家豪從農場大門外出發，三個農夫守在不同位置。大穀倉最裡面坐著拿槍的老闆：
## 家豪一靠近就開槍，家豪被槍聲嚇得飛走，正面打不到他。
## 要打倒老闆得靠骨牌：從台地放巨石撞倒水塔，五座水塔一座接一座倒，最後砸垮大穀倉。
##
## 這個檔案示範了關卡可以覆寫的東西：
##   _make_items()       道具和次數
##   _enemy_specs()      敵人（三個一般農夫 + 一個自訂 kind 的老闆）
##   _tick_enemy()       自訂敵人（老闆）的 AI
##   _level_setup/_level_reset/_level_start/_level_step   機關（水塔骨牌、穀倉、示範石頭）
##   _on_rock_rolling()  巨石撞到水塔
##   _update_highlights() 瞄準時把會被撞到的水塔亮綠色
##   各種文字

const FeedItem := preload("res://scripts/items/feed_item.gd")
const BananaItem := preload("res://scripts/items/banana_item.gd")
const RockItem := preload("res://scripts/items/rock_item.gd")

const BOSS_RANGE := 11.0       # 老闆開槍的距離
const BOSS_AIM := 0.5          # 瞄準時間
const BOSS_COOLDOWN := 1.4
const TOWER_GRAVITY := 2.6     # 水塔倒下的角加速度
const BARN_HIT_RADIUS := 4.8   # 水塔倒到這麼近就算砸中大穀倉
# 示範石頭：一開始放在台地斜坡頂端，開打後一下下就自己滑下來，讓玩家想到巨石可以放在坡上
const DEMO_ROCK_START := Vector3(10.4, 0, 4.2)
const DEMO_ROCK_DELAY := 2.5
const DEMO_ROCK_RADIUS := 0.5   # 示範石頭比巨石小一號

var boss: Fighter
# 骨牌：水塔與大穀倉
var towers: Array = []         # {node, pos, radius, height, state, angle, omega, dir, crushed}
var barn_state := "stand"      # stand / collapse / down
var barn_t := 0.0
var _barn_xf: Transform3D
var demo_rock: MeshInstance3D
var demo_path := PackedVector3Array()
var demo_i := 0
var highlighted: Array = []    # 目前亮綠色的水塔索引
var _green_mat: StandardMaterial3D
var _napoleon_tex: Texture2D

# 舊名字（自動測試在用）
var rocks: Array:
	get:
		return item("rock").rocks
var peels: Array:
	get:
		return item("banana").peels

# ------------------------------------------------------------------ 設定

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, -1),      # 準備階段 2 把，開打後不限
		BananaItem.new().uses_shared(3), # 整場共用 3 片
		RockItem.new().uses(0, 2),       # 開打後才能放，2 顆
	]

func _enemy_specs() -> Array:
	var out: Array = []
	var routes: Array = world.farmer_routes
	for i in routes.size():
		out.append({"name": "農夫%d" % (i + 1), "route": routes[i].route, "loop": routes[i].loop, "pause": routes[i].pause})
	# 老闆：站在辦公桌後面，不巡邏、沒有偵測區，啄不痛、巨石撞不到、不會滑倒
	out.append({"name": "老闆", "hud_name": "老闆（持槍）", "kind": "boss", "route": [world.boss_post], "yaw": 0.0,
		"hp": 99.0, "is_boss": true, "immune_peck": true, "immune_rock": true, "can_slip": false,
		"has_cone": false, "hears_noise": false, "target_last": true, "bar_y": 3.4})
	return out

func _level_setup() -> void:
	for f in enemies:
		if f.is_boss:
			boss = f
			f.gun = f.node.find_child("Gun", true, false)   # 胖商人模型自帶的槍
	for t in world.towers:
		towers.append({"node": t.node, "pos": t.pos, "radius": t.radius, "height": t.height,
			"state": "stand", "angle": 0.0, "omega": 0.0, "dir": Vector3.FORWARD, "crushed": false})
	_barn_xf = world.barn_node.transform
	demo_rock = MeshInstance3D.new()
	demo_rock.name = "DemoRock"
	var drng := RandomNumberGenerator.new()
	drng.seed = 999
	demo_rock.mesh = world.make_rock_mesh(drng, 3, 0.08)
	demo_rock.material_override = world._rock_material
	demo_rock.scale = Vector3.ONE * DEMO_ROCK_RADIUS
	world.add_child(demo_rock)
	_napoleon_tex = _load_tex("res://assets/ui/napoleon.png")

func _level_reset() -> void:
	for t in towers:
		t.state = "stand"
		t.angle = 0.0
		t.omega = 0.0
		t.crushed = false
		(t.node as Node3D).basis = Basis()
	barn_state = "stand"
	barn_t = 0.0
	var rr: float = RockItem.ROCK_RADIUS
	demo_path = simulate_roll(ground(DEMO_ROCK_START))
	demo_i = 0
	demo_rock.rotation = Vector3.ZERO
	demo_rock.position = (demo_path[0] if demo_path.size() > 0 else ground(DEMO_ROCK_START)) - Vector3(0, rr - DEMO_ROCK_RADIUS, 0)
	world.barn_node.transform = _barn_xf

func _level_start() -> void:
	if boss:
		boss.set_state("boss")

func _level_step(dt: float) -> void:
	_tick_towers(dt)
	_tick_demo_rock(dt)

func _level_step_ended(dt: float) -> void:
	_tick_towers(dt)   # 勝負已分，但正在倒的水塔和穀倉要照樣倒完

func _level_visuals() -> void:
	_boss_pose()

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.kind == "boss":
		_tick_boss(f, dt)
	else:
		super(f, dt)

## 家豪要降落在水池裡：推到岸邊
func _dry_landing(dest: Vector3) -> Vector3:
	var c: Vector2 = world.pond_center
	var v := Vector2(dest.x - c.x, dest.z - c.y)
	v = v.normalized() if v.length() > 0.01 else Vector2(1, 0)
	return Vector3(c.x + v.x * (world.pond_r + 0.5), 0, c.y + v.y * (world.pond_r + 0.5))

func _win_line() -> String:
	return "攻下農場大門！這場是你偷偷扳回來的。"

func _lose_line(_left: int) -> String:
	var farmers_left := enemies.filter(func(f): return f.alive() and not f.is_boss).size()
	return "家豪被農夫圍毆倒下了…（還剩 %d 個農夫）" % farmers_left

func _defeat_tip() -> String:
	return "提示：撒飼料把家豪引開，讓他一次只對上一個農夫。" if casts.is_empty() else "提示：換個時機或位置降下神蹟再試一次。"

# ------------------------------------------------------------------ 巨石撞水塔

func _on_rock_rolling(_rock: Dictionary, cur: Vector3, speed: float) -> bool:
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.state == "stand" and speed >= 0.6 and Vector2(cur.x - t.pos.x, cur.z - t.pos.y).length() < t.radius + RockItem.ROCK_RADIUS + 0.45:
			log_event("巨石撞倒了第 %d 座水塔！" % (k + 1))
			toast("撞到水塔了！", 1.4)
			_topple(k)
			return true
	return false

## 巨石路徑會撞到的水塔亮綠色，讓玩家知道那是可以互動的東西
func _update_highlights(path: PackedVector3Array, on: bool) -> void:
	var want: Array = []
	# 只有巨石真的滾過去（不是直接對著水塔放）時，才讓它撞到的「最近那一座」亮綠色
	if on and path.size() > 1 and items[selected].id == "rock":
		var first := path[0]
		var last := path[path.size() - 1]
		var rolled := Vector2(last.x - first.x, last.z - first.z).length()
		var best := -1
		var best_d := INF
		for k in towers.size():
			var t: Dictionary = towers[k]
			if t.state != "stand":
				continue
			var d_end := Vector2(last.x - t.pos.x, last.z - t.pos.y).length()
			var d_start := Vector2(first.x - t.pos.x, first.z - t.pos.y).length()
			if rolled > 1.5 and d_start > t.radius + 2.0 and d_end < t.radius + RockItem.ROCK_RADIUS + 0.6 and d_end < best_d:
				best_d = d_end
				best = k
		if best >= 0:
			want.append(best)
	if want == highlighted:
		return
	if _green_mat == null:
		_green_mat = StandardMaterial3D.new()
		_green_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_green_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_green_mat.albedo_color = Color(0.3, 1.0, 0.35, 0.45)
	for k in towers.size():
		var mat: Material = _green_mat if want.has(k) else null
		for mi in (towers[k].node as Node).find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = mat
	highlighted = want

# ------------------------------------------------------------------ 老闆

func _tick_boss(f: Fighter, dt: float) -> void:
	f.t += dt
	if not f.alive():
		return
	f.shoot_cd -= dt
	# 牆會擋子彈：只有從門口看得到家豪時才會開槍
	var in_range := bird.alive() and bird.air < 1.5 and flat_dist(f.pos, bird.pos) <= BOSS_RANGE \
		and wall_crossing(f.pos, bird.pos) == null
	match f.state:
		"boss":
			if in_range:
				_face(f, bird.pos)
				if f.shoot_cd <= 0.0:
					f.set_state("aim")
					anim(f, "Idle_Gun_Pointing")
					log_event("老闆掏出槍瞄準家豪")
			else:
				anim(f, "Idle")
		"aim":
			_face(f, bird.pos)
			if f.t >= BOSS_AIM:
				_boss_fire(f, in_range)
				f.shoot_cd = BOSS_COOLDOWN
				f.set_state("boss")

func _boss_fire(f: Fighter, hit: bool) -> void:
	anim(f, "Gun_Shoot", 1.2)
	var muzzle := f.pos + Vector3(0, 1.7, 0) + Vector3(sin(f.yaw), 0, cos(f.yaw)) * 0.8
	if f.gun:
		muzzle = (f.gun as Node3D).global_position + (f.gun as Node3D).global_basis.y * -0.5
	var target := bird.pos + Vector3(0, bird.air + 0.7, 0)
	_spawn_tracer(muzzle, target)
	if not hit:
		return
	noise_at(f.pos)
	# 子彈打不中、也不扣血：家豪只是被槍聲嚇得飛走（再回來也一樣）
	hit_spots.append(bird.pos)
	log_event("老闆開槍，家豪被槍聲嚇得飛走")
	toast("砰！", 0.8)
	say("THERE IS NOTHING I CAN DO", _napoleon_tex)
	var away := bird.pos - f.pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	start_fly(bird.pos + away * 6.5, FLY_TIME, FLY_PEAK, "land")

func _spawn_tracer(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = a.distance_to(b)
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.92, 0.5)
	mi.material_override = m
	fx_root.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_basis = Basis(side, up, side.cross(up))
	spawn_timed(mi, 0.12, "tracer")
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	flash.mesh = sm
	flash.material_override = m
	fx_root.add_child(flash)
	flash.global_position = a
	spawn_timed(flash, 0.1, "tracer")

## 胖商人：瞄準時舉起拿槍的手，被穀倉壓到就扁掉
func _boss_pose() -> void:
	if boss == null:
		return
	var arm := boss.node.find_child("ArmR", true, false) as Node3D
	var body := boss.node.find_child("Body", true, false) as Node3D
	if arm:
		var want := 0.9
		if boss.state == "aim":
			want = 1.55
		elif boss.alive() and boss.shoot_cd > BOSS_COOLDOWN - 0.25:
			want = 1.85   # 開槍的後座力
		arm.rotation.x = lerpf(arm.rotation.x, want, 0.3)
	if body:
		if boss.alive():
			body.scale = Vector3.ONE
			body.position.y = absf(sin(time * 1.6)) * 0.03   # 呼吸
		else:
			body.scale = Vector3(1.25, 0.35, 1.25)
			body.position.y = -0.4

# ------------------------------------------------------------------ 骨牌：水塔與大穀倉

func _topple(k: int) -> void:
	var t: Dictionary = towers[k]
	if t.state != "stand":
		return
	t.state = "fall"
	t.omega = 0.35
	var target: Vector2 = towers[k - 1].pos if k > 0 else Vector2(world.barn_pos.x, world.barn_pos.z)
	var d := target - (t.pos as Vector2)
	t.dir = Vector3(d.x, 0, d.y).normalized()

func _tick_towers(dt: float) -> void:
	for k in towers.size():
		var t: Dictionary = towers[k]
		if t.state != "fall":
			continue
		t.omega += TOWER_GRAVITY * dt
		t.angle = minf(t.angle + t.omega * dt, 1.45)
		var axis := Vector3.UP.cross(t.dir).normalized()
		(t.node as Node3D).basis = Basis(axis, t.angle)
		var reach: float = t.height * sin(t.angle)
		# 倒向下一座（或大穀倉）
		if k > 0:
			var n: Dictionary = towers[k - 1]
			if n.state == "stand" and reach >= (t.pos as Vector2).distance_to(n.pos) - n.radius:
				log_event("第 %d 座水塔砸倒第 %d 座" % [k + 1, k])
				_topple(k - 1)
		elif barn_state == "stand":
			var bp := Vector2(world.barn_pos.x, world.barn_pos.z)
			if reach >= (t.pos as Vector2).distance_to(bp) - BARN_HIT_RADIUS:
				_collapse_barn()
		# 倒下的路上壓到人
		if not t.crushed and t.angle > 1.0:
			t.crushed = true
			var a := Vector2(t.pos.x, t.pos.y)
			var b: Vector2 = a + Vector2(t.dir.x, t.dir.z) * t.height
			for f in all_fighters():
				if not f.alive() or f.is_boss or f.air > 1.0:
					continue
				var q := Vector2(f.pos.x, f.pos.z)
				var u := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				if q.distance_to(a.lerp(b, u)) < 1.4:
					if f.is_bird:
						log_event("水塔倒下來壓到家豪")
						hit_bird(minf(3.0, maxf(f.hp - 1.0, 0.0)), true, Vector3(a.x, 0, a.y))
					else:
						knock_out(f, "水塔倒下來壓倒了%s" % f.name)
		if t.angle >= 1.45:
			t.state = "down"
	# 大穀倉垮掉的動畫
	if barn_state == "collapse":
		barn_t += dt
		var k2 := clampf(barn_t / 0.7, 0.0, 1.0)
		var xf := _barn_xf
		xf.basis = _barn_xf.basis * Basis(Vector3.FORWARD, 0.12 * k2)
		xf.basis = xf.basis.scaled(Vector3(1.0 + 0.08 * k2, 1.0 - 0.6 * k2 * k2, 1.0 + 0.08 * k2))
		world.barn_node.transform = xf
		if k2 >= 1.0:
			barn_state = "down"

## 示範石頭只是滾下來給玩家看，不會傷人、不會撞倒水塔
func _tick_demo_rock(_dt: float) -> void:
	if time < DEMO_ROCK_DELAY or demo_i >= demo_path.size() - 1:
		return
	demo_i += 1
	var prev := demo_path[demo_i - 1]
	var cur := demo_path[demo_i]
	demo_rock.position = cur - Vector3(0, RockItem.ROCK_RADIUS - DEMO_ROCK_RADIUS, 0)
	var flat := Vector3(cur.x - prev.x, 0, cur.z - prev.z)
	if flat.length() > 0.0001:
		demo_rock.rotate(flat.normalized().cross(Vector3.UP).normalized(), -flat.length() / DEMO_ROCK_RADIUS)
	if demo_i == 1:
		log_event("台地坡頂的石頭滑下來了")

func _collapse_barn() -> void:
	barn_state = "collapse"
	barn_t = 0.0
	log_event("水塔砸垮了大穀倉！")
	toast("大穀倉垮了！", 2.0)
	noise_at(world.barn_pos)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(0.85, 0.8, 0.7, 0.55)
	for k in 10:
		var a := k * TAU / 10.0
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		mi.mesh = sm
		mi.material_override = dust_mat
		fx_root.add_child(mi)
		mi.global_position = world.barn_pos + Vector3(cos(a) * 4.0, 1.0, sin(a) * 4.0)
		spawn_timed(mi, 1.4, "dust")
	if boss and boss.alive():
		knock_out(boss, "老闆被壓在大穀倉底下，倒下了")
