extends Node3D
## 選關畫面（世界地圖）
##
## 兩層：
##   1. 島上（拉近）：家豪站在一座島的路上，一格一格走到每一小關的地標前面，地標上冒出泡泡（關名＋三顆星＋開始）。
##      走過的路是金色的、還沒走的是米白色；過關的站點是綠色、插一支金色旗子；天色跟著那一小關的時段換。
##   2. 世界地圖（拉遠，按 M／Tab／Esc 或右上角的地圖按鈕）：中間是主島「家豪的農莊」，主題島圍在四周，
##      用海上的浮標航線連到主島。每座島頭上一張島牌（名字＋星星；全破戴皇冠）。
##      方向鍵（或滑鼠點）讓家豪飛到別的島，Enter 登島。每座島的第 1 小關一開始就能玩，所以島可以自由跳著玩。
## 主島（農莊）：家豪的家，島上沒有關卡，只有功能點。一開遊戲家豪站在雞舍前面。從西到東是：
##   商店（衣櫃，用星星買服裝）、冒險紀錄（寶箱：全部的星星和過關數）、家（雞舍，可以重溫開場的那場夢）、
##   告示牌（操作說明）、碼頭（出航＝拉遠看世界地圖）。
## 範例關（examples/ 底下的農場大門）和底線開頭的大關（_template 範本）只有開發版看得到，各是一座多出來的島。
## 還沒做好的大關是一座被雲蓋住的小島（鎖頭＋？？？）。
##
## 大關從 scripts/registry.gd 自動找到（levels/*/chapter.gd、examples/*/chapter.gd），各關不用改這個檔案。
## chapter.gd 可以多寫幾個選用的常數：
##   const ICON := "冰"                                   # 島牌圓徽章上的代表字
##   const STARS_SCRIPT := "res://levels/xxx/battle.gd"   # 有 static var best_stars 的腳本（不寫：找大關資料夾裡的 rescue_battle.gd）
##   const MAP_SCRIPT := "res://levels/xxx/map_isles.gd"  # 自己蓋地圖上的大島（不寫：用共用素材蓋預設的草地島，每一小關輪流換地標）
##   const MAP_SKY := "res://levels/xxx/shaders/sky.gdshader"   # 登上這座島時換用的天空著色器（不寫：共用的天空）
## MAP_SCRIPT 是一個 extends RefCounted 的腳本，裡面的函式都是選用的：
##   func build_island(root: Node3D, ctx: Dictionary) -> void
##       蓋整座大島（座標是 root 裡面的；y = 0 是海面）。ctx = {"center": 島中心 Vector2(x, z), "rx"／"rz": 東西／南北半徑, "top_y": 島面高度,
##       "pads": 每個站點的位置, "spots": 每一小關地標的位置, "index": 第幾排}。路、站點、旗子由這個檔案鋪在島上。
##       東西都要加在 root 底下：這個檔案會把 root 整個搬到世界地圖上那座島的位置。
##   func ground_y(x: float, z: float) -> float
##       島面在 (x, z) 的高度（路、站點、家豪貼在上面）。不寫就是平的 TOP_Y。
##   func build_spot(k: int, root: Node3D, ctx: Dictionary) -> void
##       蓋第 k 小關（0 開始）的地標。root 的原點在那個地點的島面上，+z 是站點和鏡頭那一邊，大約 4 公尺見方。
##       地標比較高的話 root.set_meta("bubble_y", 高度)，泡泡就會浮在那個高度上面。
##   func mood(k: int) -> Dictionary
##       走到第 k 小關時的天色，鍵跟 DEFAULT_MOOD 一樣（只寫要改的）；"sky.xxx"／"sea.xxx" 是天空／海著色器的參數。
## 沒有三星紀錄的大關，過關就用打勾表示。
##
## 操作（島上）：← → 沿著路走、數字鍵直接走到那一格、Enter 開始（商店：進去；家：重看開場）、M／Tab／Esc 拉遠看世界地圖。
## 操作（世界地圖）：方向鍵飛到那個方向的島、Enter（或 M／Tab）登島、Esc 回到開場。
##       V 開關聲音、B 直接進商店；滑鼠點站點／島牌也可以。
## 從關卡或商店回來時，家豪站回原本那一格（剛過關就站到下一關）。
## 音效：全部用程式即時合成（不用音效檔，跟冰雪島關卡同一種做法），音色統一用音樂盒／木琴那種圓圓的鈴聲。
##       右上角的喇叭按鈕（或按 V）開關聲音；關掉的是整個遊戲的聲音（Master），設定存在 user://settings.cfg，下次開遊戲還記得。
## 開發用：命令列加 -- --mapshots=<資料夾>，會把世界地圖和每一格各截一張圖然後關掉。

const Progress := preload("res://scripts/progress.gd")
const Registry := preload("res://scripts/registry.gd")
const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const Wardrobe := preload("res://scripts/wardrobe.gd")     # 家豪的衣櫃（商店）：星星記在這裡
const SHOP_SCENE := "res://scenes/shop.tscn"
const SeaShader := preload("res://shaders/map_sea.gdshader")
const TEX := "res://assets/textures/"
const INTRO_SCENE := "res://scenes/intro.tscn"

## 正式的「島」一共幾座（四個組員各一座）；不夠的用「建造中」補滿
const ISLAND_SLOTS := 4
## 每個小關幾顆星
const STAR_MAX := 3
const SHAKE_TIME := 0.5

# ---- 地圖的尺寸（公尺）
const STEP := 11.5            # 同一個大關裡，站點和站點的間隔（東西向）
const SPOT_BACK := 5.0        # 地標在站點北邊多遠
const ROW := 48.0             # 大關和大關的間隔（南北向；下一個大關在北邊、畫面上方）
const ISLE_R := 4.6           # 還沒做好的大關那座小島的半徑
const TOP_Y := 1.5            # 島面比海面高多少
const PATH_LIFT := 0.06        # 路面比島面高多少
const WALK_SPEED := 21.0      # 家豪在路上走多快
const JUMP_TIME := 0.75       # 換大關時飛過去要幾秒
const CAM_OFFSET := Vector3(0, 10.3, 21.4)     # 鏡頭壓低：畫面最上面看得到地平線和天空（極光、晚霞）
const CAM_LOOK := Vector3(0, 3.2, -3.5)

# ---- 世界地圖（拉遠）
const HUB_TITLE := "家豪的農莊"
const HUB_COLOR := Color("e8b04a")
const HOME_COLOR := Color("f7e3a8")
const SHOP_RED := Color("e8483a")
const BOARD_COLOR := Color("f2c230")
const GUIDE_COLOR := Color("4fb3a6")
const DOCK_COLOR := Color("4a90d9")
const Tutorial := preload("res://scripts/ui/tutorial_popup.gd")   # 全遊戲共用的教學彈窗（主島的告示牌用它顯示操作說明）
const ZOOM_TIME := 0.9         # 拉遠／拉近要幾秒
const MAP_PITCH := 0.96        # 世界地圖的鏡頭往下看幾弧度（55 度）
const MAP_GAP := 18.0          # 主島的岸邊到主題島的岸邊隔多遠
const HERO_BIG := 5.0          # 世界地圖上家豪放大幾倍（像棋盤上的棋子）
const ROUTE_STEP := 3.5
const SPOT_BIG := 1.75         # 世界地圖上地標放大幾倍（遠遠的也認得出是哪座島）        # 航線上浮標的間隔

## 每座島的主色（站點、旗子）。認得的 id 用固定顏色，其他照順序輪流
const CARD_COLORS := {
	"ice": Color("7cc6ec"), "example_farm": Color("e8b04a"), "_template": Color("a99bd6"), "forest": Color("f2d24a"),
}
const CARD_CYCLE := [Color("7cc6ec"), Color("8fcf6f"), Color("f0a35a"), Color("c495e0")]
const INK := Color("3b2a20")
const PAPER := Color("fff8e7")
const PAPER_EDGE := Color("d9c9a8")
const LOCKED := Color("d9d4c8")
const LOCKED_EDGE := Color("9c968a")
const GREEN := Color("5cb85c")
const GOLD := Color("f2c230")
const PATH_DONE := Color("ffd24a")
const PATH_TODO := Color("fff6dc")
const PATH_EDGE := Color("6b4a2a")

## 預設的天色（大關沒有自己的 MAP_SCRIPT.mood() 就用這個）
const DEFAULT_MOOD := {
	"sun": Color(1.0, 0.90, 0.70), "energy": 1.7, "rot": Vector3(-0.85, 0.7, 0),
	"amb": Color(0.62, 0.74, 0.90), "amb_e": 0.9, "fog": Color(0.74, 0.88, 0.92),
	"sky.top_color": Color(0.30, 0.66, 0.90), "sky.horizon_color": Color(0.80, 0.92, 0.94),
	"sky.cloud_color": Color(0.99, 0.99, 0.96), "sky.cloud_shade": Color(0.76, 0.86, 0.90),
	"sea.deep": Color(0.08, 0.44, 0.68), "sea.near_c": Color(0.20, 0.64, 0.80), "sea.stroke_c": Color(0.74, 0.94, 0.98),
	"sea.foam_c": Color(1, 1, 1), "sea.horizon_c": Color(0.78, 0.91, 0.94),
}
const MOOD_TIME := 0.7        # 換天色要幾秒
const HOP_LEN := 2.6          # 家豪走路時一跳多遠（公尺）
const SETTINGS_PATH := "user://settings.cfg"
const SND_RATE := 22050
const BGM_DB := -15.0         # 背景音樂的音量（比音效小聲很多）

