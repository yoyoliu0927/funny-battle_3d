extends "res://levels/heaven/heaven_battle.gd"
## 【丹穴山 3 天門】壓軸（2026-11-20 第三版，見規格第 14 節）：五個人、只有兩片香蕉皮，陸吾只有一口氣。
## 兩串連鎖互相牽制——陸吾那一口氣給誰，決定阿水要早一點還是晚一點從畫門衝出來。
##
## 連鎖一（畫門）：阿水第一段的延長線通到畫門甲，從畫門乙衝出來沿著北邊那條線往東，撞上守衛、一起進星洞甲。
##   大老闆（不怕滑）從北邊走下來，開打後大約 2.3 秒才走到那條線旁邊，走一小段又離開、自己走向金光。
##   香蕉皮放阿水第一段的**後半**：阿水出來時大老闆剛好踏上那條線，連大老闆一起撞進星洞甲。
##   放**前半**：阿水出來得早，只撞到守衛；大老闆繼續走，自己走進金光（陸吾還沒吹氣的話就被吹走）。
## 連鎖二（交叉，要對時機）：阿土的滑行線穿過阿金的紅線，阿土滑到交叉點時阿金要剛好走到（按 Tab 看秒數）。
##   放阿土第二段 → 兩人一起滑進金光（陸吾那口氣用掉了）；放第一段後半 → 兩人進星洞乙（陸吾還沒吹氣）。
## 三種過法：
##   甲　阿水後半＋阿土第二段＋唱盤飼料：陸吾一口氣吹走阿土和阿金，大老闆被阿水撞進星洞（第二顆星）
##   乙　阿水後半＋阿土第一段＋唱盤飼料＋繞路飼料：五個人都進星洞，陸吾整局沒吹氣（只有第一顆星）
##   丙　阿水前半＋阿土第一段＋唱盤飼料＋繞路飼料：大老闆自己走進金光被吹走（第三顆星）
## 走不通的：阿水前半＋阿土第二段（陸吾那口氣用掉了，沒被撞到的大老闆走過去抓人）；
##           阿水第二段（被陸吾吹走：第 2 關的做法，這一關沒有人去撞守衛，大老闆也沒人管）。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")
const ENDING_SCENE := "res://levels/heaven/ending/ending.tscn"     # 全破之後的結局動畫

var _blow_checked := false     # 陸吾吹完之後，檢查過「有沒有人被撞歪、沒吹到」了沒

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		RescueFeed.new().uses(2, 0).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		# 大老闆：從北邊走下來，在 (-3.5, -5.6) 踏上畫門乙出口那條線，往東走 2 公尺，再往東南走進金光
		slow_rusher("大老闆", Vector3(-3.5, 0, -8.6), [Vector3(-3.5, 0, -5.6), Vector3(-1.5, 0, -5.6), Vector3(0.3, 0, -3.0)], 1.0, true),
		# 守衛：站在畫門乙出口那條線上、星洞甲前面
		guard("守衛", Vector3(1.5, 0, -5.6)),
		# 西邊：第一段往東南東，延長線通到畫門甲；第二段往東，延長線通到金光
		rusher("阿水", Vector3(-10.5, 0, -2.5), [Vector3(-7.5, 0, -1.0), Vector3(-1.34, 0, -2.32)]),
		# 南邊：阿土第一段往東（延長線穿過阿金的紅線、通到星洞乙），第二段往東北（穿過阿金的紅線、通到金光）
		rusher("阿土", Vector3(-8.6, 0, 2.6), [Vector3(-5.18, 0, 2.6), Vector3(-2.06, 0, 0.8)]),
		rusher("阿金", Vector3(-2.4, 0, 6.7), [Vector3(-2.4, 0, 0.0)]),
	]

## 最後一關：過關卡片按 Enter 之後不是直接回地圖，先播結局動畫（播完自己回地圖）
func _finale_leave() -> void:
	if not ResourceLoader.exists(ENDING_SCENE):
		super()
		return
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LoadingCard.go(get_tree(), ENDING_SCENE)

