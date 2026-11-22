extends Node3D
## 農莊跟著旅程長大：每破一個大關，農莊南邊多一個那座島的小地標，被救的動物搬來住（居民）。
##   冰雪島 → 雪人和燈塔、企鵝　　秋楓島 → 南瓜燈和枯樹、小紅雞　　森林 → 小屋和樹、小黃雞
##   人類要塞 → 大砲和瞭望塔、要塞雞　　丹穴山 → 涼亭和銀杏、仙鶴
## 第一次看到新的地標：從地上「噗」地長出來、居民跳進來打招呼（只演一次，之後直接站在那裡）。
## 居民可以戳（點滑鼠或按 E）：會說一句話，戳的次數記在冒險手帳（hub_life.gd 的 "resident"）。
##
## 這個節點放在世界座標原點。level_select.gd 蓋完島之後呼叫 sync()；沒有三星、沒有存檔的東西，
## 只看「這個大關全部小關都過了沒」（map._ch_cleared）。「已經長過」記在 journal.gd 的 [grown]。

const Journal := preload("res://scripts/hub/journal.gd")

## 每個大關的小地標：x／z 是主島自己座標裡的位置（南邊那一帶，路和雞圈之外）；parts：[模型, 相對位置, 最長邊(公尺), 轉向]
const K := 0.72           # 地標整體縮小（南邊離鏡頭近，不縮的話會擋住路上的家豪）

const SPECS := {
	"ice": {"name": "冰雪小角落", "who": "企鵝", "x": 3.0, "z": 8.6, "dust": Color("e8f6ff"),
		"parts": [["res://levels/ice/assets/blender/lighthouse.glb", Vector3(0, 0, 0), 3.6, 0.3],
			["res://levels/ice/assets/blender/snowman.glb", Vector3(2.2, 0, 1.4), 1.7, -0.4],
			["res://levels/ice/assets/blender/snow_drift_a.glb", Vector3(-1.8, 0, 1.6), 2.6, 0.5],
			["res://levels/ice/assets/blender/ice_chunk_b.glb", Vector3(1.0, 0, -1.8), 1.4, 0.0]],
		"res": {"model": "res://levels/ice/assets/kenney_cubepets/animal-penguin.glb", "size": 1.5, "off": Vector3(-0.6, 0, 3.0), "yaw": 0.0},
		"lines": ["有冰箱嗎？我快融化了", "謝謝你救我。魚呢？", "我不是鳥……也算鳥啦", "（假裝自己是雪人）"]},
	"liuchiyu": {"name": "南瓜燈角落", "who": "小紅雞", "x": 12.5, "z": 8.6, "dust": Color("ffb766"),
		"parts": [["res://levels/liuchiyu/assets/kaykit_halloween/tree_dead_medium.gltf", Vector3(0, 0, -0.6), 3.4, 0.4],
			["res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange_jackolantern.gltf", Vector3(1.8, 0, 1.0), 1.0, -0.5],
			["res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_yellow_jackolantern.gltf", Vector3(-1.7, 0, 1.5), 0.9, 0.6],
			["res://levels/liuchiyu/assets/kaykit_halloween/lantern_standing.gltf", Vector3(-2.4, 0, -0.4), 1.6, 0.0]],
		"res": {"hen": 1.0, "off": Vector3(0.4, 0, 3.0), "yaw": 0.0},
		"lines": ["火山超燙，羽毛都捲了", "南瓜燈是我擺的，帥吧", "秋天最適合發呆"]},
	"forest": {"name": "森林小屋", "who": "小黃雞", "x": 41.5, "z": 8.6, "dust": Color("b8e07a"),
		"parts": [["res://assets/farm/SmallBarn.glb", Vector3(0, 0, -0.6), 3.4, 0.2],
			["res://assets/nature/BirchTree.glb", Vector3(-2.8, 0, 0.2), 3.4, 0.4],
			["res://assets/nature/AutumnTree.glb", Vector3(2.9, 0, -0.2), 3.0, 1.2],
			["res://assets/nature/BushBerries.glb", Vector3(1.6, 0, 1.8), 1.1, 0.0]],
		"res": {"hen": 0.9, "off": Vector3(-0.6, 0, 3.0), "yaw": 0.0},
		"lines": ["人類都不見了，好安靜", "莓果是我種的，別偷吃", "咕。（意思是謝謝）"]},
	"fort": {"name": "小砲台", "who": "要塞雞", "x": 51.0, "z": 8.6, "dust": Color("c9c2b6"),
		"parts": [["res://levels/fort/assets/pirate/tower-watch.glb", Vector3(0, 0, -1.2), 3.8, 0.0],
			["res://levels/fort/assets/pirate/cannon.glb", Vector3(2.0, 0, 1.0), 1.8, -0.6],
			["res://levels/fort/assets/pirate/barrel.glb", Vector3(-1.8, 0, 1.0), 0.9, 0.3],
			["res://levels/fort/assets/pirate/flag-pennant.glb", Vector3(-2.6, 0, -1.0), 3.0, 0.0]],
		"res": {"hen": 1.05, "off": Vector3(0.2, 0, 3.0), "yaw": 0.0},
		"lines": ["我會用大砲！但不敢點火", "要塞好大，這裡好溫暖", "報告，今天也沒事做"]},
	"heaven": {"name": "鳳凰亭", "who": "仙鶴", "x": 61.0, "z": 8.6, "dust": Color("ffe27a"),
		"parts": [["res://levels/heaven/assets/blender/pavilion.glb", Vector3(0, 0, -0.8), 4.4, 0.0],
			["res://levels/heaven/assets/blender/ginkgo_a.glb", Vector3(3.0, 0, 0.2), 3.6, 0.5],
			["res://levels/heaven/assets/blender/mini_lantern.glb", Vector3(-2.8, 0, 1.6), 1.3, 0.0],
			["res://levels/heaven/assets/blender/star_stele.glb", Vector3(-3.0, 0, -0.6), 2.2, 0.4]],
		"res": {"model": "res://levels/heaven/assets/blender/crane.glb", "size": 2.0, "off": Vector3(0.4, 0, 3.4), "yaw": 0.0},
		"lines": ["凡雞，你羽毛掉了", "天上的事，少問", "鳳凰？沒聽過。噓"]},
}