## 預設小島的主題（沒有 MAP_SCRIPT 的大關，每一小關照順序輪流用）：島面的顏色、地標模型、樹
const DEFAULT_THEMES := [
	{"top": Color(0.62, 0.80, 0.36), "cliff": Color(0.80, 0.70, 0.56), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/Barn.glb", "tree": "res://assets/nature/BirchTree.glb"},
	{"top": Color(0.86, 0.74, 0.38), "cliff": Color(0.74, 0.62, 0.52), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/Windmill.glb", "tree": "res://assets/nature/AutumnTree.glb"},
	{"top": Color(0.98, 0.90, 0.66), "cliff": Color(0.86, 0.76, 0.60), "tex": "gravelly_sand_diff_1k.jpg", "model": "res://assets/farm/Silo.glb", "tree": "res://assets/nature/BushBerries.glb"},
	{"top": Color(0.46, 0.70, 0.40), "cliff": Color(0.66, 0.66, 0.62), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/ChickenCoop.glb", "tree": "res://assets/nature/BirchTree.glb"},
	{"top": Color(0.78, 0.62, 0.44), "cliff": Color(0.70, 0.58, 0.50), "tex": "forest_ground_04_diff_1k.jpg", "model": "res://assets/farm/BigBarn.glb", "tree": "res://assets/nature/AutumnTree.glb"},
	{"top": Color(0.70, 0.84, 0.44), "cliff": Color(0.78, 0.72, 0.62), "tex": "grass_ground_diff_1k.jpg", "model": "res://assets/farm/SiloHouse.glb", "tree": "res://assets/nature/BirchTree.glb"},
]

## 大關（照 Registry 排好）
var LEVELS: Array = []
## 地圖上的每一座島：{"ch": 大關 Dictionary（主島、還沒做好的是 {}）, "slot": 第幾座主題島（主島是 -1）, "hub": 是不是主島}。第 0 個一定是主島
var entries: Array = []
## 每一座島在 3D 裡的東西（座標都是世界座標）：{"root", "n", "pads": [Vector3], "isles": [Vector3], "isle_roots": [Node3D], "segs": [PackedVector3Array],
##   "pad_nodes": [Node3D], "hook", "origin": root 搬到哪, "center": 島中心（島面高度）, "rx"／"rz": 半徑}
var worlds: Array = []
var selected := 0            # entries 的第幾排
var stage_sel := 0           # 目前大關裡家豪站在哪個小關（0 開始）
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky_default: ShaderMaterial
var _sky_mats := {}          # 著色器路徑 -> 天空材質（大關自己的天空）
var _sky_mat: ShaderMaterial # 現在用的天空材質
var _sea_mat: ShaderMaterial
var _sea: MeshInstance3D
var _focus := Vector3.ZERO   # 鏡頭看的地方（慢慢跟上家豪）
var _hero: Node3D            # 家豪（外層：位置和朝向）
var _hero_body: Node3D       # 家豪（內層：跳動）
var _walk := {}              # 走路中：{"pts": PackedVector3Array, "d": 已走幾公尺, "len": 全長, "to": 目的地小關}
var _jump := {}              # 換大關飛行中：{"from", "to", "t", "e": 目的地那一排, "k": 小關}
var _queued := 0             # 走路中又按了方向鍵：-1／+1，走到之後接著走
var _bump_t := 0.0           # 被擋住時抖一下還剩幾秒
var _bump_dir := Vector3.ZERO
var _t := 0.0
var _toast: Label
var _toast_t := 0.0
var _starting := false
var _layer: CanvasLayer
var _overlay: _Pad           # 蓋滿畫面的一張透明畫布：左上角的標題、右上角的按鈕、右下角的按鍵提示
var _start_rect := Rect2()   # 泡泡上「開始」按鈕在畫面上的位置
var _bubble_a := 0.0         # 泡泡現在多不透明（走到了才慢慢出現）
var _shake_t := 0.0          # 鎖頭還要抖多久
var _star_src := {}          # 大關 id -> 星星紀錄表（Dictionary）或 null
var _consts := {}            # 大關 id -> chapter.gd 的常數
var _hooks := {}             # 大關 id -> MAP_SCRIPT 的實體（或 null）
var _mood_from := {}
var _mood_to := {}
var _mood_k := 1.0
var _snd := {}               # 音效名字 -> AudioStreamPlayer
var _snd_rect := Rect2()     # 右上角喇叭按鈕在畫面上的位置
var _shop_rect := Rect2()    # 右上角商店按鈕在畫面上的位置
var _ledger := {}            # 關卡場景路徑 -> 存檔裡拿過最多幾顆星（重開遊戲星星還在）
var _wallet := 0             # 還能在商店花的星星
var _stations: Array = []    # 每一排的站點：[{"kind": "stage", "ch": 大關, "k": 第幾小關} | {"kind": "shop"} | {"kind": "home"} | {"kind": "locked"}]
var _ring_pos: Array = []    # 每一排那座島的中心在世界地圖上的位置 Vector2(x, z)
var _map := false            # 現在是不是拉遠看世界地圖
var _zoom := 0.0             # 0 = 島上、1 = 世界地圖（中間是鏡頭正在拉）
var _map_center := Vector3.ZERO   # 世界地圖鏡頭看的地方（所有島的正中間）
var _map_cam := Vector3(0, 140, 90)   # 世界地圖鏡頭的位置（相對 _map_center）
var _map_rect := Rect2()     # 右上角地圖按鈕在畫面上的位置
var _go_rect := Rect2()      # 世界地圖下方「登島」按鈕在畫面上的位置
var _tag_rects: Array = []   # 世界地圖上每張島牌在畫面上的位置
var _ov_isle: _Pad           # 島上的那一層介面（站點徽章、泡泡）
var _ov_map: _Pad            # 世界地圖的那一層介面（島牌）
var _ring: MeshInstance3D    # 世界地圖上圈住目前那座島的光圈
var _ring_mat: StandardMaterial3D
var _ring_edge: StandardMaterial3D
var _guide: CanvasLayer      # 告示牌的操作說明彈窗（第一次打開才建立）
var _esc_t := 0.0            # 世界地圖上按過一次 Esc：這幾秒內再按一次才回開場
var _shallow_mat: StandardMaterial3D
var _routes: Array = []      # 航線 {pts: 每顆浮球的位置 Vector2(x, z), mm: [白球的 MultiMesh, 色球的 MultiMesh]}
var _route_z := -1.0         # 浮球現在是照哪個 z 算的大小
var _shallow_tint := Color(0.56, 0.95, 0.88)   # 淺水現在的顏色（跟著時段變）
var _small: Array = []       # 只有島上視角才顯示的小東西（柵欄：從世界地圖的高度看只是一條鋸齒線）
var _hens: Array = []        # 主島上的母雞 {node, base, phase}
var _hero_tilt: Node3D       # 家豪（中間那層：世界地圖上往後仰，從上面看得到臉）
var _hero_base: Node3D       # 世界地圖上家豪腳下的棋子底座
var _shadow: MeshInstance3D  # 飛行時海面上的影子
var _shadow_mat: StandardMaterial3D
var _snd_pop := 0.0          # 喇叭按鈕剛被按：彈一下還剩幾秒
var _hop_i := 0              # 走路時已經跳了幾下（每落地一次響一聲）
var _flags: Array = []       # 會飄的旗子 {node, phase}
var _clouds: Array = []      # 蓋住未開放小島的雲 {node, base, phase}

# ================================================================== 啟動

func _ready() -> void:
	_load_chapters()
	_sync_stars()
	_cam = get_node("../Camera3D")
	_sun = get_node("../Sun")
	_env = (get_node("../WorldEnvironment") as WorldEnvironment).environment
	_sky_default = _env.sky.sky_material as ShaderMaterial
	_sky_mat = _sky_default
	_build_sea()
	_layout()
	for e in entries.size():
		worlds.append(_build_world(e))
	_fit_map_camera()
	_build_routes()
	_build_ring()
	_build_shallows()
	_build_hero()
	_build_ui()
	_build_audio()
	var args := OS.get_cmdline_user_args()
	var testing := "--autotest" in args
	var shots := ""
	for a in args:
		if a.begins_with("--mapshots="):
			shots = a.substr(11)
			testing = true
	selected = -1
	select(0)
	if Engine.has_meta("map_last"):
		_restore(Engine.get_meta("map_last"))
	elif not testing:
		_zoom = 1.0                      # 剛開遊戲：先看一眼整張世界地圖，再拉近到主島
	_place_hero(true)
	if "--autotest" in args:
		_autotest.call_deferred()
	if shots != "":
		_mapshots.call_deferred(shots)

## 讀大關清單：第 0 座是主島（農莊：商店、冒險紀錄、家、告示牌、碼頭），接著是主題島（不夠 ISLAND_SLOTS 座的用「還沒開放」補滿）
func _load_chapters() -> void:
	LEVELS = Registry.chapters()
	var islands: Array = LEVELS.filter(func(c): return not _is_example(c))
	# 範例關（examples/）和底線開頭的大關（_template 範本）：只有開發版看得到，排在主題島後面各當一座多出來的島
	# （命令列加 --no-dev 就藏起來）。主島上不放關卡
	var drafts: Array = LEVELS.filter(func(c): return _is_example(c))
	if not OS.is_debug_build() or "--no-dev" in OS.get_cmdline_user_args():
		drafts.clear()
	entries.clear()
	_stations.clear()
	var hub: Array = [{"kind": "shop"}, {"kind": "board"}, {"kind": "home"}, {"kind": "guide"}, {"kind": "dock"}]
	entries.append({"ch": {}, "slot": -1, "hub": true})
	_stations.append(hub)
	for k in maxi(ISLAND_SLOTS, islands.size()):
		var ch: Dictionary = islands[k] if k < islands.size() else {}
		_add_isle(ch, k)
	for c in drafts:
		_add_isle(c, entries.size() - 1)

func _add_isle(ch: Dictionary, slot: int) -> void:
	entries.append({"ch": ch, "slot": slot, "hub": false})
	var sts: Array = []
	if _playable(ch):
		for j in ch.stages.size():
			sts.append({"kind": "stage", "ch": ch, "k": j})
	else:
		sts.append({"kind": "locked"})
	_stations.append(sts)

## 範例：examples/ 底下的，或底線開頭的資料夾（_template）；開發版各多一座島。範例的星星不算進商店
func _is_example(c: Dictionary) -> bool:
	return bool(c.get("example", false)) or String(c.id).begins_with("_")

func _is_hub(e: int) -> bool:
	return bool(entries[e].get("hub", false))

## 這座島的名字（存「上次站在哪」用）
func _entry_id(e: int) -> String:
	return "hub" if _is_hub(e) else String(entries[e].ch.get("id", "slot%d" % e))

## 第 e 座島的第 k 個站點
func _st(e: int, k: int) -> Dictionary:
	return _stations[e][k]

func _st_now() -> Dictionary:
	return _st(selected, stage_sel)

## 站點那一小關的資料（只有 kind = "stage" 的站點有）
func _st_stage(s: Dictionary) -> Dictionary:
	return s.ch.stages[int(s.k)]

## 站點走不走得上去：商店和家永遠可以；小關照解鎖規則；還沒做好的島不行
func _st_open(e: int, k: int) -> bool:
	var s := _st(e, k)
	match String(s.kind):
		"stage":
			return _unlocked_ch(s.ch, int(s.k) + 1)
		"locked":
			return false
	return true

func _st_cleared(e: int, k: int) -> bool:
	var s := _st(e, k)
	return String(s.kind) == "stage" and Progress.is_cleared(_st_stage(s).id)

## 站點的主色
func _st_color(e: int, k: int) -> Color:
	var s := _st(e, k)
	match String(s.kind):
		"shop":
			return SHOP_RED
		"home":
			return HOME_COLOR
		"board":
			return BOARD_COLOR
		"guide":
			return GUIDE_COLOR
		"dock":
			return DOCK_COLOR
		"stage":
			if CARD_COLORS.has(s.ch.id):
				return CARD_COLORS[s.ch.id]
	return _color_of(entries[e])

## 從關卡／商店回來：站回原本那一格。剛剛玩的那一小關（Engine 的 meta "stage_id"，關卡裡按「下一關」會往後換）
## 過關了就站到下一關。
func _restore(last: Dictionary) -> void:
	var id := String(last.get("id", ""))
	var k := int(last.get("k", 0))
	var played := String(Engine.get_meta("stage_id", "")) if String(last.get("kind", "")) == "stage" else ""
	for e in entries.size():
		if _entry_id(e) != id:
			continue
		select(e)
		var n := int(worlds[e].n)
		k = clampi(k, 0, n - 1)
		for j in n:
			var s := _st(e, j)
			if played != "" and String(s.kind) == "stage" and String(_st_stage(s).id) == played:
				k = j
		if played != "" and _st_cleared(e, k) and not bool(last.get("was_cleared", false)) and k + 1 < n and _st_open(e, k + 1):
			k += 1
		select_stage(k)
		return

## 記住現在站在哪（換場景前呼叫）
func _remember() -> void:
	var s := _st_now()
	Engine.set_meta("map_last", {"id": _entry_id(selected), "k": stage_sel, "kind": String(s.kind), "was_cleared": _st_cleared(selected, stage_sel)})

func _first_selection() -> int:
	return 0

func _playable(ch: Dictionary) -> bool:
	return not ch.is_empty() and not ch.stages.is_empty() and ch.stages.any(func(s): return String(s.scene) != "")

func _cur() -> Dictionary:
	return entries[selected].ch if selected >= 0 and selected < entries.size() else {}

func _color_of(e: Dictionary) -> Color:
	if bool(e.get("hub", false)):
		return HUB_COLOR
	var ch: Dictionary = e.ch
	if ch.is_empty() or not _playable(ch):
		return LOCKED
	if CARD_COLORS.has(ch.id):
		return CARD_COLORS[ch.id]
	return CARD_CYCLE[maxi(e.slot, 0) % CARD_CYCLE.size()]

## 開發版（編輯器、命令列執行）不擋路：還沒解鎖的站點也走得過去。自動驗收時照正式規則。
func _dev() -> bool:
	return OS.is_debug_build() and not "--autotest" in OS.get_cmdline_user_args()

# ================================================================== 3D 地圖

## 第 e 排第 k 個站點在島自己的座標裡的位置（y 之後再貼到島面上）：一條左右蜿蜒的路。
## 每座島先照「第幾排」蓋在自己的座標裡，再整座搬到世界地圖上的位置（_ring_pos）。
func _pad_xz(e: int, k: int) -> Vector3:
	return Vector3(k * STEP, 0.0, -e * ROW + sin(k * 1.9 + e * 2.3) * 3.5)

## 那一小關的地標放在哪（站點北邊）
func _spot_xz(e: int, k: int) -> Vector3:
	return _pad_xz(e, k) + Vector3(sin(k * 2.7 + e) * 1.2, 0.0, -SPOT_BACK)

## 第 e 排那座大島的範圍和上面的點（交給 MAP_SCRIPT 或預設的蓋法）
func _island_ctx(e: int, n: int) -> Dictionary:
	var pads: Array = []
	var spots: Array = []
	var zmin := INF
	var zmax := -INF
	for k in n:
		pads.append(_pad_xz(e, k))
		spots.append(_spot_xz(e, k))
		zmin = minf(zmin, spots[k].z - 5.0)
		zmax = maxf(zmax, pads[k].z + 5.5)
	var half := (n - 1) * STEP * 0.5
	return {"center": Vector2(half, (zmin + zmax) * 0.5), "rx": half + 9.5, "rz": (zmax - zmin) * 0.5,
		"top_y": TOP_Y, "pads": pads, "spots": spots, "index": e}

## (x, z) 這個位置能不能放裝飾：離路／站點／地標夠遠才行。ctx 是 _island_ctx() 的結果
static func spot_free(ctx: Dictionary, x: float, z: float, room := 2.6) -> bool:
	var p := Vector2(x, z)
	var pads: Array = ctx.pads
	for k in pads.size():
		var a := Vector2(pads[k].x, pads[k].z)
		if p.distance_to(a) < room + 0.6:
			return false
		# 站點正前方（鏡頭那一邊）留空：樹才不會擋住家豪和旗子
		if absf(x - a.x) < 3.4 and z > a.y and z - a.y < 7.0:
			return false
		if k + 1 < pads.size():
			var b := Vector2(pads[k + 1].x, pads[k + 1].z)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < room:
				return false
		var sp: Vector3 = ctx.spots[k]
		if p.distance_to(Vector2(sp.x, sp.z)) < room + 2.2:
			return false
	return true

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	_sea = MeshInstance3D.new()
	_sea.name = "Sea"
	_sea.mesh = plane
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = SeaShader
	_sea.material_override = _sea_mat
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)

## 這個大關的 MAP_SCRIPT（沒有就 null）
func _hook(ch: Dictionary) -> Object:
	if ch.is_empty():
		return null
	if not _hooks.has(ch.id):
		var h: Object = null
		var path := String(_chapter_consts(ch).get("MAP_SCRIPT", ""))
		if path != "" and ResourceLoader.exists(path):
			var scr := load(path) as Script
			if scr and scr.can_instantiate():
				h = scr.new()
		_hooks[ch.id] = h
	return _hooks[ch.id]

func _flat_mat(col: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## 沿著一串點鋪一條平平的帶子（路面）
func _strip(pts: PackedVector3Array, width: float, lift: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var dir := (b - a)
		dir.y = 0.0
		dir = dir.normalized()
		var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
		verts.append(pts[i] + Vector3(0, lift, 0) - side)
		verts.append(pts[i] + Vector3(0, lift, 0) + side)
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		if i > 0:
			var v := i * 2
			idx.append_array([v - 2, v - 1, v, v - 1, v + 1, v])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _strip_node(parent: Node3D, pts: PackedVector3Array, width: float, lift: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _strip(pts, width, lift)
	if mat is BaseMaterial3D:
		(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## 每座島放在世界地圖的哪裡：主島在正中間，主題島圍在四周（站點最多、最寬的放北邊，再來西、東、南，然後四個角）
func _layout() -> void:
	var size := func(e: int) -> Vector2:
		var n: int = (_stations[e] as Array).size()
		if String(_st(e, 0).kind) == "locked":
			return Vector2(ISLE_R + 2.0, ISLE_R + 2.0)
		return Vector2((n - 1) * STEP * 0.5 + 9.5, 13.5 if e == 0 else 11.0)
	_ring_pos.resize(entries.size())
	_ring_pos[0] = Vector2.ZERO
	var hub: Vector2 = size.call(0)
	var order: Array = range(1, entries.size())
	order.sort_custom(func(a, b):
		var na: int = (_stations[a] as Array).size()
		var nb: int = (_stations[b] as Array).size()
		return na > nb if na != nb else a < b)
	var far_n := 0.0
	var far_s := 0.0
	for i in order.size():
		var e: int = order[i]
		var s: Vector2 = size.call(e)
		var p := Vector2.ZERO
		# 北、西、東、南（方向鍵一按就到），再來是四個角
		match i % 8:
			0:
				p = Vector2(0, -(hub.y + s.y + MAP_GAP + 14.0))
				far_n = p.y
			1:
				p = Vector2(-(hub.x + s.x + MAP_GAP), -5.0)
			2:
				p = Vector2(hub.x + s.x + MAP_GAP, -5.0)
			3:
				p = Vector2(0, hub.y + s.y + MAP_GAP - 2.0)
				far_s = p.y
			4:
				p = Vector2(-(hub.x + s.x + MAP_GAP + 26.0), far_n + 4.0)
			5:
				p = Vector2(hub.x + s.x + MAP_GAP + 26.0, far_n + 4.0)
			6:
				p = Vector2(-(hub.x + s.x + MAP_GAP + 20.0), far_s - 2.0)
			_:
				p = Vector2(hub.x + s.x + MAP_GAP + 20.0, far_s - 2.0)
		_ring_pos[e] = p * (1.0 + 0.9 * float(i / 8))

## 世界地圖的鏡頭：往下看 MAP_PITCH，退到所有的島都進得了畫面
func _fit_map_camera() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for w in worlds:
		var c: Vector3 = w.center
		lo = Vector2(minf(lo.x, c.x - float(w.rx)), minf(lo.y, c.z - float(w.rz)))
		hi = Vector2(maxf(hi.x, c.x + float(w.rx)), maxf(hi.y, c.z + float(w.rz)))
	var half := (hi - lo) * 0.5
	_map_center = Vector3((lo.x + hi.x) * 0.5, 0, (lo.y + hi.y) * 0.5 + 3.5)
	var fv := deg_to_rad(_cam.fov) * 0.5
	var vs := get_viewport().get_visible_rect().size
	var fh := atan(tan(fv) * vs.x / maxf(vs.y, 1.0))
	var d_v := (half.y + 23.0) * sin(MAP_PITCH) / tan(fv)
	var d_h := (half.x + 3.0) / tan(fh) + half.y * cos(MAP_PITCH)
	var d := maxf(d_v, d_h)
	_map_cam = Vector3(0, sin(MAP_PITCH), cos(MAP_PITCH)) * d

## 蓋第 e 座島：一整座大島，島上有每個站點的地標、圓墊、路、旗子。還沒做好的大關是一座被雲蓋住的小島。
## 島先蓋在自己的座標裡（root 底下），再把 root 搬到世界地圖上的位置。
func _build_world(e: int) -> Dictionary:
	var ent: Dictionary = entries[e]
	var ch: Dictionary = ent.ch
	var hub := _is_hub(e)
	var playable := hub or _playable(ch)
	var sts: Array = _stations[e]
	var n := sts.size()
	var root := Node3D.new()
	root.name = "World%d" % e
	add_child(root)
	var hook: Object = _hook(ch) if playable and not hub else null
	var col := _color_of(ent)
	var le := 0 if hub else int(ent.slot) + 2          # 島自己座標裡的「第幾排」（決定路怎麼彎、預設島長什麼樣）
	var at: Vector2 = _ring_pos[e]
	var off := Vector3(at.x, 0, at.y)
	var w := {"root": root, "n": n, "pads": [], "isles": [], "isle_roots": [], "segs": [], "pad_nodes": [], "hook": hook,
		"center": Vector3(at.x, TOP_Y, at.y), "rx": ISLE_R + 2.0, "rz": ISLE_R + 2.0, "marks": []}
	var ctx := {}
	if playable:
		ctx = _island_ctx(le, n)
		if hub:
			ctx.rz = maxf(float(ctx.rz), 13.5)
		var c: Vector2 = ctx.center
		off = Vector3(at.x - c.x, 0, at.y - c.y)
		w.rx = float(ctx.rx)
		w.rz = float(ctx.rz)
		if hub:
			_build_farm(root, ctx)
		elif hook and hook.has_method("build_island"):
			hook.build_island(root, ctx)
		else:
			_default_island(root, le, ctx)
	root.position = off
	w["origin"] = off
	# 把一個點貼到島面上（島自己的座標）
	var on_ground := func(p: Vector3) -> Vector3:
		if not playable:
			return p
		var y := float(hook.ground_y(p.x, p.z)) if hook and hook.has_method("ground_y") else TOP_Y
		return Vector3(p.x, y, p.z)
	var lpads: Array = []
	var lspots: Array = []
	for k in n:
		if playable:
			lpads.append(on_ground.call(ctx.pads[k]))
			lspots.append(on_ground.call(ctx.spots[k]))
		else:
			lpads.append(Vector3(0, 0, ISLE_R + 1.7))
			lspots.append(Vector3.ZERO)
		w.pads.append((lpads[k] as Vector3) + off)
		w.isles.append((lspots[k] as Vector3) + off)
	# 路：一條平滑的曲線穿過所有站點，一段一段鋪在島面上（走過的那一段是金色）
	var edge_mat := _flat_mat(PATH_EDGE, true)
	for k in n - 1:
		var p0: Vector3 = lpads[maxi(k - 1, 0)]
		var p1: Vector3 = lpads[k]
		var p2: Vector3 = lpads[k + 1]
		var p3: Vector3 = lpads[mini(k + 2, n - 1)]
		var pts := PackedVector3Array()
		var wpts := PackedVector3Array()
		for i in 25:
			var p: Vector3 = on_ground.call(p1.cubic_interpolate(p2, p0, p3, i / 24.0))
			pts.append(p)
			wpts.append(p + off)
		w.segs.append(wpts)
		var done := String(_st(e, k).kind) != "stage" or _st_cleared(e, k)
		w.marks.append(_strip_node(root, pts, 1.5, PATH_LIFT, edge_mat))
		w.marks.append(_strip_node(root, pts, 1.05, PATH_LIFT + 0.04, _flat_mat(PATH_DONE if done else PATH_TODO, true)))
	for k in n:
		var s: Dictionary = sts[k]
		var kind := String(s.kind)
		var open := _st_open(e, k)
		var cleared := _st_cleared(e, k)
		var pc := LOCKED
		if kind != "stage" and kind != "locked":
			pc = _st_color(e, k)
		elif cleared:
			pc = GREEN
		elif open:
			pc = _st_color(e, k)
		w.pad_nodes.append(_build_pad(root, lpads[k], pc))
		if kind == "stage" and open:
			w.marks.append(_build_flag(root, (lpads[k] as Vector3) + Vector3(1.75, 0, -0.5), GOLD if cleared else _st_color(e, k), k * 1.3 + e))
		# 這個站點的地標
		var ir := Node3D.new()
		ir.name = "Spot%d" % k
		ir.position = lspots[k]
		root.add_child(ir)
		w.isle_roots.append(ir)
		if kind == "locked":
			_mystery_isle(ir, e)
		elif hub:
			_farm_spot(ir, s, ctx, lspots[k])
		elif hook and hook.has_method("build_spot"):
			hook.build_spot(int(s.k), ir, ctx)
		else:
			_default_spot(ir, le, int(s.k))
	return w

# ---------------------------------------------------------------- 主島：家豪的農莊

## 主島：一座綠油油的農莊。地標後面（北邊）是一塊一塊的田、風車、筒倉、乾草堆，岸邊一圈樹；靠鏡頭這一側留空。
func _build_farm(root: Node3D, ctx: Dictionary) -> void:
	var c: Vector2 = ctx.center
	var rx: float = ctx.rx
	var rz: float = ctx.rz
	var s := 1.9
	var mi := MeshInstance3D.new()
	mi.name = "Island"
	mi.mesh = _island_mesh(rx, rz, s)
	mi.position = Vector3(c.x, 0, c.y)
	mi.set_surface_override_material(0, _tex_mat("grass_ground_diff_1k.jpg", Color(0.78, 1.08, 0.46)))
	mi.set_surface_override_material(1, _tex_mat("lichen_rock_diff_1k.jpg", Color(1.08, 0.94, 0.74), 0.18))
	root.add_child(mi)
	var y := TOP_Y - 0.05
	var pads: Array = ctx.pads
	var spots: Array = ctx.spots
	# 田：兩個地標中間、往北一點；一塊翻過的土＋一排一排的作物
	var soil := _tex_mat("forest_ground_04_diff_1k.jpg", Color(1.05, 0.74, 0.50), 0.32)
	for k in spots.size() - 1:
		var m: Vector3 = ((spots[k] as Vector3) + (spots[k + 1] as Vector3)) * 0.5 + Vector3(0, 0, -1.4)
		if k == 2:
			# 家的東邊：大穀倉＋筒倉（布景，不是站點）
			_spawn_fit(root, "res://assets/farm/BigBarn.glb", Vector3(m.x - 0.6, y, m.z - 1.2), 5.6, 0.25)
			_spawn_fit(root, "res://assets/farm/Silo.glb", Vector3(m.x + 3.0, y, m.z - 1.8), 4.8, 0.0)
			continue
		var plot := PlaneMesh.new()
		plot.size = Vector2(4.6, 4.0)
		var pm := MeshInstance3D.new()
		pm.mesh = plot
		pm.material_override = soil
		pm.position = Vector3(m.x, TOP_Y + 0.03, m.z)
		pm.rotation.y = 0.12 * sin(k * 2.1)
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pm)
		for i in 4:
			for j in 5:
				var q := Vector3((i - 1.5) * 1.1, 0, (j - 2.0) * 0.78).rotated(Vector3.UP, pm.rotation.y)
				_spawn_fit(root, "res://assets/nature/BushBerries.glb", Vector3(m.x + q.x, y, m.z + q.z), 0.62, (i * 5 + j) * 1.7)
		_spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(m.x + 3.0, y, m.z + 1.2), 1.0, k * 1.3 + 0.4)
		for j in 3:
			_spawn_fit(root, "res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange.gltf", Vector3(m.x - 2.9 + j * 0.25, y, m.z + 1.4 + j * 0.62), 0.55 - 0.08 * j, j * 1.1)
	# 兩頭：西邊風車、東邊筒倉
	var west: Vector3 = spots[0]
	var east: Vector3 = spots[spots.size() - 1]
	_spawn_fit(root, "res://assets/farm/Windmill.glb", Vector3(west.x - 6.6, y, west.z + 1.0), 6.4, 0.5)
	_spawn_fit(root, "res://assets/farm/SiloHouse.glb", Vector3(east.x + 4.6, y, east.z - 2.6), 5.2, -0.4)
	# 岸邊的樹：北半圈密一點，南邊（靠鏡頭）只在兩個角落各一兩棵
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed: Array[Vector2] = []
	for i in 400:
		var a := rng.randf() * TAU
		var d := _outline(rx, rz, a, s) - rng.randf_range(1.4, 2.6)
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if sin(a) > -0.15 and absf(cos(a)) < 0.82:
			continue                              # 南邊中間不種
		if not spot_free(ctx, x, z, 2.2) or absf(x - (west.x - 6.6)) < 3.4 or absf(x - (east.x + 4.6)) < 3.2 or (cos(a) > 0.6 and sin(a) > -0.5):
			continue
		var p := Vector2(x, z)
		if placed.any(func(o): return (o as Vector2).distance_to(p) < 2.7):
			continue
		placed.append(p)
		var tree := "res://assets/nature/BirchTree.glb" if placed.size() % 3 != 0 else "res://assets/nature/AutumnTree.glb"
		_spawn_fit(root, tree, Vector3(x, y, z), rng.randf_range(2.6, 3.8), rng.randf() * TAU)
	# 路邊的莓果叢；南岸（靠鏡頭）沿著岸邊一排矮柵欄，中間留一個缺口，柵欄邊幾叢莓果、幾顆南瓜
	for k in pads.size():
		var p: Vector3 = pads[k]
		_spawn_fit(root, "res://assets/nature/BushBerries.glb", Vector3(p.x - 3.4, y, p.z - 2.2), 1.1, k * 2.0)
	var fence := "res://levels/ice/assets/kenney_platformer/fence-rope.glb"
	for i in 15:
		var a := PI * 0.5 + (i - 7) * 0.105
		if i == 7:
			continue
		var d := _outline(rx, rz, a, s) - 1.5
		var fx := c.x + cos(a) * d
		var fz := c.y + sin(a) * d
		var fn := _spawn_fit(root, fence, Vector3(fx, y, fz), 2.0, -a + PI * 0.5)
		if fn:
			_small.append(fn)
		if i % 4 == 1:
			_spawn_fit(root, "res://assets/nature/BushBerries.glb", Vector3(fx + 0.4, y, fz - 1.3), 1.0, i * 1.3)
		elif i % 4 == 3:
			_spawn_fit(root, "res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange.gltf", Vector3(fx - 0.3, y, fz - 1.1), 0.6, i * 0.9)

## 把模型上偏紅的面（穀倉的紅牆）換成另一種顏色，其他顏色不動。材質先複製一份，不會改到別的穀倉
func _recolor(node: Node, to: Color, roof := Color(0, 0, 0, 0)) -> void:
	if node == null:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m == null:
				continue
			var col := m.albedo_color
			if col.s > 0.35 and (col.h < 0.06 or col.h > 0.94):
				var d := m.duplicate() as BaseMaterial3D
				d.albedo_color = Color.from_hsv(to.h, to.s, clampf(col.v * to.v / 0.7, 0.0, 1.0))
				mi.set_surface_override_material(s, d)
			elif roof.a > 0.0 and col.s < 0.25 and col.v < 0.6:
				# 深灰色的屋頂換成 roof 這個顏色
				var d2 := m.duplicate() as BaseMaterial3D
				d2.albedo_color = roof
				mi.set_surface_override_material(s, d2)
	for ch in node.get_children():
		_recolor(ch, to, roof)

## 主島上的地標（都是功能點，沒有關卡）。at 是這個地標在島自己座標裡的位置
##   商店：紅屋頂的攤棚＋燈籠＋推車；冒險紀錄：寶箱＋旗子；家：雞舍；告示牌：路牌＋營火＋帳篷；碼頭：北岸伸進海裡的棧橋＋小船
func _farm_spot(root: Node3D, s: Dictionary, ctx: Dictionary, at: Vector3) -> void:
	match String(s.kind):
		"shop":
			var shop := _spawn_fit(root, "res://assets/farm/OpenBarn.glb", Vector3(0, -0.05, -0.3), 4.6, 0.3)
			_recolor(shop, Color("3fa7a3"), Color("a8473c"))
			_spawn_fit(root, "res://levels/ice/assets/blender/lantern_string.glb", Vector3(0.2, 2.0, 1.5), 4.4, 0.3)
			_spawn_fit(root, "res://levels/ice/assets/blender/market_stall.glb", Vector3(3.1, -0.05, 0.6), 2.4, -0.3)
			_spawn_fit(root, "res://levels/liuchiyu/assets/kenney_town/cart.glb", Vector3(-3.0, -0.05, 1.2), 1.7, 0.9)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(-2.9, -0.05, -0.3), 0.9, 0.0)
			_build_flag(root, Vector3(-2.0, 0, 2.0), SHOP_RED, 0.7)
			root.set_meta("bubble_y", 5.0)
		"board":
			_spawn_fit(root, "res://levels/fort/assets/pirate/platform-planks.glb", Vector3(0, -0.05, 0.2), 3.4, 0.2)
			_spawn_fit(root, "res://levels/fort/assets/pirate/chest.glb", Vector3(0, 0.25, 0.2), 2.0, 0.2)
			_spawn_fit(root, "res://levels/fort/assets/pirate/flag-high-pennant.glb", Vector3(-1.9, -0.05, -0.6), 4.2, 0.3)
			_spawn_fit(root, "res://levels/ice/assets/kenney_platformer/crate.glb", Vector3(1.9, -0.05, -0.5), 0.9, 0.5)
			_spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(2.3, -0.05, 0.9), 0.9, 0.2)
			root.set_meta("bubble_y", 4.4)
		"home":
			_spawn_fit(root, "res://assets/farm/ChickenCoop.glb", Vector3(0, -0.05, -0.2), 4.0, 0.25)
			_spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(-2.6, -0.05, 0.9), 0.9, 1.1)
			_spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(-2.0, -0.05, 1.7), 0.7, 0.2)
			root.set_meta("bubble_y", 4.8)
		"guide":
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/signpost-single.glb", Vector3(-0.2, -0.05, 0.6), 3.0, 0.15)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/tent.glb", Vector3(2.2, -0.05, -1.0), 2.8, -0.5)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/campfire-pit.glb", Vector3(-2.2, -0.05, 1.0), 1.2, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/tree-log.glb", Vector3(-2.6, -0.05, -0.6), 1.5, 0.8)
			root.set_meta("bubble_y", 4.4)
		"dock":
			# 棧橋從東岸伸進海裡（站點的正東邊，往東邊那座島的浮球航線就從這裡出去），旁邊停一艘小船；岸上是木桶、木箱、旗子和路牌
			var c: Vector2 = ctx.center
			var pz := at.z + 4.2                                  # 跟站點差不多同一排
			var shore := at.x + 8.0
			var best := INF
			for i in 90:
				var a := -PI * 0.5 + i * PI / 89.0                # 東半圈
				var d := _outline(float(ctx.rx), float(ctx.rz), a, 1.9)
				var rz2 := c.y + sin(a) * d
				if absf(rz2 - pz) < best:
					best = absf(rz2 - pz)
					shore = c.x + cos(a) * d
			var dx := shore - at.x
			_spawn_fit(root, "res://levels/ice/assets/blender/pier.glb", Vector3(dx + 2.4, -TOP_Y + 0.25, 4.2), 7.0, PI * 0.5)
			_spawn_fit(root, "res://levels/ice/assets/blender/rowboat.glb", Vector3(dx + 3.6, -TOP_Y - 0.1, 6.6), 2.8, 1.2)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(dx - 2.0, -0.05, 2.6), 1.0, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_platformer/crate-strong.glb", Vector3(dx - 2.8, -0.05, 3.6), 1.0, 0.4)
			_spawn_fit(root, "res://levels/fort/assets/pirate/flag-pennant.glb", Vector3(dx - 1.6, -0.05, 5.6), 3.4, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/signpost-single.glb", Vector3(0.6, -0.05, 0.4), 2.6, -0.3)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/fish-large.glb", Vector3(-1.6, 0.0, 1.0), 0.9, 0.6)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/bucket.glb", Vector3(-2.2, -0.05, 0.4), 0.7, 0.0)
			root.set_meta("bubble_y", 4.2)

