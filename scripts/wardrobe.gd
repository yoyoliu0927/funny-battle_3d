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
		"desc": "班上第三個家豪。畢業前記得拿下來。", "quip": "全班喊家豪，三個人回頭。", "win": ""},
	{"id": "mask", "name": "黑口罩", "slots": ["face"], "price": 1,
		"desc": "帥度＋3，辨識度不變。阿志都這樣戴。", "quip": "戴了還是看得出來是雞。", "win": ""},
	{"id": "slippers", "name": "藍白拖＋吊嘎", "slots": ["body"], "price": 1,
		"desc": "全台通用正式服裝，早餐店到教室都能穿。外送時請勿穿著。", "quip": "這套穿去哪都像剛睡醒。", "win": ""},
	{"id": "bag", "name": "鹹酥雞紙袋", "slots": ["head"], "price": 1,
		"desc": "社恐神器，附竹籤一支。聽說上校看了會生氣。", "quip": "……這袋子，是我攤上的吧？", "win": ""},
	{"id": "allnighter", "name": "期末爆肝套組", "slots": ["body", "face"], "price": 1,
		"desc": "系服、黑眼圈、抱著筆電，站著也能睡。", "quip": "報告明天交？那你還來逛街。", "win": "交了！"},
	{"id": "silver", "name": "銀髮＋細框眼鏡", "slots": ["head", "face"], "price": 2,
		"desc": "雞冠換成一頭往後梳的銀髮，配細框眼鏡。跟皮衣是好朋友。", "quip": "看起來身價不一樣了。", "win": ""},
	{"id": "delivery", "name": "外送保溫箱", "slots": ["back"], "price": 2,
		"desc": "餐點已送達，人還在路上。穿拖鞋送會被客訴。", "quip": "箱子裡裝的最好不是你同學。", "win": "您的餐點已送達"},
	{"id": "azhi", "name": "阿志帽 T", "slots": ["body"], "price": 2,
		"desc": "金鍊、大耳機，低音開到攤子會震。背後有驚喜。", "quip": "排氣管拔掉的別停我攤前。", "win": ""},
	{"id": "cleanroom", "name": "無塵衣", "slots": ["body", "head"], "price": 2,
		"desc": "護國神雞。全身包起來只露眼睛，口罩要戴好戴滿。", "quip": "一根羽毛都不准掉。", "win": "良率 100%"},
	{"id": "colonel", "name": "家豪上校", "slots": ["body", "head"], "price": 2,
		"desc": "祕方不外傳，因為就是他自己。", "quip": "那桶本來裝誰，你知道嗎？", "win": "本店不賣自己人"},
	{"id": "leather", "name": "爸爸的皮衣", "slots": ["body"], "price": 3,
		"desc": "爸爸說穿這件，買什麼都算省。配銀髮更像。", "quip": "你爸知道你穿這樣嗎？", "win": "買越多，省越多"},
	{"id": "gown", "name": "學士服", "slots": ["body", "head"], "price": -1,
		"desc": "全部關卡三星才拿得到。金色披肩帶、畢業證書，過關時丟帽子。", "quip": "恭喜畢業。學貸記得還。", "win": "畢業了！"},
]

## 幾件一起穿的時候，鴨子老闆會說的話（need 裡的每一件都穿著才算）
const COMBOS := [
	{"need": ["silver", "leather"], "line": "這位客人，顯卡能算我便宜嗎？"},
	{"need": ["bag", "colonel"], "line": "自己人打自己人？"},
	{"need": ["mask", "azhi"], "line": "大哥，攤位費我上禮拜繳過了。"},
	{"need": ["delivery", "slippers"], "line": "穿這樣送餐，會被負評喔。"},
	{"need": ["tag", "gown"], "line": "畢業了還掛學生證，延畢喔？"},
	{"need": ["mask", "cleanroom"], "line": "口罩戴兩層，良率會比較高嗎？"},
]

## 玩家發現過幾組組合（存檔裡記著）
static func combos_found() -> int:
	var cf := _load()
	var n := 0
	for i in COMBOS.size():
		if bool(cf.get_value("combos", str(i), false)):
			n += 1
	return n

## 記下這句組合台詞被看到了；回傳是不是第一次
static func mark_combo(line: String) -> bool:
	for i in COMBOS.size():
		if String(COMBOS[i].line) == line:
			var cf := _load()
			if bool(cf.get_value("combos", str(i), false)):
				return false
			cf.set_value("combos", str(i), true)
			cf.save(save_path())
			return true
	return false

## 這套穿著有沒有湊到組合；focus 是現在游標選的那一件（有包含它的組合才算）
static func combo_line(lk: Dictionary, focus := "") -> String:
	var worn := lk.values()
	for c in COMBOS:
		if focus != "" and not (focus in c.need):
			continue
		var ok := true
		for id in c.need:
			ok = ok and worn.has(id)
		if ok:
			return String(c.line)
	return ""

## 試穿中（商店用）：不是空的就蓋過存檔裡的穿著
static var preview: Dictionary = {}

# ================================================================== 存檔

## 存檔放哪裡。測試用：命令列加 -- --wardrobe=user://別的檔名.cfg，就不會動到玩家真正的存檔
static func save_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardrobe="):
			return a.substr(11)
	return PATH

static func _load() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(save_path())
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
		cf.save(save_path())

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
	cf.save(save_path())
	return true

## 花掉幾顆星（買船用，跟買衣服共用同一個錢包）；星星不夠回傳 false
static func spend(cost: int) -> bool:
	if cost < 0 or wallet() < cost:
		return false
	var cf := _load()
	cf.set_value("meta", "spent", int(cf.get_value("meta", "spent", 0)) + cost)
	cf.save(save_path())
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
	cf.save(save_path())

# ---------------------------------------------------------------- 眼睛

