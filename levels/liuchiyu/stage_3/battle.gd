extends "res://levels/liuchiyu/island_battle.gd"
## 第三小關的戰局：高原上的火山、小湖和盔甲騎士。
##
## 火山不會自己噴發：用「雷」劈進火山口的岩漿，才會噴出一顆大岩漿球。岩漿球飛得很慢，
## 先往上衝再往下掉：按住「風」的時候它被托住、慢慢下降，並且順著風的方向飄；一放開就很快直直掉下去。
## 落地的地方附近的人會被燙傷（家豪也會）。
##
## 場地東邊有一個小湖，中間的小島上放著第三顆星星。岩漿球掉進湖水裡會凝固成一堆鵝卵石；
## 鵝卵石從岸邊一路接到小島，家豪就能踩著過去拿星星。
##
## 最終 Boss「盔甲騎士」：家豪啄不動他（也不會去啄他），岩漿燒得到、站在湖水裡被雷劈也會倒。
## 他一開始不在場上：一般敵人都倒下之後，一架飛機飛過來，他從飛機上跳下來。
## 騎士落地後會一直朝家豪走過去。家豪會衝上去啄他一下（沒用），被他打到扣一點血、往後飛，
## 逃開一陣子之後又回去啄；玩家要趁這段時間把岩漿球引到騎士身上。
## 打到騎士這一段之後輸了，重來（R）就直接從飛機飛來開始，不用重打農夫。

const ThunderItem := preload("res://levels/liuchiyu/items/thunder_item.gd")
const WindItem := preload("res://levels/liuchiyu/items/wind_item.gd")

const VOLCANO_REACH := 6.0               # 雷要劈在離火山口多近才算劈進岩漿
const BOMB_UP := [7.5]                   # 一次噴一顆大的岩漿球，往上衝多快
const BOMB_GRAVITY := 3.4                # 掉下來的加速度（比真的重力小很多：飛得慢才好瞄準）
const BOMB_SPEED := 9.0                  # 被風吹著的時候，水平最快飄多快
const BOMB_ACCEL := 10.0                 # 風把它推到全速要多快
const BOMB_FAST := 14.0                   # 沒吹風的時候往下掉的加速度（比往上衝那一段的重力大很多）
const WIND_LIFT := 0.3                    # 風吹著的時候，重力只剩這麼多倍
const WIND_FALL := 1.4                    # 風吹著的時候，往下最快掉多快（公尺／秒）
const BOMB_DRAG := 8.0                   # 沒有風的時候，水平速度多快停下來
const BOMB_LIFE := 30.0                  # 飛太久（飛出島外）就消失
const WIND_KEEP := 0.2                   # 放開風之後，風還算在吹幾秒
const BOMB_SIZE := 1.25                  # 岩漿球看起來多大（半徑）
const BOMB_RADIUS := 3.4                 # 落地時燙到多大一圈
const BOMB_DAMAGE := 8.0                 # 農夫被燙到扣多少血（農夫 8、守衛 12）
const BOMB_BIRD_DAMAGE := 3.0            # 家豪被燙到扣多少血（最多燙到剩 1 滴）
const POOL_TIME := 3.5                   # 落地的岩漿過幾秒冷掉消失

const PLANE_TIME := 6.0                  # 飛機飛過場地要幾秒
const PLANE_SPEED := 11.0                # 飛機飛多快
const PLANE_H := 13.0                    # 飛機比地面高多少（騎士從這個高度跳下來）
const DROP_AT := 2.6                     # 飛機出現之後幾秒，騎士跳出來（這時候飛機剛好飛到落點上面）
const DROP_FALL := 1.5                   # 騎士掉到地上要幾秒
const WATER_REACH := 1.6                 # 岩漿球落點離湖岸這麼近也算碰到水（球本身半徑 1.25，擦到岸邊就算）
const MARK_RED := Color(1.0, 0.35, 0.1, 0.28)      # 落點圈：底下什麼都沒有
const MARK_GREEN := Color(0.3, 1.0, 0.4, 0.42)     # 落點圈：底下是湖水，或是有敵人
const STONE_R := 2.6                     # 岩漿掉進湖裡凝固成的鵝卵石堆有多大（半徑）
const LINK_GAP := 2.4                    # 石頭堆之間（或跟岸邊、小島之間）差這麼一點也算接得起來，中間自動補上小石頭
const STONE_TOP := 0.22                  # 鵝卵石頂面比水面高多少
const KNIGHT_SCALE := 1.25               # 騎士比一般農夫大多少
const KNIGHT_SPEED := 1.7                # 騎士走多快（比家豪慢）
const KNIGHT_REACH := 1.7                # 騎士離家豪多近就出手
const KNIGHT_HIT := 1.0                  # 騎士打家豪一下扣多少血
const KNIGHT_CD := 2.2                   # 騎士打完一下要等幾秒才能再打
const KNOCK_BACK := 5.0                  # 家豪被打到往後飛多遠
const KNOCK_TIME := 0.7                  # 飛幾秒
const KNOCK_PEAK := 1.5                  # 飛多高
const FLEE_TIME := 5.0                   # 被打之後逃幾秒，再回去啄
const PECK_REACH := 2.0                   # 家豪衝到離騎士多近就啄（要比騎士出手的距離遠一點，才啄得到第一下）
const PECK_SPEED := 2.8                  # 家豪衝過去啄騎士的速度
const FLEE_SPEED := 2.3                  # 家豪躲騎士的時候跑多快
const FLEE_NEAR := 7.5                   # 騎士靠到多近家豪就開始跑

var _bombs: Array = []                   # 飛在空中的：{pos, vel, t, node, mark}
var _pools: Array = []                   # 落在地上的：{t, node, mat}
var _wind_dir := Vector3.ZERO            # 現在風往哪邊吹
var _wind_t := 0.0                       # 風還算在吹幾秒
var _drop_t := -1.0                      # 飛機來了幾秒（< 0 = 還沒來）
var _skip_farmers := false               # 這一局是從騎士那一段重來的（農夫直接算倒下）
var _boss_phase := false                 # 已經打到騎士這一段了：輸了重來（R）就從這裡開始，不用重打農夫
var _plane: Node3D
var _boss_cut := -1.0                    # 騎士登場的特寫播了幾秒（< 0 = 沒在播）
var _boss_line := 0                      # 台詞說到第幾句了
var _boss_back := Transform3D.IDENTITY
var _boss_head := 0.0
var _boss_next := false                  # 玩家按了 Enter：換下一句
var _boss_line_t := 0.0                  # 這一句已經出現幾秒了
var _boss_hint: Label                    # 對話框右下角的「Enter ▶」
var _kn_cd := 0.0                        # 騎士還要等多久才能再打
var _bird_mode := 0                      # 家豪對騎士：0 衝過去啄、1 被打飛、2 逃開
var _bird_t := 0.0
var _flee_dir := Vector3.ZERO             # 上一步往哪邊逃（下一步盡量同方向，才不會左右亂抖）
var _pecked := false                     # 這一趟啄過了
var _kn_from := Vector3.ZERO
var _kn_to := Vector3.ZERO
var _fills: Array = []                   # 橋上補空隙的小石頭位置
var _stones: Array = []                  # 湖裡的鵝卵石堆：{pos, node}
var _bridge: Array[Vector3] = []         # 從岸邊踩著鵝卵石走到小島的路（空的 = 還沒接起來）
var _helmets := {}                       # 騎士 → 他的頭盔節點
var _nothing_said := false               # 家豪說過那句話了
var _napoleon_tex: Texture2D

