extends RefCounted
## 家豪的衣櫃（商店用）：服裝清單、存檔（星星、買了哪些、穿著哪些）、把服裝掛到家豪的模型上。
##
## 存檔在 user://wardrobe.cfg：
##   [stars]  關卡場景路徑 = 那一關拿過最多幾顆星（選關地圖每次開啟時更新，所以重開遊戲星星還在）
##   [meta]   max = 全部關卡一共幾顆星、spent = 已經花掉幾顆
##   [owned]  服裝 id = true
##   [worn]   部位 = 服裝 id
## 服裝只改外觀，不影響戰局（三星條件、重演都不受影響）。
##
## 開發用：命令列加 -- --wear=服裝id,服裝id 直接穿上（不存檔），方便在關卡裡看效果。
## 用法：
##   characters.gd 做家豪的時候呼叫 Wardrobe.look() 問現在穿什麼，做完再呼叫 Wardrobe.dress(模型, 種類, 穿著)。
##   種類："rooster"（關卡裡站著的家豪）、"round"（地圖和載入畫面圓滾滾的家豪）。
## 開發用：命令列加 -- --stars=數字，會多給這麼多顆星（不存檔）。

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const Toon := preload("res://shaders/toon_color.gdshader")

const PATH := "user://wardrobe.cfg"
const SLOTS := ["body", "head", "face", "back", "badge"]
const SLOT_NAMES := {"body": "身體", "head": "頭", "face": "臉", "back": "背後", "badge": "配件"}
## 家豪原本那件黑色帽 T：一開始就有、不用買；身體沒穿別的就是它
const DEFAULT_BODY := "hoodie"

## price：基本價（幾顆星）；-1 代表不能買，全部關卡三星才送。
## 基本價加起來是 18 顆。實際價錢用 price() 算：全遊戲的星星越多（別的大關合併進來之後），價錢照比例變貴，
## 但全部買完永遠不會超過全部星星的八成五，所以全三星一定買得完。
## quip：試穿時鴨子老闆吐槽的話。win：過關時家豪頭上冒出來的字（沒有就不冒）。
const ITEMS := [
	{"id": "tag", "name": "「家豪」名牌", "slots": ["badge"], "price": 1,
		"desc": "胸口別著「家豪（3）」：班上第三個家豪。", "quip": "全班喊家豪，三個人回頭。", "win": ""},
	{"id": "mask", "name": "黑口罩", "slots": ["face"], "price": 1,
		"desc": "黑口罩上一個白色 W，跟帽 T 是一套的。", "quip": "戴了還是看得出來是雞。", "win": ""},
	{"id": "slippers", "name": "藍白拖＋吊嘎", "slots": ["body"], "price": 1,
		"desc": "白吊嘎、條紋四角褲、藍白拖，翅膀上還掛著一袋早餐。", "quip": "這套穿去哪都像剛睡醒。", "win": ""},
	{"id": "bag", "name": "鹹酥雞紙袋", "slots": ["head"], "price": 1,
		"desc": "紙袋套頭、挖兩個洞，頂上還插著一支竹籤。", "quip": "……這袋子，是我攤上的吧？", "win": ""},
	{"id": "allnighter", "name": "期末爆肝套組", "slots": ["body", "face"], "price": 1,
		"desc": "系服、黑眼圈、抱著筆電，站著也能睡。", "quip": "報告明天交？那你還來逛街。", "win": "交了！"},
	{"id": "silver", "name": "銀髮＋細框眼鏡", "slots": ["head", "face"], "price": 2,
		"desc": "雞冠換成一頭往後梳的銀髮，配細框眼鏡。跟皮衣是好朋友。", "quip": "看起來身價不一樣了。", "win": ""},
	{"id": "delivery", "name": "外送保溫箱", "slots": ["back"], "price": 2,
		"desc": "背著大方箱到處跑。", "quip": "箱子裡裝的最好不是你同學。", "win": "您的餐點已送達"},
	{"id": "azhi", "name": "阿志帽 T", "slots": ["body"], "price": 2,
		"desc": "背後一個大雞爪和 FRIED 字樣，脖子掛著耳機，音量條跟著節拍跳。", "quip": "音樂小聲一點，我在做生意。", "win": ""},
	{"id": "cleanroom", "name": "無塵衣", "slots": ["body", "head"], "price": 2,
		"desc": "護國神雞。全身包起來只露眼睛。", "quip": "一根羽毛都不准掉。", "win": "良率 100%"},
	{"id": "colonel", "name": "家豪上校", "slots": ["body", "head"], "price": 2,
		"desc": "白西裝、黑領結、山羊鬍，頭頂一個炸雞桶。", "quip": "你確定要扮這個？", "win": "本店不賣自己人"},
	{"id": "leather", "name": "爸爸的皮衣", "slots": ["body"], "price": 3,
		"desc": "亮面黑皮衣。過關時會舉起一張顯示卡。", "quip": "你爸知道你穿這樣嗎？", "win": "買越多，省越多"},
	{"id": "gown", "name": "學士服", "slots": ["body", "head"], "price": -1,
		"desc": "全部關卡三星才拿得到。金色披肩帶、畢業證書，過關時丟帽子。", "quip": "恭喜畢業。學貸記得還。", "win": "畢業了！"},
]

## 試穿中（商店用）：不是空的就蓋過存檔裡的穿著
static var preview: Dictionary = {}

# ================================================================== 存檔

static func _load() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(PATH)
	return cf

static func _can_save() -> bool:
	return not "--autotest" in OS.get_cmdline_user_args()   # 自動驗收不動到玩家的存檔

static func item(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}

## 這一件現在賣幾顆星（-1：不能買）
static func price(id: String) -> int:
	var base := int(item(id).get("price", -1))
	if base < 0:
		return -1
	var total := 0
	for it in ITEMS:
		total += maxi(int(it.price), 0)
	return base * maxi(1, int(stars_max() * 0.85) / total)

## 選關地圖回報：這一關拿過幾顆星（只會往上記）
static func record_stars(records: Dictionary, max_total: int) -> void:
	if not _can_save():
		return
	var cf := _load()
	var changed := int(cf.get_value("meta", "max", -1)) != max_total
	cf.set_value("meta", "max", max_total)
	for key in records:
		if int(records[key]) > int(cf.get_value("stars", key, 0)):
			cf.set_value("stars", key, int(records[key]))
			changed = true
	if changed:
		cf.save(PATH)

## 這一關記錄裡拿過幾顆星
static func stars_of(key: String) -> int:
	return int(_load().get_value("stars", key, 0))

static func _bonus() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stars="):
			return int(a.substr(8))
	return 0

## 一共拿過幾顆星
static func stars_total() -> int:
	var cf := _load()
	var n := _bonus()
	if cf.has_section("stars"):
		for key in cf.get_section_keys("stars"):
			n += int(cf.get_value("stars", key, 0))
	return n

