extends Node3D
## 主島的「戳戳樂」：農莊裡的東西都可以戳，戳了會有反應（玩家是神，神可以從天上戳任何東西）。
##   母雞：跳起來「咕咕」，戳幾下會下蛋；點蛋把它收起來（每 8 顆蛋有一顆金的）
##   樹：搖一搖，掉樹葉　　風車、筒倉、南瓜、乾草堆：Q 彈一下　　小船：搖啊搖　　營火：火苗竄起來
##   穀倉：門被敲開，小雞衝出來跑一圈再回去睡覺　　乾草堆：有一堆藏著金蛋（找到才算數）
##   家豪：被戳會嫌你煩，戳十下他就轉過去不理你
## 戳法：滑鼠點它，或按 E 戳離家豪最近的那一個。次數記在冒險手帳（journal.gd）。
## 全部都是看得到的小動作，不影響關卡、星星和存檔進度。
##
## level_select.gd 蓋農莊的時候呼叫 register() 登記每一樣東西，蓋完再呼叫 spawn_hens()。
## 這個節點放在世界座標的原點，所以子節點的座標就是世界座標。

const Journal := preload("res://scripts/hub/journal.gd")
const Sfx := preload("res://scripts/hub/hub_sfx.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")

const PICK_FAR := 13.0         # 按 E 時，離家豪幾公尺內的東西才算
const EGG_MAX := 8             # 地上最多同時幾顆蛋
const HEN_SPEED := 1.3
const HERO_LINES := ["……？", "幹嘛。", "別戳了。", "我在想事情。", "你是神，這麼閒？", "（翻白眼）", "好痛。", "再戳我就飛走。", "……", "有事嗎。"]
const HEN_LINES := ["咕咕！", "咕？", "咕咕咕！", "咕嘎！", "別戳我！", "咕～"]

var map                         # 選關畫面（level_select.gd）
var things: Array = []          # 可以戳的東西 {kind, node, r, h, t, cd, base_s, base_r, ...}
var hens: Array = []
var eggs: Array = []
var _snd := {}
var _texts: Array = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _flames: Array = []
var _barn := {}
var _chicks: Array = []
var _hero_fx := 0.0             # 家豪被戳：>0 = 還在彈
var _hero_turn := 0.0           # 家豪轉過去不理人：還剩幾秒
var _hay_n := 0
var _puff_tex: Texture2D
var _gold_out := false          # 地上現在有一顆還沒收的金蛋

func _ready() -> void:
	_rng.seed = 20261121
	_snd = Sfx.attach(self, -4.0)

# ---------------------------------------------------------------- 登記

## 登記一樣可以戳的東西。r：點擊半徑（公尺）；h：中心離腳底多高。回傳那一筆資料
func register(kind: String, node: Node3D, r: float, h: float, extra := {}) -> Dictionary:
	var th := {"kind": kind, "node": node, "r": r, "h": h, "t": -1.0, "cd": 0.0,
		"base_s": node.scale, "base_r": node.rotation, "base_p": node.position, "extra": extra}
	things.append(th)
	return th

## 營火的火苗：一直閃動；戳了竄高
func register_flame(node: Node3D) -> void:
	var th := register("fire", node, 1.0, 0.5)
	_flames.append(th)

## 穀倉：把兩扇門拆成可以轉的，戳了門打開、小雞跑出來
func register_barn(holder: Node3D) -> void:
	register("barn", holder, 4.2, 3.0)
	var pivots: Array = []
	var doors: Array = []
	_find_doors(holder, doors)
	for d in doors:
		var mi := d as MeshInstance3D
		var parent := mi.get_parent() as Node3D
		var bb: AABB = mi.transform * mi.mesh.get_aabb()
		var cx := bb.position.x + bb.size.x * 0.5
		var right := cx > 0.0                               # 右邊那扇：鉸鏈在右緣，往外開是正角度
		var hinge := Vector3(bb.position.x + (bb.size.x if right else 0.0), 0.0, bb.position.z + bb.size.z * 0.5)
		var pv := Node3D.new()
		pv.position = hinge
		parent.add_child(pv)
		parent.remove_child(mi)
		pv.add_child(mi)
		mi.transform = Transform3D(Basis.IDENTITY, -hinge) * mi.transform
		pivots.append({"node": pv, "sign": 1.0 if right else -1.0})
	_barn = {"holder": holder, "pivots": pivots, "t": -1.0}