func _make_items() -> Array:
	return [
		ThunderItem.new().uses(0, -1),
		WindItem.new().uses(0, -1),
	]

## 晚上會閃藍綠色的光的東西：火山、小湖（岩漿掉進去會變成鵝卵石）
func _glow_nodes() -> Array:
	var out: Array = [[world.volcano_node(), true]]
	for pool in world.zone_pools(3):
		if pool.node:
			out.append([pool.node, true])
	return out

func _enemy_specs() -> Array:
	return [
		# 兩個農夫在場地南半邊巡邏，離家豪的起點（北邊石階頂）遠一點：玩家來得及先劈一次火山
		{"name": "農夫1", "hp": FARMER_HP, "kick_damage": FARMER_KICK, "route": [Vector3(2, 0, 6), Vector3(6, 0, 10)], "loop": false, "pause": 1.2},
		{"name": "農夫2", "hp": FARMER_HP, "kick_damage": FARMER_KICK, "route": [Vector3(-2, 0, 5), Vector3(-6, 0, 9)], "loop": false, "pause": 1.0},
		{"name": "農夫3", "hp": FARMER_HP, "kick_damage": FARMER_KICK, "route": [Vector3(-9, 0, 6), Vector3(-7, 0, 11)], "loop": false, "pause": 1.1},
		# 最終 Boss：穿盔甲的騎士。一開始不在場上，農夫都倒下之後才從飛機上跳下來（route 是他的落點：場地南邊、離石階最遠的那塊空地）。
		# 走得慢、打得重，啄他完全沒用，要用岩漿砸，或是等他走進湖裡用雷劈湖
		# is_boss：右上角敵人欄給他自己一張卡（頭像＋名字＋血條），跟其他大關的 Boss 一樣
		{"name": "豪王", "kind": "knight", "is_boss": true, "route": [Vector3(-1.0, 0, 9.5)], "yaw": PI,
			"hp": 16.0, "speed": 1.5, "immune_peck": true, "bar_y": 3.5, "hears_noise": false},
	]

## 盔甲騎士一開始不在場上：一般敵人都倒下之後，一架飛機飛過場地，他從飛機上跳下來，落地之後才開打
## （落地之後就照一般敵人的行為追家豪）。還沒落地之前什麼都碰不到他
func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.kind == "knight" and f.alive() and not f.data.get("landed", false):
		f.aggro = false
		f.kb_vel = Vector3.ZERO
		f.pos = ground(f.start_pos)
		f.yaw = f.start_yaw
		if _drop_t < DROP_AT:
			# 還在飛機上：不在場上，什麼都碰不到他（風、雷、岩漿都沒用；畫面上也藏起來）
			f.air = 60.0
			f.pos = f.start_pos + Vector3(0.0, 0.0, -400.0)
			f.data["hidden"] = true
			return
		f.data["hidden"] = false
		var k := clampf((_drop_t - DROP_AT) / DROP_FALL, 0.0, 1.0)
		f.air = PLANE_H * (1.0 - k * k)        # 越掉越快
		if k >= 1.0:
			f.air = 0.0
			f.data["landed"] = true
			noise_at(f.pos)
			log_event("%s從飛機上跳下來，落地了" % f.name)
			aggro(f)
			if bird.alive():
				f.yaw = atan2(bird.pos.x - f.pos.x, bird.pos.z - f.pos.z)
			_start_boss_cut()
		return
	if f.kind == "knight" and f.alive():
		_tick_knight(f, dt)
		return
	super(f, dt)

# ---------------------------------------------------------------- 騎士登場的特寫

const BOSS_LINES := [
	"真沒想到你可以過這一關，但到此為止了。",
	"接下來就由我豪王來當你的對手。",
	"我這身盔甲可是免疫大部分攻擊。",
	"只是不通風很熱而已...",        # 提示玩家：他怕熱，要用岩漿
]
const BOSS_MIN_LINE := 0.3       # 一句話至少出現幾秒才能按 Enter 換下一句（避免一下按太快跳過兩句）

## 騎士落地：鏡頭拉到他面前，他把話說完才開打（鏡頭原本的位置先記下來）
## 台詞不會自己換：每一句都停在畫面上，按 Enter 才換下一句，最後一句再按 Enter 就開打
func _start_boss_cut() -> void:
	if player == null or _boss_cut >= 0.0:
		return
	_boss_cut = 0.0
	_boss_line = 0
	_boss_next = false
	_boss_back = player.global_transform
	var head := player.get_node_or_null("Head") as Node3D
	_boss_head = head.rotation.x if head else 0.0
	player.set_physics_process(false)

func _end_boss_cut() -> void:
	if _boss_cut < 0.0:
		return
	_boss_cut = -1.0
	_boss_next = false
	if _boss_hint:
		_boss_hint.visible = false
	if _dialog and _dialog.t >= 0.0:
		_dialog.t = maxf(_dialog.t, DialogBox.SHOW_TIME - 0.3)     # 最後一句滑下去收起來
	if player:
		player.global_transform = _boss_back
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation.x = _boss_head
		player.set("velocity", Vector3.ZERO)
		player.set_physics_process(true)

## 每一畫面：鏡頭擺在騎士斜前方、比他矮一點往上看；台詞一句一句說（按 Enter 換下一句），說完鏡頭還給玩家
func _tick_boss_cut() -> void:
	if _boss_cut < 0.0:
		return
	var knight: Fighter = null
	for f in enemies:
		if f.kind == "knight":
			knight = f
	if knight == null or not knight.alive():
		_end_boss_cut()
		return
	_boss_cut += 1.0 / 60.0
	_boss_line_t += 1.0 / 60.0
	var next := _boss_next and _boss_line_t >= BOSS_MIN_LINE
	_boss_next = false          # 太早按的那一下不算，要等這一句出現夠久再按
	if _boss_line == 0 or next:
		if _boss_line >= BOSS_LINES.size():
			_end_boss_cut()     # 最後一句也看完了：開打
			return
		say_as(knight, BOSS_LINES[_boss_line])
		_boss_line += 1
		_boss_line_t = 0.0
	elif _dialog:
		if _dialog.t < 0.0:
			say_as(knight, BOSS_LINES[_boss_line - 1])     # 被別的東西收掉了：再顯示一次
		else:
			_dialog.t = minf(_dialog.t, 0.3)     # 對話框本來 3.2 秒會自己收：滑上來之後就一直停著，等玩家按 Enter
	_tick_boss_hint()
	var fwd := Vector3(sin(knight.yaw), 0.0, cos(knight.yaw))
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	_aim_camera(knight.pos + fwd * 4.4 + side * 1.7 + Vector3(0.0, 1.7, 0.0), knight.pos + Vector3(0.0, 2.1, 0.0))