# ---------------------------------------------------------------- 世界地圖：航線、光圈

## 每座島周圍一圈淺水（青綠色，越往外越淡）：島才像坐在海裡，不是貼在海面上
func _build_shallows() -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rings := [[0.0, 0.5], [0.58, 0.5], [0.72, 0.34], [0.86, 0.14], [1.0, 0.0]]
	for i in 73:
		var a := i * TAU / 72.0
		for rg in rings:
			verts.append(Vector3(cos(a), 0, sin(a)) * float(rg[0]))
			cols.append(Color(1, 1, 1, float(rg[1])))
		if i > 0:
			for j in rings.size() - 1:
				var v := i * rings.size() + j
				var p := v - rings.size()
				idx.append_array([p, p + 1, v, p + 1, v + 1, v])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_shallow_mat = StandardMaterial3D.new()
	_shallow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shallow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shallow_mat.vertex_color_use_as_albedo = true
	_shallow_mat.albedo_color = Color(0.56, 0.95, 0.88)
	_shallow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shallow_mat.render_priority = 1
	for w in worlds:
		var c: Vector3 = w.center
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _shallow_mat
		mi.position = Vector3(c.x, 0.05, c.z)
		mi.scale = Vector3(float(w.rx) + 12.0, 1.0, float(w.rz) + 12.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## 從島中心往 dir 這個方向到岸邊大概多遠（當成橢圓算）
func _edge(w: Dictionary, dir: Vector2) -> float:
	return 1.0 / sqrt(pow(dir.x / float(w.rx), 2.0) + pow(dir.y / float(w.rz), 2.0))

## 航線：主島到每座主題島，海面上一串紅白相間的小浮球（全破的島換成綠頂）。故意做得跟站點的圓墊不一樣：浮球上不能站。
## 浮球在島上視角是小小的，拉遠到世界地圖才放大（_size_routes）
func _build_routes() -> void:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 16
	ball.rings = 8
	var hub: Dictionary = worlds[0]
	var a2 := Vector2(hub.center.x, hub.center.z)
	for e in range(1, worlds.size()):
		var w: Dictionary = worlds[e]
		var b2 := Vector2(w.center.x, w.center.z)
		var dir := (b2 - a2).normalized()
		var p0 := a2 + dir * (_edge(hub, dir) + 5.5)
		var p1 := b2 - dir * (_edge(w, dir) + 5.5)
		var len := p0.distance_to(p1)
		if len < ROUTE_STEP:
			continue
		var mid := (p0 + p1) * 0.5 + Vector2(-dir.y, dir.x) * len * 0.10 * (1.0 if e % 2 == 0 else -1.0)
		var count := maxi(int(len / ROUTE_STEP), 3)
		var ch: Dictionary = entries[e].ch
		var done := _playable(ch) and Progress.chapter_cleared(ch)
		var pts := PackedVector2Array()
		for i in count + 1:
			var t := float(i) / count
			pts.append(p0.lerp(mid, t).lerp(mid.lerp(p1, t), t))
		var mms: Array = []
		for layer in 2:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = ball
			mm.instance_count = pts.size()
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = _flat_mat(Color(1, 1, 1) if layer == 0 else (GREEN if done else SHOP_RED))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			mms.append(mm)
		_routes.append({"pts": pts, "mm": mms})
	_size_routes(0.0)

## 照鏡頭拉到哪（z）重算每顆浮球的大小：下半顆白球泡在水裡，上面疊一顆小一點的色球
func _size_routes(z: float) -> void:
	_route_z = z
	var k := lerpf(0.5, 1.3, z)
	for rt in _routes:
		var pts: PackedVector2Array = rt.pts
		for layer in 2:
			var mm: MultiMesh = rt.mm[layer]
			var r := (0.92 if layer == 0 else 0.70) * k
			for i in pts.size():
				mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(r, r * 0.8, r)), Vector3(pts[i].x, (0.12 + 0.42 * layer) * k, pts[i].y)))

