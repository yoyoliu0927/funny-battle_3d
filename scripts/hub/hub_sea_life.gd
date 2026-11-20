extends Node3D
## 海上的彩蛋：開船的時候才會遇到。
##   - 漂流寶箱：每座島的外海各藏一個，開過去撈起來（不會再出現）。裡面是一句有梗的話；5 個撈齊，送「鳳凰船」。
##   - 游泳的企鵝：冰雪島和農莊之間的水道，一排企鵝坐在浮冰上。按 H 鳴笛，牠們會嚇得跳起來「呱」。
##   - 跳出海面的大魚：開船的時候偶爾在旁邊跳一下，濺起水花。
##   - 世界的盡頭：開到海的邊界，會有一句話；每次撞到都換一句。
## 位置全部用固定的亂數種子，每次玩都在同一個地方。

const Journal := preload("res://scripts/hub/journal.gd")
const HubBoats := preload("res://scripts/hub/hub_boats.gd")

const CHEST := "res://levels/fort/assets/pirate/chest.glb"
const BARREL := "res://levels/fort/assets/pirate/barrel.glb"
const PENGUIN := "res://levels/ice/assets/kenney_cubepets/animal-penguin.glb"
const FLOE := "res://levels/ice/assets/blender/ice_chunk_b.glb"
const BIG_FISH := "res://levels/ice/assets/kenney_survival/fish-large.glb"

const NOTES := [
	"寶箱裡只有一張發票。中獎號碼：沒中。",
	"漂流瓶：「救命，我被關在瓶子裡。」落款：一隻鵝。",
	"十顆鹹酥雞，已經涼了。你還是吃了。",
	"一張藏寶圖，上面寫「你現在的位置」。謝謝，我知道。",
	"最後一個寶箱！裡面是鳳凰船的設計圖，鳳凰船送給你。",
]
const EDGE_LINES := [
	"世界的盡頭。再往前，是出題老師的記憶體。",
	"前面沒有路了，只有 Alt＋F4。",
	"你是來測碰撞的嗎？海的邊界會一直在這裡。",
	"海鷗：「我也到過這裡。回去吧。」",
]

var map
var chests: Array = []        # {"id": 第幾個, "node": 節點, "pos": Vector2, "got": bool, "t": 相位}
var penguins: Array = []      # {"node", "base": Vector3, "ph", "jump": 跳了多久（-1 = 沒在跳）, "dir": Vector2}
var _fish: Array = []         # 正在跳的大魚 {"node", "t", "a": Vector3, "b": Vector3, "counted": bool}
var _next_fish := 8.0
var _penguin_cd := 0.0
var _edge_i := 0
var _edge_cd := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261122

## 蓋完所有的島之後呼叫一次
func build() -> void:
	var sailer = map._sailer
	var n: int = sailer.isles.size()
	# 寶箱：每座島的外海一個，角度是固定的亂數；撞到別的島的就換個角度
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in mini(n, 5):
		var spot := Vector2.ZERO
		for _try in 40:
			var a := rng.randf() * TAU
			var isle: Dictionary = sailer.isles[i]
			var p: Vector2 = (isle.c as Vector2) + Vector2(cos(a), sin(a)) * (sailer.edge(i, a) + rng.randf_range(11.0, 17.0))
			if float(sailer.nearest(p).d) > 9.0 and p.x > sailer.lo.x + 20.0 and p.x < sailer.hi.x - 20.0 and p.y > sailer.lo.y + 20.0 and p.y < sailer.hi.y - 20.0:
				spot = p
				break
		if spot == Vector2.ZERO:
			continue
		var holder := Node3D.new()
		holder.position = Vector3(spot.x, 0.0, spot.y)
		add_child(holder)
		map._spawn_fit(holder, CHEST, Vector3(0, -0.15, 0), 1.7, 0.0)
		map._spawn_fit(holder, BARREL, Vector3(1.1, -0.1, 0.5), 0.9, 0.7)
		var got := Journal.has("chest", str(i))
		holder.visible = not got
		chests.append({"id": i, "node": holder, "pos": spot, "got": got, "t": i * 1.9})
	# 企鵝：冰雪島（沒有就第二座島）和農莊之間，離航線有一點距離的海面
	var ice := 1
	for e in map.entries.size():
		if String(map._entry_id(e)) == "ice":
			ice = e
	var hub_c := Vector2(map.worlds[0].center.x, map.worlds[0].center.z)
	var ice_c := Vector2(map.worlds[ice].center.x, map.worlds[ice].center.z)
	var mid := hub_c.lerp(ice_c, 0.5)
	var side := (ice_c - hub_c).orthogonal().normalized()
	for k in 5:
		var p2 := mid + side * (16.0 + k * 3.2) + (ice_c - hub_c).normalized() * (k - 2) * 4.0
		if float(sailer.nearest(p2).d) < 6.0:
			p2 = mid - side * (16.0 + k * 3.2) + (ice_c - hub_c).normalized() * (k - 2) * 4.0
		var h2 := Node3D.new()
		h2.position = Vector3(p2.x, 0.0, p2.y)
		add_child(h2)
		map._spawn_fit(h2, FLOE, Vector3(0, -0.25, 0), 3.0, k * 1.3)
		var pg: Node3D = map._spawn_fit(h2, PENGUIN, Vector3(0, 0.25, 0), 1.5, k * 2.0)
		penguins.append({"node": h2, "peng": pg, "base": h2.position, "ph": k * 1.7, "jump": -1.0, "dir": Vector2.from_angle(k * 1.9)})