## 對話框右下角一閃一閃的「Enter ▶」：告訴玩家要按 Enter 才會換下一句
func _tick_boss_hint() -> void:
	if _dialog == null:
		return
	if _boss_hint == null:
		_boss_hint = Label.new()
		_boss_hint.text = "Enter ▶"
		_boss_hint.add_theme_font_size_override("font_size", 20)
		_boss_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		_boss_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03))
		_boss_hint.add_theme_constant_override("outline_size", 6)
		_boss_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dialog.add_child(_boss_hint)
	# 對話框畫在這個 Control 的正中間、上緣，寬 W 高 H（見 scripts/ui/dialog_box.gd）
	_boss_hint.position = Vector2((_dialog.size.x + DialogBox.W) * 0.5 - 100.0, DialogBox.H - 34.0)
	_boss_hint.visible = _boss_line_t >= BOSS_MIN_LINE
	_boss_hint.modulate.a = 0.55 + 0.45 * sin(_boss_cut * 5.0)

## 騎士登場的特寫也算鏡頭被借走：神的手收起來
func _camera_borrowed() -> bool:
	return _boss_cut >= 0.0 or super()

## 騎士登場的特寫播放中：Enter 是「下一句」，不是共用的「開打」
func _unhandled_input(event: InputEvent) -> void:
	if _boss_cut >= 0.0 and event.is_action_pressed("battle_start") and not event.is_echo():
		_boss_next = true
		get_viewport().set_input_as_handled()
		return
	super(event)

## 劈火山的時候烏雲拉得很高（雷道具會問）：不然噴出來的岩漿球會被烏雲擋住
func thunder_cloud_height(p: Vector3) -> float:
	return 34.0 if flat_dist(p, world.volcano_top()) <= VOLCANO_REACH + 2.0 else 13.0

## 落地之後的盔甲騎士：一直朝家豪走過去（走得比家豪慢），走到面前就打他一下。
## 被岩漿燙倒、被電倒的那幾秒交給共用程式處理（倒地 → 爬起來）
func _tick_knight(f: Fighter, dt: float) -> void:
	if f.state in ["down", "getup", "stagger", "startled"]:
		super._tick_enemy(f, dt)
		return
	if _boss_cut >= 0.0:
		anim(f, "Idle")        # 登場的特寫：站著把話說完
		return
	_kn_cd = maxf(_kn_cd - dt, 0.0)
	f.aggro = true
	f.kb_vel = Vector3.ZERO
	if not bird.alive():
		anim(f, "Idle")
		return
	var to := Vector3(bird.pos.x - f.pos.x, 0.0, bird.pos.z - f.pos.z)
	var d := to.length()
	if d > 0.05:
		f.yaw = atan2(to.x, to.z)
	if d > KNIGHT_REACH or bird.air > 1.0:
		if f.state != "walk":
			f.set_state("walk")
		anim(f, "Walk")
		f.pos = ground(world.clamp_play(f.pos + to.normalized() * KNIGHT_SPEED * dt))
	elif _kn_cd <= 0.0 and _bird_mode != 1 and not _fetching():
		_knight_strike(f)        # （家豪正踩著石頭去拿星星的時候不打他）
	else:
		anim(f, "Idle")

## 騎士打中家豪：扣一點血，家豪被打得往後飛一小段，落地之後會逃開一陣子
func _knight_strike(f: Fighter) -> void:
	_kn_cd = KNIGHT_CD
	anim(f, "Kick_Right")
	log_event("%s打中家豪" % f.name)
	hit_bird(KNIGHT_HIT, false, f.pos, f)
	if not bird.alive():
		return
	var away := Vector3(bird.pos.x - f.pos.x, 0.0, bird.pos.z - f.pos.z)
	away = away.normalized() if away.length() > 0.05 else Vector3(sin(f.yaw), 0.0, cos(f.yaw))
	var to: Vector3 = world.clamp_play(bird.pos + away * KNOCK_BACK)
	if world.in_pool(3, to.x, to.z, 0.4, true):
		to = world.clamp_play(bird.pos + away * 1.5)        # 後面是湖：少退一點，不要掉進水裡
	_kn_from = bird.pos
	_kn_to = ground(to)
	_bird_t = 0.0
	_bird_mode = 1
	bird.kb_vel = Vector3.ZERO
	bird.set_state("fly")

## 開場只有一句（每個道具的說明在切換道具時會出現在技能欄上面）
func _tutorial_texts() -> Array:
	return ["用雷劈火山口，岩漿球飛出來之後按住風，把它吹到敵人身上或湖裡。雷和風都不能直接對人用；對著沙地吹風，沙子會讓下風處的敵人看不見。敵人站在湖水裡的時候用雷劈湖，也能把他電倒。"]

## 最後一關過了：整個大關拿到幾顆星星（每一小關三顆：過關、打倒所有敵人、場上那顆星星）
func _win_line() -> String:
	# 打贏最後一關的這一刻，「打倒所有敵人」和「過關」兩顆就都到手了
	mark_goal(3, "foes")
	mark_goal(3, "clear")
	var total: int = world.STAR_TOTAL * 3
	var n := 0
	for k in range(1, world.STAR_TOTAL + 1):
		for id in ["clear", "foes"]:
			n += 1 if goal_done(k, id) else 0
		n += 1 if world.star_taken(k) else 0
	return "過關！星星 %d / %d" % [n, total]

func _prepare_hint() -> String:
	return "準備中：開打後用雷劈火山口，再用風把岩漿塊吹向敵人　按 Enter 開始"

# ---------------------------------------------------------------- 開場、重試

func _level_setup() -> void:
	super()
	_napoleon_tex = _load_tex("res://assets/ui/napoleon.png")
	for f in enemies:
		if f.kind == "knight":
			_armor(f)
	_build_plane()

## 一架小飛機（幾個方塊拼的）：機身、主翼、尾翼、螺旋槳。機頭朝 +z
func _build_plane() -> void:
	_plane = Node3D.new()
	_plane.name = "Plane"
	_plane.visible = false
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.78, 0.22, 0.16)
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.93, 0.88, 0.72)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.14)
	var parts: Array = [
		[Vector3(1.3, 1.3, 5.4), Vector3(0.0, 0.0, 0.0), body],          # 機身
		[Vector3(1.0, 0.9, 1.6), Vector3(0.0, 0.1, -3.2), body],         # 機尾
		[Vector3(10.0, 0.18, 1.7), Vector3(0.0, 0.35, 0.7), cream],      # 主翼
		[Vector3(3.6, 0.14, 1.0), Vector3(0.0, 0.3, -3.5), cream],       # 水平尾翼
		[Vector3(0.16, 1.4, 1.1), Vector3(0.0, 0.95, -3.5), body],       # 垂直尾翼
		[Vector3(1.0, 0.6, 1.2), Vector3(0.0, 0.75, 0.9), dark],         # 駕駛艙
		[Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.0, 2.9), dark],          # 機鼻
	]
	for pt in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pt[0]
		mi.mesh = bm
		mi.material_override = pt[2]
		mi.position = pt[1]
		_plane.add_child(mi)
	var prop := MeshInstance3D.new()
	prop.name = "Prop"
	var pm := BoxMesh.new()
	pm.size = Vector3(3.2, 0.22, 0.1)
	prop.mesh = pm
	prop.material_override = dark
	prop.position = Vector3(0.0, 0.0, 3.25)
	_plane.add_child(prop)
	world.add_child(_plane)