## 過關卡片：後面還有結局動畫，按鈕寫「看結局」
func _make_finale_card() -> Control:
	var panel := super()
	if ResourceLoader.exists(ENDING_SCENE):
		for l in panel.find_children("*", "Label", true, false):
			var lb := l as Label
			if lb.text.contains("回地圖"):
				lb.text = "看結局 ▶"
			elif lb.text.contains("感謝遊玩"):
				lb.text = "還有最後一段。"
	return panel

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "走上唱盤"},
		{"id": "luwu_two", "text": "陸吾一口氣吹走兩個", "hint": "誰的滑行線通到金光？一次要兩個"},
		{"id": "boss_blown", "text": "陸吾吹走大老闆", "hint": "他的紅線自己會走進金光：那口氣留給他"},
	]

func _how_to() -> String:
	return "香蕉皮只能放紅線上　看秒數 [Tab]"

## 按 H 的說明卡「這一關」：規則（右邊）和兩層提示（左邊，輸 1 次、3 次才打開；後面那張比較直白）
func _level_rule() -> String:
	return "五個人、兩片香蕉皮，陸吾只有一口氣：留給誰？\n\n大老闆不怕滑。最後要用飼料把家豪引上唱盤。"

func _level_hints() -> Array:
	return [
		"阿水第一段的延長線通到畫門；阿土滑出去會穿過阿金的紅線，兩個人要同時到 [Tab]",
		"阿水那片丟在第一段的後半，出門時連大老闆一起撞進星洞；阿土那片丟在第二段，跟阿金一起滑進金光；唱盤上放飼料。",
	]

func _defeat_tip() -> String:
	return _t2("香蕉皮只有兩片", "香蕉皮只有兩片：每一片都要帶走不只一個人")

func _level_reset() -> void:
	super()
	_blow_checked = false

## 在石地上踩到香蕉皮（只跌倒、不會滑）：記下來，失敗提示要用
func make_slip(f: Fighter, what := "香蕉皮") -> void:
	if not f.is_bird and not world.on_ice(f.pos.x, f.pos.z):
		f.data.fell_rough = true
	super(f, what)

## 這一關專用的小回饋：陸吾吹完之後，被撞到的人如果沒有一起被吹走（被撞歪、晚到了），在他頭上說一聲
func _level_step(dt: float) -> void:
	super(dt)
	if _blow_checked or luwu_awake or _blow_tail > 0.0:
		return
	_blow_checked = true
	var blown := enemies.filter(func(e): return e.data.has("blown"))
	if blown.size() != 1:
		return
	for f in enemies:
		if f.alive() and not f.data.has("blown") and f.data.get("was_hit", false) and f.data.get("hit_by") == blown[0]:
			log_event("%s被撞歪了，比%s晚到金光，沒被吹到" % [f.name, (blown[0] as Fighter).name])
			pop_label("晚了一步，沒吹到", f.pos + Vector3(0, 3.4, 0), Color(1, 1, 1), 1600, f)

## p 離 who 的紅線多遠（seg ≥ 0 只看第幾段；-1 整條都算；沒有紅線的人回傳很大的數）
func _route_dist(f: Fighter, p: Vector3, seg := -1) -> float:
	var pts: Array = [f.start_pos]
	pts.append_array(f.get_meta("rush", []))
	var best := 1e9
	for i in range(1, pts.size()):
		if seg >= 0 and i - 1 != seg:
			continue
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, flat_dist(a.lerp(b, t), p))
	return best

## 這一關香蕉皮只能放在紅線上（離某一條紅線不到半公尺）：
## 不然可以丟在「跑完紅線、改追家豪」的人腳下，讓他滑到場外追不上——那樣就不用想畫門了。
const PEEL_ON_LINE := 0.52