## 家豪的眼睛：玩家在商店二選一，選了之後所有關卡（還有地圖、載入畫面）都換成那一種
##   "dot"＝小黑眼、"drawn"＝手繪大眼（原本只有冰雪島在用的那一種）
const EYES := ["dot", "drawn"]
const EYE_NAMES := {"dot": "小黑眼", "drawn": "手繪大眼"}
## 還沒選過的時候用哪一種
const EYE_DEFAULT := "drawn"
const EYE_TEX := "res://assets/characters/hero_eyes.png"

## 現在用哪一種眼睛
static func eyes() -> String:
	var v := String(_load().get_value("look", "eyes", EYE_DEFAULT))
	return v if v in EYES else EYE_DEFAULT

static func set_eyes(v: String) -> void:
	var cf := _load()
	cf.set_value("look", "eyes", v if v in EYES else EYE_DEFAULT)
	cf.save(save_path())

## （舊名字，跟 eyes() 一樣）
static func eye_style(_level_default := "") -> String:
	return eyes()

## 把家豪的小黑眼換成手繪大眼（兩片貼圖，跟冰雪島工人的臉同一套畫法）
static func draw_eyes(root: Node3D, kind: String, hooded := false) -> void:
	var head := root.find_child("Head", true, false) as Node3D
	if head == null or head.has_meta("drawn_eyes") or not ResourceLoader.exists(EYE_TEX):
		return
	# 收掉原本的小黑眼：站著的家豪是「空節點裡包一顆半球」，圓滾滾的家豪是直接掛在頭上的黑色半球
	for c in head.get_children():
		if c is MeshInstance3D:
			var sm := (c as MeshInstance3D).mesh as SphereMesh
			if sm and sm.is_hemisphere and sm.radius < 0.05:
				(c as MeshInstance3D).visible = false
		elif String(c.name).begins_with("Eye"):
			(c as Node3D).visible = false
	var tex := load(EYE_TEX) as Texture2D
	var rooster := kind == "rooster"
	var size := 0.088 if rooster else 0.15
	var pos := Vector3(0.05, 0.058, 0.103) if rooster else Vector3(0.1, 0.085, (0.365 if hooded else 0.33) + 0.022)
	var yaw := 0.4 if rooster else 0.32
	for k in 2:
		var eye := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(size, size)
		eye.mesh = qm
		var em := StandardMaterial3D.new()
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		em.alpha_scissor_threshold = 0.5
		em.albedo_texture = tex
		em.uv1_scale = Vector3(0.5, 1, 1)
		em.uv1_offset = Vector3(0.5 * k, 0, 0)
		em.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		eye.material_override = em
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sx := -1.0 if k == 0 else 1.0
		eye.position = Vector3(pos.x * sx, pos.y, pos.z)
		eye.rotation = Vector3(-0.1, yaw * sx, 0)
		head.add_child(eye)
	head.set_meta("drawn_eyes", true)

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
			if not is_instance_valid(op.node):
				continue
			var n: Node3D = op.node
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
				"raise":      # 過關時把翅膀舉起來（手上拿著東西），平常不管它
					if won:
						if not op.has("base"):
							op["base"] = n.rotation
						n.rotation = Vector3(0, 0, float(op.ang) + sin(t * 7.0) * 0.08)
					elif op.has("base"):
						n.rotation = op.base
						op.erase("base")
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

static func _sphere(r: float, seg := 24) -> SphereMesh:
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
	s.radial_segments = 40
	s.rings = 14
	return s

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 5
	return c

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func _cyl(top: float, bottom: float, h: float, seg := 28) -> CylinderMesh:
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
	t.rings = 40
	t.ring_segments = 10
	return t

## 圓角方塊（卡片、箱子、鞋底、筆電都用它，邊角才不會像刀切的）。r 是圓角半徑
static var _rbox_cache := {}
static func _rbox(size: Vector3, r: float, seg := 4) -> ArrayMesh:
	r = minf(r, minf(size.x, minf(size.y, size.z)) * 0.499)
	var key := "%s|%.4f|%d" % [size, r, seg]
	if _rbox_cache.has(key):
		return _rbox_cache[key]
	var inner := size * 0.5 - Vector3.ONE * r
	var lon_n := seg * 4
	var lat_n := seg * 2
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	# 一顆球切成八塊，每一塊推到方塊的一個角上；角度都錯開半格，剛好不會踩在軸上
	for j in lat_n:
		var phi := (j + 0.5) / lat_n * PI
		for i in lon_n:
			var th := (i + 0.5) / lon_n * TAU
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			verts.append(Vector3(signf(d.x) * inner.x, signf(d.y) * inner.y, signf(d.z) * inner.z) + d * r)
			norms.append(d)
	var top_c := verts.size()
	verts.append(Vector3(0, size.y * 0.5, 0))
	norms.append(Vector3.UP)
	var bot_c := verts.size()
	verts.append(Vector3(0, -size.y * 0.5, 0))
	norms.append(Vector3.DOWN)
	var tri := func(a: int, b: int, c: int) -> void:
		# Godot 的正面是順時針：算出來的法線朝外就要換個方向
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if n.dot(norms[a] + norms[b] + norms[c]) > 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])
	for j in lat_n - 1:
		for i in lon_n:
			var a := j * lon_n + i
			var b := j * lon_n + (i + 1) % lon_n
			var c := (j + 1) * lon_n + i
			var d2 := (j + 1) * lon_n + (i + 1) % lon_n
			tri.call(a, b, c)
			tri.call(b, d2, c)
	for i in lon_n:
		tri.call(top_c, i, (i + 1) % lon_n)
		tri.call(bot_c, (lat_n - 1) * lon_n + i, (lat_n - 1) * lon_n + (i + 1) % lon_n)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_rbox_cache[key] = m
	return m

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
		l.outline_size = 22
		l.outline_modulate = Color(0.12, 0.07, 0.05)
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
	var big_eyes := head.has_meta("drawn_eyes")
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
	if big_eyes:
		# 手繪大眼比小黑眼大、位置高一點：眼鏡、黑眼圈跟著放大，口罩往下讓一點
		if kind == "rooster":
			A.eye = Vector3(0.052, 0.056, 0.1)
			A.eye_r = 0.027
			A.mask_c = (A.mask_c as Vector3) + Vector3(0, -0.014, 0)
		else:
			A.eye = Vector3(0.1, 0.085, float(A.eye.z) + 0.02)
			A.eye_r = 0.045
			A.mask_c = (A.mask_c as Vector3) + Vector3(0, -0.02, 0)
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