## 飛機往哪邊飛（水平方向）
func _plane_dir() -> Vector3:
	return Vector3(0.12, 0.0, -1.0).normalized()        # 從石階對面（南邊）飛過來，朝石階（北邊）飛過去；不經過火山上面

## 騎士的落點
func _drop_spot() -> Vector3:
	for f in enemies:
		if f.kind == "knight":
			return ground(f.start_pos)
	return Vector3.ZERO

## 一般敵人都倒下了：飛機飛過來（騎士在 _tick_enemy 裡跟著跳下來）。這時候也記下「打到騎士這一段了」
func _step_plane(dt: float) -> void:
	# 從騎士這一段重來：農夫一直是倒下的（共用程式開打的時候會把所有人叫起來，這裡再讓他們躺回去）
	if _boss_phase:
		for f in enemies:
			if f.kind != "knight" and (f.alive() or f.hp > 0.0) and f.data.get("cp_gone", _skip_farmers):
				f.hp = 0.0
				f.set_state("dead")
				f.data["cp_gone"] = true
	if phase == Phase.RUNNING and _drop_t < 0.0:
		var farmers := enemies.any(func(e): return e.alive() and e.kind != "knight")
		var knight := enemies.any(func(e): return e.alive() and e.kind == "knight")
		if not farmers and knight:
			_drop_t = 0.0
			_boss_phase = true
			log_event("一架飛機飛過來了")
	if _drop_t >= 0.0:
		_drop_t += dt

## 把農夫的模型變成盔甲騎士：整個人放大、全身換成深色的鋼鐵，外面再套上頭盔（有紅色羽飾）、胸甲、肩甲和裙甲。
## 盔甲是另外做的幾塊零件，每一畫面跟著騎士的位置和方向走（見 _level_visuals）
func _armor(f: Fighter) -> void:
	f.node.scale *= KNIGHT_SCALE
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.30, 0.33, 0.40)
	steel.metallic = 0.25
	steel.roughness = 0.55
	var plate := StandardMaterial3D.new()        # 外面那幾塊盔甲亮一點，跟身體分得開
	plate.albedo_color = Color(0.52, 0.56, 0.66)
	plate.metallic = 0.3
	plate.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.07, 0.09)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.82, 0.12, 0.12)
	var todo: Array = [f.node]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = steel
		for c in n.get_children():
			todo.append(c)
	# 量模型實際多高（放大之後），盔甲各部位照身高的比例擺，才會剛好套在頭、肩膀、胸口上
	var top_y := 0.0
	var scan: Array = [f.node]
	while not scan.is_empty():
		var sn: Node = scan.pop_back()
		if sn is VisualInstance3D and (sn as Node3D).is_inside_tree():
			var bx: AABB = (sn as VisualInstance3D).global_transform * (sn as VisualInstance3D).get_aabb()
			top_y = maxf(top_y, bx.end.y - f.node.global_position.y)
		for c in sn.get_children():
			scan.append(c)
	var tall: float = top_y if top_y > 1.0 else 3.1        # 量不到就用大概的身高
	var k: float = tall / 3.1                               # 零件的大小是照 3.1 公尺高的人做的
	var set := Node3D.new()
	set.name = "KnightArmor"
	# 每一塊：[形狀, 大小, 位置（y 是身高的幾成；騎士腳下為原點，+z 是他面對的方向）, 材質]
	var parts: Array = [
		["sphere", Vector3(0.46, 0.46, 0.48), Vector3(0.0, 0.895, 0.02), plate],       # 頭盔（把帽子也包進去）
		["box", Vector3(0.56, 0.10, 0.20), Vector3(0.0, 0.875, 0.40), dark],            # 眼縫
		["box", Vector3(0.10, 0.44, 0.62), Vector3(0.0, 1.06, -0.05), red],             # 羽飾
		["box", Vector3(0.78, 0.74, 0.50), Vector3(0.0, 0.64, 0.0), plate],             # 胸甲
		["sphere", Vector3(0.25, 0.20, 0.25), Vector3(-0.48, 0.755, 0.0), plate],       # 左肩甲
		["sphere", Vector3(0.25, 0.20, 0.25), Vector3(0.48, 0.755, 0.0), plate],        # 右肩甲
		["box", Vector3(0.70, 0.30, 0.46), Vector3(0.0, 0.445, 0.0), steel],            # 裙甲
		["box", Vector3(0.20, 0.10, 0.52), Vector3(0.0, 0.66, 0.02), red],              # 胸前一道紅色的紋
	]
	for pt in parts:
		var mi := MeshInstance3D.new()
		if pt[0] == "sphere":
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 10
			sm.rings = 5
			mi.mesh = sm
			mi.scale = (pt[1] as Vector3) * k
		else:
			var bm := BoxMesh.new()
			bm.size = (pt[1] as Vector3) * k
			mi.mesh = bm
		mi.material_override = pt[3]
		var at: Vector3 = pt[2]
		mi.position = Vector3(at.x * k, at.y * tall, at.z * k)
		set.add_child(mi)
	world.add_child(set)
	_helmets[f] = set

func _level_reset() -> void:
	super()
	_bombs.clear()        # 節點掛在 fx_root 底下，重試時會自動刪掉
	_pools.clear()
	_fills.clear()
	_stones.clear()       # 鵝卵石也掛在 fx_root 底下
	_bridge.clear()
	_wind_t = 0.0
	_nothing_said = false
	_end_boss_cut()
	_kn_cd = 0.0
	_bird_mode = 0
	_pecked = false
	_drop_t = -1.0
	# 已經打到騎士那一段的話，重來不用重打農夫：他們直接算倒下了，一開打飛機就來
	_skip_farmers = _boss_phase
	if _boss_phase:
		for f in enemies:
			if f.kind != "knight":
				f.hp = 0.0
				f.set_state("dead")
				f.data["cp_gone"] = true

# ---------------------------------------------------------------- 火山：雷劈才噴、風決定往哪飄

## 雷劈下來（雷道具會叫這個）：劈進火山口的岩漿，噴出一顆岩漿球
func on_thunder(p: Vector3) -> void:
	_shock_lake(p)
	var vt: Vector3 = world.volcano_top()
	if flat_dist(p, vt) > VOLCANO_REACH:
		return
	for up in BOMB_UP:
		var node := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = BOMB_SIZE
		sm.height = BOMB_SIZE * 2.0
		sm.radial_segments = 10
		sm.rings = 5
		node.mesh = sm
		node.material_override = world.lava_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(node)
		# 地上一個紅色的圈：這一塊現在掉下去會落在哪（正下方）
		var mark := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = BOMB_RADIUS
		cm.bottom_radius = BOMB_RADIUS
		cm.height = 0.05
		cm.radial_segments = 20
		mark.mesh = cm
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_color = MARK_RED
		mark.material_override = mm
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mark)
		_bombs.append({"pos": vt + Vector3(0.0, 0.6, 0.0), "vel": Vector3(0.0, float(up), 0.0), "t": 0.0, "node": node, "mark": mark})
	log_event("雷劈進火山口，噴出岩漿塊")

