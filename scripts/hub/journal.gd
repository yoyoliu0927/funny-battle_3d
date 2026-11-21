extends RefCounted
## 農莊的「冒險手帳」資料：存檔（user://journal.cfg）、魚的圖鑑、貼紙（成就）。
## 全部是 static，用法：const Journal := preload("res://scripts/hub/journal.gd")。不用 class_name。
## 測試的時候（--autotest／--mapshots／--hubshots）把 persist 設成 false：只記在記憶體裡，不寫玩家的存檔。
##
## 存檔格式：
##   [poke]  total／hen／tree／barn／hero／hay／windmill／boat／pumpkin／fire／silo = 戳過幾次
##   [egg]   total／gold = 收過幾顆蛋（金蛋）
##   [fish]  caught_<id> = 釣到幾次、best_<id> = 最大幾公分
##   [flag]  gold_egg = 乾草堆裡的金蛋已經找到了
##   [ach]   <貼紙 id> = true（解鎖過了，才不會每次進來都跳通知）

const PATH := "user://journal.cfg"
static var persist := true
static var _cf: ConfigFile

const MODELS := {
	"fish": "res://levels/ice/assets/kenney_survival/fish.glb",
	"large": "res://levels/ice/assets/kenney_survival/fish-large.glb",
	"peel": "res://levels/ice/assets/blender/banana_peel.glb",
	"bucket": "res://levels/ice/assets/kenney_survival/bucket.glb",
	"star": "res://levels/ice/assets/blender/fx_star.glb",
}

## 池塘裡會釣到的東西（圖鑑也是這張表）。kind："fish" 是魚、"junk" 是垃圾、"treasure" 是寶物。
## rar：稀有度 0～3（越稀有，拉線的時機條越窄、要拉的次數越多）。w：抽到的權重。cm：大小範圍。col：魚身的顏色（乘在模型上）。
const FISH := [
	{"id": "tilapia", "name": "吳郭魚", "kind": "fish", "rar": 0, "w": 30.0, "cm": [14, 34], "col": Color("a9c4d4"), "model": "fish",
		"line": "台灣池塘的原住民，什麼水都游得下去。"},
	{"id": "crucian", "name": "鯽魚", "kind": "fish", "rar": 0, "w": 26.0, "cm": [10, 26], "col": Color("c9c2a0"), "model": "fish",
		"line": "湯很白，魚很小，刺很多。"},
	{"id": "milkfish", "name": "虱目魚", "kind": "fish", "rar": 1, "w": 14.0, "cm": [30, 62], "col": Color("dcdcdc"), "model": "large",
		"line": "台南人的早餐。刺多，請專心吃。"},
	{"id": "carp", "name": "鯉魚", "kind": "fish", "rar": 1, "w": 12.0, "cm": [35, 72], "col": Color("d9a36a"), "model": "large",
		"line": "想跳龍門，結果跳進了你的桶子。"},
	{"id": "goldfish", "name": "金魚", "kind": "fish", "rar": 1, "w": 8.0, "cm": [6, 14], "col": Color("ff9a3c"), "model": "fish",
		"line": "夜市撈來的，居然活了三年。"},
	{"id": "mullet", "name": "烏魚", "kind": "fish", "rar": 2, "w": 5.0, "cm": [45, 80], "col": Color("7d8fa6"), "model": "large",
		"line": "重點是烏魚子，不是你。"},
	{"id": "goldcarp", "name": "黃金錦鯉", "kind": "fish", "rar": 3, "w": 1.6, "cm": [60, 95], "col": Color("ffd23c"), "model": "large",
		"line": "天上的神路過，說這條我要了。"},
	{"id": "peel", "name": "香蕉皮", "kind": "junk", "rar": 0, "w": 5.0, "cm": [0, 0], "col": Color(1, 1, 1), "model": "peel",
		"line": "神蹟的道具，居然掉進水裡了。"},
	{"id": "bucket", "name": "空水桶", "kind": "junk", "rar": 0, "w": 5.0, "cm": [0, 0], "col": Color(1, 1, 1), "model": "bucket",
		"line": "桶子裡沒有魚，只有一個故事。"},
	{"id": "star", "name": "許願星", "kind": "treasure", "rar": 3, "w": 1.0, "cm": [0, 0], "col": Color(1, 1, 1), "model": "star",
		"line": "許願用的，不能拿去商店換衣服。"},
]