func placement_error(i: int, p: Vector3) -> String:
	if items[i].id == "banana" and not enemies.any(func(f): return _route_dist(f, p) < PEEL_ON_LINE):
		return "香蕉皮要放在紅線上"
	return super(i, p)

## 這一局有沒有香蕉皮放在某個人的紅線上（seg ≥ 0 只看第幾段；-1 整條都算）
func _peel_on(who: String, seg := -1) -> bool:
	for f in enemies:
		if f.name == who:
			for c in casts:
				if String(c.id) == "banana" and _route_dist(f, c.pos, seg) < ON_ROUTE:
					return true
	return false

## 這一局有沒有放「彎黃線」的那把飼料（不在唱盤上的飼料）
func _bent() -> bool:
	for c in casts:
		if String(c.id) == "bait" and (not _needs_turntable() or flat_dist(c.pos, _turntable() as Vector3) > DISC_R):
			return true
	return false

## 某個人這一局最後怎麼了："洞"（掉進星洞）、"吹"（被陸吾吹走）、"活"（還在場上）
func _fate(who: String) -> String:
	for f in enemies:
		if f.name == who:
			if f.data.get("sunk", false):
				return "洞"
			if f.data.has("blown"):
				return "吹"
	return "活"

## 失敗提示（兩層）：同一種死法第一次只說死因和方向，第二次起才講明白（_t2）。
## 照「誰抓到的」「這一局東西放在哪」「每個人最後怎麼了」分。
## 阿土從阿金身邊滑過去沒撞到的那種（時機差一點），冰雪島原本的提示會直接說香蕉皮往哪邊挪，這裡不用再寫。
func _defeat_tip_for(who: String) -> String:
	match who:
		"陸吾":
			# 家豪走進金光被吹走
			if _bent():
				return _t2("黃線還有一段是紅的", "黃線還有一段是紅的：飼料放到金光的西邊，黃線才繞得開")
			if _fate("大老闆") == "吹":
				return _t2("家豪比大老闆早一步走進金光", "家豪比大老闆早到金光：用另一把飼料讓黃線繞開，大老闆自己會走進去")
			return _t2("陸吾還沒吹氣，家豪就走進金光了", "陸吾還沒吹氣：讓別人先進金光，或用另一把飼料讓黃線繞開")
		"大老闆":
			if _fate("阿水") == "吹":
				return _t2("陸吾那一口氣給了阿水", "陸吾吹走阿水，就沒人從畫門出來了：阿水的另一段通到哪？")
			if _fate("阿水") == "洞" and not luwu_awake:
				return _t2("阿水衝出畫門的時候，大老闆還沒走到那條線上", "阿水太早出來沒撞到大老闆，陸吾那口氣又用掉了：香蕉皮往後放，或把那口氣留給大老闆")
			if _fate("阿水") == "洞":
				return _t2("大老闆在半路上碰到家豪", "繞路的黃線離大老闆的紅線太近：飼料換個地方放")
			if _peel_on("大老闆"):
				return _t2("大老闆不怕滑", "大老闆不怕滑：他的紅線有一段跟畫門乙的出口在同一條線上")
			return _t2("大老闆不怕滑，香蕉皮對他沒用", "大老闆會走過畫門乙正前方那條線：誰能從畫門衝出來撞他？")
		"守衛":
			return _t2("守衛會被什麼撞到？", "從畫門乙衝出來的人會一路撞到守衛：誰的紅線通到畫門甲？")
		"阿水":
			if _peel_on("阿土") and _peel_on("阿金"):
				return _t2("香蕉皮不夠分", "阿土和阿金共用一片（阿土滑出去撞阿金），省一片給阿水")
			return _t2("阿水沒人處理", "阿水第一段的延長線通到畫門：出來那條線上有誰？")
		"阿土", "阿金":
			if enemies.any(func(e): return e.data.get("fell_rough", false)):
				return _t2("石地上只會跌倒，不會滑", "石地上只會跌倒：香蕉皮往白玉地裡面放")
			if not _peel_on("阿土"):
				if _peel_on("阿金"):
					return _t2("阿金自己滑會滑到北邊去", "阿金自己滑會滑到北邊去：香蕉皮放阿土的線，讓阿土滑去撞阿金")
				return _t2("南邊這兩個人最先碰到家豪", "阿土的滑行線會穿過阿金的紅線：一片解決兩個")
			if _fate("阿土") == "活":
				return _t2("香蕉皮被阿金先踩到了", "香蕉皮被阿金先踩到了：離阿金的紅線遠一點")
			return _t2("阿土滑過去的時候，阿金不在那裡", "阿土滑到交叉點的時候，阿金要剛好走到：按 Tab 看秒數")
	return super(who)