var map
var _built := {}          # 大關 id -> {holder, res, th, ph, delay, t, rt, announced}

## 這座島（大關 id）的小地標放在主島座標哪裡（蓋農莊時用來讓樹避開）。沒有就 Vector2.ZERO
static func slot(id: String) -> Vector2:
	if SPECS.has(id):
		return Vector2(float(SPECS[id].x), float(SPECS[id].z))
	return Vector2.ZERO

static func ids() -> Array:
	return SPECS.keys()

## 現在長出幾個了
func count() -> int:
	return _built.size()

func has_grown(id: String) -> bool:
	return _built.has(id)

## 這個大關破完了沒
func _cleared(id: String) -> bool:
	for ent in map.entries:
		var ch: Dictionary = ent.ch
		if not ch.is_empty() and String(ch.id) == id:
			return map._playable(ch) and not map._is_example(ch) and map._ch_cleared(ch)
	return false

## 照進度長出來。animate：第一次長的演一下；回傳這次新長出幾個
func sync(animate := true) -> int:
	var fresh := 0
	var delay := 0.0
	for id in SPECS:
		if _built.has(id) or not _cleared(String(id)):
			continue
		var first := not Journal.has("grown", String(id))
		grow(String(id), animate and first, delay)
		if first:
			Journal.mark("grown", String(id))
			fresh += 1
			delay += 0.9
	return fresh