## 雷劈在湖上：水會導電，站在湖水裡的人直接被電倒，盔甲騎士也一樣
func _shock_lake(p: Vector3) -> void:
	if not world.in_pool(3, p.x, p.z, 0.8, true):
		return
	pool_sparks(3, p)        # 水面爬滿白色的小電光：看得出雷劈在水上跟劈在地上不一樣
	var n := 0
	for f in enemies:
		if not f.alive() or f.data.get("hidden", false) or f.air > 0.5 or not world.in_pool(3, f.pos.x, f.pos.z):
			continue
		if f.kind == "knight" and not _knight_can_hurt(f):
			continue        # 還躺在水裡沒爬起來：這一下不算
		n += 1
		f.data.erase("blind_t")
		f.kb_vel = Vector3.ZERO
		anim(f, "Death")
		# 水會導電：站在湖水裡的人直接被電倒。盔甲騎士也一樣（盔甲是鐵的，電得更兇）——
		# 所以打倒他有兩種方法：用岩漿球砸，或是把他引進湖裡再用雷劈湖。
		# 騎士要挨 KNIGHT_HITS 下才會倒（岩漿和電可以混著算），沒倒的話躺幾秒會再爬起來
		f.hp = _knight_hp_after(f) if f.kind == "knight" else 0.0
		f.heavy = false
		f.set_state("dead" if f.hp <= 0.0 else "down")
		log_event("%s在湖裡被電倒了（剩 %d）" % [f.name, ceili(f.hp)])
	if n == 0:
		log_event("雷劈在湖上，水裡沒有人")

## 風吹過來（按住吹的每一步，風道具會叫這個）：記下風向，飛在空中的岩漿塊會順著飄
func on_wind(_p: Vector3, dir: Vector3, _dt: float) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.05:
		return
	_wind_dir = d.normalized()
	_wind_t = WIND_KEEP

func _level_step(dt: float) -> void:
	super(dt)
	_step_plane(dt)
	_step_volcano(dt)
	# 鵝卵石接到小島了：沒有敵人在追家豪的時候，他會踩著石頭走過去撿（正在打架就先打完，過關後一樣會去撿）
	if _star_going():
		if _fetch_star(dt, true) and bird.state != "charge":
			bird.set_state("charge")
		if _bird_mode == 0:
			_pecked = false
	else:
		_flee_knight(dt)
	_keep_out_of_lake()        # 放在最後：不管是打架、逃跑還是被打飛，家豪都不會踩進湖裡

func _level_step_ended(dt: float) -> void:
	super(dt)
	_step_volcano(dt)
	_keep_out_of_lake()
	if _won():
		_fetch_star(dt, true)        # 過關之後石頭才接起來（或還沒撿）：家豪一樣會走過去撿

## 現在是不是該去撿星星：石頭路接上了、還沒撿、家豪不在飛，而且沒有農夫正在追他（騎士不算）
## （已經走到一半就繼續走完，不會因為半路被發現又折回去）
func _star_going() -> bool:
	if not bird.alive() or bird.state == "fly":
		return false
	# 已經出發了（走過去、播拿到的小過場、走回來）就一路做完。這個要先看：
	# 星星一拿到 _star_done 就是 true 了，如果先看它，走回岸上的那一段會被跳過，家豪就卡在湖心的小島上
	if _fetching():
		return true
	if not _star_ready() or _star_done:
		return false
	# 只剩騎士的時候不用管他（反正打不動）：石頭路一接上就直接去拿
	return not enemies.any(func(f): return f.alive() and f.aggro and f.kind != "knight")

## 家豪不會去啄騎士（啄不動）；去撿星星的時候也不找敵人打架
func nearest_enemy(from: Vector3) -> Fighter:
	if _star_going():
		return null
	var best: Fighter = null
	var bd := INF
	for f in enemies:
		if f.alive() and f.kind != "knight":
			var d := flat_dist(from, f.pos)
			if d < bd:
				bd = d
				best = f
	return best

## 只剩騎士的時候：家豪打不動他，說完那句話之後就一直躲著他跑（騎士走得比他慢），
## 玩家趁這段時間把岩漿球引到騎士身上
func _flee_knight(dt: float) -> void:
	if phase != Phase.RUNNING or not bird.alive():
		return
	var knight: Fighter = null
	for f in enemies:
		if f.alive():
			if f.kind != "knight":
				return        # 還有別的敵人：照常打
			knight = f
	if knight == null or not knight.data.get("landed", false):
		if bird.state != "linger" and bird.state != "fly":
			bird.set_state("linger")        # 騎士還沒落地：家豪站著東張西望
		return
	if _boss_cut >= 0.0:
		if bird.state != "linger" and bird.state != "fly":
			bird.set_state("linger")        # 騎士登場的特寫：家豪先站著看
		return
	match _bird_mode:
		0:
			# 衝過去啄他一下（完全沒用）；啄完就站在他面前，等著被他打飛
			if bird.state == "fly":
				return
			var to := Vector3(knight.pos.x - bird.pos.x, 0.0, knight.pos.z - bird.pos.z)
			if to.length() > PECK_REACH:
				if bird.state != "charge":
					bird.set_state("charge")
				var d := to.normalized()
				bird.pos = ground(world.clamp_play(bird.pos + d * PECK_SPEED * dt))
				bird.yaw = atan2(d.x, d.z)
			elif not _pecked:
				_pecked = true
				bird.yaw = atan2(to.x, to.z)
				log_event("家豪啄了%s一下，完全沒用" % knight.name)
				if not _nothing_said:
					_nothing_said = true
					say("THERE IS NOTHING I CAN DO", _napoleon_tex)
		1:
			# 被打飛：往後飛一小段
			_bird_t = minf(_bird_t + dt / KNOCK_TIME, 1.0)
			bird.pos = ground(_kn_from.lerp(_kn_to, _bird_t))
			bird.air = sin(_bird_t * PI) * KNOCK_PEAK
			if _bird_t >= 1.0:
				bird.air = 0.0
				_bird_mode = 2
				_bird_t = FLEE_TIME
				_pecked = false
		2:
			# 逃開一陣子，然後再回去啄
			_bird_t -= dt
			if _bird_t <= 0.0:
				_bird_mode = 0
				return
			if flat_dist(bird.pos, knight.pos) > FLEE_NEAR:
				if bird.state != "linger":
					bird.set_state("linger")
				return
			# 往離騎士最遠的方向跑：試 16 個方向，看往那邊跑 3 公尺之後離騎士多遠（撞到場地邊、湖邊的方向不選），
			# 靠邊的時候就會沿著邊繞開，不會傻傻地被堵在角落
			var best_d := Vector3.ZERO
			var score := -INF
			for i in 16:
				var a := TAU * float(i) / 16.0
				var dd := Vector3(cos(a), 0.0, sin(a))
				var q: Vector3 = world.clamp_play(bird.pos + dd * 3.0)
				if world.in_pool(3, q.x, q.z, 0.6, true):
					continue
				var sc: float = flat_dist(q, knight.pos) + flat_dist(q, bird.pos) * 0.5 + dd.dot(_flee_dir) * 0.8
				if sc > score:
					score = sc
					best_d = dd
			if bird.state != "charge":
				bird.set_state("charge")
			if best_d.length() > 0.5:
				_flee_dir = best_d
				bird.pos = ground(world.clamp_play(bird.pos + best_d * FLEE_SPEED * dt))
				bird.yaw = atan2(best_d.x, best_d.z)

## 家豪現在是不是正踩著石頭去拿星星（或正在播拿到星星的小過場）
func _fetching() -> bool:
	return _star_stage == 1 or _star_stage == 2 or _cut_t > 0.0