# ---------------------------------------------------------------- 存取

static func _c() -> ConfigFile:
	if _cf == null:
		_cf = ConfigFile.new()
		if persist:
			_cf.load(PATH)
	return _cf

static func _save() -> void:
	if persist:
		_c().save(PATH)

## 測試用：把記憶體裡的存檔清空（不碰檔案）
static func reset_memory() -> void:
	_cf = ConfigFile.new()

## 存一個字串（現在開哪艘船）和數有幾個 key（靠過幾座島）
static func get_s(section: String, key: String, default := "") -> String:
	return String(_c().get_value(section, key, default))

static func set_s(section: String, key: String, v: String) -> void:
	_c().set_value(section, key, v)
	_save()

static func count_keys(section: String) -> int:
	return _c().get_section_keys(section).size() if _c().has_section(section) else 0

static func n(section: String, key: String) -> int:
	return int(_c().get_value(section, key, 0))

static func add(section: String, key: String, amount := 1) -> int:
	var v := n(section, key) + amount
	_c().set_value(section, key, v)
	_save()
	return v

## 只在比較大的時候更新。回傳 true = 破紀錄
static func set_max(section: String, key: String, v: int) -> bool:
	if v > n(section, key):
		_c().set_value(section, key, v)
		_save()
		return true
	return false

static func has(section: String, key: String) -> bool:
	return bool(_c().get_value(section, key, false))

static func mark(section: String, key: String) -> void:
	_c().set_value(section, key, true)
	_save()

# ---------------------------------------------------------------- 魚

static func fish_by_id(id: String) -> Dictionary:
	for f in FISH:
		if String(f.id) == id:
			return f
	return {}

## 依權重抽一個
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for f in FISH:
		total += float(f.w)
	var x := rng.randf() * total
	for f in FISH:
		x -= float(f.w)
		if x <= 0.0:
			return f
	return FISH[0]

## 這一尾多大（公分；垃圾和寶物是 0）
static func roll_size(f: Dictionary, rng: RandomNumberGenerator) -> int:
	var r: Array = f.cm
	if int(r[1]) <= 0:
		return 0
	return rng.randi_range(int(r[0]), int(r[1]))

## 記一次釣到。回傳 {"new": 第一次釣到, "record": 破了大小紀錄}
static func caught(f: Dictionary, cm: int) -> Dictionary:
	var id := String(f.id)
	var first := n("fish", "caught_" + id) == 0
	add("fish", "caught_" + id)
	var rec := false
	if cm > 0:
		rec = set_max("fish", "best_" + id, cm) and not first
	return {"new": first, "record": rec}

## 圖鑑收了幾種（含垃圾和寶物）
static func book_count() -> int:
	var c := 0
	for f in FISH:
		if n("fish", "caught_" + String(f.id)) > 0:
			c += 1
	return c

## 釣過幾種魚（不含垃圾和寶物）
static func species_count() -> int:
	var c := 0
	for f in FISH:
		if String(f.kind) == "fish" and n("fish", "caught_" + String(f.id)) > 0:
			c += 1
	return c

static func junk_count() -> int:
	var c := 0
	for f in FISH:
		if String(f.kind) == "junk":
			c += n("fish", "caught_" + String(f.id))
	return c

static func fish_total() -> int:
	var c := 0
	for f in FISH:
		if String(f.kind) == "fish":
			c += n("fish", "caught_" + String(f.id))
	return c