func _find_doors(n: Node, out: Array) -> void:
	if n is MeshInstance3D and String(n.name).contains("Door") and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		_find_doors(c, out)

func _aabb(node: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var have := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out = xf * (node as MeshInstance3D).mesh.get_aabb()
		have = true
	for c in node.get_children():
		var b := _aabb(c, xf)
		if b.size != Vector3.ZERO:
			out = out.merge(b) if have else b
			have = true
	return out

## 做一隻白色母雞（沒穿帽 T）。height：多高（公尺）
func _make_hen(height: float) -> Node3D:
	var hc := Node3D.new()
	hc.set_script(load("res://scripts/characters.gd"))
	hc.set_process(false)
	add_child(hc)
	var hen: Node3D = hc._make_round_chicken(false)
	hc.add_child(hen)
	var hb := _aabb(hen, Transform3D.IDENTITY)
	if hb.size.y > 0.01:
		var hs := height / hb.size.y
		hen.scale = Vector3.ONE * hs
		hen.position.y = -hb.position.y * hs
	return hc

## 母雞：specs = [{"pos": 世界座標, "rad": 逛多遠}]
func spawn_hens(specs: Array) -> void:
	for i in specs.size():
		var sp: Dictionary = specs[i]
		var pos: Vector3 = sp.pos
		var hc := _make_hen(1.25 + 0.15 * sin(i * 2.3))
		hc.position = pos
		var th := register("hen", hc, 1.2, 0.55, {"idx": i})
		hens.append({"idx": i, "node": hc, "thing": th, "home": pos, "pos": pos, "rad": float(sp.get("rad", 2.4)), "target": pos,
			"walk": false, "wait": 0.4 + i * 0.37, "yaw": i * 1.7, "phase": i * 1.37, "pokes": 0, "lay": -1.0, "hop": -1.0})

# ---------------------------------------------------------------- 每一格

func _on_island() -> bool:
	return map != null and map.selected == 0 and map._zoom < 0.2 and not map._busy() and not map._starting

func tick(dt: float, t: float) -> void:
	_t = t
	for th in things:
		if float(th.cd) > 0.0:
			th.cd = maxf(float(th.cd) - dt, 0.0)
	_tick_things(dt)
	_tick_hens(dt)
	_tick_eggs(dt)
	_tick_barn(dt)
	_tick_flames(dt)
	_tick_hero(dt)
	_tick_texts(dt)

## 一般的小動作（搖、彈、晃）
func _tick_things(dt: float) -> void:
	for th in things:
		var tt := float(th.t)
		if tt < 0.0:
			continue
		var kind := String(th.kind)
		if kind == "hen" or kind == "barn" or kind == "fire" or kind == "egg" or kind == "hero":
			continue
		tt += dt
		th.t = tt
		var n: Node3D = th.node
		var dur := 1.0
		match kind:
			"tree":
				dur = 0.95
				var a := pow(maxf(1.0 - tt / dur, 0.0), 2.0)
				n.rotation = (th.base_r as Vector3) + Vector3(sin(tt * 23.0) * 0.07 * a, 0.0, cos(tt * 19.0) * 0.09 * a)
			"resident":
				dur = 0.8
				var a4 := sin(tt * 18.0) * exp(-tt * 5.0) * 0.22
				n.scale = (th.base_s as Vector3) * Vector3(1.0 + a4, 1.0 - a4, 1.0 + a4)
			"windmill":
				dur = 1.5
				var a2 := exp(-tt * 2.4)
				n.scale = (th.base_s as Vector3) * Vector3(1.0 + sin(tt * 13.0) * 0.07 * a2, 1.0 - sin(tt * 13.0) * 0.06 * a2, 1.0 + sin(tt * 13.0) * 0.07 * a2)
				n.rotation = (th.base_r as Vector3) + Vector3(0, 0, sin(tt * 9.0) * 0.05 * a2)
			"boat":
				dur = 1.8
				var a3 := exp(-tt * 2.0)
				n.rotation = (th.base_r as Vector3) + Vector3(sin(tt * 6.0) * 0.12 * a3, 0, sin(tt * 7.0) * 0.22 * a3)
			_:
				dur = 0.8
				var s := sin(tt * 18.0) * exp(-tt * 5.0) * 0.28
				n.scale = (th.base_s as Vector3) * Vector3(1.0 + s, 1.0 - s, 1.0 + s)
		if tt >= dur:
			th.t = -1.0
			n.scale = th.base_s
			n.rotation = th.base_r

func _tick_flames(dt: float) -> void:
	for th in _flames:
		var n: Node3D = th.node
		var base: Vector3 = th.base_s
		var k := 1.0
		if float(th.t) >= 0.0:
			th.t = float(th.t) + dt
			var f := float(th.t) / 1.0
			if f >= 1.0:
				th.t = -1.0
			else:
				k = 1.0 + 0.9 * sin(f * PI)
		n.scale = base * Vector3(k * (1.0 + 0.06 * sin(_t * 11.0)), k * (1.0 + 0.14 * sin(_t * 8.0 + 1.0) + 0.07 * sin(_t * 17.0)), k * (1.0 + 0.06 * sin(_t * 9.0)))

# ---------------------------------------------------------------- 母雞

func _tick_hens(dt: float) -> void:
	for h in hens:
		var n: Node3D = h.node
		var hop := 0.0
		var squat := 1.0
		var peck := 0.0
		if float(h.hop) >= 0.0:
			h.hop = float(h.hop) + dt
			var k: float = float(h.hop) / 0.65
			if k >= 1.0:
				h.hop = -1.0
			else:
				hop = sin(k * PI) * 1.0
				h.yaw = float(h.yaw) + dt * 9.0
		if float(h.lay) >= 0.0:
			h.lay = float(h.lay) + dt
			var lk: float = float(h.lay) / 0.8
			squat = 1.0 - 0.22 * sin(minf(lk, 1.0) * PI) - 0.06 * sin(lk * 30.0)
			if lk >= 1.0:
				h.lay = -1.0
				_lay_egg(h)
		elif hop <= 0.0:
			if bool(h.walk):
				var to: Vector3 = h.target - h.pos
				to.y = 0.0
				var d := to.length()
				if d < 0.12:
					h.walk = false
					h.wait = _rng.randf_range(1.2, 3.6)
				else:
					var step := minf(HEN_SPEED * dt, d)
					h.pos = (h.pos as Vector3) + to / d * step
					h.yaw = lerp_angle(float(h.yaw), atan2(to.x, to.z), 1.0 - exp(-dt * 8.0))
			else:
				h.wait = float(h.wait) - dt
				var cyc := sin(_t * 7.5 + float(h.phase))
				peck = maxf(cyc - 0.2, 0.0) * 0.7
				if float(h.wait) <= 0.0:
					var a := _rng.randf() * TAU
					var r := _rng.randf_range(0.4, float(h.rad))
					h.target = (h.home as Vector3) + Vector3(cos(a) * r, 0, sin(a) * r)
					h.walk = true
		var bob := absf(sin(_t * 10.0 + float(h.phase))) * 0.07 if bool(h.walk) and hop <= 0.0 else 0.0
		n.position = (h.pos as Vector3) + Vector3(0, hop + bob, 0)
		n.rotation = Vector3(peck, float(h.yaw), 0)
		n.scale = Vector3(1.0 / sqrt(squat), squat, 1.0 / sqrt(squat))

func _lay_egg(h: Dictionary) -> void:
	if eggs.size() >= EGG_MAX:
		return
	var n_laid := Journal.n("egg", "laid") + 1
	Journal.add("egg", "laid")
	var gold := n_laid % 8 == 0
	var back := Vector3(sin(float(h.yaw)), 0, cos(float(h.yaw))) * -0.7
	_spawn_egg((h.pos as Vector3) + back, gold)
	_play("pop")
	say((h.pos as Vector3) + Vector3(0, 2.0, 0), "下蛋啦！", Color("fff3b0"))

func _spawn_egg(pos: Vector3, gold: bool) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = Vector3(pos.x, pos.y, pos.z)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.62
	sm.radial_segments = 20
	sm.rings = 12
	mi.mesh = sm
	mi.position.y = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffd23c") if gold else Color("fff4de")
	mat.roughness = 0.5
	mat.metallic = 0.55 if gold else 0.0
	if gold:
		mat.emission_enabled = true
		mat.emission = Color("ff9e1a")
		mat.emission_energy_multiplier = 0.55
	mi.material_override = mat
	holder.add_child(mi)
	holder.scale = Vector3.ZERO
	var th := register("egg", holder, 0.9, 0.3, {"gold": gold})
	th.t = 0.0
	eggs.append(th)
	if gold:
		_gold_out = true
		puff(pos + Vector3(0, 0.5, 0), Color("ffe27a"), 14, 3.0, 0.22, -2.0, 1.0)

func _tick_eggs(dt: float) -> void:
	for th in eggs:
		var tt := float(th.t)
		var n: Node3D = th.node
		if tt >= 0.0 and String(th.get("state", "")) != "fly":
			tt += dt
			th.t = tt
			var k := minf(tt / 0.35, 1.0)
			var bounce := 1.0 + 0.25 * sin(k * PI) * (1.0 - k)
			n.scale = Vector3.ONE * (k * bounce)
			if k >= 1.0:
				th.t = -1.0
				n.scale = Vector3.ONE
		if String(th.get("state", "")) == "fly":
			th.fly = float(th.fly) + dt
			var f := minf(float(th.fly) / 0.55, 1.0)
			var from: Vector3 = th.from
			n.position = from + Vector3(0, f * 2.6 + sin(f * PI) * 0.6, 0)
			n.rotation.y += dt * 12.0
			n.scale = Vector3.ONE * (1.0 - f * f)
			if f >= 1.0:
				n.queue_free()
				_erase_ref(things, th)
				_erase_ref(eggs, th)
				return
		elif bool(th.extra.get("gold", false)):
			(n.get_child(0) as Node3D).rotation.y = _t * 2.0

## 用「同一個物件」比對來移除（Dictionary 的 == 會比內容，比較慢）
func _erase_ref(arr: Array, th: Dictionary) -> void:
	for i in arr.size():
		if is_same(arr[i], th):
			arr.remove_at(i)
			return

func _collect_egg(th: Dictionary) -> void:
	if String(th.get("state", "")) == "fly":
		return
	var gold := bool(th.extra.get("gold", false))
	th.state = "fly"
	th.fly = 0.0
	th.from = (th.node as Node3D).position
	th.t = -1.0
	var total := Journal.add("egg", "total")
	if gold:
		Journal.add("egg", "gold")
		Journal.mark("flag", "gold_egg")
		_gold_out = false
		_play("gold")
		say((th.from as Vector3) + Vector3(0, 1.4, 0), "金蛋！！", Color("ffd23c"), 64)
		puff((th.from as Vector3) + Vector3(0, 0.6, 0), Color("ffe27a"), 22, 4.5, 0.26, -1.5, 1.3)
	else:
		_play("pop")
		say((th.from as Vector3) + Vector3(0, 1.2, 0), "+1 蛋（%d）" % total, Color("fff3b0"))
		puff((th.from as Vector3) + Vector3(0, 0.5, 0), Color("fff4de"), 8, 2.5, 0.16, -3.0, 0.7)
	map.call("_journal_check")

# ---------------------------------------------------------------- 穀倉

func _tick_barn(dt: float) -> void:
	if _barn.is_empty() or float(_barn.t) < 0.0:
		return
	_barn.t = float(_barn.t) + dt
	var t := float(_barn.t)
	var open := 0.0
	if t < 0.4:
		open = t / 0.4
	elif t < 3.4:
		open = 1.0
	elif t < 3.9:
		open = 1.0 - (t - 3.4) / 0.5
	for p in _barn.pivots:
		(p.node as Node3D).rotation.y = float(p.sign) * open * deg_to_rad(105.0)
	# 小雞：衝出來繞著門口跑，最後縮回去
	var front := _barn_front()
	for i in _chicks.size():
		var c: Node3D = _chicks[i]
		var k := clampf((t - 0.25 - i * 0.12) / 3.0, 0.0, 1.0)
		var ang := i * 2.1 + t * 2.2
		var rad := 1.0 + 1.5 * sin(minf(k * 1.4, 1.0) * PI * 0.5)
		c.position = front + Vector3(cos(ang) * rad, absf(sin(t * 11.0 + i)) * 0.22, sin(ang) * rad * 0.7)
		c.rotation.y = -ang + PI * 0.5 + PI
		var sc := 0.62 * (1.0 if t < 3.3 else maxf(1.0 - (t - 3.3) / 0.5, 0.0))
		c.scale = Vector3.ONE * sc
		c.visible = t > 0.25 + i * 0.12
	if t >= 3.9:
		_barn.t = -1.0
		for c in _chicks:
			(c as Node3D).visible = false

func _barn_front() -> Vector3:
	var h: Node3D = _barn.holder
	var mid := Vector3.ZERO
	for p in _barn.pivots:
		mid += (p.node as Node3D).global_position
	mid /= float(maxi(_barn.pivots.size(), 1))
	var fwd := h.global_transform.basis.z.normalized()
	return Vector3(mid.x, h.global_position.y + 0.02, mid.z) + fwd * 1.8

func _open_barn() -> void:
	if _barn.is_empty() or float(_barn.t) >= 0.0:
		return
	_barn.t = 0.0
	if _chicks.is_empty():
		for i in 3:
			var c := _make_hen(1.0)
			c.visible = false
			_chicks.append(c)
	_play("knock")
	var front := _barn_front()
	say(front + Vector3(0, 4.2, 0), "誰啊？", Color("fff3b0"))
	get_tree().create_timer(0.35).timeout.connect(func(): _play("cluck"))

# ---------------------------------------------------------------- 家豪

func _tick_hero(dt: float) -> void:
	var body: Node3D = map._hero_body
	if _hero_fx > 0.0:
		_hero_fx = maxf(_hero_fx - dt, 0.0)
		if map._walk.is_empty() and map._jump.is_empty():
			var k := 1.0 - _hero_fx / 0.45
			body.position.y += sin(k * PI) * 0.55
			body.rotation.x = sin(k * PI * 2.0) * 0.35
		if _hero_fx <= 0.0:
			body.rotation.x = 0.0
	if _hero_turn > 0.0:
		_hero_turn = maxf(_hero_turn - dt, 0.0)
		map._face_yaw = PI
		if _hero_turn <= 0.0:
			map._face_yaw = 0.0

# ---------------------------------------------------------------- 戳

## 螢幕上的位置（在鏡頭後面回傳 null）
func _screen(th: Dictionary) -> Variant:
	var cam: Camera3D = map._cam
	var wp: Vector3 = (th.node as Node3D).global_position + Vector3(0, float(th.h), 0)
	if cam.is_position_behind(wp):
		return null
	return cam.unproject_position(wp)

func _px_radius(th: Dictionary) -> float:
	var cam: Camera3D = map._cam
	var wp: Vector3 = (th.node as Node3D).global_position + Vector3(0, float(th.h), 0)
	var dist := maxf(cam.global_position.distance_to(wp), 0.5)
	var vh := get_viewport().get_visible_rect().size.y
	var focal := vh * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	return maxf(float(th.r) * focal / dist, 14.0)

## small_only：只挑母雞、蛋、家豪（站點旁邊的點擊要讓站點優先時用）
func _pick(pos: Vector2, small_only := false) -> Dictionary:
	if not _on_island():
		return {}
	var best := {}
	var best_s := 1.0
	for th in things:
		if not (th.node as Node3D).is_inside_tree() or not (th.node as Node3D).is_visible_in_tree():
			continue
		if String(th.get("state", "")) == "fly":
			continue
		if small_only and not String(th.kind) in ["hen", "egg", "hero"]:
			continue
		var sp: Variant = _screen(th)
		if sp == null:
			continue
		var s := (sp as Vector2).distance_to(pos) / _px_radius(th)
		if s < best_s:
			best_s = s
			best = th
	return best

func hover_at(pos: Vector2) -> bool:
	return not _pick(pos).is_empty()

func poke_at(pos: Vector2, small_only := false) -> bool:
	var th := _pick(pos, small_only)
	if th.is_empty():
		return false
	_poke(th)
	return true

## E：戳離家豪最近的那一個（蛋優先）
func poke_near() -> bool:
	if not _on_island():
		return false
	var me: Vector3 = map._hero.global_position
	var best := {}
	var best_d := PICK_FAR
	for th in things:
		var k := String(th.kind)
		if k == "hero" or String(th.get("state", "")) == "fly" or not (th.node as Node3D).is_visible_in_tree():
			continue
		var p: Vector3 = (th.node as Node3D).global_position
		var d := Vector2(p.x - me.x, p.z - me.z).length()
		if k == "egg":
			d *= 0.5
		if d < best_d:
			best_d = d
			best = th
	if best.is_empty():
		return false
	_poke(best)
	return true

func _poke(th: Dictionary) -> void:
	if float(th.cd) > 0.0:
		return
	var kind := String(th.kind)
	th.cd = 0.22
	var node := th.node as Node3D
	var pos := node.global_position
	if kind == "egg":
		_collect_egg(th)
		return
	Journal.add("poke", "total")
	Journal.add("poke", kind)
	var top := pos + Vector3(0, float(th.h) * 2.0 + 0.6, 0)
	match kind:
		"hen":
			var h := _hen_of(th)
			if h.is_empty():
				return
			h.hop = 0.0
			h.pokes = int(h.pokes) + 1
			_play("cluck", _rng.randf_range(0.9, 1.25))
			say(top + Vector3(0, 0.6, 0), HEN_LINES[(int(h.pokes) + int(h.idx)) % HEN_LINES.size()], Color.WHITE)
			puff(pos + Vector3(0, 0.6, 0), Color(1, 1, 1), 5, 2.0, 0.14, -4.0, 0.6)
			if int(h.pokes) % 3 == 0 and eggs.size() < EGG_MAX:
				h.lay = 0.0
		"tree":
			th.t = 0.0
			_play("rustle", _rng.randf_range(0.9, 1.1))
			var leaf: Color = th.extra.get("leaf", Color("6fae4a"))
			puff(pos + Vector3(0, float(th.h) * 1.1, 0), leaf, 14, 2.6, 0.2, -3.2, 1.6, 1.0, 1.8)
			if int(Journal.n("poke", "tree")) % 7 == 0:
				say(top, "掉了顆果子？沒有。", Color("fff3b0"))
		"windmill":
			th.t = 0.0
			_play("whoosh")
			say(top, "呼～", Color("d8f3ff"), 60)
			puff(pos + Vector3(0, 4.0, 2.0), Color(1, 1, 1, 0.9), 10, 4.0, 0.3, 0.0, 1.0)
		"silo":
			th.t = 0.0
			_play("knock")
			say(top, "咚咚！空心的。", Color("fff3b0"))
		"pumpkin":
			th.t = 0.0
			_play("boing", _rng.randf_range(0.9, 1.4))
		"hay":
			th.t = 0.0
			_play("rustle", 1.25)
			puff(pos + Vector3(0, 0.5, 0), Color("f0cf62"), 12, 2.8, 0.17, -4.0, 0.9)
			_poke_hay(th, pos)
		"boat":
			th.t = 0.0
			_play("splash")
			say(top, "搖啊搖～", Color("d8f3ff"))
			puff(pos + Vector3(0, 0.2, 0), Color(1, 1, 1), 8, 2.4, 0.16, -5.0, 0.7)
		"fire":
			th.t = 0.0
			_play("flare")
			puff(pos + Vector3(0, 0.8, 0), Color("ffb13a"), 14, 3.6, 0.13, 2.0, 1.1)
			say(top, "啪嘰！", Color("ffcf7a"))
		"barn":
			_open_barn()
		"hero":
			_poke_hero()
		"resident":
			th.t = 0.0
			_play("boing", 1.1)
			var ex: Dictionary = th.extra
			var lines: Array = ex.lines
			var line := String(lines[int(ex.n) % lines.size()])
			ex.n = int(ex.n) + 1
			say(top + Vector3(0, 0.6, 0), "%s：%s" % [String(ex.who), line], Color("fff3b0"))
	map.call("_journal_check")

func _hen_of(th: Dictionary) -> Dictionary:
	var i := int(th.extra.get("idx", -1))
	return hens[i] if i >= 0 and i < hens.size() else {}

## 乾草堆：最靠近穀倉的那一堆藏著金蛋（還沒找到過、地上也沒有金蛋的時候才會滾出來）
func _poke_hay(th: Dictionary, pos: Vector3) -> void:
	if not bool(th.extra.get("special", false)):
		return
	if Journal.has("flag", "gold_egg") or _gold_out or eggs.size() >= EGG_MAX:
		return
	say(pos + Vector3(0, 2.2, 0), "咦？有東西！", Color("ffe27a"), 56)
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_inside_tree() and not _gold_out:
			_spawn_egg(pos + Vector3(0.9, 0, 1.1), true)
	)