## 家豪進不了湖：走到水邊會被擋住，被打飛也不會掉進去。只有踩著鵝卵石去拿星星那一段可以過去
func _keep_out_of_lake() -> void:
	_keep_bird_dry(3, 1.0 / 60.0)

## 被湖擋住的時候往哪邊繞：有在追的農夫就朝他；只剩騎士的時候，衝過去啄就朝騎士、逃開就照逃的方向
func _bird_goal() -> Variant:
	var g = super()
	if g != null:
		return g
	for f in enemies:
		if f.kind == "knight" and f.alive() and f.data.get("landed", false):
			if _bird_mode == 0:
				return f.pos
			if _bird_mode == 2 and _flee_dir.length() > 0.5:
				return bird.pos + _flee_dir * 6.0
	return null

func _lake_center() -> Vector3:
	return world.zone_pools(3)[0].center

func _step_volcano(dt: float) -> void:
	if _wind_t > 0.0:
		_wind_t -= dt
	for i in range(_bombs.size() - 1, -1, -1):
		var b: Dictionary = _bombs[i]
		b.t += dt
		var vel: Vector3 = b.vel
		# 風吹著的時候被托住：掉得慢很多（往下最快只有 WIND_FALL），玩家有時間把它送到想要的地方
		# （只在往下掉的時候托住：往上衝的那一段照常，不然一開始就吹風會越飛越高、落不下來）
		if _wind_t > 0.0 and vel.y <= 0.0:
			vel.y -= BOMB_GRAVITY * WIND_LIFT * dt
			if vel.y < -WIND_FALL:
				vel.y = move_toward(vel.y, -WIND_FALL, 8.0 * dt)
		elif vel.y <= 0.0:
			vel.y -= BOMB_FAST * dt        # 沒吹風：掉得很快
		else:
			vel.y -= BOMB_GRAVITY * dt
		var flat := Vector3(vel.x, 0.0, vel.z)
		if _wind_t > 0.0:
			flat = flat.move_toward(_wind_dir * BOMB_SPEED, BOMB_ACCEL * dt)
		else:
			flat = flat.move_toward(Vector3.ZERO, BOMB_DRAG * dt)
		vel = Vector3(flat.x, vel.y, flat.z)
		b.vel = vel
		b.pos = (b.pos as Vector3) + vel * dt
		var p: Vector3 = b.pos
		var gy: float = world.height_at(p.x, p.z)
		var landed: bool = vel.y < 0.0 and p.y <= gy + 0.4
		if not landed and b.t < BOMB_LIFE:
			continue
		_bombs.remove_at(i)
		for n in [b.node, b.mark]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		if landed:
			_land(Vector3(p.x, gy, p.z))
	for i in range(_pools.size() - 1, -1, -1):
		var pl: Dictionary = _pools[i]
		pl.t += dt
		if pl.t >= POOL_TIME:
			_pools.remove_at(i)
			if is_instance_valid(pl.node):
				(pl.node as Node).queue_free()

## 盔甲騎士要挨幾下（岩漿砸到或在湖裡被電到，都算一下）才會倒
const KNIGHT_HITS := 2

## 騎士再挨一下之後剩多少血（每一下扣掉全部血量的 1 / KNIGHT_HITS）
func _knight_hp_after(f: Fighter) -> float:
	var left := f.hp - f.max_hp / float(KNIGHT_HITS)
	return 0.0 if left < 0.01 else left

## 騎士現在挨不挨得到：躺在地上、正在爬起來的那幾秒不算（不然連劈兩下湖就等於一下打倒）
func _knight_can_hurt(f: Fighter) -> bool:
	return not (f.state in ["down", "getup"])

## 一顆岩漿球落地：附近的人被燙到；掉在地上留一灘岩漿，掉進湖水裡就凝固成一堆鵝卵石
func _land(at: Vector3) -> void:
	noise_at(at)
	var n := 0
	for f in enemies:
		if f.alive() and f.air < 0.5 and flat_dist(f.pos, at) <= BOMB_RADIUS:
			if f.kind == "knight" and not _knight_can_hurt(f):
				continue        # 還躺在地上：這一下不算
			# 盔甲騎士（Boss）：被岩漿球打中 KNIGHT_HITS 次才倒；其他人照 BOMB_DAMAGE 扣
			f.hp = _knight_hp_after(f) if f.kind == "knight" else maxf(f.hp - BOMB_DAMAGE, 0.0)
			f.data.erase("blind_t")
			aggro(f)
			f.heavy = false
			var away: Vector3 = f.pos - at
			away.y = 0.0
			f.kb_vel = (away.normalized() if away.length() > 0.01 else Vector3.RIGHT) * 3.0
			anim(f, "Death")
			f.set_state("dead" if f.hp <= 0.0 else "down")
			log_event("岩漿燙到%s（剩 %d）" % [f.name, ceili(f.hp)])
			n += 1
	if bird.alive() and bird.air < 0.5 and flat_dist(bird.pos, at) <= BOMB_RADIUS:
		log_event("岩漿燙到家豪")
		hit_bird(minf(BOMB_BIRD_DAMAGE, maxf(bird.hp - 1.0, 0.0)), true, at)
	if _over_water(at):
		_make_stone(_into_water(at))
		return
	if n == 0:
		log_event("岩漿落在地上，沒燙到人")
	var pool := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = BOMB_RADIUS * 0.8
	cm.bottom_radius = BOMB_RADIUS * 0.8
	cm.height = 0.1
	cm.radial_segments = 14
	pool.mesh = cm
	var m: ShaderMaterial = world.lava_material()
	pool.material_override = m
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = at + Vector3(0.0, 0.12, 0.0)
	fx_root.add_child(pool)
	_pools.append({"t": 0.0, "node": pool, "mat": m})

# ---------------------------------------------------------------- 湖裡的鵝卵石、第三顆星星

## 岩漿球掉在這裡算不算碰到湖水：放寬到岸邊外面一點（球很大，擦到水就算），中間的小島周圍也算
func _over_water(p: Vector3) -> bool:
	return world.in_pool(3, p.x, p.z, WATER_REACH, true)

## 落點在岸上但擦到水：把石頭堆的位置往湖心挪到水裡，才不會埋在岸邊的土裡
func _into_water(p: Vector3) -> Vector3:
	var c := _lake_center()
	var q := p
	for i in 24:
		if world.in_pool(3, q.x, q.z, 0.0, true):
			break
		var d := c - q
		d.y = 0.0
		if d.length() < 0.1:
			break
		q += d.normalized() * 0.1
	return q

## 岩漿球現在掉下去會不會燙到敵人（正下方那一圈裡有沒有人）
func _over_enemy(p: Vector3) -> bool:
	for f in enemies:
		if f.alive() and not f.data.get("hidden", false) and flat_dist(f.pos, p) <= BOMB_RADIUS:
			return true
	return false

## 湖面的高度
func _lake_y() -> float:
	var list: Array = world.ZONE_POOLS[2]
	return world.pool_water_y(2, list[0])