## 全部關卡一共有幾顆星
static func stars_max() -> int:
	return int(_load().get_value("meta", "max", 0))

static func spent() -> int:
	return int(_load().get_value("meta", "spent", 0))

## 還能花的星星
static func wallet() -> int:
	return maxi(stars_total() - spent(), 0)

## 全部關卡都三星了沒
static func all_three() -> bool:
	var m := stars_max()
	return m > 0 and stars_total() - _bonus() >= m

static func owned(id: String) -> bool:
	if id == DEFAULT_BODY:
		return true
	var it := item(id)
	if it.is_empty():
		return false
	if int(it.price) < 0:
		return all_three()
	return bool(_load().get_value("owned", id, false))

## 買下來；星星不夠或已經有了回傳 false
static func buy(id: String) -> bool:
	var it := item(id)
	var cost := price(id)
	if it.is_empty() or owned(id) or cost < 0 or wallet() < cost:
		return false
	var cf := _load()
	cf.set_value("owned", id, true)
	cf.set_value("meta", "spent", int(cf.get_value("meta", "spent", 0)) + cost)
	cf.save(PATH)
	return true

## 存檔裡的穿著（部位 -> 服裝 id；沒穿的部位不在裡面，身體至少是原本的帽 T）
static func saved_look() -> Dictionary:
	var cf := _load()
	var out := {}
	for slot in SLOTS:
		var id := String(cf.get_value("worn", slot, ""))
		if id != "" and id != DEFAULT_BODY and owned(id) and slot in item(id).get("slots", []):
			out[slot] = id
	if not out.has("body"):
		out["body"] = DEFAULT_BODY
	return out

## 現在要顯示的穿著（試穿中就是試穿的那一套）
## 開發用：命令列加 -- --wear=leather,silver 直接穿上（不看有沒有買、不存檔）
static func look() -> Dictionary:
	if not preview.is_empty():
		return preview
	var lk := saved_look()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wear="):
			for id in a.substr(7).split(",", false):
				lk = with_item(lk, id)
	return lk

## 在一套穿著上再穿一件（會佔掉它需要的每個部位）
static func with_item(lk: Dictionary, id: String) -> Dictionary:
	var out := lk.duplicate()
	for slot in item(id).get("slots", []):
		out[slot] = id
	return out

## 從一套穿著脫掉一件
static func without_item(lk: Dictionary, id: String) -> Dictionary:
	var out := lk.duplicate()
	for slot in SLOTS:
		if String(out.get(slot, "")) == id:
			out.erase(slot)
	if not out.has("body"):
		out["body"] = DEFAULT_BODY
	return out

static func is_worn(lk: Dictionary, id: String) -> bool:
	return lk.values().has(id)

static func save_look(lk: Dictionary) -> void:
	var cf := _load()
	for slot in SLOTS:
		cf.set_value("worn", slot, String(lk.get(slot, "")))
	cf.save(PATH)

## 這套穿著的身體是不是原本的帽 T 那一型（模型本身做成黑色）
static func hoodie_body(lk: Dictionary) -> bool:
	return String(lk.get("body", DEFAULT_BODY)) in [DEFAULT_BODY, "azhi"]

## 帽兜要不要戴起來（頭上戴了別的東西就放下來）
static func hood_up(lk: Dictionary) -> bool:
	return hoodie_body(lk) and String(lk.get("head", "")) in ["", "bag"]

# ================================================================== 把服裝掛到模型上

## 專屬演出：飄的字、打瞌睡、過關才出現的東西
class Fx:
	extends Node3D
	var ops: Array = []
	var t := 0.0
	var win_t := 0.0
	## 商店裡按「擺姿勢」：當作過關，讓過關才有的演出跑出來
	static var demo_win := false

	func _won() -> bool:
		if demo_win:
			return true
		if not is_inside_tree():
			return false
		var sc := get_tree().current_scene
		if sc == null:
			return false
		var b := sc.get_node_or_null("Battle")
		return b != null and String(b.get("outcome")) == "win"

	func _process(dt: float) -> void:
		t += dt
		var won := _won()
		win_t = win_t + dt if won else 0.0
		for op in ops:
			var n: Node3D = op.node
			if not is_instance_valid(n):
				continue
			match String(op.k):
				"float":      # 上下飄
					n.position.y = float(op.y) + sin(t * 1.6) * float(op.amp)
				"beat":       # 跟著節拍一漲一縮
					var b := pow(maxf(sin(t * TAU * 2.0), 0.0), 6.0)
					n.scale = (op.s as Vector3) * (1.0 + 0.12 * b)
				"doze":       # 每隔幾秒冒一次 Zzz
					var ph := fmod(t, 4.0)
					n.visible = ph < 2.2 and not won
					n.position.y = float(op.y) + ph * float(op.amp)
					(n as Label3D).modulate.a = clampf(2.2 - ph, 0.0, 1.0)
				"eq":         # 音量條：各跳各的
					n.scale.y = 0.35 + 0.65 * absf(sin(t * 7.0 + float(op.ph)))
				"win":        # 過關才出現，彈出來
					n.visible = won
					n.scale = (op.s as Vector3) * minf(win_t * 5.0, 1.0)
				"toss":       # 過關時往上丟、掉回來、再丟
					var h := 0.0
					if won:
						var ph2 := fmod(win_t, 1.3) / 1.3
						h = 4.0 * ph2 * (1.0 - ph2) * float(op.amp)
						n.rotation.x = ph2 * TAU
					else:
						n.rotation.x = 0.0
					n.position.y = float(op.y) + h