## 一圈帶子（單位圓，r0～r1）
func _ring_mesh(r0: float, r1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in 97:
		var a := i * TAU / 96.0
		var d := Vector3(cos(a), 0, sin(a))
		verts.append(d * r0)
		verts.append(d * r1)
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		if i > 0:
			var v := i * 2
			idx.append_array([v - 2, v - 1, v, v - 1, v + 1, v])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

## 光圈：世界地圖上圈住家豪所在那座島的一圈金色＋深色描邊（貼在海面上，_process 裡搬到目前那座島、照島的大小拉伸）
func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.visible = false
	add_child(_ring)
	_ring_mat = _flat_mat(Color(GOLD, 0.0), true)
	_ring_edge = _flat_mat(Color(PATH_EDGE, 0.0), true)
	var layers := [[0.918, 1.012, _ring_edge, 0.0, 2], [0.935, 0.995, _ring_mat, 0.03, 3]]
	for l in layers:
		var m: StandardMaterial3D = l[2]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = int(l[4])      # 海面也是半透明的：光圈要晚一點畫，才不會被海蓋掉
		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh(float(l[0]), float(l[1]))
		mi.material_override = m
		mi.position.y = float(l[3])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.add_child(mi)

## 站點：路上的圓墊（白邊＋主色）
func _build_pad(parent: Node3D, pos: Vector3, col: Color, size := 1.0) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	for spec in [[1.62, 0.30, PATH_EDGE, 0.0], [1.46, 0.36, Color(1, 1, 1), 0.0], [1.18, 0.42, col, 0.0]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = float(spec[0]) * size
		cyl.bottom_radius = float(spec[0]) * 0.94 * size
		cyl.height = spec[1]
		cyl.radial_segments = 40
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _flat_mat(spec[2])
		mi.position.y = float(spec[1]) * 0.5 - 0.12
		node.add_child(mi)
	return node

## 旗子：白色旗桿＋三角旗（過關的是金色）
func _build_flag(parent: Node3D, pos: Vector3, col: Color, phase: float) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.08
	pole.height = 2.6
	var pm := MeshInstance3D.new()
	pm.mesh = pole
	pm.material_override = _flat_mat(Color(0.98, 0.96, 0.9))
	pm.position.y = 1.3
	node.add_child(pm)
	var ball := SphereMesh.new()
	ball.radius = 0.14
	ball.height = 0.28
	var bm := MeshInstance3D.new()
	bm.mesh = ball
	bm.material_override = _flat_mat(GOLD)
	bm.position.y = 2.66
	node.add_child(bm)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0.55, 0), Vector3(1.15, 0.1, 0), Vector3(0, -0.45, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var tri := ArrayMesh.new()
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var fm := _flat_mat(col)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flag := MeshInstance3D.new()
	flag.mesh = tri
	flag.material_override = fm
	flag.position = Vector3(0.05, 2.0, 0)
	node.add_child(flag)
	_flags.append({"node": flag, "phase": phase})
	return node

# ---------------------------------------------------------------- 預設的小島（共用素材）

static func _grid_indices(cols: int, rows: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for si in cols:
		var sj := (si + 1) % cols
		for ri in rows - 1:
			var a := si * rows + ri
			var b := si * rows + ri + 1
			var c := sj * rows + ri + 1
			var d := sj * rows + ri
			idx.append_array([a, b, c, a, c, d])
	return idx

static func _surface(mesh: ArrayMesh, verts: PackedVector3Array, idx: PackedInt32Array) -> void:
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var fn := (verts[idx[i + 2]] - a).cross(verts[idx[i + 1]] - a)
		norms[idx[i]] += fn
		norms[idx[i + 1]] += fn
		norms[idx[i + 2]] += fn
	for i in norms.size():
		norms[i] = norms[i].normalized() if norms[i].length_squared() > 1e-12 else Vector3.UP
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

## 預設大島的輪廓：圓角方形（rx = rz 時是圓的）加一點歪扭。從中心往 a 這個方向到岸邊的距離
static func _outline(rx: float, rz: float, a: float, s: float) -> float:
	var n := 2.0 if is_equal_approx(rx, rz) else 3.0
	var base := pow(pow(absf(cos(a)) / rx, n) + pow(absf(sin(a)) / rz, n), -1.0 / n)
	return base * (1.0 + 0.05 * sin(2.0 * a + s) + 0.04 * sin(3.0 * a + s * 2.1) + 0.03 * sin(5.0 * a + s * 3.3) + 0.015 * sin(9.0 * a + s))

## 預設的島的網格：第 0 面是島面（平的，草皮往外垂一點），第 1 面是岩壁（一層一層往下收，插進海裡）
func _island_mesh(rx: float, rz: float, s: float) -> ArrayMesh:
	var segs := 48 if rx < 8.0 else 120
	var mesh := ArrayMesh.new()
	var top := PackedVector3Array()
	var rings := 6
	for si in segs:
		var a := si * TAU / segs
		var rr := _outline(rx, rz, a, s)
		for ri in rings + 1:
			var t := float(ri) / rings
			top.append(Vector3(cos(a) * rr * t, TOP_Y, sin(a) * rr * t))
		# 草皮的邊：往外一點、往下垂
		var lip := 0.35 + 0.25 * absf(sin(a * 9.0 + s))
		top.append(Vector3(cos(a) * (rr + 0.16), TOP_Y - lip * 0.5, sin(a) * (rr + 0.16)))
		top.append(Vector3(cos(a) * (rr + 0.02), TOP_Y - lip, sin(a) * (rr + 0.02)))
	_surface(mesh, top, _grid_indices(segs, rings + 3))
	var cliff := PackedVector3Array()
	var rows := 6
	for si in segs:
		var a := si * TAU / segs
		var rr := _outline(rx, rz, a, s) - 0.12
		for ri in rows + 1:
			var d := float(ri) / rows
			var bump := 0.22 * sin(a * 17.0 + ri * 2.1 + s) * sin(a * 7.0 - ri * 1.3)
			var q := rr - 0.9 * pow(d, 1.4) + bump * (0.3 + d)
			cliff.append(Vector3(cos(a) * q, lerpf(TOP_Y - 0.2, -1.4, d), sin(a) * q))
	_surface(mesh, cliff, _grid_indices(segs, rows + 1))
	return mesh

func _tex_mat(tex: String, tint: Color, scale := 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 1.0
	return m

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

## 放一個模型：縮放到最長邊 = target 公尺，底部貼在 pos
func _spawn_fit(parent: Node3D, path: String, pos: Vector3, target: float, yaw := 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	var n := ps.instantiate() as Node3D
	holder.add_child(n)
	var bb := _aabb(n, Transform3D.IDENTITY)
	var s := target / maxf(maxf(bb.size.x, bb.size.y), maxf(bb.size.z, 0.001))
	var c := bb.get_center()
	n.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), -Vector3(c.x, bb.position.y, c.z) * s) * n.transform
	return holder

## 預設的大島（沒有 MAP_SCRIPT 的大關）：共用貼圖的草地島，空地上種一些樹
func _default_island(root: Node3D, e: int, ctx: Dictionary) -> void:
	var th: Dictionary = DEFAULT_THEMES[e % DEFAULT_THEMES.size()]
	var c: Vector2 = ctx.center
	var s := 1.0 + e * 0.9
	var mi := MeshInstance3D.new()
	mi.name = "Island"
	mi.mesh = _island_mesh(ctx.rx, ctx.rz, s)
	mi.position = Vector3(c.x, 0, c.y)
	mi.set_surface_override_material(0, _tex_mat(String(th.tex), (th.top as Color) * 1.25))
	mi.set_surface_override_material(1, _tex_mat("lichen_rock_diff_1k.jpg", (th.cliff as Color) * 1.3, 0.18))
	root.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + e
	var placed := 0
	for i in 200:
		if placed >= 8 + int(float(ctx.rx) * 0.5):
			break
		var a := rng.randf() * TAU
		var d := _outline(ctx.rx, ctx.rz, a, s) * sqrt(rng.randf()) - 1.6
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if d < 0.0 or not spot_free(ctx, x, z):
			continue
		var tree := String(DEFAULT_THEMES[(e + placed) % DEFAULT_THEMES.size()].tree)
		_spawn_fit(root, tree, Vector3(x, TOP_Y - 0.05, z), rng.randf_range(2.0, 3.2) * (0.4 if tree.contains("Bush") else 1.0), rng.randf() * TAU)
		placed += 1

## 預設的地標（沒有 MAP_SCRIPT 的大關）：每一小關輪流換一個模型（穀倉、風車、筒倉…），旁邊兩三棵樹
func _default_spot(root: Node3D, e: int, k: int) -> void:
	var th: Dictionary = DEFAULT_THEMES[(k + e * 2) % DEFAULT_THEMES.size()]
	_spawn_fit(root, String(th.model), Vector3(0, -0.05, -0.3), 4.2, 0.35)
	var tree := String(th.tree)
	var small := tree.contains("Bush")
	for t in [[2.9, 0.4, 2.4], [-3.0, 0.6, 2.0], [2.4, -2.2, 2.8]]:
		_spawn_fit(root, tree, Vector3(t[0], -0.05, t[1]), float(t[2]) * (0.45 if small else 1.0), t[0] * 2.0)
	root.set_meta("bubble_y", 5.2)

## 還沒做好的大關：一座灰色的小島，被幾團雲蓋住（root 在海面上）
func _mystery_isle(root: Node3D, e: int) -> void:
	var s := 1.0 + e * 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = _island_mesh(ISLE_R, ISLE_R, s)
	mi.set_surface_override_material(0, _tex_mat("grass_ground_diff_1k.jpg", Color(0.80, 0.82, 0.86)))
	mi.set_surface_override_material(1, _tex_mat("lichen_rock_diff_1k.jpg", Color(0.62, 0.64, 0.70), 0.18))
	root.add_child(mi)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 1)
	cm.emission_enabled = true
	cm.emission = Color(0.80, 0.86, 0.94)
	cm.emission_energy_multiplier = 0.55
	cm.roughness = 1.0
	for i in 9:
		var a := i * TAU / 9.0 + s
		var d := 0.0 if i == 0 else (1.6 if i < 4 else 3.4)
		var blob := SphereMesh.new()
		blob.radius = 1.0
		blob.height = 2.0
		blob.radial_segments = 16
		blob.rings = 8
		var b := MeshInstance3D.new()
		b.mesh = blob
		b.material_override = cm
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sc := 2.6 - d * 0.32 + 0.4 * sin(i * 2.3)
		b.scale = Vector3(sc * 1.25, sc * 0.8, sc)
		b.position = Vector3(cos(a) * d, TOP_Y + 1.5 + 0.5 * sin(i * 1.7), sin(a) * d)
		root.add_child(b)
		_clouds.append({"node": b, "base": b.position, "phase": i * 0.9 + e})
	root.set_meta("bubble_y", 5.6)

# ---------------------------------------------------------------- 家豪

func _build_hero() -> void:
	_hero = Node3D.new()
	_hero.name = "Hero"
	add_child(_hero)
	_hero_tilt = Node3D.new()
	_hero.add_child(_hero_tilt)
	_hero_body = Node3D.new()
	_hero_tilt.add_child(_hero_body)
	# 棋子底座（世界地圖上才看得到）：家豪變成棋盤上的一顆棋
	_hero_base = _build_pad(_hero, Vector3(0, -0.22, 0), HOME_COLOR, 0.5)
	_hero_base.visible = false
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	_shadow_mat = _flat_mat(Color(0.02, 0.10, 0.22, 0.0), true)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.render_priority = 4
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.visible = false
	add_child(_shadow)
	var chars := Node3D.new()
	chars.set_script(load("res://scripts/characters.gd"))
	chars.set_process(false)
	_hero_body.add_child(chars)
	var chicken: Node3D = chars._make_round_chicken(true)
	chars.add_child(chicken)
	var bb := _aabb(chicken, Transform3D.IDENTITY)
	if bb.size.y > 0.01:
		chars.scale = Vector3.ONE * (1.7 / bb.size.y)
		chars.position.y = -bb.position.y * chars.scale.y
	# 主島上的幾隻母雞（白色、沒穿帽 T）：在家門口和田邊啄來啄去
	if not worlds.is_empty() and int(worlds[0].n) >= 2:
		var home: Vector3 = worlds[0].pads[_first_open_stage_of(0)]
		var hens := [Vector3(-3.6, 0, 2.6), Vector3(3.3, 0, 2.2), Vector3(-5.6, 0, -0.6), Vector3(5.4, 0, 3.4), Vector3(1.6, 0, 4.6)]
		for i in hens.size():
			var hc := Node3D.new()
			hc.set_script(load("res://scripts/characters.gd"))
			hc.set_process(false)
			add_child(hc)
			var hen: Node3D = hc._make_round_chicken(false)
			hc.add_child(hen)
			var hb := _aabb(hen, Transform3D.IDENTITY)
			if hb.size.y > 0.01:
				var hs := (1.25 + 0.15 * sin(i * 2.3)) / hb.size.y
				hen.scale = Vector3.ONE * hs
				hen.position.y = -hb.position.y * hs
			var base: Vector3 = home + hens[i] + Vector3(0, 0.02, 0)
			hc.position = base
			_hens.append({"node": hc, "base": base, "phase": i * 1.37})

## 家豪站在站點上的位置
func _stand(e: int, k: int) -> Vector3:
	return (worlds[e].pads[k] as Vector3) + Vector3(0, 0.3, 0)

## 世界地圖上家豪這顆棋子放在第 e 座島的哪裡：路的正中間往南一點（靠鏡頭這一側通常是空地，不擋地標）
func _token(e: int) -> Vector3:
	var w: Dictionary = worlds[e]
	var n := int(w.n)
	var mid: Vector3 = ((w.pads[0] as Vector3) + (w.pads[n - 1] as Vector3)) * 0.5
	var c: Vector3 = w.center
	return Vector3(mid.x, mid.y + 0.3, minf(mid.z + 7.5, c.z + float(w.rz) - 2.2))

## 家豪現在該站在哪（島上：站點上；世界地圖：那座島的棋子位置；拉遠拉近時在兩個之間）
func _stand_now() -> Vector3:
	return _stand(selected, stage_sel).lerp(_token(selected), _z())

# ================================================================== 音效（程式合成）

## 整個遊戲現在是不是靜音
static func sound_muted() -> bool:
	return AudioServer.is_bus_mute(0)

## 開／關整個遊戲的聲音，並記到設定檔
static func set_sound_muted(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("audio", "muted", on)
	cf.save(SETTINGS_PATH)

func _build_audio() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		AudioServer.set_bus_mute(0, bool(cf.get_value("audio", "muted", false)))
	var streams := {
		"hop": _snd_hop(), "arrive": _snd_arrive(), "bump": _snd_bump(), "fly": _snd_fly(),
		"land": _snd_land(), "start": _snd_start(), "click": _snd_click(), "bgm": _snd_bgm(),
	}
	for id in streams:
		var p := AudioStreamPlayer.new()
		p.stream = streams[id]
		p.volume_db = BGM_DB if id == "bgm" else -4.0
		add_child(p)
		_snd[id] = p
	(_snd["bgm"] as AudioStreamPlayer).play()

## 播一個音效。pitch：音高倍率（走路的每一跳稍微不一樣，才不會像機關槍）
func _play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _snd.get(id)
	if p:
		p.pitch_scale = pitch
		p.play()

## 換場景之後還要繼續響的音效（按下開始）：播放器掛在最上層，播完自己消失
func _play_detached(id: String) -> void:
	var src: AudioStreamPlayer = _snd.get(id)
	if src == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = src.stream
	p.volume_db = src.volume_db
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## V／喇叭按鈕：開關聲音（打開的時候響一聲，讓人知道有聲音了）
func _toggle_sound() -> void:
	set_sound_muted(not sound_muted())
	_snd_pop = 0.25
	if not sound_muted():
		_play("click")

static func _snd_wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SND_RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

static func _snd_buf(sec: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(sec * SND_RATE))
	return s

## 在 buf 的第 at 秒加一顆音樂盒的音（基音＋兩個泛音，敲下去之後慢慢變小）。wrap：超出尾巴的部分繞回開頭（循環音樂用）
static func _bell(buf: PackedFloat32Array, at: float, note: int, dur: float, amp: float, wrap := false) -> void:
	var f := 440.0 * pow(2.0, (note - 69) / 12.0)
	var n := int(dur * SND_RATE)
	var start := int(at * SND_RATE)
	var size := buf.size()
	for j in n:
		var i := start + j
		if i >= size:
			if not wrap:
				break
			i %= size
		var t := float(j) / SND_RATE
		var env := minf(float(j) / 60.0, 1.0) * exp(-t * 5.0 / dur)
		buf[i] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0) + 0.15 * sin(TAU * f * 4.0 * t) * exp(-t * 12.0)) * env * amp

## 走路的每一跳：很短、往上滑的「啵」
static func _snd_hop() -> AudioStreamWAV:
	var s := _snd_buf(0.07)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		ph += TAU * lerpf(420.0, 760.0, k) / SND_RATE
		s[i] = sin(ph) * sin(k * PI) * 0.32
	return _snd_wav(s)

## 走到站點：往上的兩顆音「叮咚」
static func _snd_arrive() -> AudioStreamWAV:
	var s := _snd_buf(0.6)
	_bell(s, 0.0, 76, 0.35, 0.4)
	_bell(s, 0.09, 81, 0.5, 0.45)
	return _snd_wav(s)

## 被擋住（還沒解鎖、走到盡頭）：兩下悶悶的「咚咚」
static func _snd_bump() -> AudioStreamWAV:
	var s := _snd_buf(0.3)
	for hit in 2:
		var at := int(hit * 0.11 * SND_RATE)
		var ph := 0.0
		for j in int(0.12 * SND_RATE):
			var k := float(j) / (0.12 * SND_RATE)
			ph += TAU * lerpf(190.0, 110.0, k) / SND_RATE
			s[at + j] += sin(ph) * (1.0 - k) * 0.6
	return _snd_wav(s)

## 飛到別的大關：一聲往上再往下的口哨
static func _snd_fly() -> AudioStreamWAV:
	var s := _snd_buf(JUMP_TIME)
	var ph := 0.0
	for i in s.size():
		var k := float(i) / s.size()
		var f := lerpf(500.0, 1500.0, sin(k * PI)) * (1.0 + 0.02 * sin(k * 70.0))
		ph += TAU * f / SND_RATE
		s[i] = sin(ph) * sin(k * PI) * 0.22
	return _snd_wav(s)

## 落地：一下軟軟的「砰」加一顆低音
static func _snd_land() -> AudioStreamWAV:
	var s := _snd_buf(0.5)
	var ph := 0.0
	for j in int(0.16 * SND_RATE):
		var k := float(j) / (0.16 * SND_RATE)
		ph += TAU * lerpf(170.0, 70.0, k) / SND_RATE
		s[j] += sin(ph) * (1.0 - k) * 0.7
	_bell(s, 0.04, 72, 0.4, 0.3)
	return _snd_wav(s)

## 按下開始：往上的四顆音，最後一顆拉長
static func _snd_start() -> AudioStreamWAV:
	var s := _snd_buf(1.1)
	var notes := [72, 76, 79, 84]
	for i in notes.size():
		_bell(s, i * 0.085, notes[i], 0.35 if i < 3 else 0.8, 0.36)
	_bell(s, 0.255, 88, 0.8, 0.16)
	return _snd_wav(s)

## 按鈕：一顆短短的高音
static func _snd_click() -> AudioStreamWAV:
	var s := _snd_buf(0.2)
	_bell(s, 0.0, 84, 0.18, 0.4)
	return _snd_wav(s)

## 背景音樂：音樂盒的四小節循環（C–Am–F–G，9.6 秒），音符的尾巴繞回開頭，所以接起來聽不出接縫
static func _snd_bgm() -> AudioStreamWAV:
	var step := 0.3
	var melody := [76, -1, 79, -1, 84, -1, 79, 76,  81, -1, 76, -1, 72, -1, 76, -1,
		77, -1, 81, -1, 84, -1, 81, 77,  79, -1, 74, -1, 79, 83, 86, -1]
	var bass := [48, 55, 52, 55,  45, 52, 48, 52,  41, 48, 45, 48,  43, 50, 47, 50]
	var s := _snd_buf(melody.size() * step)
	for i in melody.size():
		if melody[i] >= 0:
			_bell(s, i * step, melody[i], 1.1, 0.20, true)
	for i in bass.size():
		_bell(s, i * step * 2.0, bass[i], 0.9, 0.22, true)
	return _snd_wav(s, true)

# ================================================================== 天色

## 第 e 座島第 k 個站點的天色：DEFAULT_MOOD 加上大關自己的 mood(k)。世界地圖一律用預設的大晴天
func _mood_of(e: int, k: int) -> Dictionary:
	var m := DEFAULT_MOOD.duplicate()
	if _map:
		return m
	var hook: Object = worlds[e].hook if e < worlds.size() else null
	if hook and hook.has_method("mood"):
		m.merge(hook.mood(int(_st(e, k).get("k", k))), true)
	return m

## 第 e 座島用哪個天空材質（大關有 MAP_SKY 就用它的著色器；世界地圖用共用的天空）
func _sky_of(e: int) -> ShaderMaterial:
	var ch: Dictionary = entries[e].ch
	var path := String(_chapter_consts(ch).get("MAP_SKY", "")) if _playable(ch) and not _map else ""
	if path == "" or not ResourceLoader.exists(path):
		return _sky_default
	if not _sky_mats.has(path):
		var m := ShaderMaterial.new()
		m.shader = load(path)
		_sky_mats[path] = m
	return _sky_mats[path]

func _set_mood(e: int, k: int, instant := false) -> void:
	_mood_from = _blend_mood(_mood_k) if not _mood_to.is_empty() else {}
	_mood_to = _mood_of(e, k)
	var sky := _sky_of(e)
	if sky != _sky_mat:
		_sky_mat = sky
		_env.sky.sky_material = sky
	_mood_k = 1.0 if instant or _mood_from.is_empty() else 0.0
	_apply_mood(_blend_mood(_mood_k))

func _blend_mood(k: float) -> Dictionary:
	var e := k * k * (3.0 - 2.0 * k)
	var out := {}
	for key in _mood_to:
		var b = _mood_to[key]
		var a = _mood_from.get(key, b)
		if b is Color and a is Color:
			out[key] = (a as Color).lerp(b, e)
		elif b is Vector3 and a is Vector3:
			out[key] = (a as Vector3).lerp(b, e)
		elif (b is float or b is int) and (a is float or a is int):
			out[key] = lerpf(float(a), float(b), e)
		else:
			out[key] = b
	return out

func _apply_mood(m: Dictionary) -> void:
	_sun.light_color = m.sun
	_sun.light_energy = m.energy
	_sun.rotation = m.rot
	_env.ambient_light_color = m.amb
	_env.ambient_light_energy = m.amb_e
	_env.fog_light_color = m.fog
	if m.has("sea.near_c") and m.has("sea.stroke_c"):
		_shallow_tint = (m["sea.near_c"] as Color).lerp(m["sea.stroke_c"], 0.45)
	for key in m:
		var s := String(key)
		if s.begins_with("sky."):
			_sky_mat.set_shader_parameter(s.substr(4), m[key])
		elif s.begins_with("sea."):
			_sea_mat.set_shader_parameter(s.substr(4), m[key])

# ================================================================== 星星、圖示的資料

## 這個大關 chapter.gd 裡的常數（ICON、STARS_SCRIPT 這類選用的設定）
func _chapter_consts(ch: Dictionary) -> Dictionary:
	if ch.is_empty():
		return {}
	if not _consts.has(ch.id):
		var c := {}
		var path := String(ch.dir).path_join("chapter.gd")
		if ResourceLoader.exists(path):
			var scr := load(path) as Script
			if scr:
				c = scr.get_script_constant_map()
		_consts[ch.id] = c
	return _consts[ch.id]

## 這個大關的星星紀錄表（{關卡場景路徑: {條件 id: true}}）；沒有三星制度的大關回傳 null
## 預設找大關資料夾裡的 rescue_battle.gd 的 static var best_stars；chapter.gd 也可以用 STARS_SCRIPT 指定別的腳本。
## 注意：這張表只在這次開遊戲期間累積，所以重開遊戲後，過關的小關至少算 1 顆（照存檔）。
func _star_table(ch: Dictionary):
	if ch.is_empty():
		return null
	if not _star_src.has(ch.id):
		var table = null
		var path := String(_chapter_consts(ch).get("STARS_SCRIPT", String(ch.dir).path_join("rescue_battle.gd")))
		if ResourceLoader.exists(path):
			var scr = load(path)
			if scr is Script:
				var v = (scr as Script).get("best_stars")
				if v is Dictionary:
					table = v
		_star_src[ch.id] = table
	return _star_src[ch.id]

## 這一小關拿了幾顆星（0～STAR_MAX）；-1 代表這個大關沒有三星制度（只用打勾表示過關）
func _stars(ch: Dictionary, st: Dictionary) -> int:
	var table = _star_table(ch)
	if table == null:
		return -1
	var got = (table as Dictionary).get(String(st.scene), {})
	var n := mini(STAR_MAX, (got as Dictionary).size()) if got is Dictionary else 0
	if n == 0 and Progress.is_cleared(st.id):
		n = 1
	return maxi(n, int(_ledger.get(String(st.scene), 0)))

## 把每一關拿到的星星記進衣櫃的存檔（商店用星星買服裝），順便讀回以前記過的（重開遊戲星星還在）。
## 沒有三星制度的大關：過一關算 1 顆。範例關不算。
func _sync_stars() -> void:
	var records := {}
	var max_total := 0
	for ch in LEVELS:
		if _is_example(ch) or not _playable(ch):
			continue
		for st in ch.stages:
			var key := String(st.scene)
			if key == "":
				continue
			var n := _stars(ch, st)
			if n < 0:
				n = 1 if Progress.is_cleared(st.id) else 0
				max_total += 1
			else:
				max_total += STAR_MAX
			records[key] = n
	Wardrobe.record_stars(records, max_total)
	for key in records:
		_ledger[key] = maxi(int(records[key]), Wardrobe.stars_of(key))
	_wallet = Wardrobe.wallet()

func open_shop() -> void:
	if _starting or not ResourceLoader.exists(SHOP_SCENE):
		return
	_starting = true
	_play_detached("start")
	_remember()                          # 從商店回來還站在原本那一格
	get_tree().change_scene_to_file(SHOP_SCENE)

# ================================================================== 畫圖工具

## 自己畫的方塊（卡片、圓點、面板都用它）：畫圖交給 painter，滑鼠交給 on_hover／on_click
class _Pad:
	extends Control
	var painter: Callable
	var on_hover: Callable
	var on_click: Callable
	var data := {}
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion and on_hover.is_valid():
			on_hover.call(self, e)
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
			on_click.call(self, e)
			accept_event()

func _pad(parent: Node, painter: Callable, stop_mouse := true) -> _Pad:
	var p := _Pad.new()
	p.painter = painter
	p.mouse_filter = Control.MOUSE_FILTER_STOP if stop_mouse else Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

# ---------------------------------------------------------------- 畫圖

func _font() -> Font:
	var f := UIStyle.font()
	return f if f else ThemeDB.fallback_font

func _box(bg: Color, edge: Color, radius: float, border := 3.0, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(int(border))
	s.border_width_bottom = int(border) + 2
	s.set_corner_radius_all(int(radius))
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = 8
		s.shadow_offset = Vector2(3, 6)
	return s

func _text(c: Control, pos: Vector2, t: String, size: float, col: Color, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(_font(), pos, t, align, w, int(size), col)

## 字太寬就縮小字級（不截斷）
func _fit(t: String, size: float, w: float, min_size := 11.0) -> float:
	var f := _font()
	while size > min_size and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x > w:
		size -= 1.0
	return size

func _lock_icon(c: Control, center: Vector2, s: float, col: Color, rot := 0.0) -> void:
	# 大鎖：U 形鎖環＋圓角鎖身＋鑰匙孔（rot 是抖動的角度，以鎖身中心為軸）
	c.draw_set_transform(center + Vector2(0, s * 0.3), rot, Vector2.ONE)
	var o := Vector2(0, -s * 0.3)
	c.draw_arc(o + Vector2(0, -s * 0.15), s * 0.42, PI, TAU, 24, col, s * 0.14, true)
	c.draw_line(o + Vector2(-s * 0.42, -s * 0.15), o + Vector2(-s * 0.42, s * 0.1), col, s * 0.14, true)
	c.draw_line(o + Vector2(s * 0.42, -s * 0.15), o + Vector2(s * 0.42, s * 0.1), col, s * 0.14, true)
	c.draw_style_box(_box(col, col.darkened(0.3), s * 0.12, 2.0, false), Rect2(o + Vector2(-s * 0.62, 0.0), Vector2(s * 1.24, s * 0.9)))
	c.draw_circle(o + Vector2(0, s * 0.36), s * 0.11, Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(o + Vector2(-s * 0.04, s * 0.38), Vector2(s * 0.08, s * 0.22)), Color(0, 0, 0, 0.45))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _check_icon(c: Control, center: Vector2, s: float, col: Color) -> void:
	c.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.45, 0), center + Vector2(-s * 0.1, s * 0.35), center + Vector2(s * 0.5, -s * 0.4)]), col, s * 0.2, true)