## 岩漿掉進湖裡：凝固成一堆圓圓的鵝卵石，露出水面，可以踩
func _make_stone(at: Vector3) -> void:
	var top := _lake_y() + STONE_TOP
	var node := Node3D.new()
	var r := RandomNumberGenerator.new()
	r.seed = 9000 + _stones.size() * 31
	# 跟島上一般的石頭同一種材質，但把上面金黃色的落葉斑點拿掉（剛凝固的石頭上不會有落葉）
	var mat: ShaderMaterial = (world._cliff_material() as ShaderMaterial).duplicate()
	for key in ["leaf_a", "leaf_b", "night_leaf_a", "night_leaf_b"]:
		mat.set_shader_parameter(key, Color(0.40, 0.33, 0.35))
	# 稜角分明的石塊（不是圓球）：邊數很少的球壓扁、歪一邊，每一塊大小和角度都不一樣
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 5
	sm.rings = 2
	# 中間一塊大的，外面圍一圈小一點的
	var spots: Array = [[Vector2.ZERO, STONE_R * 0.6]]
	for i in 8:
		var a := TAU * float(i) / 8.0 + r.randf_range(-0.25, 0.25)
		spots.append([Vector2(cos(a), sin(a)) * STONE_R * r.randf_range(0.5, 0.7), STONE_R * r.randf_range(0.3, 0.46)])
	for sp in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		var rad: float = sp[1]
		var bs := Basis.from_euler(Vector3(r.randf_range(-0.22, 0.22), r.randf() * TAU, r.randf_range(-0.22, 0.22)))
		mi.transform = Transform3D(bs.scaled(Vector3(rad * r.randf_range(0.85, 1.25), r.randf_range(0.34, 0.5), rad * r.randf_range(0.8, 1.15))), Vector3(sp[0].x, -0.22 + r.randf_range(-0.05, 0.05), sp[0].y))
		node.add_child(mi)
	fx_root.add_child(node)
	node.global_position = Vector3(at.x, top, at.z)
	# 一團白色的水蒸氣
	if world.has_method("make_smoke"):
		var steam: CPUParticles3D = world.make_smoke(Vector3(at.x, top + 0.3, at.z))
		steam.color = Color(0.95, 0.95, 0.95, 0.7)
		steam.one_shot = true
		steam.emitting = true
		if steam.get_parent():
			steam.get_parent().remove_child(steam)
		fx_root.add_child(steam)
	_stones.append({"pos": Vector3(at.x, top, at.z), "node": node})
	log_event("岩漿掉進湖裡，凝固成鵝卵石")
	var was := _bridge.is_empty()
	_find_bridge()
	if was and not _bridge.is_empty():
		log_event("鵝卵石接到湖中間的小島了")

## 找一條路：岸邊 → 一顆接一顆的鵝卵石 → 小島。找到就記在 _bridge（y 是腳要踩的高度）
func _find_bridge() -> void:
	_bridge.clear()
	var c := _lake_center()
	var isle_r: float = world.ZONE_POOLS[2][0].isle
	# 每一堆石頭：碰不碰得到岸（岸上那一點記下來）、碰不碰得到小島
	var shore: Array = []
	var isle: Array = []
	for st in _stones:
		var p: Vector3 = st.pos
		var sp = null
		# 從石頭邊緣往外一圈一圈找岸：差一點點（LINK_GAP 以內）也算碰得到，挑最近的那一圈
		for ring in 5:
			var rr: float = STONE_R + 0.9 + LINK_GAP * float(ring) / 4.0
			for i in 16:
				var a := TAU * float(i) / 16.0
				var q := Vector3(p.x + cos(a) * rr, 0.0, p.z + sin(a) * rr)
				if not world.in_pool(3, q.x, q.z, 0.3, true) and world.walkable(q.x, q.z):
					if sp == null or flat_dist(q, c) < flat_dist(sp, c):
						sp = q
			if sp != null:
				break
		shore.append(sp)
		isle.append(flat_dist(p, c) - STONE_R <= isle_r + 0.35 + LINK_GAP)
	# 從碰得到岸的石頭開始往外找，直到碰得到小島的石頭
	var prev := {}
	var todo: Array = []
	for i in _stones.size():
		if shore[i] != null:
			prev[i] = -1
			todo.append(i)
	var goal := -1
	while not todo.is_empty():
		var i: int = todo.pop_front()
		if isle[i]:
			goal = i
			break
		for j in _stones.size():
			if not prev.has(j) and flat_dist(_stones[i].pos, _stones[j].pos) <= STONE_R * 2.0 - 0.4 + LINK_GAP:
				prev[j] = i
				todo.append(j)
	if goal < 0:
		return
	var chain: Array = []
	var k := goal
	while k >= 0:
		chain.push_front(k)
		k = prev[k]
	var first: Vector3 = shore[chain[0]]
	_bridge.append(ground(first))
	for i in chain:
		_bridge.append(_stones[i].pos)
	_bridge.append(ground(c))
	_fill_gaps()

## 橋接起來了：路上還泡在水裡、沒有石頭的空隙補上小石頭，看起來是一整條連起來的路
func _fill_gaps() -> void:
	var top := _lake_y() + STONE_TOP
	for i in _bridge.size() - 1:
		var a: Vector3 = _bridge[i]
		var b: Vector3 = _bridge[i + 1]
		var steps := int(ceil(flat_dist(a, b) / 0.9))
		for k in range(1, steps):
			var q: Vector3 = a.lerp(b, float(k) / float(steps))
			if not world.in_pool(3, q.x, q.z, 0.3):
				continue        # 已經是岸上或小島上
			var covered := false
			for st in _stones:
				if flat_dist(st.pos, q) <= STONE_R * 0.75:
					covered = true
			for fp in _fills:
				if flat_dist(fp, q) <= 0.8:
					covered = true
			if covered:
				continue
			_fills.append(q)
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 5
			sm.rings = 2
			mi.mesh = sm
			var mat: ShaderMaterial = (world._cliff_material() as ShaderMaterial).duplicate()
			for key in ["leaf_a", "leaf_b", "night_leaf_a", "night_leaf_b"]:
				mat.set_shader_parameter(key, Color(0.40, 0.33, 0.35))
			mi.material_override = mat
			var r := RandomNumberGenerator.new()
			r.seed = 7000 + _fills.size() * 17
			var bs := Basis.from_euler(Vector3(r.randf_range(-0.2, 0.2), r.randf() * TAU, r.randf_range(-0.2, 0.2)))
			mi.transform = Transform3D(bs.scaled(Vector3(r.randf_range(1.0, 1.3), r.randf_range(0.34, 0.46), r.randf_range(1.0, 1.3))), Vector3.ZERO)
			fx_root.add_child(mi)
			mi.global_position = Vector3(q.x, top - 0.22, q.z)

## 鵝卵石接到小島之後才拿得到星星
func _star_ready() -> bool:
	return not _bridge.is_empty()

func _star_pos() -> Vector3:
	return ground(_lake_center())

func _star_path() -> Array[Vector3]:
	return _bridge.duplicate()

func _star_back() -> Array[Vector3]:
	var p := _bridge.duplicate()
	p.reverse()
	return p.slice(1)

# ---------------------------------------------------------------- 瞄準、畫面