static func biggest() -> int:
	var b := 0
	for f in FISH:
		b = maxi(b, n("fish", "best_" + String(f.id)))
	return b

# ---------------------------------------------------------------- 貼紙（成就）

## 貼紙的種類：journey 旅程（金色）、poke 戳戳樂（綠色）、fish 釣魚（藍色）
const CAT_COLORS := {"journey": Color("e8b04a"), "poke": Color("6dbb55"), "fish": Color("4a9fe0"), "sea": Color("2fb5c9"), "dj": Color("a04fd0")}

## 全部貼紙。ctx 是主島傳進來的旅程進度：
##   {"stars": 已拿星星, "stars_max": 全部星星, "feathers": 已拿羽毛, "feathers_max": 羽毛總數, "cleared": 過了幾個小關, "owned": 買了幾件衣服}
## 回傳 [{id, name, desc, glyph, cat, cur, need, got}]
static func stickers(ctx: Dictionary) -> Array:
	var out: Array = []
	var d := func(id: String, name: String, desc: String, glyph: String, cat: String, cur: int, need: int) -> void:
		out.append({"id": id, "name": name, "desc": desc, "glyph": glyph, "cat": cat, "cur": mini(cur, need), "need": need, "got": cur >= need})
	var fm := int(ctx.get("feathers_max", 5))
	d.call("first", "第一步", "過第一個小關", "步", "journey", int(ctx.get("cleared", 0)), 1)
	d.call("feather1", "拾羽人", "帶回第一根羽毛", "羽", "journey", int(ctx.get("feathers", 0)), 1)
	d.call("feather3", "羽翼漸豐", "帶回三根羽毛", "翼", "journey", int(ctx.get("feathers", 0)), 3)
	d.call("feather5", "五采而文", "帶回全部的羽毛", "鳳", "journey", int(ctx.get("feathers", 0)), maxi(fm, 1))
	d.call("stars10", "星光閃閃", "拿到 10 顆星星", "星", "journey", int(ctx.get("stars", 0)), 10)
	d.call("starsall", "滿天星斗", "星星全部拿滿", "滿", "journey", int(ctx.get("stars", 0)), maxi(int(ctx.get("stars_max", 1)), 1))
	d.call("dress", "愛美的雞", "在商店買三件衣服", "衣", "journey", int(ctx.get("owned", 0)), 3)
	d.call("poke10", "手癢", "在農莊戳 10 下", "戳", "poke", n("poke", "total"), 10)
	d.call("poke50", "戳戳達人", "在農莊戳 50 下", "指", "poke", n("poke", "total"), 50)
	d.call("hen20", "母雞的惡夢", "戳母雞 20 下", "雞", "poke", n("poke", "hen"), 20)
	d.call("tree15", "搖錢樹", "搖樹 15 次", "樹", "poke", n("poke", "tree"), 15)
	d.call("barn3", "穀倉敲敲樂", "把穀倉的門敲開 3 次", "倉", "poke", n("poke", "barn"), 3)
	d.call("hero10", "不要戳我", "戳家豪 10 下", "豪", "poke", n("poke", "hero"), 10)
	d.call("goldegg", "大海撈針", "在乾草堆裡找到金蛋", "金", "poke", 1 if has("flag", "gold_egg") else 0, 1)
	d.call("eggs10", "蛋蛋收藏家", "收集 10 顆蛋", "蛋", "poke", n("egg", "total"), 10)
	d.call("fish1", "第一尾", "釣到第一條魚", "魚", "fish", fish_total(), 1)
	d.call("species5", "圖鑑達人", "釣到 5 種魚", "鑑", "fish", species_count(), 5)
	d.call("junk3", "環保志工", "從池塘撈出 3 件垃圾", "環", "fish", junk_count(), 3)
	d.call("big", "大魚上鉤", "釣到 60 公分以上的魚", "大", "fish", biggest(), 60)
	d.call("goldcarp", "鯉躍龍門", "釣到黃金錦鯉", "鯉", "fish", n("fish", "caught_goldcarp"), 1)
	d.call("neighbor1", "新鄰居", "有第一位居民搬進農莊（破一個大關）", "鄰", "journey", int(ctx.get("residents", 0)), 1)
	d.call("neighbors", "熱鬧農莊", "全部的居民都搬進農莊", "村", "journey", int(ctx.get("residents", 0)), maxi(int(ctx.get("residents_max", 5)), 1))
	d.call("sail1", "出海！", "第一次開船出航", "航", "sea", n("sail", "trips"), 1)
	d.call("sail1000", "遠洋漁船", "一共開了 1000 公尺", "洋", "sea", int(n("sail", "meters")), 1000)
	d.call("docks", "環島旅行", "每座島都靠過岸（%d 座）" % int(ctx.get("isles_max", 5)), "靠", "sea", count_keys("dock"), maxi(int(ctx.get("isles_max", 5)), 1))
	d.call("chest3", "寶藏獵人", "在海上撈到 3 個漂流寶箱", "寶", "sea", n("sea", "chest"), 3)
	d.call("fishjump", "魚躍龍門", "看到大魚跳出海面 8 次", "躍", "sea", n("sea", "jump"), 8)
	d.call("horn10", "汽笛達人", "按 10 次汽笛", "笛", "sea", n("sail", "horn"), 10)
	d.call("penguin", "企鵝聯合會", "用汽笛叫醒游泳的企鵝 3 次", "企", "sea", n("sea", "penguin"), 3)
	d.call("edge", "天涯海角", "開到世界的盡頭", "涯", "sea", 1 if has("flag", "world_edge") else 0, 1)
	d.call("boats3", "船東", "擁有 3 艘船", "船", "sea", int(ctx.get("boats", 1)), 3)
	d.call("duck_red", "前途一片紅果", "在商店連續點鹹酥雞老闆 10 下", "紅", "poke", 1 if has("flag", "duck_red") else 0, 1)
	d.call("talk10", "話癆", "跟居民聊 10 次（戳他們）", "聊", "poke", n("poke", "resident"), 10)
	d.call("dj_first", "開張大吉", "在 DJ 台完成第一場演出", "演", "dj", n("dj", "plays"), 1)
	d.call("dj_b", "三曲連發", "三首歌都拿到 B 以上", "曲", "dj", _dj_ranked(3), 3)
	d.call("dj_s", "全場安可", "任何一首歌拿到 S", "安", "dj", _dj_ranked(5), 1)
	d.call("dj_fc", "完美無瑕", "任何一首歌全連擊（一個 Miss 都沒有）", "瑕", "dj", n("dj", "fc"), 1)
	d.call("dj_fever", "嗨起來", "進入 FEVER 5 次", "嗨", "dj", n("dj", "fever"), 5)
	d.call("dj_guest", "貴賓蒞臨", "FEVER 的時候，破關搬進農莊的居民跑來看演出", "賓", "dj", n("dj", "guest"), 1)
	d.call("dj_jam", "混音大師", "自由混音：四個樂器全開撐 10 秒", "混", "dj", 1 if has("flag", "dj_jam") else 0, 1)
	return out

## DJ 台：有幾首歌的評價達到 min_rank（1=D … 5=S）
static func _dj_ranked(min_rank: int) -> int:
	var k := 0
	for i in 3:
		if n("dj", "rank_%d" % i) >= min_rank:
			k += 1
	return k

## 找出這次新解鎖的貼紙（並記起來，下次不再通知）
static func unlock_new(ctx: Dictionary) -> Array:
	var fresh: Array = []
	for s in stickers(ctx):
		if bool(s.got) and not has("ach", String(s.id)):
			mark("ach", String(s.id))
			fresh.append(s)
	return fresh

static func sticker_count(ctx: Dictionary) -> Array:
	var have := 0
	var all := stickers(ctx)
	for s in all:
		if bool(s.got):
			have += 1
	return [have, all.size()]