static func _mat(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Toon
	m.set_shader_parameter("albedo", c)
	return m

static func _p(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _sphere(r: float, seg := 14) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

static func _half(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.is_hemisphere = true
	s.radial_segments = 20
	s.rings = 8
	return s

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 8
	c.rings = 3
	return c

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c

static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 20
	t.ring_segments = 6
	return t

static func _label(parent: Node3D, text: String, pos: Vector3, px: float, color: Color, size := 48, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UIStyle.font()
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 10
		l.outline_modulate = Color(0.15, 0.1, 0.08)
		l.no_depth_test = true
		l.render_priority = 3
		l.outline_render_priority = 2
	else:
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(l)
	return l

## 模型上各個部位的位置（模型自己的座標）
static func _anchors(root: Node3D, kind: String, lk: Dictionary) -> Dictionary:
	var body := root.get_node_or_null("Body") as Node3D
	var head := root.find_child("Head", true, false) as Node3D
	if body == null or head == null:
		return {}
	var hooded := hoodie_body(lk)
	var A := {"kind": kind, "feet": body, "head": head, "hooded": hooded, "root": root,
		"wings": [root.find_child("WingL", true, false), root.find_child("WingR", true, false)]}
	if kind == "rooster":
		var upper := body.get_node_or_null("Upper") as Node3D
		A.body = upper if upper else body
		A.u = 1.0
		A.fc = Vector3(0, 0.55, 0.08)
		A.fr = Vector3(0.23, 0.25, 0.2375)
		A.g = 1.02 if hooded else 1.09
		A.eye = Vector3(0.066, 0.035, 0.092)
		A.eye_r = 0.022
		A.beak = Vector3(0, 0.005, 0.125)
		A.mask_c = Vector3(0, -0.02, 0.125)
		A.mask_r = Vector3(0.09, 0.08, 0.07)
		A.top = 0.14
		A.hair_y = 0.14
		A.hair_k = 1.0
		A.hat_r = 0.105
		A.bag_c = Vector3(0, 0.05, 0.015)
		A.bag_s = Vector3(0.31, 0.38, 0.31)
		A.neck = Vector3(0, 0.69, 0.285)
		A.foot = Vector3(0.09, 0.03, 0.05)
		A.back = Vector3(0, 0.50, -0.385)
		A.wing_p = Vector3(0.02, -0.12, 0.0)
		A.wing_s = Vector3(0.35, 0.75, 1.15)
		A.wing_rot = Vector3(0.2, 0, 0.15)
		A.over = 0.34      # 頭頂上方飄字的高度（頭的座標）
	else:
		A.body = body
		A.u = 1.55
		var clothed := not hooded
		A.fc = Vector3(0, 0.57, 0) if clothed else Vector3(0, 0.48, 0)
		A.fr = Vector3(0.425, 0.55, 0.404) if clothed else Vector3(0.4, 0.432, 0.38)
		A.g = 1.02
		var dz := 0.035 if hooded else 0.0     # 帽 T 版的臉比較凸
		A.eye = Vector3(0.105, 0.07, 0.33 + dz)
		A.eye_r = 0.034
		A.beak = Vector3(0, -0.02, 0.36 + dz)
		A.mask_c = Vector3(0, -0.045, 0.31 + dz)
		A.mask_r = Vector3(0.17, 0.105, 0.14)
		A.top = 0.27
		A.hair_y = 0.33
		A.hair_k = 2.1
		A.hat_r = 0.2
		A.bag_c = Vector3(0, 0.11, 0.02)
		A.bag_s = Vector3(0.78, 0.5, 0.76 + dz * 2.0)
		A.neck = Vector3(0, 0.56, 0.385)
		A.foot = Vector3(0.12, 0.02, 0.05)
		A.back = Vector3(0, 0.46, -0.40)
		A.wing_p = Vector3(0.02, -0.1, 0.0)
		A.wing_s = Vector3(0.35, 0.8, 0.95)
		A.wing_rot = Vector3(0, 0, 0.12)
		A.over = 0.72
	return A

## 橢球表面上的一點：中心 c、半徑 r，給 x、y（相對中心）算出正面（+z）那一側的位置，lift 是浮起來多少
static func _ell(c: Vector3, r: Vector3, x: float, y: float, lift := 0.0) -> Vector3:
	var d := 1.0 - pow(x / r.x, 2.0) - pow(y / r.y, 2.0)
	return c + Vector3(x, y, r.z * sqrt(maxf(d, 0.0)) + lift)

## 胸前表面上的一點（身體的座標）：x、y 給定，算出貼在衣服外面的 z
static func _chest(A: Dictionary, x: float, y: float, lift := 0.0) -> Vector3:
	var fc: Vector3 = A.fc
	var fr: Vector3 = (A.fr as Vector3) * float(A.g)
	return _ell(fc, fr, x, y - fc.y, lift)

## 有光澤的材質（皮衣、鏡框、拉鍊）
static func _gloss(c: Color, rough := 0.42, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.2
	return m

## 兩點之間的一條圓頭線（縫線、帶子、筆畫）
static func _stroke(parent: Node3D, a: Vector3, b: Vector3, r: float, col: Color, mat: Material = null) -> MeshInstance3D:
	var d := b - a
	var len := d.length()
	var mi := _p(parent, _capsule(r, len + r * 2.0), col, (a + b) * 0.5)
	if mat:
		mi.material_override = mat
	if len > 0.0001:
		var y := d / len
		var x := y.cross(Vector3.FORWARD)
		if x.length() < 0.01:
			x = y.cross(Vector3.RIGHT)
		x = x.normalized()
		mi.basis = Basis(x, y, x.cross(y))
	return mi

## 沿著一串點畫線
static func _path(parent: Node3D, pts: Array, r: float, col: Color, mat: Material = null) -> void:
	for i in pts.size() - 1:
		_stroke(parent, pts[i], pts[i + 1], r, col, mat)

## 貼著橢球表面畫一串折線（pts 是相對中心的 x、y）；每一段再切細，線才會順著曲面彎、不會陷進去
static func _surf_path(parent: Node3D, c: Vector3, r: Vector3, pts: Array, rad: float, col: Color, mat: Material = null) -> void:
	var out := []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		for k in 5:
			if k == 4 and i < pts.size() - 2:
				continue
			var q := a.lerp(b, k / 4.0)
			out.append(_ell(c, r, q.x, q.y, rad * 0.7))
	_path(parent, out, rad, col, mat)

## 貼在橢球表面上的 W（跟家豪帽 T 胸前那個 W 同一個字形）
static func _w_mark(parent: Node3D, c: Vector3, r: Vector3, s: float, col: Color, dy := 0.0) -> void:
	var pts := []
	for q in [Vector2(-1, 1), Vector2(-0.5, -1), Vector2(0, 0.35), Vector2(0.5, -1), Vector2(1, 1)]:
		pts.append(Vector2(q.x * s, q.y * s + dy))
	_surf_path(parent, c, r, pts, s * 0.11, col)

## 把頭上的雞冠收起來（戴假髮的時候）
static func _hide_comb(h: Node3D) -> void:
	for n in h.get_children():
		var mi := n as MeshInstance3D
		if mi == null or mi.position.y < 0.1:
			continue
		var m := mi.material_override as ShaderMaterial
		if m == null:
			continue
		var col: Color = m.get_shader_parameter("albedo")
		if col.r > 0.8 and col.g < 0.3:
			mi.visible = false

## 一件包住身體的衣服；領口探出一圈白羽毛
static func _cloth(A: Dictionary, col: Color, gloss := false) -> void:
	var b: Node3D = A.body
	var parts: Array = []
	if A.kind == "rooster":
		parts.append(_p(b, _sphere(0.27, 20), col.darkened(0.08), Vector3(0, 0.46, -0.06), Vector3(0.9, 0.85, 1.15) * 1.06))
		parts.append(_p(b, _sphere(0.25, 20), col, Vector3(0, 0.55, 0.08), Vector3(0.92, 1.0, 0.95) * 1.06))
		_p(b, _sphere(0.13, 12), Color(0.97, 0.96, 0.93), Vector3(0, 0.74, 0.2), Vector3(1.0, 0.45, 0.85))
	else:
		# 圓滾滾的家豪：臉長在身體上，所以衣服是一個從脖子往下包的碗
		parts.append(_p(b, _half(0.425, 0.55), col, Vector3(0, 0.57, 0), Vector3(1, 1, 0.95), Vector3(0, 0, PI)))
		parts.append(_p(b, _torus(0.385, 0.425), col.darkened(0.12), Vector3(0, 0.57, 0), Vector3(1, 0.5, 0.95)))
	if gloss:
		for mi in parts:
			(mi as MeshInstance3D).material_override = _gloss(col)

static func _sleeves(A: Dictionary, col: Color, gloss := false) -> void:
	for i in 2:
		var w := A.wings[i] as Node3D
		if w == null:
			continue
		var sx := -1.0 if i == 0 else 1.0
		var wp: Vector3 = A.wing_p
		var wr: Vector3 = A.wing_rot
		var mi := _p(w, _sphere(0.15, 14), col, Vector3(wp.x * sx, wp.y, wp.z), (A.wing_s as Vector3) * 1.13, Vector3(wr.x, 0, wr.z * sx))
		if gloss:
			mi.material_override = _gloss(col)

## 眼鏡：兩個圓框＋中間的橫樑＋往後的鏡腳
static func _glasses(A: Dictionary, col: Color, thick: float, metal := false) -> void:
	var h: Node3D = A.head
	var e: Vector3 = A.eye
	var r := float(A.eye_r) * 1.75
	var u: float = A.u
	var m: Material = _gloss(col, 0.25, 0.8) if metal else null
	for sx in [-1.0, 1.0]:
		var ring := _p(h, _torus(r, r + thick * u), col, Vector3(e.x * sx, e.y, e.z + 0.012 * u), Vector3.ONE, Vector3(PI * 0.5, 0, 0) + Vector3(0, 0.3 * sx, 0))
		if m:
			ring.material_override = m
		_stroke(h, Vector3((e.x + r) * sx, e.y, e.z + 0.006 * u), Vector3((e.x + r * 1.25) * sx, e.y + r * 0.2, e.z - 0.09 * u), thick * u * 0.45, col, m)
	_stroke(h, Vector3(-(e.x - r), e.y + r * 0.25, e.z + 0.022 * u), Vector3(e.x - r, e.y + r * 0.25, e.z + 0.022 * u), thick * u * 0.45, col, m)

## 雞爪印（自創的標誌）：三根往上張開的腳趾＋一根往下的後趾
static func _claw(parent: Node3D, center: Vector3, s: float, col: Color, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = center
	n.rotation.y = yaw
	parent.add_child(n)
	for a in [-0.6, 0.0, 0.6]:
		var len := s * (1.25 if a == 0.0 else 1.0)
		_p(n, _capsule(s * 0.11, len), col, Vector3(sin(a) * len * 0.5, cos(a) * len * 0.5, 0), Vector3(1, 1, 0.4), Vector3(0, 0, -a))
	_p(n, _capsule(s * 0.11, s * 0.6), col, Vector3(0, -s * 0.3, 0), Vector3(1, 1, 0.4))
	return n

static func dress(root: Node3D, kind: String, lk: Dictionary) -> void:
	var A := _anchors(root, kind, lk)
	if A.is_empty():
		return
	var fx := Fx.new()
	fx.name = "OutfitFx"
	root.add_child(fx)
	A.fx = fx
	var built := {}
	for slot in SLOTS:
		var id := String(lk.get(slot, ""))
		if id == "" or id == DEFAULT_BODY:
			continue
		_build(id, slot, A)
		# 過關時頭上冒出來的字（一件服裝只冒一次）
		var win := String(item(id).get("win", ""))
		if win != "" and not built.has(id):
			var l := _label(A.head, win, Vector3(0, float(A.over) + 0.13 * float(A.u) * (built.size() + 1), 0), 0.0016 * float(A.u), Color(1, 0.95, 0.6), 64, true)
			l.visible = false
			fx.ops.append({"k": "win", "node": l, "s": Vector3.ONE})
		built[id] = true
	if fx.ops.is_empty():
		fx.set_process(false)

static func _build(id: String, slot: String, A: Dictionary) -> void:
	var b: Node3D = A.body
	var h: Node3D = A.head
	var u: float = A.u
	var fx: Fx = A.fx
	var rooster: bool = A.kind == "rooster"
	var white := Color(0.97, 0.97, 0.95)
	var black := Color(0.07, 0.07, 0.08)
	var silver := Color(0.80, 0.82, 0.86)
	var gold := Color(0.96, 0.78, 0.2)
	var cy: float = A.fc.y
	var neck: Vector3 = A.neck
	var foot: Vector3 = A.foot
	var back: Vector3 = A.back
	match id:
		"tag":
			# 夾在胸口的學生證：藍色頭帶、名字、夾子
			var card := Node3D.new()
			card.position = _chest(A, -0.09 * u, cy - 0.005 * u, 0.007 * u)
			card.rotation = Vector3(-0.12, -0.4, 0.06)
			b.add_child(card)
			_p(card, _box(Vector3(0.115, 0.08, 0.006) * u), white, Vector3.ZERO)
			_p(card, _box(Vector3(0.115, 0.022, 0.007) * u), Color(0.2, 0.45, 0.85), Vector3(0, 0.029 * u, 0))
			_p(card, _box(Vector3(0.028, 0.03, 0.005) * u), Color(0.98, 0.85, 0.5), Vector3(-0.036 * u, -0.012 * u, 0.002 * u))
			_p(card, _box(Vector3(0.03, 0.016, 0.012) * u), silver, Vector3(0, 0.046 * u, 0)).material_override = _gloss(silver, 0.3, 0.8)
			_label(card, "家豪(3)", Vector3(0.014 * u, -0.012 * u, 0.0045 * u), 0.00045 * u, Color(0.1, 0.1, 0.12))
		"mask":
			# 黑口罩：正面一個白色 W（跟帽 T 胸前同一個字）、鼻樑壓條、掛耳的帶子
			var mc: Vector3 = A.mask_c
			var mr: Vector3 = A.mask_r
			var dark := Color(0.11, 0.11, 0.13)
			_p(h, _sphere(1.0, 20), dark, mc, mr)
			_w_mark(h, mc, mr, mr.y * 0.42, white, -mr.y * 0.08)
			_surf_path(h, mc, mr, [Vector2(-mr.x * 0.42, mr.y * 0.74), Vector2(0, mr.y * 0.8), Vector2(mr.x * 0.42, mr.y * 0.74)], 0.004 * u, Color(0.34, 0.34, 0.38))
			for sx in [-1.0, 1.0]:
				var ear := mc + Vector3(mr.x * 1.25 * sx, mr.y * 0.45, -mr.z * 2.2)
				for sy in [-1.0, 1.0]:
					_stroke(h, mc + Vector3(mr.x * 0.93 * sx, mr.y * 0.3 * sy, 0.0), ear, 0.0045 * u, dark)
		"slippers":
			# 白吊嘎（深藍滾邊）＋藍白拖＋翅膀上掛一袋紅白塑膠袋
			var navy := Color(0.14, 0.25, 0.55)
			_cloth(A, Color(0.99, 0.99, 0.98))
			var rim := []
			for k in 11:
				var t := (k - 5) / 5.0
				rim.append(_chest(A, t * 0.12 * u, neck.y - 0.015 * u - (1.0 - t * t) * 0.1 * u, 0.004 * u))
			_path(b, rim, 0.008 * u, navy)
			# 藍白條紋四角褲
			var sc := Vector3(0, 0.45, -0.03) if rooster else Vector3(0, 0.37, 0)
			var srx := 0.272 if rooster else 0.415
			var sh := 0.25 if rooster else 0.34
			var sz := 1.4 if rooster else 0.95
			var blue := Color(0.36, 0.62, 0.95)
			_p(b, _half(srx, sh), blue, sc, Vector3(1, 1, sz), Vector3(0, 0, PI))
			_p(b, _torus(srx * 0.97, srx * 1.03), white, sc, Vector3(1, 0.45, sz))
			for d in [0.35, 0.62, 0.84]:
				var rr := srx * sqrt(1.0 - d * d) * 1.012
				_p(b, _torus(rr - srx * 0.045, rr + srx * 0.02), white, sc + Vector3(0, -sh * d, 0), Vector3(1, 0.5, sz))
			for sx in [-1.0, 1.0]:
				_p(A.feet, _box(Vector3(0.1, 0.03, 0.23) * u), Color(0.13, 0.36, 0.85), Vector3(foot.x * sx, 0.015 * u, foot.z + 0.015 * u))
				var toe := Vector3(foot.x * sx, 0.035 * u, foot.z + 0.085 * u)
				for k2 in [-1.0, 1.0]:
					_stroke(A.feet, toe, Vector3(foot.x * sx + 0.045 * u * k2, 0.04 * u, foot.z - 0.03 * u), 0.012 * u, white)
			var wr := A.wings[1] as Node3D
			if wr:
				var bag0 := Node3D.new()
				bag0.position = (A.wing_p as Vector3) + Vector3(0.05, -0.2, 0.07)
				wr.add_child(bag0)
				_p(bag0, _sphere(0.06, 12), white, Vector3.ZERO, Vector3(1.0, 1.15, 0.8))
				for k3 in 3:
					_p(bag0, _torus(0.05, 0.06), Color(0.9, 0.16, 0.14), Vector3(0, -0.035 + k3 * 0.035, 0), Vector3(1.0 - absf(k3 - 1) * 0.22, 0.6, 0.8 - absf(k3 - 1) * 0.18))
				for sx2 in [-1.0, 1.0]:
					_stroke(bag0, Vector3(0.03 * sx2, 0.06, 0), Vector3(0.012 * sx2, 0.12, 0), 0.006, white)
		"bag":
			# 套在頭上的牛皮紙袋：兩個挖歪的洞、紅色店章、油漬，頂上還插著一支竹籤
			var paper := Color(0.80, 0.63, 0.42)
			var c: Vector3 = A.bag_c
			var s: Vector3 = A.bag_s
			var bag := Node3D.new()
			bag.position = c
			bag.rotation = Vector3(0, 0, 0.06)
			h.add_child(bag)
			_p(bag, _box(s), paper, Vector3.ZERO)
			_p(bag, _box(Vector3(s.x * 1.03, s.y * 0.07, s.z * 1.03)), paper.darkened(0.2), Vector3(0, s.y * 0.465, 0))
			var fz := s.z * 0.5 + 0.001
			for sx in [-1.0, 1.0]:
				_p(bag, _box(Vector3(s.x * 0.012, s.y * 0.9, 0.002)), paper.darkened(0.12), Vector3(s.x * 0.36 * sx, -s.y * 0.03, fz))
			var e: Vector3 = A.eye
			var er := float(A.eye_r)
			_p(bag, _sphere(er * 1.9, 14), Color(0.04, 0.03, 0.03), Vector3(-e.x * 1.05, e.y - c.y, fz), Vector3(1, 1.1, 0.06))
			_p(bag, _sphere(er * 1.5, 14), Color(0.04, 0.03, 0.03), Vector3(e.x * 1.05, e.y - c.y + er * 0.3, fz), Vector3(1.1, 1, 0.06))
			for q in [Vector3(-0.3, -0.34, 0.9), Vector3(-0.18, -0.4, 0.6), Vector3(0.28, -0.3, 0.7)]:
				_p(bag, _sphere(s.x * 0.09 * q.z, 10), paper.darkened(0.2), Vector3(s.x * q.x, s.y * q.y, fz), Vector3(1.2, 1, 0.05))
			var red := Color(0.82, 0.13, 0.1)
			var ty := s.y * 0.3
			var hw := s.x * 0.3
			var hh := s.y * 0.09
			_path(bag, [Vector3(-hw, ty - hh, fz), Vector3(hw, ty - hh, fz), Vector3(hw, ty + hh, fz), Vector3(-hw, ty + hh, fz), Vector3(-hw, ty - hh, fz)], s.x * 0.008, red)
			_label(bag, "鹹酥雞", Vector3(0, ty, fz + 0.002), 0.00085 * u * (1.0 if rooster else 1.5), red, 56)
			var stick := Node3D.new()
			stick.position = Vector3(s.x * 0.18, s.y * 0.5, 0)
			stick.rotation = Vector3(0.1, 0, -0.35)
			bag.add_child(stick)
			_p(stick, _cyl(0.004 * u, 0.006 * u, 0.24 * u, 6), Color(0.9, 0.8, 0.55), Vector3(0, 0.08 * u, 0))
			for k4 in 2:
				_p(stick, _sphere(0.03 * u, 8), Color(0.78, 0.5, 0.2) if k4 == 0 else Color(0.7, 0.42, 0.16), Vector3(0, (0.07 + k4 * 0.055) * u, 0), Vector3(1, 0.85, 1))
		"allnighter":
			if slot == "body":
				# 深藍系服（胸口「資工」、背後「爆肝中」）、抱著筆電、頭上冒 Zzz
				var navy2 := Color(0.15, 0.21, 0.42)
				_cloth(A, navy2)
				_sleeves(A, navy2)
				var l := _label(b, "資工", _chest(A, 0, cy + 0.035 * u, 0.004), 0.0013 * u, white, 56)
				l.rotation.x = -0.12
				for k in 2:   # 胸口兩條白線
					var line := []
					for j in 7:
						line.append(_chest(A, (j - 3) * 0.035 * u, cy - (0.035 + k * 0.02) * u, 0.003))
					_path(b, line, 0.004 * u, white)
				var bl := _label(b, "爆肝中", back + Vector3(0, -0.03 * u, -0.012 * u), 0.0012 * u, white, 56)
				bl.rotation.y = PI
				var lap := Node3D.new()
				lap.position = _chest(A, 0, cy - 0.15 * u, 0.0) + Vector3(0, 0, 0.07 * u)
				b.add_child(lap)
				var alu := Color(0.66, 0.68, 0.72)
				_p(lap, _box(Vector3(0.2, 0.012, 0.13) * u), alu, Vector3.ZERO)
				_p(lap, _box(Vector3(0.2, 0.13, 0.01) * u), alu, Vector3(0, 0.06 * u, 0.068 * u), Vector3.ONE, Vector3(0.25, 0, 0))
				_p(lap, _box(Vector3(0.17, 0.1, 0.004) * u), Color(0.45, 0.8, 1.0), Vector3(0, 0.061 * u, 0.061 * u), Vector3.ONE, Vector3(0.25, 0, 0))
				_p(lap, _sphere(0.012 * u, 8), white, Vector3(0, 0.062 * u, 0.076 * u))
				var z := _label(h, "Zzz", Vector3(0.12 * u, A.over, 0), 0.0013 * u, Color(0.75, 0.85, 1.0), 64, true)
				fx.ops.append({"k": "doze", "node": z, "y": float(A.over) - 0.1 * u, "amp": 0.05 * u})
			else:
				# 黑眼圈＋額頭上的退熱貼
				var e2: Vector3 = A.eye
				var er2: float = A.eye_r
				for sx in [-1.0, 1.0]:
					_p(h, _sphere(er2 * 1.7, 10), Color(0.40, 0.31, 0.50), Vector3(e2.x * sx, e2.y - er2 * 1.5, e2.z - er2 * 0.55), Vector3(1.0, 0.6, 0.5), Vector3(0, 0.3 * sx, 0))
				_p(h, _box(Vector3(er2 * 4.2, er2 * 1.8, er2 * 0.5)), Color(0.72, 0.88, 1.0), Vector3(0, e2.y + er2 * 2.6, e2.z - er2 * 0.6), Vector3.ONE, Vector3(-0.35, 0, 0.05))
		"silver":
			if slot == "head":
				# 一頭往後梳的銀髮：雞冠收起來，換成一頂貼著頭的頭髮＋前面往上翹的瀏海
				_hide_comb(h)
				var hair := Color(0.90, 0.91, 0.94)
				var shade := hair.darkened(0.09)
				if rooster:
					_p(h, _sphere(1.0, 18), hair, Vector3(0, 0.07, -0.03), Vector3(0.106, 0.086, 0.12))
					_p(h, _sphere(1.0, 14), hair, Vector3(0, 0.135, 0.035), Vector3(0.075, 0.042, 0.07), Vector3(-0.45, 0, 0))
					_p(h, _sphere(1.0, 12), shade, Vector3(0, 0.05, -0.115), Vector3(0.085, 0.07, 0.05))
					for sx in [-1.0, 1.0]:
						_p(h, _sphere(1.0, 12), shade, Vector3(0.088 * sx, 0.055, -0.01), Vector3(0.03, 0.055, 0.085))
						_stroke(h, Vector3(0.03 * sx, 0.16, 0.06), Vector3(0.045 * sx, 0.13, -0.09), 0.012, shade)
				else:
					_p(h, _sphere(1.0, 18), hair, Vector3(0, 0.12, -0.02), Vector3(0.335, 0.195, 0.325))
					_p(h, _sphere(1.0, 14), hair, Vector3(0, 0.30, 0.10), Vector3(0.2, 0.085, 0.17), Vector3(-0.4, 0, 0))
					for sx in [-1.0, 1.0]:
						_stroke(h, Vector3(0.09 * sx, 0.34, 0.15), Vector3(0.13 * sx, 0.27, -0.2), 0.03, shade)
			else:
				_glasses(A, Color(0.2, 0.2, 0.22), 0.004, true)
		"delivery":
			# 背在背上的保溫箱：深色上蓋、反光條、白字、兩條背帶
			var box := Node3D.new()
			box.position = back + Vector3(0, 0.08 * u, -0.14 * u)
			box.rotation.x = 0.06
			b.add_child(box)
			var orange := Color(0.97, 0.5, 0.1)
			_p(box, _box(Vector3(0.31, 0.3, 0.27) * u), orange, Vector3.ZERO)
			_p(box, _box(Vector3(0.325, 0.06, 0.285) * u), orange.darkened(0.35), Vector3(0, 0.135 * u, 0))
			_p(box, _box(Vector3(0.315, 0.022, 0.275) * u), Color(0.95, 0.95, 0.85), Vector3(0, -0.105 * u, 0))
			_p(box, _box(Vector3(0.09, 0.02, 0.02) * u), black, Vector3(0, 0.175 * u, 0))
			var dl := _label(box, "家豪快送", Vector3(0, 0.03 * u, -0.1365 * u), 0.0012 * u, white, 56)
			dl.rotation.y = PI
			_claw(box, Vector3(0, -0.045 * u, -0.137 * u), 0.028 * u, white, PI)
			for sx in [-1.0, 1.0]:
				var strap := []
				for j in 6:
					var a := j / 5.0
					strap.append(_chest(A, 0.1 * u * sx, cy + (0.16 - a * 0.26) * u, 0.006 * u))
				_path(b, strap, 0.013 * u, black)
				_stroke(b, strap[0], back + Vector3(0.1 * u * sx, 0.2 * u, 0.0), 0.013 * u, black)
		"azhi":
			# 背後的大雞爪標誌＋FRIED 字樣＋會跳的音量條；脖子上掛一副耳機
			var mark := Node3D.new()
			mark.position = back + Vector3(0, 0.0, -0.012 * u)
			if rooster:
				mark.position.y -= 0.05      # 上面是尾羽，圖案往下挪
			b.add_child(mark)
			_claw(mark, Vector3.ZERO, 0.085 * u, white, PI)
			var t1 := _label(mark, "FRIED", Vector3(0, -0.1 * u, 0.014 * u), 0.0013 * u, white, 56)
			t1.rotation = Vector3(-0.3, PI, 0)
			var t2 := _label(mark, "JIA-HAO REMIX", Vector3(0, -0.15 * u, 0.04 * u), 0.00055 * u, white, 56)
			t2.rotation = Vector3(-0.5, PI, 0)
			for sx in [-1.0, 1.0]:
				for j in 3:
					var bar := _p(mark, _box(Vector3(0.014, 0.07, 0.005) * u), white, Vector3((0.1 + j * 0.026) * u * sx, 0.01 * u, 0.014 * u + j * 0.014 * u))
					fx.ops.append({"k": "eq", "node": bar, "ph": j * 1.3 + (0.7 if sx > 0.0 else 0.0)})
			var cup := Vector3(0.17, 0.73, 0.1) if rooster else Vector3(0.40, 0.60, 0.06)
			var cr := 0.05 if rooster else 0.075
			var redc := Color(0.9, 0.18, 0.16)
			for sx in [-1.0, 1.0]:
				_p(b, _cyl(cr, cr, cr * 0.7, 16), white, Vector3(cup.x * sx, cup.y, cup.z), Vector3.ONE, Vector3(0, 0, PI * 0.5))
				_p(b, _cyl(cr * 0.55, cr * 0.55, cr * 0.75, 16), redc, Vector3(cup.x * sx * 1.01, cup.y, cup.z), Vector3.ONE, Vector3(0, 0, PI * 0.5))
			var band := []
			for j in 9:
				var a2 := PI * j / 8.0
				band.append(Vector3(cos(a2) * cup.x, cup.y + 0.01, cup.z - sin(a2) * cup.x * 1.25))
			_path(b, band, cr * 0.22, white)
		"cleanroom":
			var suit := Color(0.80, 0.90, 0.98)
			var seam := Color(0.55, 0.70, 0.88)
			if slot == "body":
				# 連身無塵衣：中間一條拉鍊、腰上一圈縫線、識別證、藍色鞋套
				_cloth(A, suit)
				_sleeves(A, suit)
				var zipl := []
				for j in 9:
					zipl.append(_chest(A, 0, neck.y - 0.01 * u - j * 0.04 * u, 0.003 * u))
				_path(b, zipl, 0.006 * u, seam)
				_p(b, _sphere(0.012 * u, 8), silver, zipl[0] + Vector3(0, 0, 0.004 * u))
				var waist := []
				for j in 9:
					waist.append(_chest(A, (j - 4) * 0.045 * u, cy - 0.12 * u, 0.003 * u))
				_path(b, waist, 0.005 * u, seam)
				var idc := Node3D.new()
				idc.position = _chest(A, 0.1 * u, cy + 0.03 * u, 0.006 * u)
				idc.rotation.y = 0.4
				b.add_child(idc)
				_p(idc, _box(Vector3(0.07, 0.045, 0.005) * u), white, Vector3.ZERO)
				_p(idc, _box(Vector3(0.07, 0.014, 0.006) * u), Color(0.2, 0.45, 0.85), Vector3(0, 0.016 * u, 0))
				_label(idc, "FAB", Vector3(0, -0.007 * u, 0.004 * u), 0.0004 * u, Color(0.1, 0.1, 0.15))
				for sx in [-1.0, 1.0]:
					_p(A.feet, _sphere(0.065 * u, 10), Color(0.3, 0.55, 0.9), Vector3(foot.x * sx, 0.035 * u, foot.z), Vector3(1.0, 0.6, 1.5))
			else:
				# 頭套＋口罩，只露出眼睛；頭上飄著「奈米」
				if rooster:
					_p(h, _sphere(0.16, 18), suit, Vector3(0, 0.05, -0.08), Vector3(1.05, 1.3, 1.0))
					_p(h, _torus(0.105, 0.135), seam, Vector3(0, 0.035, 0.055), Vector3(1.0, 1.0, 1.15), Vector3(PI * 0.5, 0, 0))
				else:
					_p(h, _half(0.34, 0.4), suit, Vector3(0, 0.125, 0), Vector3(1, 1, 0.95))
					_p(h, _torus(0.315, 0.345), seam, Vector3(0, 0.125, 0), Vector3(1, 0.4, 0.95))
				var mc2: Vector3 = A.mask_c
				var mr2: Vector3 = A.mask_r
				_p(h, _sphere(1.0, 18), Color(0.94, 0.97, 1.0), mc2, mr2)
				for k in 3:   # 口罩的摺線
					var pl := []
					for j in 7:
						pl.append(_ell(mc2, mr2, (j - 3) / 3.0 * mr2.x * 0.7, (k - 1) * mr2.y * 0.38, 0.001))
					_path(h, pl, 0.003 * u, seam)
				var nl := _label(h, "奈米", Vector3(0, A.over, 0), 0.0016 * u, Color(0.6, 0.95, 1.0), 64, true)
				fx.ops.append({"k": "float", "node": nl, "y": float(A.over), "amp": 0.02 * u})
		"colonel":
			if slot == "body":
				# 白西裝：翻領、黑色細領結、金扣子
				var cream := Color(1.0, 0.97, 0.87)
				_cloth(A, cream)
				_sleeves(A, cream)
				for sx in [-1.0, 1.0]:
					var lapel := []
					for j in 6:
						var a := j / 5.0
						lapel.append(_chest(A, (0.105 - a * 0.1) * u * sx, neck.y - 0.02 * u - a * 0.2 * u, 0.004 * u))
					_path(b, lapel, 0.012 * u, cream.darkened(0.3))
				_p(b, _sphere(0.02 * u, 8), black, neck + Vector3(0, -0.005 * u, 0.012 * u))
				for sx in [-1.0, 1.0]:
					_p(b, _sphere(0.036 * u, 10), black, neck + Vector3(0.042 * u * sx, -0.005 * u, 0.006 * u), Vector3(1.0, 0.7, 0.4), Vector3(0, 0, 0.25 * sx))
					_stroke(b, neck + Vector3(0.008 * u * sx, -0.02 * u, 0.014 * u), neck + Vector3(0.026 * u * sx, -0.12 * u, 0.02 * u), 0.007 * u, black)
				for k2 in 3:
					_p(b, _sphere(0.018 * u, 8), gold, _chest(A, 0, cy - 0.03 * u - k2 * 0.07 * u, 0.004))
			else:
				# 頭上倒扣的炸雞桶（白底紅條、正面一個「豪」字）、黑框眼鏡、白色山羊鬍和白眉毛
				var r: float = A.hat_r
				var redb := Color(0.86, 0.12, 0.12)
				var bucket := Node3D.new()
				bucket.position = Vector3(0, float(A.top) + 0.05 * u, -0.01 * u)
				bucket.rotation = Vector3(-0.1, 0, 0.07)
				h.add_child(bucket)
				_p(bucket, _cyl(r * 0.78, r, 0.17 * u, 20), white, Vector3.ZERO)
				for k3 in 6:
					var a3 := TAU * (k3 + 0.5) / 6.0
					_p(bucket, _box(Vector3(r * 0.4, 0.17 * u, 0.008 * u)), redb, Vector3(sin(a3), 0, cos(a3)) * r * 0.9, Vector3.ONE, Vector3(-0.19, a3, 0))
				_p(bucket, _torus(r * 0.93, r * 1.07), redb, Vector3(0, -0.08 * u, 0))
				_p(bucket, _cyl(r * 0.8, r * 0.8, 0.012 * u, 20), redb, Vector3(0, 0.088 * u, 0))
				_p(bucket, _cyl(r * 0.36, r * 0.36, 0.006 * u, 18), white, Vector3(0, -0.005 * u, r * 0.905), Vector3.ONE, Vector3(PI * 0.5 - 0.19, 0, 0))
				_label(bucket, "豪", Vector3(0, -0.005 * u, r * 0.92), 0.0012 * u * (1.0 if rooster else 1.25), redb, 56).rotation.x = -0.19
				_glasses(A, black, 0.008)
				_p(h, _cyl(0.032 * u, 0.0, 0.11 * u, 8), white, A.beak + Vector3(0, -0.09 * u, 0.005 * u))
				var e3: Vector3 = A.eye
				var er3: float = A.eye_r
				for sx in [-1.0, 1.0]:
					_stroke(h, Vector3((e3.x - er3) * sx, e3.y + er3 * 2.5, e3.z + 0.012 * u), Vector3((e3.x + er3 * 1.4) * sx, e3.y + er3 * 2.0, e3.z - 0.002 * u), er3 * 0.42, white)
		"leather":
			# 亮面黑皮衣：立起來的領子、正中間一條銀拉鍊、兩個斜的拉鍊口袋、下襬的皮帶扣；過關時舉起顯示卡
			var lea := Color(0.05, 0.05, 0.06)
			var zmat := _gloss(silver, 0.3, 0.9)
			_cloth(A, lea, true)
			_sleeves(A, lea, true)
			for sx in [-1.0, 1.0]:
				# 領子：脖子兩邊往外翻的兩片
				var flap := _p(b, _sphere(0.06 * u, 12), lea, neck + Vector3(0.065 * u * sx, -0.012 * u, -0.022 * u), Vector3(1.05, 0.62, 0.5), Vector3(0.25, 0, -0.55 * sx))
				flap.material_override = _gloss(Color(0.09, 0.09, 0.1), 0.4)
				_p(b, _sphere(0.011 * u, 8), silver, neck + Vector3(0.105 * u * sx, -0.035 * u, 0.0)).material_override = zmat
				# 斜的拉鍊口袋
				var pk := []
				for j in 4:
					pk.append(_chest(A, (0.085 + j * 0.022) * u * sx, cy - (0.05 + j * 0.022) * u, 0.003 * u))
				_path(b, pk, 0.006 * u, silver, zmat)
				_p(b, _sphere(0.011 * u, 8), silver, pk[0] + Vector3(0, -0.012 * u, 0.004 * u)).material_override = zmat
			var zp := []
			for j in 11:
				zp.append(_chest(A, 0.0, neck.y - 0.05 * u - j * 0.03 * u, 0.003 * u))
			_path(b, zp, 0.007 * u, silver, zmat)
			_p(b, _box(Vector3(0.018, 0.034, 0.008) * u), silver, zp[1] + Vector3(0, 0, 0.007 * u)).material_override = zmat
			# 下襬的皮帶扣
			_p(b, _box(Vector3(0.055, 0.036, 0.01) * u), silver, zp[10] + Vector3(0, -0.01 * u, 0.004 * u)).material_override = zmat
			# 過關時舉起來的顯示卡
			var gpu := Node3D.new()
			gpu.position = Vector3(0.0, float(A.over) - 0.12 * u, 0.02 * u)
			gpu.rotation = Vector3(0, 0, 0.12)
			gpu.visible = false
			h.add_child(gpu)
			_p(gpu, _box(Vector3(0.26, 0.11, 0.035) * u), Color(0.12, 0.13, 0.14), Vector3.ZERO)
			_p(gpu, _box(Vector3(0.265, 0.018, 0.037) * u), Color(0.45, 0.85, 0.1), Vector3(0, 0.05 * u, 0))
			_p(gpu, _box(Vector3(0.012, 0.13, 0.04) * u), silver, Vector3(-0.136 * u, -0.005 * u, 0))
			for sx in [-1.0, 1.0]:
				_p(gpu, _cyl(0.042 * u, 0.042 * u, 0.006 * u, 16), Color(0.3, 0.32, 0.34), Vector3(0.06 * u * sx, -0.005 * u, 0.018 * u), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
				_p(gpu, _cyl(0.014 * u, 0.014 * u, 0.008 * u, 10), silver, Vector3(0.06 * u * sx, -0.005 * u, 0.02 * u), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
			fx.ops.append({"k": "win", "node": gpu, "s": Vector3.ONE})
		"gown":
			if slot == "body":
				# 黑色學士袍：金色披肩帶、白領子、翅膀下夾著一卷畢業證書
				_cloth(A, black)
				_sleeves(A, black)
				for sx in [-1.0, 1.0]:
					var stole := []
					for j in 7:
						var a := j / 6.0
						stole.append(_chest(A, (0.12 - a * 0.115) * u * sx, neck.y - 0.01 * u - a * 0.24 * u, 0.006 * u))
					_path(b, stole, 0.02 * u, gold)
					_stroke(b, neck + Vector3(0.012 * u * sx, -0.005 * u, 0.012 * u), neck + Vector3(0.05 * u * sx, -0.05 * u, 0.006 * u), 0.011 * u, white)
				var wl := A.wings[0] as Node3D
				if wl:
					var roll := Node3D.new()
					roll.position = (A.wing_p as Vector3) * Vector3(-1, 1, 1) + Vector3(-0.05, -0.08, 0.1)
					roll.rotation = Vector3(PI * 0.5 - 0.3, 0, 0.2)
					wl.add_child(roll)
					_p(roll, _cyl(0.025, 0.025, 0.2, 12), white, Vector3.ZERO)
					_p(roll, _torus(0.024, 0.032), Color(0.86, 0.14, 0.14), Vector3.ZERO)
			else:
				# 方帽＋金色流蘇；過關時往上丟
				var cap := Node3D.new()
				var capy := float(A.top) + 0.03 * u
				cap.position = Vector3(0, capy, -0.01 * u)
				h.add_child(cap)
				var r2: float = A.hat_r
				_p(cap, _cyl(r2 * 0.78, r2 * 0.88, 0.075 * u, 16), black, Vector3.ZERO)
				_p(cap, _box(Vector3(r2 * 2.7, 0.014 * u, r2 * 2.7)), black, Vector3(0, 0.043 * u, 0), Vector3.ONE, Vector3(0, 0.35, 0))
				_p(cap, _sphere(0.016 * u, 8), gold, Vector3(0, 0.054 * u, 0))
				_stroke(cap, Vector3(0, 0.054 * u, 0), Vector3(r2 * 1.1, 0.05 * u, r2 * 0.75), 0.005 * u, gold)
				_stroke(cap, Vector3(r2 * 1.1, 0.05 * u, r2 * 0.75), Vector3(r2 * 1.12, -0.07 * u, r2 * 0.77), 0.005 * u, gold)
				_p(cap, _capsule(0.012 * u, 0.05 * u), gold, Vector3(r2 * 1.12, -0.09 * u, r2 * 0.77))
				fx.ops.append({"k": "toss", "node": cap, "y": capy, "amp": 0.5 * u})