func _star(c: Control, center: Vector2, r: float, col: Color, edge := Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.47
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)
	if edge.a > 0.0:
		pts.append(pts[0])
		c.draw_polyline(pts, edge, maxf(r * 0.16, 1.5), true)

## 三顆星：拿到幾顆亮幾顆（沒拿到的是空心灰星）
func _star_row(c: Control, center: Vector2, r: float, have: int, on_dark := false) -> void:
	var gap := r * 2.5
	for i in STAR_MAX:
		var p := center + Vector2((i - (STAR_MAX - 1) * 0.5) * gap, 0)
		if i < have:
			_star(c, p, r, GOLD, Color("8a6410"))
		else:
			_star(c, p, r, Color(1, 1, 1, 0.35) if on_dark else Color(0, 0, 0, 0.12), Color(1, 1, 1, 0.75) if on_dark else Color(0, 0, 0, 0.3))

## 雪花（冰雪島的圖示）
func _snowflake(c: Control, center: Vector2, r: float, col: Color, w: float) -> void:
	for i in 6:
		var a := i * PI / 3.0 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		c.draw_line(center, center + d * r, col, w, true)
		for sgn in [-1.0, 1.0]:
			var b: Vector2 = d.rotated(sgn * 0.85)
			c.draw_line(center + d * r * 0.55, center + d * r * 0.55 + b * r * 0.34, col, w, true)
	c.draw_circle(center, w * 0.9, col)

## 三角旗（「過了幾關」的圖示）：一根桿＋一面實心旗
func _pennant(c: Control, center: Vector2, r: float, col := Color("e0663a")) -> void:
	c.draw_line(center + Vector2(-r * 0.55, -r), center + Vector2(-r * 0.55, r), Color("7a4a2a"), maxf(r * 0.24, 2.0), true)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.45, -r * 0.95), center + Vector2(r * 0.95, -r * 0.35), center + Vector2(-r * 0.45, r * 0.25)]), col)

## 預設圖示：小土丘上一支旗子
func _flag_icon(c: Control, center: Vector2, r: float, col: Color, w: float) -> void:
	c.draw_arc(center + Vector2(0, r * 0.95), r * 0.75, PI * 1.15, PI * 1.85, 16, col, w, true)
	c.draw_line(center + Vector2(-r * 0.15, r * 0.3), center + Vector2(-r * 0.15, -r * 0.85), col, w, true)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.15, -r * 0.85), center + Vector2(r * 0.7, -r * 0.5), center + Vector2(-r * 0.15, -r * 0.15)]), col)

## 島的圓徽章：認得的島畫圖示（冰雪島＝雪花、森林＝樹、要塞＝城垛、秋島＝葉子）；其他的 chapter.gd 有 ICON 就用那個字，沒有就畫旗子
func _island_badge(c: Control, ch: Dictionary, center: Vector2, r: float, col: Color) -> void:
	c.draw_circle(center + Vector2(0, r * 0.08), r, col.darkened(0.35))
	c.draw_circle(center, r, col.darkened(0.12))
	c.draw_circle(center, r * 0.86, col.lightened(0.25))
	var ink := col.darkened(0.6)
	var k := r / 22.0
	match String(ch.id):
		"ice":
			_snowflake(c, center, r * 0.62, ink, r * 0.17)
			_snowflake(c, center, r * 0.62, Color(1, 1, 1), r * 0.09)
		"forest":
			for i in 3:
				var y := (-13.0 + i * 7.0) * k
				var hw := (7.0 + i * 3.5) * k
				c.draw_colored_polygon(PackedVector2Array([center + Vector2(0, y - 3.0 * k), center + Vector2(hw, y + 8.0 * k), center + Vector2(-hw, y + 8.0 * k)]), ink)
			c.draw_rect(Rect2(center + Vector2(-2.5, 9.0) * k, Vector2(5.0, 6.0) * k), ink)
		"fort":
			c.draw_rect(Rect2(center + Vector2(-11, -5) * k, Vector2(22, 18) * k), ink)
			for i in 3:
				c.draw_rect(Rect2(center + Vector2(-11.0 + i * 8.5, -12.0) * k, Vector2(5.0, 8.0) * k), ink)
			c.draw_rect(Rect2(center + Vector2(-3.5, 3.0) * k, Vector2(7.0, 10.0) * k), col.lightened(0.25))
		"liuchiyu":
			var leaf := PackedVector2Array()
			for p in [Vector2(0, -14), Vector2(4, -6), Vector2(12, -8), Vector2(9, 0), Vector2(14, 5), Vector2(5, 6), Vector2(0, 13), Vector2(-5, 6), Vector2(-14, 5), Vector2(-9, 0), Vector2(-12, -8), Vector2(-4, -6)]:
				leaf.append(center + (p as Vector2) * k * 0.92)
			c.draw_colored_polygon(leaf, ink)
			c.draw_line(center + Vector2(0, 4) * k, center + Vector2(0, 15) * k, ink, 2.4 * k, true)
		_:
			var glyph := String(_chapter_consts(ch).get("ICON", ""))
			if glyph != "":
				_text(c, center + Vector2(-r, r * 0.36), glyph.substr(0, 1), r * 1.0, INK, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				_flag_icon(c, center, r * 0.6, ink, r * 0.12)

## 圓形數字徽章（小關編號）
func _num_badge(c: Control, center: Vector2, r: float, n: int, col: Color, ring := Color(1, 1, 1, 0.95)) -> void:
	c.draw_circle(center + Vector2(0, r * 0.14), r + r * 0.1, Color(0, 0, 0, 0.22))
	c.draw_circle(center, r + maxf(r * 0.12, 3.0), ring)
	c.draw_circle(center, r, col)
	_text(c, center + Vector2(-r, r * 0.38), str(n), r * 1.05, INK, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

# ================================================================== 介面（畫在 3D 地圖上面）

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	# 三張蓋滿畫面的透明畫布：島上的（站點徽章、泡泡）、世界地圖的（島牌）、兩邊都有的（標題、按鈕、按鍵提示）。
	# 前兩張跟著鏡頭拉遠拉近淡入淡出
	_ov_isle = _pad(_layer, _paint_isle_layer, false)
	_ov_map = _pad(_layer, _paint_map_layer, false)
	_overlay = _pad(_layer, _paint_overlay, false)
	for p in [_ov_isle, _ov_map, _overlay]:
		(p as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 提示字卡
	_toast = Label.new()
	_toast.label_settings = UIStyle.ls(26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 150
	_toast.visible = false
	UIStyle.pill(_toast)
	_layer.add_child(_toast)

## 畫面的縮放比例（以 1600×900 為準）
func _u() -> float:
	var vs := get_viewport().get_visible_rect().size
	return minf(vs.x / 1600.0, vs.y / 900.0)

## 鏡頭拉到哪了（0 = 島上、1 = 世界地圖；頭尾慢、中間快）
func _z() -> float:
	return _zoom * _zoom * (3.0 - 2.0 * _zoom)

## 這個大關的星星：[拿到幾顆, 一共幾顆, 有沒有三星制度]
func _star_total(ch: Dictionary) -> Array:
	var have := 0
	var maxn := 0
	var starred := _star_table(ch) != null
	for st in ch.stages:
		if starred:
			have += maxi(_stars(ch, st), 0)
			maxn += STAR_MAX
		else:
			have += 1 if Progress.is_cleared(st.id) else 0
			maxn += 1
	return [have, maxn, starred]

## 所有主題島加起來：[星星拿到幾顆, 星星一共幾顆, 過了幾關（沒有三星制度的島）, 一共幾關]
func _star_all() -> Array:
	var out := [0, 0, 0, 0]
	for ent in entries:
		if _playable(ent.ch) and not _is_example(ent.ch):
			var t := _star_total(ent.ch)
			var o := 0 if t[2] else 2
			out[o] += int(t[0])
			out[o + 1] += int(t[1])
	var ht := _hub_total()
	out[2] += int(ht[0])
	out[3] += int(ht[1])
	return out

func _paint_isle_layer(c: Control) -> void:
	_start_rect = Rect2()
	if worlds.is_empty() or selected < 0:
		return
	var u := _u()
	_paint_nodes(c, u)
	_paint_bubble(c, u)

func _paint_map_layer(c: Control) -> void:
	if worlds.is_empty() or selected < 0:
		return
	_paint_chart(c, _u())
	_paint_tags(c, _u())
	_paint_compass(c, _u())

func _paint_overlay(c: Control) -> void:
	if worlds.is_empty() or selected < 0:
		return
	var u := _u()
	_paint_hud(c, u)
	_paint_buttons(c, u)
	_paint_keys(c, u)

## 「下一步在這裡」的記號：一顆跳動的紅色驚嘆號（島上：下一關的徽章；世界地圖：還有關卡可以玩的島牌）
func _next_mark(c: Control, at: Vector2, s: float) -> void:
	var np := at + Vector2(0, -absf(sin(_t * 3.4)) * 7.0 * s)
	c.draw_circle(np + Vector2(0, 2.5 * s), 16.5 * s, Color(0, 0, 0, 0.22))
	c.draw_circle(np, 16.5 * s, Color(1, 1, 1))
	c.draw_circle(np, 13.5 * s, SHOP_RED)
	_text(c, np + Vector2(-13.0 * s, 8.5 * s), "!", 24.0 * s, Color(1, 1, 1), 26.0 * s, HORIZONTAL_ALIGNMENT_CENTER)

## 世界地圖上建議下一個去哪座島（只有這一座的島牌掛驚嘆號）：先找玩到一半的，沒有就找還沒開始的；都全過了回傳 -1
func _next_isle() -> int:
	var fresh := -1
	for e in range(1, entries.size()):
		var ch: Dictionary = entries[e].ch
		if not _playable(ch) or _is_example(ch) or _next_station(e) < 0:
			continue
		if ch.stages.any(func(st): return Progress.is_cleared(st.id)):
			return e
		if fresh < 0:
			fresh = e
	return fresh

## 這座島上「下一關」是第幾個站點（第一個還沒過、可以玩的小關；沒有就 -1）
func _next_station(e: int) -> int:
	for k in (_stations[e] as Array).size():
		if String(_st(e, k).kind) == "stage" and _st_open(e, k) and not _st_cleared(e, k):
			return k
	return -1

## 上鎖的圓徽章
func _locked_badge(c: Control, sp: Vector2, r: float) -> void:
	c.draw_circle(sp + Vector2(0, r * 0.14), r * 1.1, Color(0, 0, 0, 0.22))
	c.draw_circle(sp, r + maxf(r * 0.12, 3.0), Color(1, 1, 1, 0.95))
	c.draw_circle(sp, r, LOCKED)
	_lock_icon(c, sp + Vector2(0, -r * 0.15), r * 0.72, Color("8a857a"))

## 衣架（商店的圖示）。k：大小（1 = 半寬 19 像素）
func _hanger(c: Control, o: Vector2, k: float, col: Color) -> void:
	c.draw_arc(o + Vector2(0, -13) * k, 5.0 * k, -PI * 0.9, PI * 0.5, 12, col, 3.2 * k, true)
	c.draw_polyline(PackedVector2Array([o + Vector2(0, -8) * k, o + Vector2(-19, 8) * k, o + Vector2(19, 8) * k, o + Vector2(0, -8) * k]), col, 3.2 * k, true)

## 小房子（家／主島的圖示）
func _house(c: Control, o: Vector2, k: float, col: Color, door: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-21, -1) * k, o + Vector2(0, -19) * k, o + Vector2(21, -1) * k]), col)
	c.draw_rect(Rect2(o + Vector2(-14, -2) * k, Vector2(28, 18) * k), col)
	c.draw_rect(Rect2(o + Vector2(-4.5, 5) * k, Vector2(9, 11) * k), door)

## 皇冠（全破的島）
func _crown(c: Control, o: Vector2, k: float) -> void:
	var pts := PackedVector2Array([o + Vector2(-13, 8) * k, o + Vector2(-16, -7) * k, o + Vector2(-7, 0) * k, o + Vector2(0, -11) * k,
		o + Vector2(7, 0) * k, o + Vector2(16, -7) * k, o + Vector2(13, 8) * k])
	c.draw_colored_polygon(pts, GOLD)
	pts.append(pts[0])
	c.draw_polyline(pts, Color("8a6410"), maxf(2.0 * k, 1.5), true)
	for x in [-16.0, 0.0, 16.0]:
		c.draw_circle(o + Vector2(x, -9.0 if x != 0.0 else -13.0) * k, 2.6 * k, Color("fff1bf"))

## 圓形圖示徽章：商店＝衣架、家＝小房子、冒險紀錄＝星星、告示牌＝問號、碼頭＝帆船
func _icon_badge(c: Control, center: Vector2, r: float, kind: String) -> void:
	var col := HUB_COLOR
	match kind:
		"shop":
			col = SHOP_RED
		"board":
			col = Color("e3a31c")
		"guide":
			col = GUIDE_COLOR
		"dock":
			col = DOCK_COLOR
	c.draw_circle(center + Vector2(0, r * 0.14), r + r * 0.1, Color(0, 0, 0, 0.22))
	c.draw_circle(center, r + maxf(r * 0.12, 3.0), Color(1, 1, 1, 0.95))
	c.draw_circle(center, r, col)
	var k := r / 30.0
	var white := Color(1, 1, 1)
	match kind:
		"shop":
			_hanger(c, center + Vector2(0, r * 0.08), k, white)
		"board":
			_star(c, center + Vector2(0, r * 0.03), r * 0.62, white)
		"guide":
			_text(c, center + Vector2(-r, r * 0.42), "?", r * 1.25, white, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)
		"dock":
			# 帆船：一根桅、一面三角帆、一個船身
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-1, -19) * k, center + Vector2(14, 3) * k, center + Vector2(-1, 3) * k]), white)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -12) * k, center + Vector2(-4, 3) * k, center + Vector2(-13, 3) * k]), white)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-17, 7) * k, center + Vector2(17, 7) * k, center + Vector2(11, 16) * k, center + Vector2(-11, 16) * k]), white)
		_:
			_house(c, center + Vector2(0, r * 0.06), r / 34.0, white, col.darkened(0.25))

## 島上每個站點上面浮著的徽章：小關是編號＋三顆小星，商店是衣架，家是小房子（家豪站的那一格不畫，那一格有泡泡）
func _paint_nodes(c: Control, u: float) -> void:
	var busy := _busy()
	var e := selected
	var w: Dictionary = worlds[e]
	var next_k := _next_station(e)
	for k in int(w.n):
		if k == stage_sel and not busy:
			continue
		var wp: Vector3 = (w.pads[k] as Vector3) + Vector3(0, 1.5, 0)
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		if absi(k - stage_sel) == 1 and not busy:
			# 左右隔壁那一格：就算站點在畫面邊上，徽章也要完整看得到
			sp.x = clampf(sp.x, 64.0 * u, c.size.x - 64.0 * u)
			sp.y = minf(sp.y, c.size.y - 150.0 * u)
		if sp.x < -80 or sp.y < -80 or sp.x > c.size.x + 80 or sp.y > c.size.y + 80:
			continue
		var s := clampf(24.0 / _cam.global_position.distance_to(wp), 0.4, 1.1) * u
		var r := 25.0 * s
		var st := _st(e, k)
		var kind := String(st.kind)
		if kind != "stage" and kind != "locked":
			_icon_badge(c, sp, r, kind)
			continue
		if not _st_open(e, k):
			_locked_badge(c, sp, r)
			continue
		var cleared := _st_cleared(e, k)
		_num_badge(c, sp, r, int(st.k) + 1, GREEN if cleared else _st_color(e, k))
		if k == next_k:
			_next_mark(c, sp + Vector2(r * 0.95, -r * 1.05), maxf(s, 0.95 * u))
		var stars := _stars(st.ch, _st_stage(st))
		if stars >= 0:
			var y := sp.y + r + 20.0 * s
			c.draw_style_box(_box(Color(PAPER, 0.96), PAPER_EDGE, 14 * s, 2.0, false), Rect2(Vector2(sp.x - 42 * s, y - 14 * s), Vector2(84 * s, 28 * s)))
			_star_row(c, Vector2(sp.x, y), 9.5 * s, stars)
		elif cleared:
			c.draw_circle(sp + Vector2(r * 0.75, -r * 0.75), r * 0.36, Color(1, 1, 1))
			_check_icon(c, sp + Vector2(r * 0.75, -r * 0.75), r * 0.4, GREEN)

## 泡泡的外框：浮在 wp 上面，尖角指著它。回傳 [框, 冒出來時縮放過的 u]；看不到就回傳 []
func _bubble_frame(c: Control, u: float, wp: Vector3, width: float) -> Array:
	if _cam.is_position_behind(wp):
		return []
	# 冒出來的時候從小放大（尺寸直接乘上去，不用畫布的變形：_lock_icon 會自己改變形）
	u *= 0.6 + 0.4 * (1.0 - pow(1.0 - _bubble_a, 3.0))
	var bw := width * u
	var bh := 132.0 * u
	var tail := 24.0 * u
	var anchor := _cam.unproject_position(wp)
	anchor.x = _cam.unproject_position(_hero.position).x
	var u1 := _u()
	anchor.y = clampf(anchor.y, 335.0 * u1, 430.0 * u1) + sin(_t * 2.2) * 3.0 * u
	# 泡泡不要跑出畫面：框框往裡面推，尖角還是指著地標
	var vw := get_viewport().get_visible_rect().size.x
	var r := Rect2(Vector2(clampf(anchor.x - bw * 0.5, 16.0 * u, vw - bw - 16.0 * u), anchor.y - bh - tail), Vector2(bw, bh))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 26 * u, 3.0), r)
	var tx := clampf(anchor.x, r.position.x + 40 * u, r.end.x - 40 * u)
	var ty := anchor.y - tail
	c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 17 * u, ty - 4.0), Vector2(tx + 17 * u, ty - 4.0), Vector2(tx, anchor.y)]), PAPER)
	c.draw_polyline(PackedVector2Array([Vector2(tx - 17 * u, ty - 1.0), Vector2(tx, anchor.y), Vector2(tx + 17 * u, ty - 1.0)]), PAPER_EDGE, 3.0, true)
	return [r, u]

