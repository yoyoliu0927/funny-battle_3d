extends RefCounted
## 船塢：幾種船、各自的速度和操作、怎麼買。目前開哪艘、買了哪些記在冒險手帳的存檔（journal.gd 的 [boat]），
## 星星用同一個錢包（Wardrobe.spend）。船長什麼樣子由 level_select.gd 的 _boat_build() 用現成模型拼出來。
##
## 欄位：id、name、price（幾顆星；0 = 一開始就有；-1 = 只能靠彩蛋拿）、max（全速，公尺／秒）、acc（加速）、turn（轉彎，弧度／秒）、
##       tint（船身顏色，乘在小木船的模型上；白色 = 不改）、desc（一句話）、quip（上船時家豪說的話）

const Journal := preload("res://scripts/hub/journal.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")

const BOATS := [
	{"id": "rowboat", "name": "小木船", "price": 0, "max": 22.0, "acc": 13.0, "turn": 1.7, "tint": Color(1, 1, 1),
		"desc": "碼頭邊那艘。穩穩的，不快也不慢。", "quip": "……划起來比走路慢。"},
	{"id": "raft", "name": "木桶筏", "price": 1, "max": 16.0, "acc": 9.0, "turn": 1.25, "tint": Color(1, 1, 1),
		"desc": "木板綁在桶子上。慢，但浪再大也不會翻。", "quip": "這算船嗎。"},
	{"id": "pumpkin", "name": "南瓜船", "price": 2, "max": 28.0, "acc": 15.0, "turn": 1.85, "tint": Color(1.0, 0.62, 0.3),
		"desc": "秋楓島的特產，刻意不裝輪子。", "quip": "會不會在午夜變回馬車？"},
	{"id": "pirate", "name": "海盜小艇", "price": 3, "max": 34.0, "acc": 17.0, "turn": 2.0, "tint": Color(0.55, 0.42, 0.34),
		"desc": "要塞退役的小艇，旗子是撿來的。", "quip": "我沒有搶東西，我是借的。"},
	{"id": "phoenix", "name": "鳳凰船", "price": 5, "max": 42.0, "acc": 20.0, "turn": 2.2, "tint": Color(1.0, 0.82, 0.3),
		"desc": "金色的羽毛做的。海上最快，聽說會自己發光。", "quip": "天選之雞，坐天選之船。"},
]

static func all() -> Array:
	return BOATS

static func get_boat(id: String) -> Dictionary:
	for b in BOATS:
		if String(b.id) == id:
			return b
	return BOATS[0]

static func owned(id: String) -> bool:
	return int(get_boat(id).price) == 0 or Journal.has("boat", "own_" + id)

static func owned_count() -> int:
	var n := 0
	for b in BOATS:
		if owned(String(b.id)):
			n += 1
	return n

## 現在開的船（沒買過的不算，回到小木船）
static func current() -> Dictionary:
	var id := Journal.get_s("boat", "current", "rowboat")
	return get_boat(id if owned(id) else "rowboat")

static func equip(id: String) -> bool:
	if not owned(id):
		return false
	Journal.set_s("boat", "current", id)
	return true

## 用星星買；星星不夠、已經有了、或只能靠彩蛋的回傳 false
static func buy(id: String) -> bool:
	var b := get_boat(id)
	var cost := int(b.price)
	if owned(id) or cost < 0 or not Wardrobe.spend(cost):
		return false
	Journal.mark("boat", "own_" + id)
	return true

## 彩蛋送的（寶箱全撈到）：不花星星
static func grant(id: String) -> void:
	Journal.mark("boat", "own_" + id)
