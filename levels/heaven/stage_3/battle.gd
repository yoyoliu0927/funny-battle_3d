extends "res://levels/heaven/heaven_battle.gd"
## 【丹穴山 3 天門】壓軸（2026-11-20 重新設計，見規格第 14 節）：五個人、只有兩片香蕉皮，每一片都要帶走一串人。
##
## 連鎖一（要想到）：大老闆不怕滑，後面也沒有人可以撞他——他背後立著畫門乙。阿水第一段的延長線通到畫門甲，
##   從畫門乙衝出來剛好沿著大老闆的紅線往東：撞上大老闆、再撞上守衛，三個人一起進星洞甲。
## 連鎖二（要對時機）：剩下一片要處理阿土和阿金兩個人。阿土的滑行線會穿過阿金的紅線，
##   香蕉皮要放在「阿土滑到交叉點的時候阿金剛好走到」的位置（按 Tab 看秒數）：
##   放在阿土第二段 → 兩個人一起滑進金光，陸吾一口氣吹走兩個，家豪從睡著的陸吾面前走過去；
##   放在阿土第一段的後半 → 兩個人一起進星洞乙，陸吾還醒著，要用另一把飼料讓黃線繞開金光。
## 最後一步：一把飼料放唱盤上。
## 走不通的：阿水第二段（被陸吾吹走）是第 2 關學到的做法——這一關只有阿水撞得到大老闆，陸吾那口氣也白白用掉。

const RescueFeed := preload("res://levels/ice/items/rescue_feed_item.gd")

func _make_items() -> Array:
	return [
		BananaItem.new().uses_shared(2).cooldown_sec(0.0),
		RescueFeed.new().uses(2, 0).cooldown_sec(0.0),
	]

func _enemy_specs() -> Array:
	return [
		# 北邊那條線：畫門乙（西頭）→ 大老闆 → 守衛 → 星洞甲（東頭）
		slow_rusher("大老闆", Vector3(-7.8, 0, -5.6), [Vector3(-0.8, 0, -5.6)], 1.0, true),
		guard("守衛", Vector3(1.5, 0, -5.6)),
		# 西邊：第一段往東南東，延長線通到畫門甲；第二段往東，延長線通到金光
		rusher("阿水", Vector3(-10.5, 0, -2.5), [Vector3(-7.5, 0, -1.0), Vector3(-4.57, 0, -1.63)]),
		# 南邊：阿土第一段往東（延長線穿過阿金的紅線、通到星洞乙），第二段往東北（穿過阿金的紅線、通到金光）
		rusher("阿土", Vector3(-8.6, 0, 2.6), [Vector3(-5.18, 0, 2.6), Vector3(-2.06, 0, 0.8)]),
		rusher("阿金", Vector3(-2.4, 0, 6.7), [Vector3(-2.4, 0, 0.0)]),
	]

func _checklist() -> Array:
	return [
		{"id": "rescue", "text": "走上唱盤"},
		{"id": "luwu_two", "text": "陸吾一口氣吹走兩個", "hint": "誰的滑行線通到金光？一次要兩個"},
		{"id": "all_sunk", "text": "五個人都掉進星洞", "hint": "陸吾整局醒著：黃線要繞開金光"},
	]

func _how_to() -> String:
	return "只有兩片香蕉皮．唱盤上要放飼料．看秒數 [Tab]"

func _defeat_tip() -> String:
	return "香蕉皮只有兩片：每一片都要帶走不只一個人"

## 這一局有沒有香蕉皮放在某個人的紅線上（seg ≥ 0 只看第幾段；-1 整條都算）
func _peel_on(who: String, seg := -1) -> bool:
	for f in enemies:
		if f.name != who:
			continue
		var pts: Array = [f.start_pos]
		pts.append_array(f.get_meta("rush", []))
		for c in casts:
			if String(c.id) != "banana":
				continue
			for i in range(1, pts.size()):
				if seg >= 0 and i - 1 != seg:
					continue
				var a: Vector3 = pts[i - 1]
				var b: Vector3 = pts[i]
				var ab := Vector2(b.x - a.x, b.z - a.z)
				var t := clampf(Vector2(c.pos.x - a.x, c.pos.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				if flat_dist(a.lerp(b, t), c.pos) < ON_ROUTE:
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

## 失敗提示：照「誰抓到的」和「這一局東西放在哪、每個人最後怎麼了」給一句話（每一種常見的錯各一句）。
## 阿土從阿金身邊滑過去沒撞到的那種（時機差一點），冰雪島原本的提示會直接說香蕉皮往哪邊挪，這裡不用再寫。
func _defeat_tip_for(who: String) -> String:
	match who:
		"陸吾":
			# 家豪走進金光被吹走
			if _bent():
				return "黃線還有一段是紅的：飼料放到金光的西邊，黃線才繞得開"
			if _fate("阿土") == "洞" and _fate("阿金") == "洞":
				return "陸吾還醒著：用另一把飼料讓黃線繞開，或讓阿土和阿金改去餵陸吾"
			return "家豪自己走進金光了：讓別人先進去，或用另一把飼料讓黃線繞開"
		"大老闆", "守衛":
			if _fate("阿水") == "吹":
				return "陸吾吹走阿水，就沒人撞得到大老闆了：阿水的另一段通到哪？"
			if _peel_on("大老闆"):
				return "大老闆不怕滑：要有人從他背後那扇畫門滑出來撞他"
			return "大老闆不怕滑，背後有一扇畫門：誰能從那裡滑出來？"
		"阿水":
			if _peel_on("阿土") and _peel_on("阿金"):
				return "阿土和阿金共用一片（阿土滑出去撞阿金），省一片給阿水"
			return "阿水第一段的延長線通到畫門：只有他撞得到大老闆"
		"阿土", "阿金":
			for c in casts:
				if String(c.id) == "banana" and not world.on_ice(c.pos.x, c.pos.z):
					return "石地上只會跌倒：香蕉皮要放在白玉地上"
			if not _peel_on("阿土"):
				if _peel_on("阿金"):
					return "阿金自己滑會滑到北邊去：香蕉皮放阿土的線，讓阿土滑去撞阿金"
				return "阿土的滑行線會穿過阿金的紅線：一片解決兩個"
			if _fate("阿土") == "活":
				return "香蕉皮被阿金先踩到了：離阿金的紅線遠一點"
			return "阿土滑到交叉點的時候，阿金要剛好走到：按 Tab 看秒數"
	return super(who)

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