## 一片三角形的布（翻領、露出來的內搭）：a、b、c 三個角
static func _flap(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, col: Color, mat: Material = null) -> MeshInstance3D:
	var n := (b - a).cross(c - a).normalized()
	if n.z < 0.0:
		n = -n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in [a, b, c, a, c, b]:      # 正反兩面都畫，法線都朝外
		st.set_normal(n)
		st.add_vertex(q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat if mat else _mat(col)
	parent.add_child(mi)
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
static func _cloth(A: Dictionary, col: Color, gloss := false, hem := true, trim: Variant = null) -> void:
	var b: Node3D = A.body
	var tc: Color = trim if trim != null else col.darkened(0.18)
	var hems: Array = []
	var parts: Array = []
	if A.kind == "rooster":
		parts.append(_p(b, _sphere(0.27, 20), col.darkened(0.08), Vector3(0, 0.46, -0.06), Vector3(0.9, 0.85, 1.15) * 1.06))
		parts.append(_p(b, _sphere(0.25, 20), col, Vector3(0, 0.55, 0.08), Vector3(0.92, 1.0, 0.95) * 1.06))
		_p(b, _sphere(0.13, 16), Color(0.97, 0.96, 0.93), Vector3(0, 0.74, 0.2), Vector3(1.0, 0.45, 0.85))
		if hem:   # 下襬：一圈比較深的收邊，看起來才是「穿著一件衣服」
			hems.append(_p(b, _torus(0.18, 0.222), tc, Vector3(0, 0.3, -0.055), Vector3(1.0, 1.1, 1.26)))
	else:
		# 圓滾滾的家豪：臉長在身體上，所以衣服是一個從脖子往下包的碗
		parts.append(_p(b, _half(0.425, 0.55), col, Vector3(0, 0.57, 0), Vector3(1, 1, 0.95), Vector3(0, 0, PI)))
		parts.append(_p(b, _torus(0.385, 0.425), col.darkened(0.12), Vector3(0, 0.57, 0), Vector3(1, 0.5, 0.95)))
		if hem:
			hems.append(_p(b, _torus(0.265, 0.31), tc, Vector3(0, 0.185, 0), Vector3(1, 0.8, 0.95)))
	if gloss:
		for mi in parts:
			(mi as MeshInstance3D).material_override = _gloss(col, 0.6)

static func _sleeves(A: Dictionary, col: Color, gloss := false, trim: Variant = null) -> void:
	var tc: Color = trim if trim != null else col.darkened(0.2)
	for i in 2:
		var w := A.wings[i] as Node3D
		if w == null:
			continue
		var sx := -1.0 if i == 0 else 1.0
		var wp: Vector3 = A.wing_p
		var wr: Vector3 = A.wing_rot
		var ws: Vector3 = (A.wing_s as Vector3) * 1.13
		var mi := _p(w, _sphere(0.15, 20), col, Vector3(wp.x * sx, wp.y, wp.z), ws, Vector3(wr.x, 0, wr.z * sx))
		# 袖口：靠近翅膀尖的一圈收邊，白色的翅膀尖從袖口露出來
		var cuff := _p(w, _torus(0.74, 1.0), tc, Vector3(wp.x * sx, wp.y - 0.15 * ws.y * 0.62, wp.z), Vector3(0.15 * ws.x * 0.82, 0.02, 0.15 * ws.z * 0.8), Vector3(wr.x, 0, wr.z * sx))
		_p(w, _sphere(0.15, 14), Color(0.96, 0.96, 0.94), Vector3(wp.x * sx, wp.y - 0.15 * ws.y * 0.5, wp.z), ws * Vector3(0.72, 0.62, 0.72), Vector3(wr.x, 0, wr.z * sx))
		if gloss:
			mi.material_override = _gloss(col, 0.6)

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
	fx.process_priority = 10      # 排在戰局擺姿勢之後，舉翅膀才不會被蓋掉
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
			_p(card, _rbox(Vector3(0.115, 0.08, 0.008) * u, 0.004 * u), white, Vector3.ZERO)
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
			# 米白吊嘎（深藍滾邊的 U 領和肩帶）＋藍白直條四角褲（有兩個褲管）＋藍白拖＋翅膀上掛一袋紅白塑膠袋
			var navy := Color(0.14, 0.25, 0.55)
			_cloth(A, Color(0.80, 0.78, 0.71), false, false)
			var rim := []
			for k in 13:
				var t := (k - 6) / 6.0
				rim.append(_chest(A, t * 0.115 * u, neck.y - 0.015 * u - (1.0 - t * t) * 0.1 * u, 0.006 * u))
			_path(b, rim, 0.009 * u, navy)
			for sx in [-1.0, 1.0]:
				var strap := []
				for j in 6:
					strap.append(_chest(A, 0.115 * u * sx, neck.y - 0.015 * u + j * 0.022 * u, 0.006 * u))
				_path(b, strap, 0.009 * u, navy)
			# 四角褲：只包住肚子下半，深藍鬆緊帶褲頭、寬的藍白直條、兩條腿各套一截褲管
			var sc := Vector3(0, 0.405, -0.03) if rooster else Vector3(0, 0.33, 0)
			var srx := 0.275 if rooster else 0.42
			var sh := 0.2 if rooster else 0.27
			var sz := 1.4 if rooster else 0.95
			var blue := Color(0.36, 0.62, 0.95)
			_p(b, _half(srx, sh), blue, sc, Vector3(1, 1, sz), Vector3(0, 0, PI))
			_p(b, _torus(srx * 0.93, srx * 1.05), navy, sc, Vector3(1, 0.75, sz))
			var stripes := 8
			for k in stripes:
				var th := TAU * (k + 0.5) / stripes
				var mer := []
				for j in 6:
					var t2 := 0.12 + j * 0.2
					mer.append(sc + Vector3(srx * cos(t2) * cos(th), -sh * sin(t2), srx * sz * cos(t2) * sin(th)) * Vector3(1.012, 1.0, 1.012) + Vector3(0, 0, -sc.z * 0.012))
				_path(b, mer, 0.017 if rooster else 0.024, white)
			for sx in [-1.0, 1.0]:
				# 褲管
				var ly := 0.115 if rooster else 0.055
				var lh := 0.13 if rooster else 0.09
				var lr := 0.068 if rooster else 0.095
				_p(A.feet, _cyl(lr * 0.9, lr, lh, 24), blue, Vector3(foot.x * sx, ly, 0.0))
				for k in 6:
					var a := TAU * k / 6.0
					_stroke(A.feet, Vector3(foot.x * sx + cos(a) * lr * 0.92, ly + lh * 0.45, sin(a) * lr * 0.92), Vector3(foot.x * sx + cos(a) * lr * 1.0, ly - lh * 0.45, sin(a) * lr * 1.0), 0.011, white)
				_p(A.feet, _torus(lr * 0.86, lr * 1.12), navy, Vector3(foot.x * sx, ly - lh * 0.5, 0.0), Vector3(1, 0.6, 1))
				# 藍白拖：圓角鞋底＋白色人字帶
				_p(A.feet, _rbox(Vector3(0.1, 0.03, 0.23) * u, 0.014 * u), Color(0.13, 0.36, 0.85), Vector3(foot.x * sx, 0.015 * u, foot.z + 0.015 * u))
				_p(A.feet, _rbox(Vector3(0.092, 0.008, 0.22) * u, 0.004 * u), white, Vector3(foot.x * sx, 0.032 * u, foot.z + 0.015 * u))
				var toe := Vector3(foot.x * sx, 0.04 * u, foot.z + 0.085 * u)
				for k2 in [-1.0, 1.0]:
					_stroke(A.feet, toe, Vector3(foot.x * sx + 0.045 * u * k2, 0.045 * u, foot.z - 0.03 * u), 0.012 * u, white)
			var wr := A.wings[1] as Node3D
			if wr:
				var bag0 := Node3D.new()
				bag0.position = (A.wing_p as Vector3) + Vector3(0.05, -0.2, 0.07)
				wr.add_child(bag0)
				_p(bag0, _sphere(0.06, 16), white, Vector3.ZERO, Vector3(1.0, 1.15, 0.8))
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
			_p(bag, _rbox(s, s.x * 0.03), paper, Vector3.ZERO)
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
				# 深藍系服（胸口兩行字「NTU／IM」、背後「爆肝中」）、抱著筆電、頭上冒 Zzz
				var navy2 := Color(0.15, 0.21, 0.42)
				_cloth(A, navy2)
				_sleeves(A, navy2)
				var l := _label(b, "NTU\nIM", _chest(A, 0, cy + 0.04 * u, 0.004), 0.00105 * u, white, 56)
				l.line_spacing = -10.0
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
				_p(lap, _rbox(Vector3(0.2, 0.014, 0.13) * u, 0.006 * u), alu, Vector3.ZERO)
				_p(lap, _rbox(Vector3(0.2, 0.13, 0.012) * u, 0.005 * u), alu, Vector3(0, 0.06 * u, 0.068 * u), Vector3.ONE, Vector3(0.25, 0, 0))
				_p(lap, _box(Vector3(0.17, 0.1, 0.004) * u), Color(0.45, 0.8, 1.0), Vector3(0, 0.061 * u, 0.061 * u), Vector3.ONE, Vector3(0.25, 0, 0))
				_p(lap, _sphere(0.012 * u, 8), white, Vector3(0, 0.062 * u, 0.076 * u))
				for sxa in [-1.0, 1.0]:
					var sh0 := _chest(A, 0.19 * u * sxa, cy - 0.06 * u, -0.01 * u)
					var hand := lap.position + Vector3(0.105 * u * sxa, 0.0, 0.01 * u)
					_stroke(b, sh0, hand, 0.03 * u, navy2)
					_p(b, _sphere(0.034 * u, 12), white, hand + Vector3(0, 0.004 * u, 0.012 * u), Vector3(0.8, 0.7, 1.2))
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
				# 往後梳的銀灰色頭髮：雞冠收起來，一頂貼著頭的髮底＋七束往後梳的髮絲＋前面翹起來的瀏海＋鬢角
				_hide_comb(h)
				var base := Color(0.44, 0.48, 0.55)
				var hi := Color(0.72, 0.75, 0.80)
				var hc := Vector3(0, 0.07, -0.03) if rooster else Vector3(0, 0.12, -0.02)
				var hr := Vector3(0.106, 0.086, 0.12) if rooster else Vector3(0.335, 0.195, 0.325)
				_p(h, _sphere(1.0, 28), base, hc, hr)
				for k in 7:
					var a := (k - 3) * 0.3
					var lock := []
					for j in 9:
						var t := 0.42 + j * 0.28
						lock.append(hc + hr * Vector3(sin(a) * sin(t), cos(a) * sin(t), cos(t)) * 1.02)
					_path(h, lock, hr.x * (0.15 if k % 2 == 0 else 0.11), hi if k % 2 == 0 else Color(0.60, 0.64, 0.70))
				_p(h, _sphere(1.0, 18), hi, hc + Vector3(0, hr.y * 0.8, hr.z * 0.6), Vector3(hr.x * 0.72, hr.y * 0.4, hr.z * 0.5), Vector3(-0.5, 0, 0))
				for sx in [-1.0, 1.0]:
					_p(h, _sphere(1.0, 12), base, hc + Vector3(hr.x * 0.88 * sx, -hr.y * 0.5, hr.z * 0.36), Vector3(hr.x * 0.18, hr.y * 0.52, hr.z * 0.28))
			else:
				_glasses(A, Color(0.2, 0.2, 0.22), 0.004, true)
		"delivery":
			# 背在背上的保溫箱：圓角箱體、深色上蓋和蓋縫、反光條、提把、側邊口袋、白字，兩條背帶繞過肩膀
			var box := Node3D.new()
			box.position = back + Vector3(0, 0.08 * u, -0.14 * u)
			box.rotation.x = 0.06
			b.add_child(box)
			var orange := Color(0.97, 0.5, 0.1)
			var lid := orange.darkened(0.35)
			_p(box, _rbox(Vector3(0.31, 0.3, 0.27) * u, 0.025 * u), orange, Vector3.ZERO)
			_p(box, _rbox(Vector3(0.325, 0.07, 0.285) * u, 0.025 * u), lid, Vector3(0, 0.135 * u, 0))
			_p(box, _rbox(Vector3(0.318, 0.012, 0.278) * u, 0.005 * u), Color(0.12, 0.12, 0.13), Vector3(0, 0.098 * u, 0))
			_p(box, _rbox(Vector3(0.318, 0.026, 0.278) * u, 0.008 * u), Color(0.96, 0.96, 0.86), Vector3(0, -0.105 * u, 0))
			_path(box, [Vector3(-0.05, 0.172, 0) * u, Vector3(-0.04, 0.2, 0) * u, Vector3(0.04, 0.2, 0) * u, Vector3(0.05, 0.172, 0) * u], 0.011 * u, black)
			for sx in [-1.0, 1.0]:
				_p(box, _rbox(Vector3(0.02, 0.13, 0.16) * u, 0.008 * u), lid, Vector3(0.158 * u * sx, -0.02 * u, 0))
			_p(box, _cyl(0.05 * u, 0.05 * u, 0.006 * u, 24), white, Vector3(0, -0.045 * u, -0.1365 * u), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
			var dl := _label(box, "家豪快送", Vector3(0, 0.04 * u, -0.1365 * u), 0.0012 * u, white, 56)
			dl.rotation.y = PI
			_claw(box, Vector3(0, -0.048 * u, -0.141 * u), 0.024 * u, orange, PI)
			for sx in [-1.0, 1.0]:
				var strap2 := []
				for j in 7:
					strap2.append(_chest(A, 0.1 * u * sx, cy + (0.2 - j * 0.05) * u, 0.008 * u))
				_path(b, strap2, 0.014 * u, black)
				_path(b, [strap2[0], Vector3(0.1 * u * sx, strap2[0].y + 0.035 * u, back.z * 0.3), back + Vector3(0.1 * u * sx, 0.2 * u, -0.02 * u)], 0.014 * u, black)
				_p(b, _rbox(Vector3(0.036, 0.022, 0.012) * u, 0.004 * u), silver, strap2[3] + Vector3(0, 0, 0.008 * u))
		"azhi":
			# 背後的雞爪標誌＋FRIED 字樣＋會跳的音量條；頭上戴著大耳罩耳機，胸前一條金項鍊
			var mark := Node3D.new()
			mark.position = back + Vector3(0, 0.02 * u, -0.012 * u)
			b.add_child(mark)
			if rooster:
				# 尾羽塞進帽 T 裡（不然會蓋住背後的圖案），只在下襬露出一小撮
				for tm in b.get_children():
					var tmi := tm as MeshInstance3D
					if tmi and tmi.mesh is CapsuleMesh and tmi.position.z < -0.3 and tmi.position.y > 0.5:
						tmi.visible = false
			_claw(mark, Vector3.ZERO, 0.085 * u, Color(1.0, 0.84, 0.2), PI)
			var t1 := _label(mark, "FRIED", Vector3(0, -0.1 * u, 0.014 * u), 0.0012 * u, white, 56)
			t1.rotation = Vector3(-0.3, PI, 0)
			for sx in [-1.0, 1.0]:
				for j in 3:
					var bar := _p(mark, _rbox(Vector3(0.014, 0.06, 0.006) * u, 0.003 * u), Color(0.95, 0.25, 0.3) if j == 1 else Color(1.0, 0.84, 0.2), Vector3((0.105 + j * 0.026) * u * sx, 0.01 * u, 0.02 * u + j * 0.016 * u))
					fx.ops.append({"k": "eq", "node": bar, "ph": j * 1.3 + (0.7 if sx > 0.0 else 0.0)})
			var redc := Color(0.9, 0.18, 0.16)
			var cup := Vector3(0.172, 0.03, -0.03) if rooster else Vector3(0.375, 0.1, 0.0)
			var cr := 0.058 if rooster else 0.1
			var top_y := 0.24 if rooster else 0.36
			for sx in [-1.0, 1.0]:
				_p(h, _cyl(cr, cr, cr * 0.75, 24), Color(0.16, 0.16, 0.18), Vector3(cup.x * sx, cup.y, cup.z), Vector3.ONE, Vector3(0, 0, PI * 0.5))
				_p(h, _torus(cr * 0.62, cr * 1.05), redc, Vector3((cup.x + cr * 0.36) * sx, cup.y, cup.z), Vector3.ONE, Vector3(0, 0, PI * 0.5))
				_p(h, _cyl(cr * 0.5, cr * 0.5, cr * 0.2, 20), silver, Vector3((cup.x + cr * 0.42) * sx, cup.y, cup.z), Vector3.ONE, Vector3(0, 0, PI * 0.5))
			var band := []
			for j in 13:
				var a2 := PI * j / 12.0
				band.append(Vector3(cos(a2) * (cup.x + cr * 0.1), cup.y + sin(a2) * (top_y - cup.y), cup.z))
			_path(h, band, cr * 0.2, Color(0.16, 0.16, 0.18))
			_path(h, band.slice(4, 9), cr * 0.26, redc)
			var gmat := _gloss(gold, 0.3, 0.9)
			for j in 15:
				var t3 := (j - 7) / 7.0
				_p(b, _sphere(0.011 * u, 10), gold, _chest(A, t3 * 0.1 * u, neck.y - 0.03 * u - (1.0 - t3 * t3) * 0.085 * u, 0.008 * u)).material_override = gmat
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
				# 白西裝：兩片翻領、胸口袋露出紅手帕、黑色細領結、金扣子
				var cream := Color(1.0, 0.97, 0.87)
				var shade2 := cream.darkened(0.22)
				_cloth(A, cream, false, true, shade2)
				_sleeves(A, cream, false, shade2)
				_flap(b, _chest(A, -0.075 * u, neck.y + 0.01 * u, 0.004 * u), _chest(A, 0.075 * u, neck.y + 0.01 * u, 0.004 * u), _chest(A, 0, neck.y - 0.17 * u, 0.004 * u), Color(0.99, 0.99, 0.99))
				for sx in [-1.0, 1.0]:
					# 翻領：上緣貼著脖子兩側，尖角朝外，往下收到第一顆扣子
					var la := _chest(A, 0.075 * u * sx, neck.y + 0.02 * u, 0.012 * u)
					var lt := _chest(A, 0.15 * u * sx, neck.y - 0.06 * u, 0.014 * u)
					var ln := _chest(A, 0.105 * u * sx, neck.y - 0.085 * u, 0.014 * u)
					var ll := _chest(A, 0.008 * u * sx, neck.y - 0.19 * u, 0.012 * u)
					_flap(b, la, lt, ln, cream.darkened(0.1))
					_flap(b, la, ln, ll, cream.darkened(0.1))
					_path(b, [lt, ln, ll], 0.005 * u, Color(0.66, 0.62, 0.54))
				_p(b, _rbox(Vector3(0.05, 0.008, 0.01) * u, 0.003 * u), shade2, _chest(A, -0.115 * u, cy - 0.005 * u, 0.006 * u))
				_p(b, _sphere(0.02 * u, 10), Color(0.86, 0.14, 0.14), _chest(A, -0.115 * u, cy + 0.008 * u, 0.006 * u), Vector3(1.1, 0.8, 0.5))
				var tie := neck + Vector3(0, -0.03 * u, 0.02 * u)
				_p(b, _sphere(0.016 * u, 10), black, tie)
				for sx in [-1.0, 1.0]:
					_p(b, _sphere(0.028 * u, 12), black, tie + Vector3(0.034 * u * sx, 0, -0.004 * u), Vector3(1.0, 0.7, 0.4), Vector3(0, 0, 0.25 * sx))
					_stroke(b, tie + Vector3(0.006 * u * sx, -0.012 * u, 0), _chest(A, 0.018 * u * sx, neck.y - 0.115 * u, 0.016 * u), 0.006 * u, black)
				for k2 in 3:
					_p(b, _sphere(0.016 * u, 10), gold, _chest(A, 0, cy - 0.05 * u - k2 * 0.065 * u, 0.006 * u)).material_override = _gloss(gold, 0.3, 0.9)
			else:
				# 頭上倒扣的炸雞桶（白底黃條、正面一個「豪」字）、黑框眼鏡、白色短山羊鬍和白眉毛
				var r: float = A.hat_r
				var stripe := Color(0.98, 0.72, 0.12)
				var rimc := Color(0.72, 0.36, 0.1)
				var bucket := Node3D.new()
				bucket.position = Vector3(0, float(A.top) + 0.05 * u, -0.01 * u)
				bucket.rotation = Vector3(-0.1, 0, 0.07)
				h.add_child(bucket)
				_p(bucket, _cyl(r * 0.78, r, 0.17 * u, 32), white, Vector3.ZERO)
				for k3 in 8:
					var a3 := TAU * (k3 + 0.5) / 8.0
					_p(bucket, _rbox(Vector3(r * 0.3, 0.165 * u, 0.008 * u), 0.003 * u), stripe, Vector3(sin(a3), 0, cos(a3)) * r * 0.9, Vector3.ONE, Vector3(-0.19, a3, 0))
				_p(bucket, _torus(r * 0.93, r * 1.08), rimc, Vector3(0, -0.08 * u, 0))
				_p(bucket, _torus(r * 0.72, r * 0.84), rimc, Vector3(0, 0.086 * u, 0))
				_p(bucket, _cyl(r * 0.78, r * 0.78, 0.012 * u, 32), white, Vector3(0, 0.082 * u, 0))
				_p(bucket, _cyl(r * 0.5, r * 0.5, 0.006 * u, 28), rimc, Vector3(0, -0.005 * u, r * 0.9), Vector3.ONE, Vector3(PI * 0.5 - 0.19, 0, 0))
				_p(bucket, _cyl(r * 0.43, r * 0.43, 0.008 * u, 28), Color(1.0, 0.9, 0.62), Vector3(0, -0.005 * u, r * 0.905), Vector3.ONE, Vector3(PI * 0.5 - 0.19, 0, 0))
				# 桶子正面的圖案：一支炸雞腿
				var leg := Node3D.new()
				leg.position = Vector3(-r * 0.06, 0.012 * u, r * 0.93)
				leg.rotation = Vector3(-0.19, 0, 0.7)
				leg.scale = Vector3.ONE * 0.8
				bucket.add_child(leg)
				var lk := r * 0.3
				var bone := Color(0.80, 0.74, 0.62)
				_p(leg, _sphere(lk, 16), Color(0.72, 0.42, 0.14), Vector3(0, lk * 0.45, 0), Vector3(0.72, 0.95, 0.3))
				_p(leg, _sphere(lk * 0.6, 12), Color(0.72, 0.42, 0.14), Vector3(0, -lk * 0.3, 0), Vector3(0.6, 1.0, 0.3))
				_p(leg, _capsule(lk * 0.17, lk * 1.0), bone, Vector3(0, -lk * 1.05, 0), Vector3(1, 1, 0.5))
				for sxl in [-1.0, 1.0]:
					_p(leg, _sphere(lk * 0.24, 10), bone, Vector3(lk * 0.2 * sxl, -lk * 1.55, 0), Vector3(1, 1, 0.5))
				_glasses(A, black, 0.008)
				_p(h, _cyl(0.026 * u, 0.0, 0.07 * u, 12), white, A.beak + Vector3(0, -0.075 * u, 0.012 * u))
				var e3: Vector3 = A.eye
				var er3: float = A.eye_r
				for sx in [-1.0, 1.0]:
					_stroke(h, Vector3((e3.x - er3) * sx, e3.y + er3 * 2.5, e3.z + 0.012 * u), Vector3((e3.x + er3 * 1.4) * sx, e3.y + er3 * 2.0, e3.z - 0.002 * u), er3 * 0.42, white)
		"leather":
			# 黑皮衣（霧面皮革）：打開的翻領露出裡面的灰 T、正中間銀拉鍊、斜口袋、肩章、羅紋袖口和下襬；過關時右翅膀舉起顯示卡
			var lea := Color(0.085, 0.085, 0.095)
			var rib := Color(0.22, 0.22, 0.24)
			var zmat := _gloss(silver, 0.3, 0.9)
			_cloth(A, lea, true, true, rib)
			_sleeves(A, lea, true, rib)
			_flap(b, _chest(A, -0.04 * u, neck.y, 0.004 * u), _chest(A, 0.04 * u, neck.y, 0.004 * u), _chest(A, 0, neck.y - 0.16 * u, 0.004 * u), Color(0.45, 0.45, 0.48))
			for sx in [-1.0, 1.0]:
				var la := _chest(A, 0.036 * u * sx, neck.y + 0.012 * u, 0.012 * u)
				var lt := _chest(A, 0.132 * u * sx, neck.y - 0.075 * u, 0.015 * u)
				var ll := _chest(A, 0.006 * u * sx, neck.y - 0.18 * u, 0.012 * u)
				_flap(b, la, lt, ll, Color(0.15, 0.15, 0.165), _gloss(Color(0.15, 0.15, 0.165), 0.5))
				_path(b, [la, lt, ll], 0.006 * u, rib)
				_p(b, _sphere(0.011 * u, 10), silver, lt + Vector3(-0.012 * u * sx, 0.004 * u, 0.006 * u)).material_override = zmat
				var pk0 := _chest(A, 0.075 * u * sx, cy - 0.05 * u, 0.005 * u)
				var pk1 := _chest(A, 0.15 * u * sx, cy - 0.11 * u, 0.005 * u)
				_stroke(b, pk0, pk1, 0.011 * u, rib)
				_stroke(b, pk0 + Vector3(0, 0, 0.008 * u), pk1 + Vector3(0, 0, 0.008 * u), 0.004 * u, silver, zmat)
				_stroke(b, _chest(A, 0.1 * u * sx, cy + 0.15 * u, 0.006 * u), _chest(A, 0.175 * u * sx, cy + 0.12 * u, 0.006 * u), 0.013 * u, rib)
			var zp := []
			for j in 7:
				zp.append(_chest(A, 0.0, neck.y - 0.18 * u - j * 0.03 * u, 0.004 * u))
			_path(b, zp, 0.007 * u, silver, zmat)
			_p(b, _rbox(Vector3(0.018, 0.034, 0.01) * u, 0.004 * u), silver, zp[0] + Vector3(0, -0.012 * u, 0.008 * u)).material_override = zmat
			_p(b, _rbox(Vector3(0.06, 0.04, 0.012) * u, 0.006 * u), silver, zp[6] + Vector3(0, -0.012 * u, 0.004 * u)).material_override = zmat
			# 過關時右翅膀舉起來的顯示卡
			var wg := A.wings[1] as Node3D
			if wg:
				var ang := 2.55
				var gpu := Node3D.new()
				gpu.position = (A.wing_p as Vector3) + Vector3(0.02, -0.235, 0.07)
				gpu.rotation.z = -ang
				gpu.visible = false
				wg.add_child(gpu)
				var k := 1.0 if rooster else 1.25
				_p(gpu, _rbox(Vector3(0.26, 0.11, 0.035) * k, 0.01 * k), Color(0.12, 0.13, 0.14), Vector3.ZERO)
				_p(gpu, _rbox(Vector3(0.265, 0.018, 0.037) * k, 0.006 * k), Color(0.45, 0.85, 0.1), Vector3(0, 0.05 * k, 0))
				_p(gpu, _rbox(Vector3(0.012, 0.13, 0.04) * k, 0.004 * k), silver, Vector3(-0.136 * k, -0.005 * k, 0))
				for sx in [-1.0, 1.0]:
					_p(gpu, _cyl(0.042 * k, 0.042 * k, 0.006 * k, 24), Color(0.3, 0.32, 0.34), Vector3(0.06 * k * sx, -0.005 * k, 0.018 * k), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
					for q in 5:
						_p(gpu, _rbox(Vector3(0.03, 0.01, 0.004) * k, 0.002 * k), Color(0.5, 0.52, 0.55), Vector3(0.06 * k * sx, -0.005 * k, 0.022 * k) + Vector3(cos(q * TAU / 5.0), sin(q * TAU / 5.0), 0) * 0.018 * k, Vector3.ONE, Vector3(0, 0, q * TAU / 5.0 + 0.5))
					_p(gpu, _cyl(0.012 * k, 0.012 * k, 0.01 * k, 12), silver, Vector3(0.06 * k * sx, -0.005 * k, 0.022 * k), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
				for q2 in [-1.0, 1.0]:      # 扣在卡片前面的兩根白羽毛
					_p(gpu, _capsule(0.016 * k, 0.07 * k), white, Vector3(0.03 * k * q2, -0.045 * k, 0.024 * k), Vector3(1, 1, 0.6), Vector3(0, 0, 0.25 * q2))
				fx.ops.append({"k": "win", "node": gpu, "s": Vector3.ONE})
				fx.ops.append({"k": "raise", "node": wg, "ang": ang})
		"gown":
			if slot == "body":
				# 黑色學士袍：長下襬、喇叭袖、金色披肩帶、白領子；左翅膀夾著一卷綁紅緞帶的畢業證書
				_cloth(A, black, false, false)
				_sleeves(A, black)
				if rooster:
					_p(b, _cyl(0.2, 0.275, 0.22, 32), black, Vector3(0, 0.27, -0.055), Vector3(1, 1, 1.25))
					_p(b, _torus(0.26, 0.285), gold, Vector3(0, 0.165, -0.055), Vector3(1, 0.6, 1.25))
				else:
					_p(b, _cyl(0.3, 0.37, 0.17, 32), black, Vector3(0, 0.11, 0), Vector3(1, 1, 0.95))
					_p(b, _torus(0.355, 0.38), gold, Vector3(0, 0.03, 0), Vector3(1, 0.6, 0.95))
				for i in 2:
					var w := A.wings[i] as Node3D
					if w:
						var sxw := -1.0 if i == 0 else 1.0
						_p(w, _cyl(0.045, 0.1, 0.14, 20), black, (A.wing_p as Vector3) * Vector3(sxw, 1, 1) + Vector3(0.01 * sxw, -0.09, 0), Vector3(0.6, 1, 1.5), Vector3(0, 0, 0.12 * sxw))
				for sx in [-1.0, 1.0]:
					var stole := []
					for j in 7:
						var a := j / 6.0
						stole.append(_chest(A, (0.12 - a * 0.115) * u * sx, neck.y - 0.01 * u - a * 0.24 * u, 0.008 * u))
					_path(b, stole, 0.021 * u, gold)
					_stroke(b, neck + Vector3(0.012 * u * sx, -0.005 * u, 0.012 * u), neck + Vector3(0.05 * u * sx, -0.05 * u, 0.006 * u), 0.011 * u, white)
				var wl := A.wings[0] as Node3D
				if wl:
					var roll := Node3D.new()
					roll.position = (A.wing_p as Vector3) * Vector3(-1, 1, 1) + Vector3(-0.06, -0.1, 0.12)
					roll.rotation = Vector3(PI * 0.5 - 0.35, 0, 0.25)
					wl.add_child(roll)
					_p(roll, _cyl(0.032, 0.032, 0.24, 20), Color(0.99, 0.97, 0.9), Vector3.ZERO)
					for sy in [-1.0, 1.0]:
						_p(roll, _torus(0.012, 0.033), Color(0.9, 0.86, 0.75), Vector3(0, 0.12 * sy, 0))
					_p(roll, _torus(0.03, 0.042), Color(0.86, 0.14, 0.14), Vector3.ZERO)
					for sy in [-1.0, 1.0]:
						_p(roll, _sphere(0.022, 10), Color(0.86, 0.14, 0.14), Vector3(0.03 * sy, 0, 0.04), Vector3(1.2, 0.5, 0.6))
			else:
				# 方帽＋金色流蘇；過關時往上丟
				var cap := Node3D.new()
				var capy := float(A.top) + 0.03 * u
				cap.position = Vector3(0, capy, -0.01 * u)
				h.add_child(cap)
				var r2: float = A.hat_r
				_p(cap, _cyl(r2 * 0.78, r2 * 0.88, 0.075 * u, 28), black, Vector3.ZERO)
				_p(cap, _rbox(Vector3(r2 * 2.7, 0.016 * u, r2 * 2.7), 0.006 * u), black, Vector3(0, 0.043 * u, 0), Vector3.ONE, Vector3(0, 0.35, 0))
				_p(cap, _sphere(0.016 * u, 10), gold, Vector3(0, 0.054 * u, 0))
				_stroke(cap, Vector3(0, 0.054 * u, 0), Vector3(r2 * 1.1, 0.05 * u, r2 * 0.75), 0.005 * u, gold)
				_stroke(cap, Vector3(r2 * 1.1, 0.05 * u, r2 * 0.75), Vector3(r2 * 1.12, -0.07 * u, r2 * 0.77), 0.005 * u, gold)
				_p(cap, _capsule(0.012 * u, 0.05 * u), gold, Vector3(r2 * 1.12, -0.09 * u, r2 * 0.77))
				fx.ops.append({"k": "toss", "node": cap, "y": capy, "amp": 0.5 * u})