## 泡泡右下角的主要按鈕（Enter 鍵帽畫在按鈕裡）；順便記下它在畫面上的位置給滑鼠點
func _bubble_button(c: Control, u: float, r: Rect2, label: String, bg: Color, edge: Color, ink := Color(1, 1, 1)) -> void:
	var row_y := r.position.y + 96 * u
	var f := _font()
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(25 * u)).x
	var ks := UIStyle.keycap_size("Enter", 14 * u)
	var bw := lw + ks.x + 52 * u
	var br := Rect2(Vector2(r.end.x - bw - 18 * u, row_y - 24 * u), Vector2(bw, 48 * u))
	var pulse := 1.0 + sin(_t * 4.0) * 0.03
	var bb := Rect2(br.get_center() - br.size * 0.5 * pulse, br.size * pulse)
	c.draw_style_box(_box(bg, edge, 22 * u, 3.0, false), bb)
	_text(c, Vector2(bb.position.x + 18 * u, bb.get_center().y + 9 * u), label, 25 * u, ink)
	UIStyle.draw_keycap(c, Vector2(bb.end.x - 12 * u - ks.x, bb.get_center().y - ks.y * 0.5), "Enter", 14 * u)
	_start_rect = bb

## 家豪所在那一格的泡泡：浮在地標上面，尖角指著地標
func _paint_bubble(c: Control, u0: float) -> void:
	if _map or _bubble_a <= 0.02 or _busy():
		return
	var w: Dictionary = worlds[selected]
	var ir: Node3D = w.isle_roots[stage_sel]
	var wp: Vector3 = (w.isles[stage_sel] as Vector3) + Vector3(0, float(ir.get_meta("bubble_y", 5.0)), 0)
	var st := _st_now()
	var kind := String(st.kind)
	var fr := _bubble_frame(c, u0, wp, 400.0 if kind == "stage" else 372.0)
	if fr.is_empty():
		return
	var r: Rect2 = fr[0]
	var u: float = fr[1]
	var o := r.position
	var bc := o + Vector2(50 * u, 46 * u)
	var text_x := o.x + 92 * u
	var row_y := o.y + 96 * u
	match kind:
		"locked":
			var rot := sin(_shake_t * 42.0) * 0.28 * (_shake_t / SHAKE_TIME) if _shake_t > 0.0 else 0.0
			_lock_icon(c, bc + Vector2(0, 14 * u), 34 * u, Color("8a857a"), rot)
			_text(c, Vector2(text_x, o.y + 60 * u), "？？？", 34 * u, Color("7d776c"))
			_text(c, Vector2(text_x, o.y + 100 * u), "即將開放", 22 * u, Color("7d776c"))
		"shop":
			_icon_badge(c, bc, 29 * u, "shop")
			_text(c, Vector2(text_x, o.y + 58 * u), "商店", 32 * u, INK)
			_star(c, Vector2(text_x + 14 * u, row_y), 14 * u, GOLD, Color("8a6410"))
			_text(c, Vector2(text_x + 36 * u, row_y + 9 * u), str(_wallet), 24 * u, INK)
			_bubble_button(c, u, r, "進去", SHOP_RED, Color("8f231c"))
		"board":
			# 冒險紀錄：全部的星星和過關數（只是看的，沒有按鈕）
			_icon_badge(c, bc, 29 * u, "board")
			_text(c, Vector2(text_x, o.y + 58 * u), "冒險紀錄", 32 * u, INK)
			var all := _star_all()
			var x := text_x + 14 * u
			if int(all[1]) > 0:
				_star(c, Vector2(x, row_y), 14 * u, GOLD, Color("8a6410"))
				var t1 := "%d/%d" % [all[0], all[1]]
				_text(c, Vector2(x + 22 * u, row_y + 9 * u), t1, 24 * u, INK)
				x += 22 * u + _font().get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x + 34 * u
			if int(all[3]) > 0:
				_pennant(c, Vector2(x, row_y), 12 * u)
				_text(c, Vector2(x + 20 * u, row_y + 9 * u), "%d/%d" % [all[2], all[3]], 24 * u, INK)
		"guide":
			_icon_badge(c, bc, 29 * u, "guide")
			_text(c, Vector2(text_x, o.y + 58 * u), "告示牌", 32 * u, INK)
			_bubble_button(c, u, r, "操作說明", GUIDE_COLOR.darkened(0.12), Color("2c6f66"))
		"dock":
			_icon_badge(c, bc, 29 * u, "dock")
			_text(c, Vector2(text_x, o.y + 58 * u), "碼頭", 32 * u, INK)
			_bubble_button(c, u, r, "出航", DOCK_COLOR, Color("2c5d8a"))
		"home":
			_icon_badge(c, bc, 29 * u, "home")
			_text(c, Vector2(text_x, o.y + 58 * u), "家豪的家", 32 * u, INK)
			_bubble_button(c, u, r, "重溫那場夢", Color("fff1c9"), Color("b98a4a"), INK)      # 次要的按鈕：米色底，不搶「開始」的綠色
		_:
			var ch: Dictionary = st.ch
			var stage := _st_stage(st)
			var open := _st_open(selected, stage_sel)
			var cleared := _st_cleared(selected, stage_sel)
			var stars := _stars(ch, stage)
			var col: Color = GREEN if cleared else (_st_color(selected, stage_sel) if open else LOCKED)
			if open:
				_num_badge(c, bc, 27 * u, int(st.k) + 1, col, col.darkened(0.3))
			else:
				c.draw_circle(bc, 31 * u, LOCKED_EDGE)
				c.draw_circle(bc, 27 * u, LOCKED)
				_lock_icon(c, bc + Vector2(0, -5 * u), 21 * u, Color("8a857a"))
			var title := String(stage.title)
			var fs := _fit(title, 32 * u, r.end.x - text_x - 20 * u, 16.0)
			_text(c, Vector2(text_x, o.y + 46 * u + fs * 0.36), title, fs, INK)
			if not open:
				_text(c, Vector2(text_x, row_y + 8 * u), "先過第 %d 關" % int(st.k), 22 * u, Color("6f6a60"))
			else:
				if stars >= 0:
					_star_row(c, Vector2(text_x + 44 * u, row_y), 15 * u, stars)
				elif cleared:
					c.draw_circle(Vector2(text_x + 14 * u, row_y), 13 * u, GREEN)
					_check_icon(c, Vector2(text_x + 14 * u, row_y), 14 * u, Color(1, 1, 1))
					_text(c, Vector2(text_x + 34 * u, row_y + 8 * u), "過關", 22 * u, Color("3c7d3c"))
				else:
					c.draw_arc(Vector2(text_x + 14 * u, row_y), 11.5 * u, 0, TAU, 28, Color(0, 0, 0, 0.3), 3.0 * u, true)
					_text(c, Vector2(text_x + 34 * u, row_y + 8 * u), "未過關", 22 * u, Color("6f6a60"))
				_bubble_button(c, u, r, "開始", GREEN, Color("2f7a2f"))

## 世界地圖上島牌要寫的東西：{"title", "col", "stat": "13/18"（沒有就空白）, "starred", "done": 全破, "kind": "hub"／"isle"／"locked"}
func _tag_info(e: int) -> Dictionary:
	var ent: Dictionary = entries[e]
	var todo := _next_station(e) >= 0
	if _is_hub(e):
		var t := _hub_total()
		return {"title": HUB_TITLE, "col": HUB_COLOR, "stat": ("%d/%d" % [t[0], t[1]]) if int(t[1]) > 0 else "", "starred": false,
			"done": int(t[1]) > 0 and int(t[0]) >= int(t[1]), "kind": "hub", "fresh": todo}
	var ch: Dictionary = ent.ch
	if not _playable(ch):
		return {"title": "？？？", "col": LOCKED, "stat": "", "starred": false, "done": false, "kind": "locked", "fresh": false}
	var t2 := _star_total(ch)
	return {"title": String(ch.title), "col": _color_of(ent), "stat": "%d/%d" % [t2[0], t2[1]], "starred": bool(t2[2]),
		"done": int(t2[1]) > 0 and int(t2[0]) >= int(t2[1]), "kind": "isle", "fresh": todo}

## 主島上的關卡：[過了幾關, 一共幾關]
func _hub_total() -> Array:
	var have := 0
	var total := 0
	for k in (_stations[0] as Array).size():
		if String(_st(0, k).kind) == "stage":
			total += 1
			have += 1 if _st_cleared(0, k) else 0
	return [have, total]

## 世界地圖：每座島頭上一張島牌（圓徽章＋名字＋星星）。家豪所在的那座大一號，下面多一顆「登島」按鈕。
func _paint_tags(c: Control, u: float) -> void:
	_tag_rects.resize(entries.size())
	_go_rect = Rect2()
	var f := _font()
	var mouse := c.get_local_mouse_position()
	var vs := get_viewport().get_visible_rect().size
	var cur := int(_jump.e) if not _jump.is_empty() else selected
	var hint := _next_isle()
	var order: Array = range(entries.size())
	order.erase(cur)
	order.append(cur)                     # 選到的最後畫，蓋在最上面
	for e in order:
		var w: Dictionary = worlds[e]
		var info := _tag_info(e)
		var on: bool = e == cur
		var kind := String(info.kind)
		var hubc: Vector3 = worlds[0].center
		var wc: Vector3 = w.center
		var below := kind != "hub" and wc.z > hubc.z + 8.0 and absf(wc.x - hubc.x) < 12.0
		var top: Vector3 = wc + (Vector3(float(w.rx) + 7.5, 0, 0) if below else Vector3(0, 5.0, -float(w.rz)))
		if _cam.is_position_behind(top):
			_tag_rects[e] = Rect2()
			continue
		var anchor := _cam.unproject_position(top)
		var s := u * (1.0 if on else 0.82)
		var title := String(info.title)
		var ts := 28.0 * s
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts)).x
		var stat := String(info.stat)
		var ss := 22.0 * s
		var sw := (f.get_string_size(stat, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ss)).x + 34.0 * s) if stat != "" else 0.0
		var bw := 66.0 * s + tw + (sw + 16.0 * s if stat != "" else 0.0) + 22.0 * s
		var can_go := on and kind != "locked" and _jump.is_empty()
		var label := "進農莊" if kind == "hub" else "登島"
		var go_w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s)).x + UIStyle.keycap_size("Enter", 14 * s).x + 58 * s
		if can_go:
			bw = maxf(bw, go_w + 24 * s)
		var bh := 60.0 * s + (52.0 * s if can_go else 0.0)
		var tail := 16.0 * s
		var bob := sin(_t * 2.2 + e) * 2.5 * u if on else 0.0
		if not below and absf(wc.x - hubc.x) > 20.0:
			anchor.x += signf(wc.x - hubc.x) * 46.0 * u      # 東西兩邊的島：島牌往外挪一點，讓出中間給主島的島牌
		var ax := anchor.x
		if kind == "hub":
			anchor.x -= bw * 0.5 + 16.0 * s          # 整張往左挪，尖角在右下角
		var r := Rect2(Vector2(anchor.x - bw * 0.5, anchor.y - bh - tail + bob), Vector2(bw, bh))
		if below:
			r.position = Vector2(anchor.x + tail, anchor.y - bh * 0.5 + bob)
		r.position.x = clampf(r.position.x, 14.0 * u, vs.x - bw - 14.0 * u)
		r.position.y = clampf(r.position.y, 14.0 * u, vs.y - bh - 14.0 * u)
		var hover := r.has_point(mouse)
		var col: Color = info.col
		var edge := col.darkened(0.25) if on or hover else PAPER_EDGE
		c.draw_style_box(_box(PAPER if kind != "locked" else Color("efece4"), edge, 22 * s, 4.0 if on else 3.0), r)
		# 尖角
		var fill := PAPER if kind != "locked" else Color("efece4")
		var lw2 := 4.0 if on else 3.0
		if below:
			# 尖角在左邊、朝左
			var cy2 := clampf(anchor.y, r.position.y + 22 * s, r.end.y - 22 * s)
			var lx := r.position.x
			c.draw_colored_polygon(PackedVector2Array([Vector2(lx + 4.0, cy2 - 12 * s), Vector2(lx + 4.0, cy2 + 12 * s), Vector2(lx - tail, cy2)]), fill)
			c.draw_polyline(PackedVector2Array([Vector2(lx + 1.0, cy2 - 12 * s), Vector2(lx - tail, cy2), Vector2(lx + 1.0, cy2 + 12 * s)]), edge, lw2, true)
		else:
			var tx := clampf(ax - (26.0 * s if kind == "hub" else 0.0), r.position.x + 30 * s, r.end.x - 30 * s)
			var ty := r.end.y
			c.draw_colored_polygon(PackedVector2Array([Vector2(tx - 12 * s, ty - 4.0), Vector2(tx + 12 * s, ty - 4.0), Vector2(tx, ty + tail)]), fill)
			c.draw_polyline(PackedVector2Array([Vector2(tx - 12 * s, ty - 1.0), Vector2(tx, ty + tail), Vector2(tx + 12 * s, ty - 1.0)]), edge, lw2, true)
		# 圓徽章
		var bc := r.position + Vector2(34 * s, 30 * s)
		var br := 22.0 * s
		if kind == "hub":
			c.draw_circle(bc + Vector2(0, br * 0.08), br, col.darkened(0.35))
			c.draw_circle(bc, br, col.darkened(0.12))
			c.draw_circle(bc, br * 0.86, col.lightened(0.25))
			_house(c, bc + Vector2(0, br * 0.08), br / 36.0, col.darkened(0.55), col.lightened(0.25))
		elif kind == "locked":
			var rot := sin(_shake_t * 42.0) * 0.28 * (_shake_t / SHAKE_TIME) if _shake_t > 0.0 and on else 0.0
			_lock_icon(c, bc + Vector2(0, 2 * s), 17 * s, Color("8a857a"), rot)
		else:
			_island_badge(c, entries[e].ch, bc, br, col)
			if bool(info.done):
				_crown(c, bc + Vector2(0, -br - 5.0 * s), s * 0.85)
			elif Progress.chapter_cleared(entries[e].ch):
				# 每一關都過了、星星還沒拿滿：徽章右下角一顆小綠勾（拿滿才戴皇冠）
				var cp := bc + Vector2(br * 0.72, br * 0.72)
				c.draw_circle(cp, 9.5 * s, Color(1, 1, 1))
				c.draw_circle(cp, 7.8 * s, GREEN)
				_check_icon(c, cp, 8.0 * s, Color(1, 1, 1))
		var tcol := INK if kind != "locked" else Color("7d776c")
		_text(c, Vector2(r.position.x + 66 * s, r.position.y + 30 * s + ts * 0.36), title, ts, tcol)
		if e == hint:
			_next_mark(c, Vector2(r.end.x - 4.0 * s, r.position.y + 2.0 * s), maxf(s, 0.9 * u) * 0.92)
		if stat != "":
			var sx := r.position.x + 66 * s + tw + 16 * s
			var chip := Rect2(Vector2(sx, r.position.y + 14 * s), Vector2(sw, 32 * s))
			var flagged := not bool(info.starred) and not bool(info.done)
			c.draw_style_box(_box(Color("ffe2d2") if flagged else Color("fff1bf"), Color("e0a07c") if flagged else Color("d9b84a"), 16 * s, 2.0, false), chip)
			if bool(info.starred):
				_star(c, chip.position + Vector2(15, 16) * s, 9 * s, GOLD, Color("8a6410"))
			elif bool(info.done):
				c.draw_circle(chip.position + Vector2(15, 16) * s, 8.5 * s, GREEN)
				_check_icon(c, chip.position + Vector2(15, 16) * s, 9 * s, Color(1, 1, 1))
			else:
				_pennant(c, chip.position + Vector2(16, 16) * s, 9.5 * s)
			_text(c, chip.position + Vector2(28 * s, 23.5 * s), stat, ss, INK)
		if can_go:
			var ks := UIStyle.keycap_size("Enter", 14 * s)
			var pulse := 1.0 + sin(_t * 4.0) * 0.025
			var gr := Rect2(Vector2(r.position.x + 12 * s, r.position.y + 57 * s), Vector2(bw - 24 * s, 43 * s))
			gr = Rect2(gr.get_center() - gr.size * 0.5 * pulse, gr.size * pulse)
			c.draw_style_box(_box(GREEN, Color("2f7a2f"), 20 * s, 3.0, false), gr)
			var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s)).x
			var x0 := gr.get_center().x - (lw + 10 * s + ks.x) * 0.5
			_text(c, Vector2(x0, gr.get_center().y + 8.5 * s), label, 24 * s, Color(1, 1, 1))
			UIStyle.draw_keycap(c, Vector2(x0 + lw + 10 * s, gr.get_center().y - ks.y * 0.5), "Enter", 14 * s)
			_go_rect = gr
		_tag_rects[e] = r

## 世界地圖的底：淡淡的經緯虛線＋四周壓暗（像一張攤開的航海圖），畫在島牌下面
func _paint_chart(c: Control, u: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var line := Color(1, 1, 1, 0.11)
	var step := 190.0 * u
	var x := fmod(vs.x * 0.5, step)
	while x < vs.x:
		c.draw_dashed_line(Vector2(x, 0), Vector2(x, vs.y), line, 2.0 * u, 14.0 * u)
		x += step
	var y := fmod(vs.y * 0.5, step)
	while y < vs.y:
		c.draw_dashed_line(Vector2(0, y), Vector2(vs.x, y), line, 2.0 * u, 14.0 * u)
		y += step
	var dark := Color(0.02, 0.10, 0.24, 0.34)
	var clear := Color(0.02, 0.10, 0.24, 0.0)
	var m := 230.0 * u
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, m), Vector2(0, m)]), PackedColorArray([dark, dark, clear, clear]))
	c.draw_polygon(PackedVector2Array([Vector2(0, vs.y - m), Vector2(vs.x, vs.y - m), Vector2(vs.x, vs.y), Vector2(0, vs.y)]), PackedColorArray([clear, clear, dark, dark]))
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(m, 0), Vector2(m, vs.y), Vector2(0, vs.y)]), PackedColorArray([dark, clear, clear, dark]))
	c.draw_polygon(PackedVector2Array([Vector2(vs.x - m, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - m, vs.y)]), PackedColorArray([clear, dark, dark, clear]))

## 世界地圖左下角的羅盤（裝飾）：像印在地圖上的白色線條，沒有底、沒有陰影，才不會被當成按鈕
func _paint_compass(c: Control, u: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var o := Vector2(92 * u, vs.y - 100 * u)
	var r := 46.0 * u
	var ink := Color(1, 1, 1, 0.62)
	c.draw_arc(o, r, 0, TAU, 64, ink, 2.4 * u, true)
	c.draw_arc(o, r * 0.80, 0, TAU, 48, Color(1, 1, 1, 0.3), 1.6 * u, true)
	for i in 16:
		var a := i * TAU / 16.0
		var d := Vector2(cos(a), sin(a))
		c.draw_line(o + d * r * (0.86 if i % 4 != 0 else 0.80), o + d * r, ink, 2.0 * u, true)
	for i in 4:
		var a := -PI * 0.5 + i * PI * 0.5
		var tip := o + Vector2(cos(a), sin(a)) * r * 0.72
		var l := o + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * r * 0.14
		var rt := o + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * r * 0.14
		c.draw_colored_polygon(PackedVector2Array([tip, l, o]), Color(1, 1, 1, 0.85))
		c.draw_colored_polygon(PackedVector2Array([tip, o, rt]), Color(1, 1, 1, 0.45))
	_text(c, o + Vector2(-r, -r - 8 * u), "N", 20 * u, Color(1, 1, 1, 0.85), r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

## 左上角的大標題（白邊紅字，稍微歪一點）
func _headline(c: Control, u: float, head: String, size: float) -> void:
	var f := _font()
	var fs := int(size * u)
	c.draw_set_transform(Vector2(40 * u, 92 * u), -0.035, Vector2.ONE)
	c.draw_string_outline(f, Vector2(0, 6 * u), head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(20 * u), Color(0.20, 0.10, 0.06, 0.35))
	c.draw_string_outline(f, Vector2.ZERO, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(18 * u), Color(1, 1, 1))
	c.draw_string(f, Vector2.ZERO, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("e8483a"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 標題下面的一張小紙片：前面一個圖示（"star"／"check"／""），後面一行字。回傳它的框
func _chip(c: Control, u: float, pos: Vector2, icon: String, label: String, size: float, bar := Color(0, 0, 0, 0)) -> Rect2:
	var f := _font()
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * u)).x
	var lead := 48.0 * u if icon != "" else (26.0 * u if bar.a > 0.0 else 18.0 * u)
	var r := Rect2(pos, Vector2(lead + lw + 16 * u, 50 * u))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 14 * u, 3.0), r)
	if bar.a > 0.0:
		c.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(10 * u, r.size.y - 12)), bar)
	var ic := r.position + Vector2(26 * u, 24 * u)
	if icon == "star":
		_star(c, ic, 14 * u, GOLD, Color("8a6410"))
	elif icon == "check":
		c.draw_circle(ic, 13 * u, GREEN)
		_check_icon(c, ic, 14 * u, Color(1, 1, 1))
	elif icon == "flag":
		_pennant(c, ic + Vector2(2 * u, 0), 13 * u)
	_text(c, r.position + Vector2(lead, 25 * u + size * u * 0.36), label, size * u, INK)
	return r