## 蓋出一個小地標和它的居民。show：演長出來的動畫（delay 秒後開始）
func grow(id: String, show: bool, delay := 0.0) -> void:
	if _built.has(id) or not SPECS.has(id) or map.worlds.is_empty():
		return
	var sp: Dictionary = SPECS[id]
	var off: Vector3 = map.worlds[0].origin
	var pos := Vector3(float(sp.x), map.TOP_Y - 0.05, float(sp.z)) + off
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	for p in sp.parts:
		map._spawn_fit(holder, String(p[0]), (p[1] as Vector3) * K, float(p[2]) * K, float(p[3]))
	# 居民
	var rs: Dictionary = sp.res
	var rpos: Vector3 = pos + (rs.off as Vector3) * Vector3(K, 1.0, 0.9)
	var res: Node3D
	if rs.has("hen"):
		res = map._life._make_hen(float(rs.hen))
		res.position = rpos
	else:
		res = map._spawn_fit(self, String(rs.model), rpos, float(rs.size), 0.0)
	var th: Dictionary = {}
	if res:
		th = map._life.register("resident", res, 1.3, 0.8, {"id": id, "who": String(sp.who), "lines": sp.lines, "n": 0})
	var b := {"holder": holder, "res": res, "th": th, "base": rpos, "ph": randf() * 6.0, "delay": delay if show else -1.0,
		"t": 0.0, "rt": -1.0, "yaw": float(rs.yaw), "show": show, "name": String(sp.name), "who": String(sp.who), "dust": sp.dust}
	_built[id] = b
	if show:
		holder.scale = Vector3.ZERO
		if res:
			res.visible = false

func _ease_back(k: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)

func tick(dt: float, t: float) -> void:
	var hero: Vector3 = map._hero.global_position
	for id in _built:
		var b: Dictionary = _built[id]
		var holder: Node3D = b.holder
		var res: Node3D = b.res
		# 長出來的動畫：等 delay → 地標彈出來（0.9 秒）→ 居民跳進來
		if float(b.delay) >= 0.0:
			b.delay = float(b.delay) - dt
			if float(b.delay) < 0.0:
				b.t = 0.0
				b.delay = -2.0              # 開始演了
				map._life._play("gold")
				map._life.puff(holder.global_position + Vector3(0, 0.6, 0), b.dust, 22, 5.0, 0.34, -5.0, 1.2, 1.0, 1.8)
				map._life.say(holder.global_position + Vector3(0, 4.6, 0), "%s蓋好了！" % String(b.name), Color("fff3b0"), 60)
		elif float(b.delay) == -2.0:
			b.t = float(b.t) + dt
			var k := clampf(float(b.t) / 0.9, 0.0, 1.0)
			holder.scale = Vector3.ONE * maxf(_ease_back(k), 0.0)
			if float(b.t) > 0.7 and float(b.rt) < 0.0 and res:
				b.rt = 0.0
				res.visible = true
				map._life._play("boing", 1.2)
				map._life.say((b.base as Vector3) + Vector3(0, 2.8, 0), "%s搬來啦！" % String(b.who), Color.WHITE)
				map._life.puff((b.base as Vector3) + Vector3(0, 0.3, 0), Color(1, 1, 1), 10, 3.0, 0.2, -5.0, 0.8)
			if k >= 1.0 and float(b.rt) >= 0.0 and float(b.t) > 1.6:
				b.delay = -1.0
				holder.scale = Vector3.ONE
		if res == null or not res.visible:
			continue
		# 居民：輕輕彈、轉向家豪（在附近才轉；遠的時候面對鏡頭）
		var rt := float(b.rt)
		var hop := 0.0
		if rt >= 0.0:
			rt += dt
			b.rt = rt
			if rt < 0.7:
				hop = sin(rt / 0.7 * PI) * 1.2
			else:
				b.rt = 99.0
		var bp: Vector3 = b.base
		res.position = bp + Vector3(0, hop + absf(sin(t * 2.6 + float(b.ph))) * 0.07, 0)
		var to := hero - bp
		var want := float(b.yaw)
		if Vector2(to.x, to.z).length() < 15.0:
			want = atan2(to.x, to.z) + float(b.yaw)
		res.rotation.y = lerp_angle(res.rotation.y, want, 1.0 - exp(-dt * 5.0))