func _poke_hero() -> void:
	var n := Journal.n("poke", "hero")
	_hero_fx = 0.45
	_play("boing", 1.3)
	var hp: Vector3 = (map._hero as Node3D).global_position
	if n % 10 == 0:
		_hero_turn = 3.0
		say(hp + Vector3(0, 3.2, 0), "不理你了。", Color("ffd0d0"), 60)
	else:
		say(hp + Vector3(0, 3.2, 0), HERO_LINES[(n - 1) % HERO_LINES.size()], Color.WHITE)

# ---------------------------------------------------------------- 小特效

func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _snd.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()

## 浮出一行字，往上飄、慢慢淡掉（字的大小固定在畫面上大約 46 像素）
func say(pos: Vector3, text: String, col := Color.WHITE, size := 54) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UIStyle.font()
	l.font_size = size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.modulate = Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, col.a)      # 比 1 亮一點：不然被色調映射壓成灰色
	l.outline_size = 16
	l.outline_modulate = Color(0.23, 0.16, 0.12, 1.0)
	l.render_priority = 10
	l.outline_render_priority = 9
	add_child(l)
	l.global_position = pos
	var cam: Camera3D = map._cam
	var dist := maxf(cam.global_position.distance_to(pos), 1.0)
	var vh := get_viewport().get_visible_rect().size.y
	var focal := vh * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var u := minf(get_viewport().get_visible_rect().size.x / 1600.0, vh / 900.0)
	l.pixel_size = 46.0 * u * dist / (float(size) * focal)
	_texts.append({"node": l, "t": 0.0, "y": pos.y})

func _tick_texts(dt: float) -> void:
	for i in range(_texts.size() - 1, -1, -1):
		var d: Dictionary = _texts[i]
		d.t = float(d.t) + dt
		var k: float = float(d.t) / 1.3
		var l: Label3D = d.node
		if k >= 1.0:
			l.queue_free()
			_texts.remove_at(i)
			continue
		var p := l.global_position
		l.global_position = Vector3(p.x, float(d.y) + k * 1.6, p.z)
		l.modulate.a = 1.0 - smoothstep(0.65, 1.0, k)

## 一把小碎片（樹葉、乾草、火星、星光）往外噴，噴完自己消失
func puff(pos: Vector3, col: Color, count := 10, speed := 3.0, size := 0.2, grav := -6.0, life := 0.9, _unused := 1.0, spread_r := 0.3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_r
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.angle_max = 360.0
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	if _puff_tex == null:
		# 圓圓軟軟的小光點（不然碎片是一格一格的方塊）
		var pg := Gradient.new()
		pg.set_color(0, Color(1, 1, 1, 1))
		pg.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = pg
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_puff_tex = gt
	mat.albedo_texture = _puff_tex
	qm.material = mat
	p.mesh = qm
	p.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