## 每一幕。sailing：現在在不在開船；pos／spd：船的位置和速度
func tick(dt: float, t: float, sailing: bool, pos: Vector2, spd: float) -> void:
	for c in chests:
		if bool(c.got):
			continue
		var n: Node3D = c.node
		var y: float = map._sea_h(Vector2(n.position.x, n.position.z)) + 0.05
		n.position.y = y + sin(t * 1.6 + float(c.t)) * 0.06
		n.rotation = Vector3(sin(t * 1.1 + float(c.t)) * 0.05, t * 0.25 + float(c.t), cos(t * 0.9) * 0.05)
		if sailing and (c.pos as Vector2).distance_to(pos) < 4.2:
			_collect(c)
	for p in penguins:
		var h: Node3D = p.node
		var b: Vector3 = p.base
		var y2: float = map._sea_h(Vector2(b.x, b.z))
		if float(p.jump) >= 0.0:
			p.jump = float(p.jump) + dt
			var k := float(p.jump) / 1.1
			h.position = b + Vector3((p.dir as Vector2).x * 3.0 * k, y2 + sin(minf(k, 1.0) * PI) * 3.2, (p.dir as Vector2).y * 3.0 * k)
			h.rotation.y += dt * 8.0
			if k >= 1.0:
				p.jump = -1.0
				p.base = Vector3(h.position.x, 0.0, h.position.z)
		else:
			h.position = Vector3(b.x, y2 + sin(t * 1.3 + float(p.ph)) * 0.08, b.z)
			h.rotation = Vector3(sin(t * 1.0 + float(p.ph)) * 0.05, h.rotation.y, cos(t * 0.8 + float(p.ph)) * 0.05)
	_penguin_cd = maxf(_penguin_cd - dt, 0.0)
	_edge_cd = maxf(_edge_cd - dt, 0.0)
	# 大魚：開船時，每隔一陣子在船旁邊跳一次
	if sailing:
		_next_fish -= dt
		if _next_fish <= 0.0 and spd > 6.0:
			_next_fish = _rng.randf_range(9.0, 16.0)
			_spawn_fish(pos)
	for f in _fish.duplicate():
		f.t = float(f.t) + dt / 1.5
		var k2 := float(f.t)
		var a: Vector3 = f.a
		var b2: Vector3 = f.b
		var node: Node3D = f.node
		var p3 := a.lerp(b2, k2)
		node.position = Vector3(p3.x, map._sea_h(Vector2(p3.x, p3.z)) + sin(minf(k2, 1.0) * PI) * 3.0 - 0.3, p3.z)
		var ahead := a.lerp(b2, minf(k2 + 0.05, 1.0))
		node.rotation = Vector3(-cos(minf(k2, 1.0) * PI) * 0.9, atan2(b2.x - a.x, b2.z - a.z), 0)
		if not bool(f.splashed) and k2 > 0.02:
			f.splashed = true
			_splash(Vector3(a.x, 0.1, a.z))
		if k2 >= 1.0:
			_splash(Vector3(b2.x, 0.1, b2.z))
			node.queue_free()
			_fish.erase(f)