## 左上角：島上是島名（大標題）＋這座島的進度；世界地圖是「世界地圖」＋全部的進度（星星和過關數分開算）
func _paint_hud(c: Control, u: float) -> void:
	var ent: Dictionary = entries[selected]
	var ch: Dictionary = ent.ch
	var at := Vector2(44 * u, 116 * u)
	if _zoom > 0.5:
		_headline(c, u, "世界地圖", 62.0)
		var all := _star_all()
		var x := at.x
		if int(all[1]) > 0:
			x = _chip(c, u, at, "star", "%d/%d" % [all[0], all[1]], 24.0).end.x + 12 * u
		if int(all[3]) > 0:
			_chip(c, u, Vector2(x, at.y), "check" if int(all[2]) >= int(all[3]) else "flag", "%d/%d" % [all[2], all[3]], 24.0)
		return
	if _is_hub(selected):
		_headline(c, u, HUB_TITLE, 62.0)
		var ht := _hub_total()
		if int(ht[1]) > 0:
			_chip(c, u, at, "check" if int(ht[0]) >= int(ht[1]) else "flag", "%d/%d" % [ht[0], ht[1]], 24.0)
		return
	var playable := _playable(ch)
	_headline(c, u, String(ch.title) if playable else "？？？", 62.0)
	if not playable:
		return
	# 「★ 7/18」；沒有三星制度的大關顯示過了幾關
	var tot := _star_total(ch)
	_chip(c, u, at, "star" if tot[2] else ("check" if int(tot[0]) >= int(tot[1]) else "flag"), "%d/%d" % [tot[0], tot[1]], 24.0)

## 右上角的圓按鈕底：米色紙片＋陰影；下面掛一顆鍵帽。回傳半徑
func _round_button(c: Control, u: float, ctr: Vector2, key: String, label: String, bg := PAPER, edge := PAPER_EDGE, pop := 0.0) -> float:
	var r := 34.0 * u * (1.0 + 0.18 * sin(pop / 0.25 * PI))
	c.draw_circle(ctr + Vector2(2, 5) * u, r + 3.0 * u, Color(0, 0, 0, 0.25))
	c.draw_circle(ctr, r + 3.0 * u, edge)
	c.draw_circle(ctr, r, bg)
	var f := _font()
	var ks := UIStyle.keycap_size(key, 14 * u)
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u)).x
	var x := ctr.x - (ks.x + 5 * u + lw) * 0.5
	var y := ctr.y + 34.0 * u + 5.0 * u
	UIStyle.draw_keycap(c, Vector2(x, y), key, 14 * u)
	c.draw_string_outline(f, Vector2(x + ks.x + 5 * u, y + ks.y * 0.5 + 6 * u), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), int(6 * u), Color(1, 1, 1, 0.9))
	c.draw_string(f, Vector2(x + ks.x + 5 * u, y + ks.y * 0.5 + 6 * u), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u), INK)
	return r

## 右上角三顆圓按鈕（由右到左）：聲音 V、商店 B、世界地圖 M
func _paint_buttons(c: Control, u: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	# ---- 聲音：喇叭有聲波＝開、打叉＝關
	var muted := sound_muted()
	var ctr := Vector2(vs.x - 62.0 * u, 62.0 * u)
	_snd_rect = Rect2(ctr - Vector2(44, 44) * u, Vector2(88, 88) * u)
	var r := _round_button(c, u, ctr, "V", "聲音", LOCKED if muted else PAPER, LOCKED_EDGE if muted else PAPER_EDGE, _snd_pop)
	var ink := Color("8a857a") if muted else INK
	var k := r / 34.0
	var o := ctr + Vector2(-7, 0) * k
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(-11, -6) * k, o + Vector2(-3, -6) * k, o + Vector2(7, -15) * k,
		o + Vector2(7, 15) * k, o + Vector2(-3, 6) * k, o + Vector2(-11, 6) * k]), ink)
	if muted:
		var x := ctr + Vector2(13, 0) * k
		c.draw_line(x + Vector2(-6, -6) * k, x + Vector2(6, 6) * k, Color("d9534f"), 4.0 * k, true)
		c.draw_line(x + Vector2(-6, 6) * k, x + Vector2(6, -6) * k, Color("d9534f"), 4.0 * k, true)
	else:
		c.draw_arc(o + Vector2(7, 0) * k, 8.0 * k, -0.9, 0.9, 12, ink, 3.2 * k, true)
		c.draw_arc(o + Vector2(7, 0) * k, 15.0 * k, -0.9, 0.9, 16, ink, 3.2 * k, true)
	# ---- 商店：衣架；右下角掛著還能花的星星
	ctr += Vector2(-118.0 * u, 0)
	_shop_rect = Rect2(ctr - Vector2(48, 44) * u, Vector2(96, 88) * u)
	_round_button(c, u, ctr, "B", "商店")
	_hanger(c, ctr + Vector2(0, -2) * u, u, INK)
	var label := str(_wallet)
	var f := _font()
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u)).x
	var chip := Rect2(ctr + Vector2(4, 12) * u, Vector2(lw + 32 * u, 26 * u))
	c.draw_style_box(_box(Color("fff1bf"), Color("d9b84a"), 13 * u, 2.0, false), chip)
	_star(c, chip.position + Vector2(13, 13) * u, 8 * u, GOLD, Color("8a6410"))
	_text(c, chip.position + Vector2(24 * u, 19 * u), label, 17 * u, INK)
	# ---- 世界地圖：一張摺起來的地圖；正在看地圖時按鈕是亮的
	ctr += Vector2(-118.0 * u, 0)
	_map_rect = Rect2(ctr - Vector2(48, 44) * u, Vector2(96, 88) * u)
	_round_button(c, u, ctr, "M", "世界地圖", Color("ffe98a") if _map else PAPER, Color("d9b84a") if _map else PAPER_EDGE)
	var m := PackedVector2Array([Vector2(-18, -10), Vector2(-6, -14), Vector2(6, -9), Vector2(18, -13),
		Vector2(18, 10), Vector2(6, 14), Vector2(-6, 9), Vector2(-18, 13), Vector2(-18, -10)])
	for i in m.size():
		m[i] = ctr + m[i] * u
	c.draw_polyline(m, INK, 3.2 * u, true)
	c.draw_line(ctr + Vector2(-6, -14) * u, ctr + Vector2(-6, 9) * u, INK, 2.6 * u, true)
	c.draw_line(ctr + Vector2(6, -9) * u, ctr + Vector2(6, 14) * u, INK, 2.6 * u, true)
	c.draw_circle(ctr + Vector2(0.5, 1.0) * u, 3.4 * u, SHOP_RED)

## 右下角的按鍵提示（一條橫的小紙片，「鍵帽＋做什麼」一組一組排）：
##   島上：← → 走路／（站點多的島）1~6 直達／M 世界地圖；世界地圖：↑ ← ↓ → 選島／Esc 返回標題。
##   Enter 寫在泡泡和島牌的按鈕上，這裡不重複。只有一列高，才不會蓋到往右下延伸的路和下一站
func _paint_keys(c: Control, u: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var f := _font()
	var items: Array = []
	if _zoom > 0.5:
		items = [[["↑", "←", "↓", "→"], "選島"], [["Esc"], "返回標題"]]
	else:
		var n := int(worlds[selected].n)
		items = [[["←", "→"], "走路" if n > 1 else "離島"]]
		if n >= 4:
			items.append([["1~%d" % n], "直達"])
		items.append([["M"], "世界地圖"])
	var ks := 16.0 * u
	var ts := 20.0 * u
	var gap := 4.0 * u
	var cap_h := UIStyle.keycap_size("M", ks).y
	var w := 0.0
	for it in items:
		for key in it[0]:
			w += UIStyle.keycap_size(String(key), ks).x + gap
		w += 5.0 * u + f.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts)).x
	w += 26.0 * u * (items.size() - 1)
	var r := Rect2(Vector2(vs.x - w - 58.0 * u, vs.y - 68.0 * u), Vector2(w + 36.0 * u, 48.0 * u))
	c.draw_style_box(_box(Color(PAPER, 0.94), PAPER_EDGE, 24 * u, 3.0), r)
	var x := r.position.x + 18.0 * u
	var cy := r.get_center().y - 1.0 * u
	for it in items:
		for key in it[0]:
			x += UIStyle.draw_keycap(c, Vector2(x, cy - cap_h * 0.5), String(key), ks).x + gap
		x += 5.0 * u
		var label := String(it[1])
		_text(c, Vector2(x, cy + ts * 0.36), label, ts, INK)
		x += f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts)).x + 26.0 * u

# ================================================================== 選取、移動、開始

## 第 i 個大關（LEVELS 的索引）的第 n 小關（從 1 開始）照規則解鎖了沒
func unlocked(i: int, n := 1) -> bool:
	return _unlocked_ch(LEVELS[i], n)

func _unlocked_ch(ch: Dictionary, n: int) -> bool:
	if ch.is_empty() or n < 1 or n > ch.stages.size() or String(ch.stages[n - 1].scene) == "":
		return false
	return Progress.unlocked(ch.id, n)

func _busy() -> bool:
	return not _walk.is_empty() or not _jump.is_empty()

## 一登島先站在哪一格：主島是家；主題島是「第一個還沒過、可以玩的小關」
func _first_open_stage_of(e: int) -> int:
	if _is_hub(e):
		for k in (_stations[e] as Array).size():
			if String(_st(e, k).kind) == "home":
				return k
		return 0
	for k in (_stations[e] as Array).size():
		if _st_open(e, k) and not _st_cleared(e, k):
			return k
	return 0

func _first_open_stage() -> int:
	return _first_open_stage_of(selected)

## 直接站到第 i 座島（不飛；一進畫面、自動驗收時用）
func select(i: int) -> void:
	if entries.is_empty():
		return
	var was := selected
	selected = clampi(i, 0, entries.size() - 1)
	if selected != was or stage_sel >= int(worlds[selected].n):
		stage_sel = _first_open_stage()
	if String(_st_now().kind) == "locked":
		_shake_t = SHAKE_TIME            # 還沒做好的島：鎖頭抖一下
	_place_hero()

## 直接站到目前這座島的第 n 個站點（0 開始；不走路）
func select_stage(n: int) -> void:
	if entries.is_empty():
		return
	stage_sel = clampi(n, 0, int(worlds[selected].n) - 1)
	_place_hero()

## 把家豪直接放到現在該站的位置。snap：鏡頭和泡泡也直接到位（不慢慢跟）
func _place_hero(snap := false) -> void:
	_walk = {}
	_jump = {}
	_queued = 0
	_hero.position = _stand_now()
	_hero.rotation.y = 0.0
	_hero_body.position = Vector3.ZERO
	_hero_body.rotation = Vector3.ZERO
	_hero_body.scale = Vector3.ONE
	var first := _t <= 0.0 or snap
	if first:
		_focus = Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z)
		_bubble_a = 1.0
	_set_mood(selected, stage_sel, first)

## 沿著路走到目前這座島的第 k 個站點（0 開始）。中間有還沒解鎖的站點就停在它前面。
func walk_to(k: int) -> void:
	if _busy() or _starting or _map:
		return
	var w: Dictionary = worlds[selected]
	var d := signi(k - stage_sel)
	if d == 0:
		return
	if k == -1 or k == int(w.n):
		set_map(true)                    # 走到路的盡頭再往外：出海，看世界地圖
		return
	if k < 0 or k > int(w.n):
		_bump(Vector3(d, 0, 0))
		return
	var to := stage_sel
	while to != k:
		if d > 0 and not _dev() and not _st_open(selected, to + d):
			break
		to += d
	if to == stage_sel:
		_bump(Vector3(d, 0, 0))
		_show_toast("先過這一關")
		return
	var pts := PackedVector3Array()
	var j := stage_sel
	while j != to:
		var seg: PackedVector3Array = w.segs[j if d > 0 else j - 1]
		for i in seg.size():
			var p := seg[i if d > 0 else seg.size() - 1 - i]
			if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.001:
				pts.append(p)
		j += d
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	_walk = {"pts": pts, "d": 0.0, "len": total, "to": to}
	_hop_i = 0
	_bubble_a = 0.0
	_set_mood(selected, to)

## 拉遠看世界地圖／拉近回島上
func set_map(on: bool) -> void:
	if _starting or _busy() or _map == on:
		return
	if not on and String(_st_now().kind) == "locked":
		_shake_t = SHAKE_TIME            # 還沒做好的島：上不去，鎖頭抖一下
		_play("bump")
		return
	_map = on
	_play("fly", 0.8 if on else 1.15)
	_bubble_a = 0.0
	_set_mood(selected, stage_sel)

## 世界地圖上按方向鍵：飛到那個方向最近的島（dir 是畫面上的方向：x 往右、y 往下）
func _move_dir(dir: Vector2) -> void:
	if _busy() or _starting:
		return
	var here: Vector3 = worlds[selected].center
	var best := -1
	var best_s := INF
	for e in entries.size():
		if e == selected:
			continue
		var c: Vector3 = worlds[e].center
		var d := Vector2(c.x - here.x, c.z - here.z)
		var along := d.normalized().dot(dir)
		if along < 0.38:
			continue
		var s := d.length() / (along * along)
		if s < best_s:
			best_s = s
			best = e
	if best < 0:
		_bump(Vector3(dir.x, 0, dir.y))
		return
	_jump_to(best, _first_open_stage_of(best))

## 飛到第 e 座島的第 k 個站點
func _jump_to(e: int, k: int) -> void:
	if _busy() or _starting:
		return
	var to := _stand(e, k).lerp(_token(e), _z())
	var h := 3.4 if e == selected else clampf(_hero.position.distance_to(to) * 0.24, 7.0, 22.0)
	_jump = {"from": _hero.position, "to": to, "t": 0.0, "e": e, "k": k, "h": h}
	_play("fly")
	_bubble_a = 0.0
	_set_mood(e, k)

## 被擋住：往那個方向頂一下再彈回來
func _bump(dir: Vector3) -> void:
	_bump_dir = dir
	_bump_t = 0.25
	_play("bump")

## Enter：世界地圖上是登島；島上是開始這一關（商店：進去；家：重看開場）
func start_selected() -> bool:
	if _starting or entries.is_empty() or _busy():
		return false
	if _map:
		set_map(false)
		return false
	var s := _st_now()
	match String(s.kind):
		"shop":
			open_shop()
			return _starting
		"home":
			if not ResourceLoader.exists(INTRO_SCENE):
				return false
			_starting = true
			_play_detached("start")
			_remember()
			get_tree().change_scene_to_file(INTRO_SCENE)
			return true
		"locked":
			_shake_t = SHAKE_TIME           # 還沒做好的島：不跳字，鎖頭抖一下就好
			_play("bump")
			return false
		"board":
			return false                    # 冒險紀錄只是看的
		"dock":
			set_map(true)                   # 出航：拉遠看世界地圖
			return false
		"guide":
			_open_guide()
			return false
	var stage := _st_stage(s)
	if String(stage.scene) == "":
		_play("bump")
		return false
	if not _st_open(selected, stage_sel):
		if _dev():
			_show_toast("（開發模式：還沒解鎖也讓你進去）")
		else:
			_show_toast("先過第 %d 關" % int(s.k))
			_play("bump")
			return false
	_starting = true
	_play_detached("start")
	_remember()
	Engine.set_meta("next_scene", stage.scene)
	Engine.set_meta("stage_id", stage.id)
	get_tree().change_scene_to_file("res://scenes/loading.tscn")   # 先進載入畫面
	return true

## 告示牌：用全遊戲共用的教學彈窗顯示選關畫面的操作說明（兩頁：島上、世界地圖）
func _open_guide() -> void:
	if _guide == null:
		_guide = Tutorial.new()
		_guide.kicker_text = "操作說明"
		add_child(_guide)
		_guide.set_pages([
			{"title": "在島上", "body": "家豪沿著路一格一格走。走到地標前面，按 Enter 開始那一關。",
				"controls": [["←／→", "走到隔壁一格"], ["Enter", "開始／進去"], ["1～9", "直接走到那一格"], ["M", "世界地圖"]]},
			{"title": "世界地圖", "body": "每座島的第一關一開始就能玩，想先去哪座島都可以。星星拿去商店換衣服。",
				"controls": [["↑／←／↓／→", "飛到那個方向的島"], ["Enter", "登島"], ["B", "商店"], ["V", "聲音開關"]]},
		])
	_play("click")
	_guide.open()

func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 2.0

## 島上：滑鼠點在目前這座島的哪個站點上（找不到回傳 -1）
func _node_at(pos: Vector2) -> int:
	var best := -1
	var best_d := 80.0 * _u()
	var w: Dictionary = worlds[selected]
	for k in int(w.n):
		for h in [0.3, 1.5]:
			var wp: Vector3 = (w.pads[k] as Vector3) + Vector3(0, h, 0)
			if _cam.is_position_behind(wp):
				continue
			var d := _cam.unproject_position(wp).distance_to(pos)
			if d < best_d:
				best_d = d
				best = k
	return best