## 火山可以用雷劈（準心指在它身上就算指到）。只有手上拿著雷的時候才算：
## 拿著風的時候如果也算，視線只要經過火山附近（半徑 6 公尺、高 11 公尺的範圍，岩漿球剛噴出來就在這裡），
## 準心就會被吸到火山腳下，風變成「朝火山吹」，岩漿球就往回飛。
func _aim_targets() -> Array:
	if selected < 0 or selected >= items.size() or items[selected].id != "thunder":
		return []
	var vt: Vector3 = world.volcano_top()
	return [{"pos": vt - Vector3(0.0, 9.0, 0.0), "h": 11.0, "r": 6.0}]

## 岩漿球和地上的落點圈跟著位置走、地上的岩漿慢慢冷掉、騎士的頭盔跟著他；
## 拿著雷、準心指到火山的時候，火山變淺白色
## 紙片風格的血條（跟人類要塞右上角 Boss 卡上的那一條同一種畫法）：米色底、紅色的血、深色外框；
## 剛被扣掉的那一段先變淺黃色，再慢慢縮掉
class PaperBar extends Control:
	var fill := Color("e2483d")
	var ratio := 1.0
	var chip := 1.0

	func set_values(r: float, c: float) -> void:
		if absf(r - ratio) > 0.001 or absf(c - chip) > 0.001:
			ratio = r
			chip = c
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := int(size.y * 0.5)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("e9dcc0")
		bg.set_corner_radius_all(rad)
		bg.anti_aliasing = true
		draw_style_box(bg, r)
		var inner := r.grow(-3.0)
		for part in [[chip, Color(1, 0.93, 0.7)], [ratio, fill]]:
			var w: float = inner.size.x * clampf(part[0], 0.0, 1.0)
			if w <= 0.5:
				continue
			var sb := StyleBoxFlat.new()
			sb.bg_color = part[1]
			sb.set_corner_radius_all(int(inner.size.y * 0.5))
			sb.anti_aliasing = true
			draw_style_box(sb, Rect2(inner.position, Vector2(maxf(w, inner.size.y), inner.size.y)))
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.border_color = UIStyle.INK
		edge.set_border_width_all(2)
		edge.set_corner_radius_all(rad)
		edge.anti_aliasing = true
		draw_style_box(edge, r)

var _boss_bar: PaperBar
var _boss_card: Control        # 右上角豪王那一整張卡（他從飛機上跳下來之後才出現）

## 右上角豪王那張卡：名字底下加一條血條（共用的敵人欄只畫頭像和名字）
func _tick_boss_bar() -> void:
	var knight: Fighter = null
	for f in enemies:
		if f.kind == "knight":
			knight = f
	if knight == null:
		return
	if _boss_bar == null:
		for row in _enemy_rows:
			if row.fighter != knight:
				continue
			# 卡片裡原本是「頭像｜名字」：把名字換成「名字在上、血條在下」
			var holder := (row.face as Control).get_parent().get_parent() as BoxContainer
			var nm := holder.get_child(holder.get_child_count() - 1) as Label
			if holder == null or nm == null:
				return
			var info := VBoxContainer.new()
			info.alignment = BoxContainer.ALIGNMENT_CENTER
			info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(info)
			nm.reparent(info)
			_boss_bar = PaperBar.new()
			_boss_bar.custom_minimum_size = Vector2(170, 16)
			_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.add_child(_boss_bar)
			_boss_card = holder.get_parent() as Control
		if _boss_bar == null:
			return
	# 豪王還沒登場（還在飛機上、或是農夫還沒打完）的時候，右上角不先露出他的卡
	if _boss_card:
		_boss_card.visible = phase != Phase.PREPARE and (knight.data.get("landed", false) or _drop_t >= DROP_AT)
	_boss_bar.set_values(knight.ratio() if knight.alive() else 0.0, knight.chip)

func _level_visuals() -> void:
	_tick_boss_bar()
	super()
	if not world.has_method("volcano_set"):
		return
	world.volcano_set(1.0)        # 岩漿一直是滿的，等雷來劈
	for b in _bombs:
		var p: Vector3 = b.pos
		if is_instance_valid(b.node):
			(b.node as Node3D).global_position = p
		if is_instance_valid(b.mark):
			var my: float = world.height_at(p.x, p.z)
			var wet := _over_water(p)
			if wet:
				my = maxf(my, _lake_y())
			(b.mark as Node3D).global_position = Vector3(p.x, my + 0.15, p.z)
			# 底下是湖水（會變成石頭）或是有敵人（會燙到）：圈變綠色，不然是紅色
			var mat := (b.mark as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color = MARK_GREEN if wet or _over_enemy(p) else MARK_RED
	for pl in _pools:
		(pl.mat as ShaderMaterial).set_shader_parameter("heat", clampf(1.0 - pl.t / POOL_TIME, 0.0, 1.0))
	_tick_boss_cut()
	# 飛機：沿著一條直線飛過場地（飛到落點正上方的時候騎士跳出來），螺旋槳一直轉
	if _plane:
		var flying: bool = _drop_t >= 0.0 and _drop_t <= PLANE_TIME
		_plane.visible = flying
		if flying:
			var d := _plane_dir()
			var spot := _drop_spot()
			var pp: Vector3 = spot + d * PLANE_SPEED * (_drop_t - DROP_AT) + Vector3(0.0, PLANE_H + 1.6, 0.0)
			_plane.global_transform = Transform3D(Basis.looking_at(-d, Vector3.UP), pp)
			(_plane.get_node("Prop") as Node3D).rotation.z = _drop_t * 40.0
	# 重來之後直接算倒下的農夫、還在飛機上的騎士：畫面上都藏起來
	for f in enemies:
		if f.kind == "knight":
			# 還沒從飛機上跳下來（包含開打之前）：不在場上
			f.data["hidden"] = f.alive() and not f.data.get("landed", false) and _drop_t < DROP_AT
			f.node.visible = not f.data["hidden"] and (f.alive() or f.node.visible)
		elif f.data.get("cp_gone", false) or _skip_farmers:
			f.node.visible = false
		elif phase == Phase.PREPARE:
			f.node.visible = true
	# 騎士的盔甲：套在身上、跟著他走和轉；倒下或還沒跳下來就不見
	for f in _helmets:
		var helm: Node3D = _helmets[f]
		helm.visible = f.alive() and not f.data.get("hidden", false)
		# 騎士被燙倒、電倒的時候，盔甲跟著他一起往後倒在地上；爬起來的時候再立起來
		var lie: float = float(f.data.get("lie", 0.0))
		lie = move_toward(lie, 1.0 if f.state == "down" else 0.0, (1.0 / 60.0) / 0.35)
		f.data["lie"] = lie
		var yb := Basis(Vector3.UP, f.yaw)
		helm.global_transform = Transform3D(yb * Basis(Vector3.RIGHT, -PI * 0.5 * lie), f.pos + Vector3(0.0, f.air + 0.25 * lie, 0.0))
	var p2 := _aim_p()
	# 準備階段（還沒按 Enter）也會變白
	var can: bool = not _leaving and selected >= 0 and selected < items.size() and items[selected].id == "thunder"
	world.set_highlight(world.volcano_node(), can and flat_dist(p2, world.volcano_top()) <= VOLCANO_REACH)
	# 拿著雷指到湖，湖面也變淺白色
	for pool in world.zone_pools(3):
		if pool.node:
			world.set_highlight(pool.node, can and world.in_pool(3, p2.x, p2.z, 0.8, true))