func _spawn_fish(pos: Vector2) -> void:
	var heading := Vector2(sin(float(map._sail.yaw)), cos(float(map._sail.yaw)))
	var side := Vector2(-heading.y, heading.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var start: Vector2 = pos + heading * _rng.randf_range(14.0, 26.0) + side * _rng.randf_range(8.0, 15.0)
	if float(map._sailer.nearest(start).d) < 6.0:
		return
	var end := start + side * -1.0 * 8.0 + heading * 4.0
	if float(map._sailer.nearest(end).d) < 4.0:
		return
	var node := Node3D.new()
	add_child(node)
	var m: Node3D = map._spawn_fit(node, BIG_FISH, Vector3.ZERO, 3.2, 0.0)
	map._tint_model(m, Color(0.55, 0.8, 1.0))
	if Vector2(pos).distance_to(start) < 40.0:
		Journal.add("sea", "jump")
		map._journal_check()
	_fish.append({"node": node, "t": 0.0, "a": Vector3(start.x, 0, start.y), "b": Vector3(end.x, 0, end.y), "splashed": false})
	map._life._play("splash", 0.9)

func _splash(p: Vector3) -> void:
	var ps := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.radial_segments = 6
	sm.rings = 3
	var mat: StandardMaterial3D = map._flat_mat(Color(1, 1, 1, 0.85), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mat
	ps.mesh = sm
	ps.amount = 22
	ps.lifetime = 0.9
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.direction = Vector3.UP
	ps.spread = 50.0
	ps.initial_velocity_min = 3.0
	ps.initial_velocity_max = 6.5
	ps.gravity = Vector3(0, -12.0, 0)
	ps.position = p
	add_child(ps)
	ps.emitting = true
	get_tree().create_timer(1.6).timeout.connect(ps.queue_free)

func _collect(c: Dictionary) -> void:
	c.got = true
	(c.node as Node3D).visible = false
	_splash((c.node as Node3D).position)
	Journal.mark("chest", str(int(c.id)))
	var total := Journal.add("sea", "chest")
	map._life._play("chime")
	var idx := clampi(total - 1, 0, NOTES.size() - 1)
	var note := String(NOTES[idx])
	if total >= 5 or _all_got():
		note = String(NOTES[NOTES.size() - 1])
		HubBoats.grant("phoenix")
	map._show_toast("寶箱 %d／%d：%s" % [total, chests.size(), note], 4.5)
	map._journal_check()

func _all_got() -> bool:
	for c in chests:
		if not bool(c.got):
			return false
	return not chests.is_empty()

## 按 H 鳴笛：附近的企鵝嚇一跳
func on_horn(pos: Vector2) -> void:
	if _penguin_cd > 0.0:
		return
	var woke := false
	for p in penguins:
		var b: Vector3 = p.base
		if Vector2(b.x, b.z).distance_to(pos) < 45.0 and float(p.jump) < 0.0:
			p.jump = 0.0
			p.dir = Vector2.from_angle(_rng.randf() * TAU)
			woke = true
	if woke:
		_penguin_cd = 5.0
		map._life._play("quack", 1.1)
		var cnt := Journal.add("sea", "penguin")
		map._show_toast("企鵝：「呱！？」", 1.6)
		if cnt in [1, 3]:
			map._journal_check()

## 船擦到海的邊界：說一句話（第一次記成「天涯海角」貼紙）
func on_edge() -> void:
	if _edge_cd > 0.0:
		return
	_edge_cd = 5.0
	map._show_toast(String(EDGE_LINES[_edge_i % EDGE_LINES.size()]), 3.2)
	_edge_i += 1
	if not Journal.has("flag", "world_edge"):
		Journal.mark("flag", "world_edge")
		map._journal_check()