## 世界地圖：滑鼠點在哪座島上（島牌或島本身；找不到回傳 -1）
func _isle_at(pos: Vector2) -> int:
	for e in mini(_tag_rects.size(), entries.size()):
		if (_tag_rects[e] as Rect2).has_point(pos):
			return e
	var best := -1
	var best_d := 130.0 * _u()
	for e in entries.size():
		var c: Vector3 = worlds[e].center
		if _cam.is_position_behind(c):
			continue
		var d := _cam.unproject_position(c).distance_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _snd_rect.has_point(ev.position):
			_toggle_sound()
		elif _shop_rect.has_point(ev.position):
			open_shop()
		elif _map_rect.has_point(ev.position):
			set_map(not _map)
		elif _map and _go_rect.has_point(ev.position):
			start_selected()
		elif _map:
			var e := _isle_at(ev.position)
			if e == selected:
				start_selected()             # 再點一次所在的島：登島
			elif e >= 0:
				_jump_to(e, _first_open_stage_of(e))
		elif _start_rect.has_point(ev.position):
			start_selected()
		else:
			var k := _node_at(ev.position)
			if k == stage_sel:
				start_selected()
			elif k >= 0:
				walk_to(k)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_LEFT, KEY_A:
				_arrow(Vector2(-1, 0))
			KEY_RIGHT, KEY_D:
				_arrow(Vector2(1, 0))
			KEY_UP, KEY_W:
				_arrow(Vector2(0, -1))
			KEY_DOWN, KEY_S:
				_arrow(Vector2(0, 1))
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if not _map:
					walk_to(ev.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_selected()
			KEY_M, KEY_TAB:
				set_map(not _map)
			KEY_V:
				_toggle_sound()
			KEY_B:
				open_shop()
			KEY_ESCAPE:
				if not _map:
					set_map(true)                # 島上按 Esc：先退到世界地圖
				elif not _starting and not _busy() and ResourceLoader.exists(INTRO_SCENE):
					if _esc_t > 0.0:
						get_tree().change_scene_to_file(INTRO_SCENE)
					else:
						_esc_t = 2.0
						_show_toast("再按一次 Esc 返回標題")

## 方向鍵：世界地圖上是換島；島上 ← → 是沿著路走，↑ ↓ 沒有路（頂一下）
func _arrow(d: Vector2) -> void:
	if _map:
		_move_dir(d)
	elif d.x != 0.0:
		_step(int(d.x))
	elif not _busy():
		_bump(Vector3(0, 0, d.y))
		_show_toast("按 M 看世界地圖")

## ← →：走到前一格／下一格（走路中再按一次：走到之後接著走）
func _step(d: int) -> void:
	if not _walk.is_empty():
		_queued = d
	else:
		walk_to(stage_sel + d)

func _process(dt: float) -> void:
	_t += dt
	_tick_hero(dt)
	_zoom = move_toward(_zoom, 1.0 if _map else 0.0, dt / ZOOM_TIME)
	var z := _z()
	# 島上的鏡頭慢慢跟上家豪；世界地圖的鏡頭固定在所有島的正上方（稍微偏向家豪所在的島）。兩個之間照 z 混合
	var target := Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z)
	_focus = _focus.lerp(target, 1.0 - exp(-dt * 5.5))
	var sway := Vector3(sin(_t * 0.25) * 0.5, 0, 0)
	var lean := (Vector3(_focus.x, 0, _focus.z) - _map_center) * 0.06
	var pos := (_focus + CAM_OFFSET + sway).lerp(_map_center + _map_cam + lean + sway * 2.0, z)
	var look := (_focus + CAM_LOOK).lerp(_map_center + lean, z)
	_cam.position = pos
	_cam.look_at(look)
	# 海跟著鏡頭走（花紋用世界座標，不會跟著滑）；拉遠時霧變淡、影子畫遠一點、海面晚一點才融進地平線
	var sea := Vector3(_focus.x, 0, _focus.z).lerp(_map_center, z)
	_sea.position = Vector3(sea.x, 0, sea.z)
	_env.fog_density = lerpf(0.003, 0.0003, smoothstep(0.0, 0.45, z))    # 霧先散掉：拉到一半畫面才不會白白的
	_sun.directional_shadow_max_distance = lerpf(90.0, _map_cam.length() * 1.5, z)
	_sea_mat.set_shader_parameter("fade_near", lerpf(60.0, 700.0, z))
	_sea_mat.set_shader_parameter("fade_far", lerpf(260.0, 1400.0, z))
	_sea_mat.set_shader_parameter("zoom", z)
	_hero.scale = Vector3.ONE * lerpf(1.0, HERO_BIG, z)
	_hero_tilt.rotation.x = -0.62 * z                    # 世界地圖是從上面看：往後仰，才看得到臉
	_hero_base.visible = z > 0.3 and _jump.is_empty()        # 飛的時候底座不跟著飛
	_hero_base.scale = Vector3.ONE * smoothstep(0.3, 0.9, z)
	_shadow.visible = z > 0.3 and not _jump.is_empty()
	if _shadow.visible:
		var lift := sin(float(_jump.t) * PI)
		_shadow.position = Vector3(_hero.position.x, 0.3, _hero.position.z)
		_shadow.scale = Vector3(5.6 - 1.8 * lift, 1.0, 3.8 - 1.2 * lift)
		_shadow_mat.albedo_color = Color(0.02, 0.10, 0.22, 0.42 - 0.14 * lift)
	# 光圈：只有世界地圖上看得到
	_ring.visible = z > 0.02
	if _ring.visible:
		var w: Dictionary = worlds[int(_jump.e) if not _jump.is_empty() else selected]
		var c: Vector3 = w.center
		var grow := 1.0 + 0.035 * sin(_t * 3.0)
		_ring.position = Vector3(c.x, 0.22, c.z)
		_ring.scale = Vector3((float(w.rx) + 6.5) * grow, 1.0, (float(w.rz) + 6.5) * grow)
		_ring_mat.albedo_color = Color(Color("ffd033"), z)
		_ring_edge.albedo_color = Color(PATH_EDGE, z * 0.85)
	for sm in _small:
		(sm as Node3D).visible = z < 0.5
	for h in _hens:
		var hop := maxf(sin(_t * 2.6 + float(h.phase)), 0.0)
		(h.node as Node3D).position = (h.base as Vector3) + Vector3(0, hop * hop * 0.22, 0)
		(h.node as Node3D).rotation.y = float(h.phase) * 1.7 + sin(_t * 0.6 + float(h.phase)) * 0.5
	# 世界地圖上地標放大（玩具地圖的感覺）、飽和度收一點（海才不會搶島的顏色）
	var big := Vector3.ONE * lerpf(1.0, SPOT_BIG, z)
	for w2 in worlds:
		for ir in w2.isle_roots:
			(ir as Node3D).scale = big
	_env.adjustment_saturation = lerpf(1.35, 1.2, z)
	_shallow_mat.albedo_color = Color(_shallow_tint, lerpf(0.5, 1.0, z))
	if absf(z - _route_z) > 0.004:
		_size_routes(z)
	_ov_isle.modulate.a = 1.0 - smoothstep(0.0, 0.45, z)
	_ov_isle.visible = _ov_isle.modulate.a > 0.01
	_ov_map.modulate.a = smoothstep(0.55, 1.0, z)
	_ov_map.visible = _ov_map.modulate.a > 0.01
	if not _ov_isle.visible:
		_start_rect = Rect2()
	if _mood_k < 1.0:
		_mood_k = minf(_mood_k + dt / MOOD_TIME, 1.0)
		_apply_mood(_blend_mood(_mood_k))
	if not _busy():
		_bubble_a = minf(_bubble_a + dt * 4.0, 1.0)
	for fl in _flags:
		(fl.node as Node3D).rotation.y = sin(_t * 2.4 + float(fl.phase)) * 0.35
	for cl in _clouds:
		(cl.node as Node3D).position = (cl.base as Vector3) + Vector3(sin(_t * 0.5 + float(cl.phase)) * 0.25, sin(_t * 0.8 + float(cl.phase)) * 0.15, 0)
	# 家豪站的那個站點輕輕縮放
	var cur_e := int(_jump.e) if not _jump.is_empty() else selected
	for e in worlds.size():
		var pn: Array = worlds[e].pad_nodes
		var show := e == selected or e == cur_e or z > 0.12
		for k in pn.size():
			var on := e == selected and k == stage_sel and not _busy() and not _map
			(pn[k] as Node3D).scale = Vector3.ONE * ((1.06 + sin(_t * 4.0) * 0.04) if on else 1.0)
			(pn[k] as Node3D).visible = show
		for mk in worlds[e].marks:
			(mk as Node3D).visible = show
	if _shake_t > 0.0:
		_shake_t = maxf(_shake_t - dt, 0.0)
	_snd_pop = maxf(_snd_pop - dt, 0.0)
	_esc_t = maxf(_esc_t - dt, 0.0)
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast.text = ""
			_toast.visible = false
	var mp := get_viewport().get_mouse_position()
	var hot := _snd_rect.has_point(mp) or _shop_rect.has_point(mp) or _map_rect.has_point(mp)
	if not hot and _map:
		hot = _isle_at(mp) >= 0
	elif not hot:
		hot = _start_rect.has_point(mp) or _node_at(mp) >= 0
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hot else Input.CURSOR_ARROW)
	_overlay.queue_redraw()
	_ov_isle.queue_redraw()
	_ov_map.queue_redraw()

## 家豪的動作：走路（一跳一跳）、換島（飛過去）、原地待機
func _tick_hero(dt: float) -> void:
	if not _walk.is_empty():
		var pts: PackedVector3Array = _walk.pts
		_walk.d = minf(float(_walk.d) + WALK_SPEED * dt, float(_walk.len))
		var left: float = _walk.d
		var pos := pts[pts.size() - 1]
		var dir := Vector3.ZERO
		for i in pts.size() - 1:
			var seg := pts[i].distance_to(pts[i + 1])
			if left <= seg:
				pos = pts[i].lerp(pts[i + 1], left / maxf(seg, 0.0001))
				dir = pts[i + 1] - pts[i]
				break
			left -= seg
		_hero.position = pos + Vector3(0, 0.3, 0)
		if dir.length_squared() > 0.0001:
			_hero.rotation.y = lerp_angle(_hero.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-dt * 18.0))
		_hero_body.position.y = absf(sin(float(_walk.d) * PI / HOP_LEN)) * 0.7
		# 每落地一次響一聲（音高一高一低）
		var hops := int(float(_walk.d) / HOP_LEN)
		if hops != _hop_i:
			_hop_i = hops
			_play("hop", 1.0 + 0.12 * (hops % 2))
		if float(_walk.d) >= float(_walk.len):
			stage_sel = _walk.to
			_walk = {}
			_hero_body.position.y = 0.0
			_play("arrive")
			if _queued != 0:
				var q := _queued
				_queued = 0
				walk_to(stage_sel + q)
		return
	if not _jump.is_empty():
		_jump.t = minf(float(_jump.t) + dt / JUMP_TIME, 1.0)
		var k: float = _jump.t
		var e := k * k * (3.0 - 2.0 * k)
		var a: Vector3 = _jump.from
		var b: Vector3 = _jump.to
		_hero.position = a.lerp(b, e)
		_hero_body.position.y = sin(k * PI) * float(_jump.get("h", 7.0)) / maxf(_hero.scale.y, 1.0)
		var zz := _z()
		_hero_body.rotation.x = e * TAU * (1.0 if a.z >= b.z else -1.0) * (1.0 - zz)      # 島上：翻一個筋斗；世界地圖上不翻，臉一直朝鏡頭
		var stretch := sin(k * PI)
		_hero_body.scale = Vector3(1.0 - 0.10 * stretch, 1.0 + 0.16 * stretch, 1.0 - 0.10 * stretch)
		_hero.rotation.y = lerp_angle(_hero.rotation.y, atan2(b.x - a.x, b.z - a.z) * (1.0 - zz) + clampf((b.x - a.x) * 0.02, -0.5, 0.5) * zz, 1.0 - exp(-dt * 14.0))
		if k >= 1.0:
			selected = _jump.e
			stage_sel = _jump.k
			_jump = {}
			_hero_body.position.y = 0.0
			_hero_body.rotation = Vector3.ZERO
			_hero_body.scale = Vector3.ONE
			_play("land")
			if String(_st_now().kind) == "locked":
				_shake_t = SHAKE_TIME
		return
	# 待機：轉回來面對鏡頭、輕輕彈；被擋住時往那邊頂一下
	_hero.rotation.y = lerp_angle(_hero.rotation.y, 0.0, 1.0 - exp(-dt * 8.0))
	_hero_body.position.y = absf(sin(_t * 3.2)) * 0.08
	var base := _stand_now()
	if _bump_t > 0.0:
		_bump_t = maxf(_bump_t - dt, 0.0)
		base += _bump_dir * sin(_bump_t / 0.25 * PI) * 0.6 * _hero.scale.x
	_hero.position = base

# ================================================================== 開發用：世界地圖和每一格各截一張圖（--mapshots=資料夾）

func _snap_view() -> void:
	_focus = Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z)
	_zoom = 1.0 if _map else 0.0
	_set_mood(selected, stage_sel, true)
	_bubble_a = 1.0

func _shot(path: String) -> void:
	_snap_view()
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _mapshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# 順便檢查合成的音效：長度、最大音量（超過 1 會破音）
	for id in _snd:
		var w := (_snd[id] as AudioStreamPlayer).stream as AudioStreamWAV
		var peak := 0
		for i in range(0, w.data.size(), 2):
			peak = maxi(peak, absi(w.data.decode_s16(i)))
		print("SND %s %.2fs peak=%.2f" % [id, w.get_length(), peak / 30000.0])
	await get_tree().create_timer(0.8).timeout
	# 世界地圖：家豪輪流站在每座島上
	_map = true
	for e in entries.size():
		select(e)
		await _shot(dir.path_join("world_%d.png" % e))
	_map = false
	# 拉遠到一半、飛到別的島飛到一半各一張
	select(0)
	await _shot(dir.path_join("zoom_0.png"))
	set_map(true)
	await get_tree().create_timer(ZOOM_TIME * 0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("zoom_1_mid.png"))
	await get_tree().create_timer(ZOOM_TIME).timeout
	_move_dir(Vector2(1, 0))
	await get_tree().create_timer(JUMP_TIME * 0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("zoom_2_fly.png"))
	await get_tree().create_timer(JUMP_TIME).timeout
	_map = false
	for e in entries.size():
		select(e)
		for k in int(worlds[e].n):
			select_stage(k)
			await _shot(dir.path_join("map_w%d_s%d.png" % [e, k + 1]))
	get_tree().quit()

# ================================================================== 自動驗收（--autotest）

func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)

func _autotest() -> void:
	var lines: Array = []
	var fails := 0
	var out_dir := "user://autotest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--outdir="):
			out_dir = a.substr(9)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().create_timer(1.5).timeout
	# 農場範例是哪一座島（開發版才有）
	var farm := -1
	for e in entries.size():
		if String(entries[e].ch.get("id", "")) == "example_farm":
			farm = e
	var all_first := true
	for k in LEVELS.size():
		all_first = all_first and (LEVELS[k].stages.is_empty() or unlocked(k, 1))
	var on_map := 0
	for ent in entries:
		if not (ent.ch as Dictionary).is_empty():
			on_map += 1
	var hub_kinds: Array = (_stations[0] as Array).map(func(s): return String(s.kind))
	var real_isles := entries.filter(func(en): return not bool(en.get("hub", false)) and not ((en.ch as Dictionary).is_empty() == false and _is_example(en.ch))).size()
	var checks := [
		["選關畫面自動找到所有大關（%d 個）" % LEVELS.size(), on_map == LEVELS.size() and LEVELS.size() >= 1],
		["一進畫面家豪站在主島（農莊）的家", _is_hub(selected) and String(_st_now().kind) == "home"],
		["主島沒有關卡，只有功能點（商店、冒險紀錄、家、告示牌、碼頭）", hub_kinds == ["shop", "board", "home", "guide", "dock"]],
		["農場範例是開發版多出來的一座島", farm > 0],
		["每個大關的第 1 小關都可以玩", all_first],
		["主題島至少 %d 座（沒做好的上鎖）" % ISLAND_SLOTS, real_isles >= ISLAND_SLOTS],
	]
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00_level_select.png"))
	# 主島：從家往西走兩格到商店，再走回來
	walk_to(0)
	await get_tree().create_timer(2.5).timeout
	var at_shop := String(_st_now().kind) == "shop" and not _busy()
	_press(KEY_RIGHT)
	await get_tree().create_timer(1.5).timeout
	_press(KEY_RIGHT)
	await get_tree().create_timer(1.5).timeout
	checks.append(["主島：從家走到商店，按兩次 → 走回家", at_shop and String(_st_now().kind) == "home"])
	# 主島的碼頭：走到最東邊按 Enter 出航（拉遠到世界地圖），再按 Enter 回主島
	walk_to(int(worlds[0].n) - 1)
	await get_tree().create_timer(2.5).timeout
	var at_dock := String(_st_now().kind) == "dock"
	_press(KEY_ENTER)
	await get_tree().create_timer(ZOOM_TIME + 0.3).timeout
	var sailed := _map
	_press(KEY_ENTER)
	await get_tree().create_timer(ZOOM_TIME + 0.3).timeout
	checks.append(["主島的碼頭按 Enter 出航（世界地圖），再按 Enter 回主島", at_dock and sailed and not _map])
	select(0)
	# 世界地圖：按 M 拉遠，方向鍵飛到別的島，Enter 登島
	_press(KEY_M)
	await get_tree().create_timer(ZOOM_TIME + 0.3).timeout
	checks.append(["按 M 拉遠看世界地圖", _map and _zoom >= 0.99])
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00a_world_map.png"))
	_press(KEY_UP)
	await get_tree().create_timer(JUMP_TIME + 0.4).timeout
	var flew := selected != 0 and not _busy()
	checks.append(["世界地圖上按 ↑ 飛到北邊的島", flew])
	_press(KEY_ENTER)
	await get_tree().create_timer(ZOOM_TIME + 0.3).timeout
	checks.append(["按 Enter 登島（鏡頭拉近）", flew and not _map and _zoom <= 0.01])
	_press(KEY_ESCAPE)
	await get_tree().create_timer(ZOOM_TIME + 0.3).timeout
	checks.append(["島上按 Esc 退回世界地圖", _map])
	_press(KEY_DOWN)
	await get_tree().create_timer(JUMP_TIME + 0.4).timeout
	_press(KEY_ENTER)
	await get_tree().create_timer(ZOOM_TIME + 0.3).timeout
	checks.append(["按 ↓ 飛回主島再登島", _is_hub(selected) and not _map])
	# 找一座有第 2 小關的島：從第 2 小關沿著路走回第 1 小關（往回走永遠可以）
	for k in range(1, entries.size()):
		if _playable(entries[k].ch) and entries[k].ch.stages.size() >= 2:
			_map = false
			_zoom = 0.0
			select(k)
			select_stage(1)
			walk_to(0)
			await get_tree().create_timer(1.5).timeout
			checks.append(["沿著路從第 2 小關走回第 1 小關", stage_sel == 0 and not _busy()])
			break
	# 找一座有第 2 小關的島，測「沒過第 1 小關，走不到也進不去第 2 小關」
	for k in range(1, entries.size()):
		var ch: Dictionary = entries[k].ch
		if not ch.is_empty() and ch.stages.size() >= 2 and not Progress.is_cleared(ch.stages[0].id):
			select(k)
			select_stage(0)
			walk_to(1)
			checks.append(["還沒過第 1 小關，走不到第 2 小關", _walk.is_empty() and stage_sel == 0])
			select_stage(1)
			checks.append(["還沒過第 1 小關，第 2 小關進不去", not start_selected()])
			break
	# 聲音開關：按 V 切換、再按一次切回來（測完恢復原本的設定）
	var was_muted := sound_muted()
	_press(KEY_V)
	await get_tree().process_frame
	await get_tree().process_frame
	var flipped := sound_muted() != was_muted
	var saved := ConfigFile.new()
	saved.load(SETTINGS_PATH)
	checks.append(["按 V 開關聲音，設定有存檔", flipped and bool(saved.get_value("audio", "muted", was_muted)) == sound_muted()])
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00d_sound_toggled.png"))
	set_sound_muted(was_muted)
	checks.append(["音效都合成出來了（%d 個）、背景音樂在播" % _snd.size(), _snd.size() == 8 and (_snd["bgm"] as AudioStreamPlayer).playing])
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("00b_level_locked.png"))
	# 自動驗收直接用程式選到農場範例那座島
	select(maxi(farm, 0))
	select_stage(0)
	for c in checks:
		var ok: bool = c[1]
		if not ok:
			fails += 1
		var s := "[%s] %s" % ["PASS" if ok else "FAIL", c[0]]
		print(s)
		lines.append(s)
	Engine.set_meta("ls_lines", lines)
	Engine.set_meta("ls_fails", fails)
	# 進入農場範例，繼續農場的驗收
	start_selected()