## Tab 俯視的秒數刻度：冰雪島原本的寫法每個人都用一般的速度算。這一關大老闆走得慢、又晚出發，
## 而「他幾秒踏上畫門乙出口那條線」正是玩家要看的，所以這裡照每個人自己的速度和晚出發的秒數重畫。
func _draw_time_dots() -> void:
	var used := 0
	if _aid("tab") and phase == Phase.PREPARE:
		var top_on: bool = _top_cam != null and _top_cam.current
		for f in enemies:
			if not f.alive() or f.data.get("guard", false):
				continue
			var spd: float = BOSS_SPEED if f.get_meta("slow", false) else RUSH_SPEED
			var wait: float = float(f.get_meta("delay", 0.0))
			var route := planned_route(f)
			var total := 0.0
			for i in range(1, route.size()):
				total += flat_dist(route[i - 1], route[i])
			var sec := int(floor(wait)) + 1
			while (float(sec) - wait) * spd <= total and used < 40:
				var d := (float(sec) - wait) * spd
				var p := _along(route, d)
				var w := 0.22
				for v in [p + Vector3(-w, 0.13, -w), p + Vector3(w, 0.13, -w), p + Vector3(w, 0.13, w),
						p + Vector3(-w, 0.13, -w), p + Vector3(w, 0.13, w), p + Vector3(-w, 0.13, w)]:
					_v(Color(1, 1, 1, 0.95), v)
				if used >= _time_labels.size():
					var l := Label3D.new()
					l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
					l.no_depth_test = true
					l.pixel_size = 0.0005
					l.fixed_size = true
					l.font_size = 84
					l.outline_size = 22
					l.outline_modulate = UISkin.INK
					world.add_child(l)
					_time_labels.append(l)
				var tl: Label3D = _time_labels[used]
				tl.text = "%d" % sec
				var dv := _along(route, d + 0.3) - _along(route, d - 0.3)
				dv.y = 0.0
				var perp := dv.normalized().cross(Vector3.UP) if dv.length() > 0.01 else Vector3(0, 0, 1)
				if perp.z < -0.01 or (absf(perp.z) <= 0.01 and perp.x < 0.0):
					perp = -perp
				tl.position = p + perp * (0.35 + 28.0 * _px(p)) + Vector3(0, 0.3, 0)
				tl.visible = top_on
				used += 1
				sec += 1
	for i in range(used, _time_labels.size()):
		(_time_labels[i] as Label3D).visible = false

func _level_setup() -> void:
	super()
	preview_full = false
	show_names_always = true
	# 時機輔助（跟冰雪島看時機的關卡同一套）：Tab 俯視看紅線上的秒數、交叉點的地上標記、
	# 瞄準阿土的紅線時畫出阿金那時候走到哪、重來之後留著前三次的記號
	aid_tab_seconds = true
	aid_cross_mark = true
	aid_ghost = true
	aid_last_try = 3
	# 「差一點！」只算阿土（滑的人）和阿金（穿越的人）這一組
	timing_slider = "阿土"
	timing_crosser = "阿金"
	win_line = "……這是唱盤"
	caught_line = "……太小了。搓不開。"
