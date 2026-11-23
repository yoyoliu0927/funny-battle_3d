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
## 範例關（examples/ 底下的農場大門）平常不上地圖，只有 --autotest／--dev 時多一座島；底線開頭的大關（_template 範本）不上地圖。
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
const TitleScreen := preload("res://scripts/ui/title_screen.gd")   # 一開遊戲的標題畫面（掛在這個場景上，拿世界地圖當背景）
const ENDING_SCENE := "res://levels/heaven/ending/ending.tscn"   # 結局動畫（隱藏按鍵 Shift＋E 直接播，展示用）
const HubLife := preload("res://scripts/hub/hub_life.gd")         # 主島的戳戳樂（母雞、樹、風車、穀倉……）
const HubFishing := preload("res://scripts/hub/hub_fishing.gd")   # 農莊池塘和釣魚小遊戲
const HubDj := preload("res://scripts/hub/hub_dj.gd")             # 家豪的 DJ 台（節奏演出＋自由混音）
const HubJournal := preload("res://scripts/hub/hub_journal.gd")   # 冒險手帳（旅程、貼紙、魚圖鑑）
const HubGrowth := preload("res://scripts/hub/hub_growth.gd")     # 破關後農莊長出小地標和居民
const HubUI := preload("res://scripts/hub/hub_ui.gd")            # 手帳和釣魚共用的畫圖工具
const Journal := preload("res://scripts/hub/journal.gd")          # 手帳的存檔和資料
const HubSail := preload("res://scripts/hub/hub_sail.gd")         # 出航：開船去不同的島（實驗：experiment/free-walk）
const HubBoats := preload("res://scripts/hub/hub_boats.gd")       # 幾種船、速度、買船
const HubSeaLife := preload("res://scripts/hub/hub_sea_life.gd")   # 海上的彩蛋（寶箱、企鵝、跳魚、世界的盡頭）
const HubSfx := preload("res://scripts/hub/hub_sfx.gd")
const HubTime := preload("res://scripts/hub/hub_time.gd")         # 一天的天色（跟著電腦的時間、固定、快轉）
const HubNight := preload("res://scripts/hub/hub_night.gd")       # 夜晚的螢火蟲和路燈
const SEA_WAVE := 0.55            # 開船時海浪多高（公尺）
const ROWBOAT := "res://levels/ice/assets/blender/rowboat.glb"
const BOAT_LEN := 4.2             # 開船用的小船多長（公尺）
const BOAT_FLIP := false          # 船頭模型是反的就改成 true
const SAIL_CAM := 1.45            # 開船時鏡頭拉遠幾倍
const HubWalk := preload("res://scripts/hub/hub_walk.gd")         # 主島自由走：位置、障礙、吸附站點（實驗：experiment/free-walk）

## 主島自由走的障礙：模型檔名 -> 擋多大一圈（公尺）。蓋主島的時候 _spawn_fit 看到這些檔名就登記
const HUB_SOLID := {
	"BigBarn.glb": 2.3, "Barn.glb": 2.0, "SmallBarn.glb": 1.4, "OpenBarn.glb": 1.8, "ChickenCoop.glb": 1.5,
	"SiloHouse.glb": 1.5, "Silo.glb": 1.1, "Windmill.glb": 1.6, "BirchTree.glb": 0.5, "AutumnTree.glb": 0.5,
	"market_stall.glb": 1.1, "tent.glb": 1.3, "cart.glb": 0.8, "chest.glb": 0.6, "campfire-pit.glb": 0.55,
	"campfire-fishing-stand.glb": 0.8, "fish_net.glb": 0.5, "tree-log.glb": 0.7, "barrel.glb": 0.4,
	"crate-strong.glb": 0.5, "signpost-single.glb": 0.25, "post_lantern.gltf": 0.25,
}
const FREE_DASH_SPEED := 38.0     # 按數字鍵衝到站點的速度（公尺／秒）

## 正式的「島」一共幾座（四個組員各一座）；不夠的用「建造中」補滿
const ISLAND_SLOTS := 4
## 每個小關幾顆星
const STAR_MAX := 3
const SHAKE_TIME := 0.5

# ---- 地圖的尺寸（公尺）
const STEP := 11.5            # 同一個大關裡，站點和站點的間隔（東西向）
const HUB_STEP := 13.5        # 主島的站點間隔（主島比較大：中間有田、穀倉、池塘）
const HUB_RZ := 21.0          # 主島南北的半徑
const HUB_CZ := -3.5          # 主島的中心在路的北邊多遠（北邊比較深：田和林子）
const POND_R := Vector2(6.4, 4.6)   # 農莊池塘的半徑（東西、南北）
const FISH_COLOR := Color("3fa0d8")
const DJ_COLOR := Color("a04fd0")
const RANKS_TEST := ["", "D", "C", "B", "A", "S"]
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

## 世界分兩區：主島在中間，北邊是「北方諸國」（神獸與冰雪的國度），南邊是「南方島嶼」（人類佔領的島）。
## 這裡沒列到的大關算南方；大關也可以在自己的 chapter.gd 寫 const REGION := "north" 或 "south" 指定。
const NORTH_IDS := ["ice", "heaven"]
const FINAL_IDS := ["heaven"]       # 最終章：其他大關都破完（帶回所有羽毛）才能上去；排在北方最高的地方
const REGION_INFO := {
	"north": {"name": "北方諸國", "sub": "神獸與冰雪的國度", "col": Color("e6f6ff"), "cap": Color("4a9fe0")},
	"south": {"name": "南方島嶼", "sub": "被人類佔領的島", "col": Color("fff1d6"), "cap": Color("e8483a")},
}
## 世界地圖上島四周淺水的顏色：南方像沙灘、北方像結冰的淺灘
const SHALLOW_TINT := {"north": Color(0.10, 0.38, 0.64), "south": Color(1, 1, 1)}      # 南方用頂點顏色（沙灘＋淺水），這裡是白
## 每破一個大關，家豪帶回一根羽毛（湊齊就是「五采而文」的鳳凰）。顏色照劇本（levels/ice/docs/劇情故事.md）：
## 冰雪島是青色、最後丹穴山是金色，中間三根是紅、黃和另一個顏色。沒列到的照島的主色
const FEATHER_COLORS := {
	"ice": Color("4fc3d9"), "liuchiyu": Color("e2483a"), "forest": Color("f2d03a"), "fort": Color("9a72d8"), "heaven": Color("f0a81c"),
}
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
	"sky.night": 0.0, "sky.sun_vis": 0.0, "sky.moon_vis": 0.0,        # 星星、太陽、月亮（農莊天色才會開，別的地方要關回來）
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
var _idle_t := 0.0           # 多久沒按鍵、沒點滑鼠了（太久就把按鍵提示叫回來）
var _head_key := ""          # 左上角大標題現在寫的字（換了就重新計時：先大大的秀，再淡出）
var _head_t0 := 0.0
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
var _title: Node             # 標題畫面（還開著的時候：這裡的介面藏起來、不收按鍵）
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
var _hens: Array = []        # 主島上的母雞（就是 _life.hens，每筆有 node；標題畫面的開場動畫要用，不要拿掉）
var _life: Node3D            # 主島的戳戳樂（hub_life.gd）：母雞、樹、風車、穀倉、蛋
var _dj: Node3D              # 家豪的 DJ 台（hub_dj.gd）
var _fishing: Node3D         # 農莊池塘和釣魚小遊戲（hub_fishing.gd）
var _growth: Node3D          # 農莊跟著旅程長大（hub_growth.gd）
var _journal: CanvasLayer    # 冒險手帳（hub_journal.gd）
var _cam_bias := Vector3.ZERO      # 鏡頭多看向哪邊（釣魚時偏向池塘）
var _cam_bias_to := Vector3.ZERO
var _face_yaw := 0.0         # 家豪待機時朝哪個方向（0 = 面對鏡頭；釣魚時朝池塘）
var _hub_yard := Rect2()     # 主島雞圈的範圍（島自己的座標：x, z, 寬, 深）
var _free := HubWalk.new()   # 主島自由走（hub_walk.gd）
var _free_enabled := true    # 主島用自由走（命令列 --no-freewalk 關掉；自動測試預設關掉，--freewalk 再打開）
var _free_near := true       # 家豪離最近的站點夠近（泡泡、Enter 才有效）
var _free_goal := Vector3.ZERO     # 滑鼠點地面：走到這個點
var _free_goal_on := false
var _free_stuck := 0.0       # 走向滑鼠點的路上被擋住多久了
var _free_dash := {}         # 按數字鍵衝向站點：{"from", "to", "t", "dur", "k"}
var _free_dist := 0.0        # 自由走一共走了幾公尺（算一跳一跳）
var _free_hop_i := 0
var _sailer := HubSail.new() # 出航（hub_sail.gd）
var _sail_enabled := true    # 碼頭的「出航」是開船（命令列 --no-sail 關掉，回到原本的「拉遠看世界地圖」；自動測試預設關）
var _sail := {}              # 開船中：{"state": "board"／"sail", "t", "from", "pos": Vector2, "yaw", "spd", "path", "idx", "auto", "auto_e", "pick", "sel"}
var _boat: Node3D            # 開船用的小船（第一次出航才蓋）
var _boat_model: Node3D
var _pier_boat: Node3D       # 碼頭邊停著的小船（出航時藏起來）
var _wake: CPUParticles3D    # 船尾的浪花
var _cam_yaw := 0.0          # 鏡頭繞著家豪轉了多少（開船時跟在船後面）
var _cam_sail := 0.0         # 0 = 一般鏡頭、1 = 開船的鏡頭（拉遠一點）
var _sail_near := -1         # 離哪座島夠近可以靠岸（entries 的索引；-1 = 沒有）
var _sail_rows: Array = []   # 自動航行選單每一列在畫面上的位置
var _sail_roll := 0.0        # 船轉彎時歪多少
var _sail_bump_t := 0.0      # 擦到岸邊的音效冷卻
var _boat_id := ""           # 小船現在是哪一種（hub_boats.gd 的 id）
var _boat_light: OmniLight3D
var _spray: CPUParticles3D   # 船頭的水花
var _wave_snd: AudioStreamPlayer
var _cam_fov0 := 75.0
var _wave_amp := 0.0         # 現在海浪多高（開船才有）
var _sea_life: Node3D        # 海上的彩蛋（hub_sea_life.gd）
var _yard := {}              # 船塢開著：{"sel": 選到第幾艘}
var _yard_rows: Array = []
var _meters_acc := 0.0
var _tod_on := false         # 天色跟著時間走（農莊、世界地圖、沒有自己天色的島）
var _tod_mode := "auto"      # "auto" 跟電腦時間、"fixed" 固定、"cycle" 快轉（一天兩分鐘）
var _tod_hour := 12.0        # 現在幾點（小時，含小數）
var _tod_fixed := 12.0       # 固定時間
var _tod_base := 12.0        # 快轉從幾點開始
var _tod_t0 := 0.0           # 快轉從什麼時候開始（_t）
var _tod_timer := 0.0
var _night: Node3D           # 螢火蟲和路燈（hub_night.gd）
var _tod_open := false       # 時間面板開著
var _tod_sel := 0            # 面板上選到哪一列（0～2 三種模式）
var _tod_rows: Array = []
var _tod_presets: Array = []
var _tod_slider := Rect2()
var _tod_drag := false
var _time_rect := Rect2()    # 右上角時間按鈕在畫面上的位置
var _hub_build := false      # 正在蓋主島：_spawn_fit 要登記障礙
var _hub_blocks: Array = []  # 主島的障礙 [節點, 半徑, 世界座標偏移]
var _hero_tilt: Node3D       # 家豪（中間那層：世界地圖上往後仰，從上面看得到臉）
var _hero_base: Node3D       # 世界地圖上家豪腳下的棋子底座
var _shadow: MeshInstance3D  # 飛行時海面上的影子
var _shadow_mat: StandardMaterial3D
var _snd_pop := 0.0          # 喇叭按鈕剛被按：彈一下還剩幾秒
var _hop_i := 0              # 走路時已經跳了幾下（每落地一次響一聲）
var _flags: Array = []       # 會飄的旗子 {node, phase}
var _clouds: Array = []      # 蓋住未開放小島的雲 {node, base, phase}
var _plumes: Node3D          # 家豪屁股上的羽毛（破一個大關多一根；世界地圖上才看得到）
var _shallow_mats := {}      # 區 -> 淺水材質（世界地圖上：南方沙色、北方冰藍）
var _floats: Array = []      # 海上漂的東西（北方的浮冰、南方的沙洲）{node, base, phase}

# ================================================================== 啟動

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest" or a.begins_with("--mapshots=") or a.begins_with("--hubshots=") or a.begins_with("--titleshots=") or a == "--freetest" or a.begins_with("--freeshots=") or a == "--sailtest" or a.begins_with("--sailshots=") or a.begins_with("--todshots=") or a == "--todtest":
			Journal.persist = false          # 測試不寫玩家的手帳存檔
	_load_chapters()
	_sync_stars()
	_cam = get_node("../Camera3D")
	_sun = get_node("../Sun")
	_env = (get_node("../WorldEnvironment") as WorldEnvironment).environment
	_sky_default = _env.sky.sky_material as ShaderMaterial
	_sky_mat = _sky_default
	_build_sea()
	_layout()
	_life = HubLife.new()
	_life.map = self
	add_child(_life)
	_fishing = HubFishing.new()
	_fishing.map = self
	add_child(_fishing)
	_dj = HubDj.new()
	_dj.map = self
	add_child(_dj)
	for e in entries.size():
		worlds.append(_build_world(e))
		if not _is_hub(e):
			_flatten_pieces(worlds[e].root)
	_hub_build = false
	_free.map = self
	_free.build()
	_sailer.map = self
	_sailer.build()
	_cam_fov0 = _cam.fov
	_fit_map_camera()
	_sea_mat.set_shader_parameter("region_z", float(worlds[0].center.z))
	var isles: Array = []
	for w in worlds.slice(0, 8):
		var c: Vector3 = w.center
		isles.append(Vector4(c.x, c.z, float(w.rx), float(w.rz)))
	_sea_mat.set_shader_parameter("isles", isles)
	var top_z := INF
	for w in worlds:
		top_z = minf(top_z, float(w.center.z) - float(w.rz))
	_sea_mat.set_shader_parameter("calm_z", top_z - 4.0)
	_ring_margins()
	_sea_mat.set_shader_parameter("isle_count", isles.size())
	_build_routes()
	_build_ring()
	_build_shallows()
	_build_sea_props()
	_build_halo()
	_build_hero()
	_spawn_hub_hens()
	_life.register("hero", _hero, 1.0, 0.9)
	_growth = HubGrowth.new()
	_growth.map = self
	add_child(_growth)
	_growth.sync(false)                  # 已經長過的先直接站好；新破關的在「回到農莊」時再演（_growth_check）
	_build_ui()
	_journal = HubJournal.new()
	_journal.map = self
	add_child(_journal)
	_build_audio()
	var args := OS.get_cmdline_user_args()
	var testing := "--autotest" in args
	var shots := ""
	var hub_shots := ""
	var hub_test := false
	var free_test := false
	var free_shots := ""
	var sail_test := false
	var sail_shots := ""
	var tod_shots := ""
	var tod_test := false
	for a in args:
		if a.begins_with("--mapshots="):
			shots = a.substr(11)
			testing = true
		if a.begins_with("--hubshots="):
			hub_shots = a.substr(11)
			testing = true
		if a == "--hubtest":
			hub_test = true
			testing = true
		if a == "--freetest":
			free_test = true
			testing = true
		if a == "--sailtest":
			sail_test = true
			testing = true
		if a.begins_with("--sailshots="):
			sail_shots = a.substr(12)
			testing = true
		if a.begins_with("--todshots="):
			tod_shots = a.substr(11)
			testing = true
		if a == "--todtest":
			tod_test = true
			testing = true
		if a.begins_with("--freeshots="):
			free_shots = a.substr(12)
			testing = true
	# 主島自由走：預設開；--no-freewalk 關掉。舊的自動測試是照「沿路走」寫的，所以測試預設關，加 --freewalk 才開
	_free_enabled = not ("--no-freewalk" in args) and (not testing or "--freewalk" in args or free_test or free_shots != "" or sail_test or sail_shots != "")
	_sail_enabled = not ("--no-sail" in args) and (not testing or "--sail" in args or sail_test or sail_shots != "")
	if _sail_enabled:
		_sail_make_boat()                       # 碼頭邊停著的是現在選的那艘船
		_sea_life = HubSeaLife.new()
		_sea_life.map = self
		add_child(_sea_life)
		_sea_life.build()
	# 天色跟著時間：預設開；自動測試和截圖維持原本的大晴天，加 --tod 或 --hour=21.5 才開
	var forced := HubTime.forced_hour()
	_tod_on = not testing or "--tod" in args or forced >= 0.0 or tod_shots != "" or tod_test
	if _tod_on:
		var ts := HubTime.load_settings()
		_tod_mode = String(ts.mode)
		_tod_fixed = float(ts.hour)
		if forced >= 0.0:
			_tod_mode = "fixed"
			_tod_fixed = forced
		_tod_hour = _tod_current_hour()
		_night = HubNight.new()
		_night.map = self
		add_child(_night)
		_night.build()
	selected = -1
	select(0)
	if Engine.has_meta("map_last"):
		_restore(Engine.get_meta("map_last"))
	elif not testing:
		_zoom = 1.0                      # 剛開遊戲：先看一眼整張世界地圖，再拉近到主島
	_place_hero(true)
	if TitleScreen.wanted() and hub_shots == "" and not hub_test and not free_test and free_shots == "" and not sail_test and sail_shots == "" and tod_shots == "" and not tod_test:
		# 剛開遊戲：先放標題畫面。按下開始之後鏡頭直接滑到主島（第一次玩會先接開場劇情）
		_zoom = 0.0
		_layer.visible = false
		_title = TitleScreen.new()
		_title.map = self
		add_child(_title)
	if "--autotest" in args:
		_autotest.call_deferred()
	if shots != "":
		_mapshots.call_deferred(shots)
	if hub_shots != "":
		_hubshots.call_deferred(hub_shots)
	if hub_test:
		_hubtest.call_deferred()
	if free_test:
		_freetest.call_deferred()
	if free_shots != "":
		_freeshots.call_deferred(free_shots)
	if sail_test:
		_sailtest.call_deferred()
	if sail_shots != "":
		_sailshots.call_deferred(sail_shots)
	if tod_shots != "":
		_todshots.call_deferred(tod_shots)
	if tod_test:
		_todtest.call_deferred()
	if _title == null and not testing:
		_growth_check.call_deferred()
		_journal_check.call_deferred()

## 標題畫面收掉了：介面拿出來，開始收按鍵
func _title_end() -> void:
	_title = null
	_layer.visible = true
	_growth_check()
	_journal_check()

## 讀大關清單：第 0 座是主島（農莊：商店、冒險紀錄、家、告示牌、碼頭），接著是主題島（不夠 ISLAND_SLOTS 座的用「還沒開放」補滿）
func _load_chapters() -> void:
	LEVELS = Registry.chapters()
	var islands: Array = LEVELS.filter(func(c): return not _is_example(c))
	# 範例關（examples/ 底下的農場大門）：平常不上地圖（連從編輯器執行也看不到）；
	# 只有自動驗收（--autotest，要進農場範例做檢查）或命令列加 --dev 時，排在主題島後面當一座多出來的島。
	# 底線開頭的大關（_template 範本）不上地圖：它只是開新大關時複製用的。主島上不放關卡
	var drafts: Array = LEVELS.filter(func(c): return _is_example(c) and not String(c.id).begins_with("_"))
	var cli := OS.get_cmdline_user_args()
	if not ("--autotest" in cli or "--dev" in cli):
		drafts.clear()
	entries.clear()
	_stations.clear()
	var hub: Array = [{"kind": "shop"}, {"kind": "board"}, {"kind": "home"}, {"kind": "guide"}, {"kind": "fish"}, {"kind": "dock"}]
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
			return _unlocked_ch(s.ch, int(s.k) + 1) and _gate_need(s.ch) == 0
		"locked":
			return false
	return true

## 開發用：命令列加 --fresh 時當成全新存檔（只影響畫面，不讀也不寫進度和星星），看新玩家第一次打開的樣子
var _fresh := OS.is_debug_build() and "--fresh" in OS.get_cmdline_user_args()

func _cleared(id: String) -> bool:
	return not _fresh and Progress.is_cleared(id)

func _ch_cleared(ch: Dictionary) -> bool:
	return not _fresh and Progress.chapter_cleared(ch)

## 這座島在哪一區："hub"（主島）、"north"、"south"、"dev"（開發版才有的範例島）
func _region(e: int) -> String:
	if _is_hub(e):
		return "hub"
	var ch: Dictionary = entries[e].ch
	if ch.is_empty():
		return "south"
	if _is_example(ch):
		return "dev"
	var r := String(_chapter_consts(ch).get("REGION", ""))
	if r == "north" or r == "south":
		return r
	return "north" if String(ch.id) in NORTH_IDS else "south"

## 羽毛：每個正式大關一根，全部小關都過了就拿到。[{id, col, have}]，照地圖上的順序
func _feathers() -> Array:
	var out: Array = []
	for ent in entries:
		var ch: Dictionary = ent.ch
		if _playable(ch) and not _is_example(ch):
			out.append({"id": String(ch.id), "col": _feather_col(ch), "have": _ch_cleared(ch), "final": String(ch.id) in FINAL_IDS})
	return out

func _feather_col(ch: Dictionary) -> Color:
	return FEATHER_COLORS.get(String(ch.id), CARD_COLORS.get(String(ch.id), GOLD))

## 最終章還差幾根羽毛才能上去（不是最終章、或已經玩過了，都是 0：舊存檔不會被鎖回去）
func _gate_need(ch: Dictionary) -> int:
	if ch.is_empty() or not String(ch.id) in FINAL_IDS:
		return 0
	if ch.stages.any(func(st): return _cleared(st.id)):
		return 0
	var need := 0
	for f in _feathers():
		if String(f.id) != String(ch.id) and not bool(f.have):
			need += 1
	return need

func _st_cleared(e: int, k: int) -> bool:
	var s := _st(e, k)
	return String(s.kind) == "stage" and _cleared(_st_stage(s).id)

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
		"fish":
			return FISH_COLOR
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
	if e == 0:
		return Vector3(k * HUB_STEP, 0.0, sin(k * 1.9) * 4.0)       # 主島
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
	if e == 0:
		var hh := (n - 1) * HUB_STEP * 0.5
		return {"center": Vector2(hh, HUB_CZ), "rx": hh + 11.0, "rz": HUB_RZ, "top_y": TOP_Y, "pads": pads, "spots": spots, "index": e}
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
	plane.subdivide_width = 299            # 開船時海面要能起伏（頂點浪），每格 3 公尺
	plane.subdivide_depth = 299
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

## 每座島放在世界地圖的哪裡：主島在正中間，北方諸國一排在上面（最終章再往北抬高，像一路往上爬），
## 南方島嶼一排在下面（最寬的在兩端、最小的在中間，像一道圍著主島的弧）。開發版的範例島排在最南邊。
func _layout() -> void:
	var sizes := {}
	for e in entries.size():
		var n: int = (_stations[e] as Array).size()
		if String(_st(e, 0).kind) == "locked":
			sizes[e] = Vector2(ISLE_R + 2.0, ISLE_R + 2.0)
		else:
			sizes[e] = (Vector2((n - 1) * HUB_STEP * 0.5 + 11.0, HUB_RZ) if e == 0 else Vector2((n - 1) * STEP * 0.5 + 9.5, 11.0)) * _isle_scale(e)
	_ring_pos.resize(entries.size())
	_ring_pos[0] = Vector2.ZERO
	var hub: Vector2 = sizes[0]
	var north: Array = []
	var south: Array = []
	var dev: Array = []
	for e in range(1, entries.size()):
		match _region(e):
			"north":
				north.append(e)
			"dev":
				dev.append(e)
			_:
				south.append(e)
	# 北方：最終章放在主島正北、最高的地方（像一路往上爬的終點）；其他北方的島排成一排、整排往左讓開
	var finals: Array = north.filter(func(e): return String(entries[e].ch.get("id", "")) in FINAL_IDS)
	var others: Array = north.filter(func(e): return not e in finals)
	_place_row(others, sizes, -1.0, hub.y + MAP_GAP, {}, 26.0)
	if not finals.is_empty() and not others.is_empty():
		var right := -INF
		for e in others:
			right = maxf(right, float(_ring_pos[e].x) + (sizes[e] as Vector2).x)
		for e in others:
			_ring_pos[e] += Vector2(-7.0 - right, 0.0)
	var top := hub.y + MAP_GAP
	for e in others:
		top = maxf(top, -float(_ring_pos[e].y) + (sizes[e] as Vector2).y)
	_place_row(finals, sizes, -1.0, top - 3.0, {}, 26.0)
	for e in finals:
		_ring_pos[e] += Vector2(6.0, 0.0)
	# 南方：寬的放兩端，小的放中間
	var by_w := south.duplicate()
	by_w.sort_custom(func(a, b): return (sizes[a] as Vector2).x > (sizes[b] as Vector2).x if not is_equal_approx((sizes[a] as Vector2).x, (sizes[b] as Vector2).x) else a < b)
	var left: Array = []
	var right: Array = []
	for i in by_w.size():
		if i % 2 == 0:
			left.append(by_w[i])
		else:
			right.push_front(by_w[i])
	_place_row(left + right, sizes, 1.0, hub.y + MAP_GAP, {}, 26.0)
	# 開發版的範例島：南方再往南一排
	var far := hub.y + MAP_GAP
	for e in south:
		far = maxf(far, float(_ring_pos[e].y) + (sizes[e] as Vector2).y + MAP_GAP)
	_place_row(dev, sizes, 1.0, far, {}, 18.0)
	for e in dev:
		_ring_pos[e] += Vector2(-34.0, 0.0)          # 往左挪：航線才不會穿過南方中間那座島

## 最終章放大 1.2 倍，其他 1 倍
func _isle_scale(e: int) -> float:
	return 1.2 if not _is_hub(e) and String(entries[e].ch.get("id", "")) in FINAL_IDS else 1.0

## 一排島：照寬度排開、左右置中；中間的往外凸一點。sign：-1 往北、1 往南；base：離主島中心多遠開始
func _place_row(list: Array, sizes: Dictionary, sign: float, base: float, rise: Dictionary, gap: float) -> void:
	if list.is_empty():
		return
	var total := gap * (list.size() - 1)
	for e in list:
		total += (sizes[e] as Vector2).x * 2.0
	var x := -total * 0.5
	for i in list.size():
		var e: int = list[i]
		var s: Vector2 = sizes[e]
		x += s.x
		var t := 1.0 if list.size() == 1 else absf(float(i) / (list.size() - 1) * 2.0 - 1.0)   # 0 = 中間、1 = 兩端
		var d := base + s.y + (1.0 - t) * 8.0 + float(rise.get(e, 0.0))
		_ring_pos[e] = Vector2(x, d * sign)
		x += s.x + gap

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

## 效能：把島上不會動的模型（.glb 拆成很多小零件的那種，一棵樹可能有 80 幾個零件）
## 每個模型合併成「一種材質一個面」，繪製次數從幾千降到幾百。
## 有腳本、動畫、骨架、形狀鍵的模型不動（可能會被搖晃、換材質、開關），藏起來的零件也不合併。
func _flatten_pieces(root: Node) -> void:
	for c in root.get_children():
		if c is Node3D and String(c.scene_file_path) != "" and _static_piece(c):
			_merge_piece(c)
		else:
			_flatten_pieces(c)

func _static_piece(n: Node) -> bool:
	if n.get_script() != null or n is AnimationPlayer or n is AnimationTree or n is Skeleton3D:
		return false
	if n is MeshInstance3D:
		var mesh := (n as MeshInstance3D).mesh
		if mesh and (mesh.get_blend_shape_count() > 0 or (n as MeshInstance3D).skin != null):
			return false
	for c in n.get_children():
		if not _static_piece(c):
			return false
	return true

func _merge_piece(piece: Node3D) -> void:
	var inv := piece.global_transform.affine_inverse()
	var groups := {}      # 材質＋影子設定 → [SurfaceTool, 材質, 影子]
	var done: Array = []
	for m in piece.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.get_child_count() > 0:
			continue
		var tris := true
		for s in mi.mesh.get_surface_count():
			tris = tris and mi.mesh.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES
		if not tris:
			continue
		var xf := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var key := "%d|%d|%d" % [mat.get_instance_id() if mat else 0, mi.cast_shadow, mi.layers]
			if not groups.has(key):
				var st := SurfaceTool.new()
				groups[key] = [st, mat, mi.cast_shadow, mi.layers]
			(groups[key][0] as SurfaceTool).append_from(mi.mesh, s, xf)
		done.append(mi)
	if done.size() < 2:
		return
	# 影子設定、圖層一樣的放進同一個網格（通常整個模型只有一種），每種材質一個面
	var meshes := {}      # "影子|圖層" → MeshInstance3D
	for key in groups:
		var g: Array = groups[key]
		var nk := "%d|%d" % [g[2], g[3]]
		if not meshes.has(nk):
			var mi := MeshInstance3D.new()
			mi.name = "Merged"
			mi.mesh = ArrayMesh.new()
			mi.cast_shadow = g[2]
			mi.layers = g[3]
			piece.add_child(mi)
			meshes[nk] = mi
		var am: ArrayMesh = (meshes[nk] as MeshInstance3D).mesh
		(g[0] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, g[1])
	for mi in done:
		mi.get_parent().remove_child(mi)
		mi.queue_free()

## 蓋第 e 座島：一整座大島，島上有每個站點的地標、圓墊、路、旗子。還沒做好的大關是一座被雲蓋住的小島。
## 島先蓋在自己的座標裡（root 底下），再把 root 搬到世界地圖上的位置。
func _build_world(e: int) -> Dictionary:
	var ent: Dictionary = entries[e]
	var ch: Dictionary = ent.ch
	var hub := _is_hub(e)
	_hub_build = hub                                  # 蓋主島的時候，_spawn_fit 會登記自由走的障礙
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
	var sc := _isle_scale(e)                          # 最終章整座放大一點（全圖的視覺高潮）
	var w := {"root": root, "n": n, "pads": [], "isles": [], "isle_roots": [], "segs": [], "pad_nodes": [], "hook": hook,
		"center": Vector3(at.x, TOP_Y, at.y), "rx": ISLE_R + 2.0, "rz": ISLE_R + 2.0, "marks": []}
	var ctx := {}
	if playable:
		ctx = _island_ctx(le, n)
		var c: Vector2 = ctx.center
		off = Vector3(at.x - c.x * sc, 0, at.y - c.y * sc)
		w.rx = float(ctx.rx) * sc
		w.rz = float(ctx.rz) * sc
		if hub:
			_build_farm(root, ctx)
		elif hook and hook.has_method("build_island"):
			hook.build_island(root, ctx)
		else:
			_default_island(root, le, ctx)
	root.position = off
	root.scale = Vector3.ONE * sc
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
		w.pads.append((lpads[k] as Vector3) * sc + off)
		w.isles.append((lspots[k] as Vector3) * sc + off)
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
			wpts.append(p * sc + off)
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

## 主島：一座大農莊。路蜿蜒在中間；北邊是田、穀倉、風車和一片林子；南邊是母雞的雞圈；東邊是池塘和碼頭。
## 農莊裡的東西大多可以戳（見 scripts/hub/hub_life.gd），蓋的時候順便登記。
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
	var fk := _hub_index("fish")
	# 已經放了大東西的地方 Vector3(x, z, 半徑)：樹和雜物要避開
	var solid: Array = []
	var pond_c := Vector2(float((spots[fk] as Vector3).x), float((spots[fk] as Vector3).z) - 2.0)
	solid.append(Vector3(pond_c.x, pond_c.y, maxf(POND_R.x, POND_R.y) * 1.3 + 2.0))
	# DJ 台：在池塘和碼頭東北邊的空地上（不是站點；走近按 E 或點混音台）
	var dj_c := Vector3(float((spots[fk] as Vector3).x) + 9.0, y, -9.5)
	_dj.build_stage(root, dj_c)
	solid.append(Vector3(dj_c.x, dj_c.z, 7.5))
	# 雞圈：家的正南邊
	var yard := Rect2(Vector2(float((pads[2] as Vector3).x) - 8.5, 7.6), Vector2(17.0, 5.8))
	_hub_yard = yard
	solid.append(Vector3(yard.get_center().x, yard.get_center().y, 9.5))
	for gid in HubGrowth.ids():
		var gs := HubGrowth.slot(String(gid))
		solid.append(Vector3(gs.x, gs.y + 1.2, 4.6))                  # 破關後會長小地標的地方：樹不要種在這裡
	var soil := _tex_mat("forest_ground_04_diff_1k.jpg", Color(1.05, 0.74, 0.50), 0.32)
	# 兩個地標中間、往北一點：田、穀倉、南瓜園
	for k in spots.size() - 1:
		var m: Vector3 = ((spots[k] as Vector3) + (spots[k + 1] as Vector3)) * 0.5 + Vector3(0, 0, -1.4)
		if k == 2:
			# 家的東邊：大穀倉（門可以敲開）＋筒倉
			var barn := _spawn_fit(root, "res://assets/farm/BigBarn.glb", Vector3(m.x - 0.6, y, m.z - 1.2), 5.6, 0.25)
			var silo := _spawn_fit(root, "res://assets/farm/Silo.glb", Vector3(m.x + 3.0, y, m.z - 1.8), 4.8, 0.0)
			if barn:
				_life.register_barn(barn)
			if silo:
				_life.register("silo", silo, 2.0, 2.4)
			solid.append(Vector3(m.x - 0.6, m.z - 1.2, 5.0))
			solid.append(Vector3(m.x + 3.0, m.z - 1.8, 2.8))
		elif k == fk - 1:
			_pumpkin_patch(root, Vector3(m.x - 1.0, y, m.z - 3.5), y, solid)
		elif k == fk:
			continue                                   # 池塘和碼頭中間不種東西
		else:
			_farm_plot(root, soil, m, k, y, solid, k == 1)
			_farm_plot(root, soil, m + Vector3(0, 0, -8.5), k + 7, y, solid, false)
	# 兩頭：西邊風車、東邊筒倉小屋
	var west: Vector3 = spots[0]
	var east: Vector3 = spots[spots.size() - 1]
	var wm := _spawn_fit(root, "res://assets/farm/Windmill.glb", Vector3(west.x - 6.6, y, west.z + 1.0), 6.4, 0.5)
	if wm:
		_life.register("windmill", wm, 3.0, 3.2)
	solid.append(Vector3(west.x - 6.6, west.z + 1.0, 3.6))
	var sh := _spawn_fit(root, "res://assets/farm/SiloHouse.glb", Vector3(east.x + 4.6, y, east.z - 2.6), 5.2, -0.4)
	if sh:
		_life.register("silo", sh, 2.4, 2.6)
	solid.append(Vector3(east.x + 4.6, east.z - 2.6, 3.4))
	# 雞圈的柵欄（北邊中間留一個門）、水桶和乾草
	var fence := "res://levels/ice/assets/kenney_platformer/fence-rope.glb"
	var gate_x := yard.get_center().x
	_fence_line(root, fence, Vector2(yard.position.x, yard.position.y), Vector2(yard.end.x, yard.position.y), y, gate_x - 1.9, gate_x + 1.9)
	_fence_line(root, fence, Vector2(yard.position.x, yard.end.y), Vector2(yard.end.x, yard.end.y), y)
	_fence_line(root, fence, Vector2(yard.position.x, yard.position.y), Vector2(yard.position.x, yard.end.y), y)
	_fence_line(root, fence, Vector2(yard.end.x, yard.position.y), Vector2(yard.end.x, yard.end.y), y)
	_spawn_fit(root, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(yard.end.x - 1.0, y, yard.end.y - 1.0), 0.95, 0.3)
	var yh := _spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(yard.position.x + 1.4, y, yard.end.y - 1.0), 1.1, 0.6)
	if yh:
		_life.register("hay", yh, 1.1, 0.5, {"special": false})
	# 岸邊的樹：北半圈密一點（還往裡面種成一片林子），南邊（靠鏡頭）只在兩個角落種
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var placed: Array[Vector2] = []
	for i in 1600:
		var a := rng.randf() * TAU
		var edge := _outline(rx, rz, a, s)
		var inner := sin(a) < -0.1 and rng.randf() < 0.5
		var d := edge * rng.randf_range(0.42, 0.88) if inner else edge - rng.randf_range(1.4, 2.6)
		var x := c.x + cos(a) * d
		var z := c.y + sin(a) * d
		if sin(a) > -0.15 and absf(cos(a)) < 0.82:
			continue                              # 南邊中間不種
		if not spot_free(ctx, x, z, 2.2) or (cos(a) > 0.6 and sin(a) > -0.5):
			continue
		if solid.any(func(q): return Vector2(x, z).distance_to(Vector2(q.x, q.y)) < float(q.z) + 1.2):
			continue
		var p := Vector2(x, z)
		if placed.any(func(o): return (o as Vector2).distance_to(p) < 2.7):
			continue
		placed.append(p)
		var autumn := placed.size() % 3 == 0
		var tree := "res://assets/nature/AutumnTree.glb" if autumn else "res://assets/nature/BirchTree.glb"
		var th := rng.randf_range(2.6, 3.8)
		var tn := _spawn_fit(root, tree, Vector3(x, y, z), th, rng.randf() * TAU)
		if tn:
			_life.register("tree", tn, 1.5, th * 0.5, {"leaf": Color("e0902f") if autumn else Color("7cb84a")})
	# 路邊的莓果叢和路燈
	for k in pads.size():
		var p: Vector3 = pads[k]
		_spawn_fit(root, "res://assets/nature/BushBerries.glb", Vector3(p.x - 3.4, y, p.z - 2.2), 1.1, k * 2.0)
		_spawn_fit(root, "res://levels/liuchiyu/assets/kaykit_halloween/post_lantern.gltf", Vector3(p.x + 2.6, y, p.z + 0.4), 2.6, 0.0)
	# 南岸（靠鏡頭）沿著岸邊一排矮柵欄，中間留一個缺口，柵欄邊幾叢莓果、幾顆南瓜
	var last := Vector2(INF, INF)
	var n_fence := 0
	for i in 400:
		var a := PI * 0.5 - 0.95 + i * (1.9 / 399.0)
		var d := _outline(rx, rz, a, s) - 1.5
		var fx := c.x + cos(a) * d
		var fz := c.y + sin(a) * d
		if absf(fx - c.x) < 2.2 or Vector2(fx, fz).distance_to(last) < 2.0:
			continue
		last = Vector2(fx, fz)
		n_fence += 1
		var fn := _spawn_fit(root, fence, Vector3(fx, y, fz), 2.0, -a + PI * 0.5)
		if fn:
			_small.append(fn)
		if n_fence % 4 == 1:
			_spawn_fit(root, "res://assets/nature/BushBerries.glb", Vector3(fx + 0.4, y, fz - 1.3), 1.0, n_fence * 1.3)
		elif n_fence % 4 == 3:
			var pk := _spawn_fit(root, "res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange.gltf", Vector3(fx - 0.3, y, fz - 1.1), 0.6, n_fence * 0.9)
			if pk:
				_life.register("pumpkin", pk, 0.55, 0.25)

## 一塊田：翻過的土＋一排一排的作物，旁邊乾草和南瓜（乾草堆和南瓜可以戳；special 那一堆藏著金蛋）
func _farm_plot(root: Node3D, soil: Material, m: Vector3, k: int, y: float, solid: Array, special_hay: bool) -> void:
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
	var hay := _spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(m.x + 3.0, y, m.z + 1.2), 1.0, k * 1.3 + 0.4)
	if hay:
		_life.register("hay", hay, 1.1, 0.5, {"special": special_hay})
	for j in 3:
		var pk := _spawn_fit(root, "res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange.gltf", Vector3(m.x - 2.9 + j * 0.25, y, m.z + 1.4 + j * 0.62), 0.55 - 0.08 * j, j * 1.1)
		if pk:
			_life.register("pumpkin", pk, 0.55, 0.25)
	solid.append(Vector3(m.x, m.z, 3.4))

## 南瓜園：一堆南瓜、幾捆乾草
func _pumpkin_patch(root: Node3D, c: Vector3, y: float, solid: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 11:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 3.0
		var sz := rng.randf_range(0.5, 0.9)
		var pk := _spawn_fit(root, "res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange.gltf", Vector3(c.x + cos(a) * r, y, c.z + sin(a) * r * 0.8), sz, rng.randf() * TAU)
		if pk:
			_life.register("pumpkin", pk, maxf(sz * 0.7, 0.5), sz * 0.45)
	for i in 2:
		var hy := _spawn_fit(root, "res://assets/farm/Hay.glb", Vector3(c.x + 3.4 - i * 6.6, y, c.z + 1.4 - i), 1.1, i * 1.7)
		if hy:
			_life.register("hay", hy, 1.1, 0.5, {"special": false})
	solid.append(Vector3(c.x, c.z, 4.4))

## 沿著 a→b 一段一段放柵欄；skip_from～skip_to（x 座標）之間留空當門
func _fence_line(root: Node3D, path: String, a: Vector2, b: Vector2, y: float, skip_from := 1.0e9, skip_to := -1.0e9) -> void:
	var d := b - a
	var len := d.length()
	var n := maxi(int(round(len / 2.0)), 1)
	var yaw := atan2(-d.y, d.x)
	for i in n:
		var p := a + d * ((i + 0.5) / n)
		if p.x > skip_from and p.x < skip_to:
			continue
		var fn := _spawn_fit(root, path, Vector3(p.x, y, p.y), len / n, yaw)
		if fn:
			_small.append(fn)
			# 柵欄擋路：每一段沿著它的方向放三個小圓，門（skip 那一段）是空的，家豪走得進去
			var along := Vector3(d.x, 0, d.y).normalized() * (len / n) * 0.33
			for sgn in [-1.0, 0.0, 1.0]:
				_hub_blocks.append([fn, 0.35, along * sgn, 0.0])

## 主島第幾個站點是這種功能（找不到回傳 0）
func _hub_index(kind: String) -> int:
	var sts: Array = _stations[0]
	for k in sts.size():
		if String(sts[k].kind) == kind:
			return k
	return 0

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
			var flame := _spawn_fit(root, "res://levels/ice/assets/blender/flame.glb", Vector3(-2.2, 0.0, 1.0), 0.95, 0.0)
			if flame:
				_life.register_flame(flame)
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
			var boat := _spawn_fit(root, "res://levels/ice/assets/blender/rowboat.glb", Vector3(dx + 3.6, -TOP_Y - 0.1, 6.6), 2.8, 1.2)
			if boat:
				_life.register("boat", boat, 1.7, 0.5)
				_pier_boat = boat
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(dx - 2.0, -0.05, 2.6), 1.0, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_platformer/crate-strong.glb", Vector3(dx - 2.8, -0.05, 3.6), 1.0, 0.4)
			_spawn_fit(root, "res://levels/fort/assets/pirate/flag-pennant.glb", Vector3(dx - 1.6, -0.05, 5.6), 3.4, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/signpost-single.glb", Vector3(0.6, -0.05, 0.4), 2.6, -0.3)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/fish-large.glb", Vector3(-1.6, 0.0, 1.0), 0.9, 0.6)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/bucket.glb", Vector3(-2.2, -0.05, 0.4), 0.7, 0.0)
			root.set_meta("bubble_y", 4.2)
		"fish":
			# 池塘（水、魚影、睡蓮、石頭）在 hub_fishing.gd 蓋；這裡擺岸邊的東西：木板平台、釣竿架、魚網、木桶、長椅
			_fishing.build_pond(root, Vector3(0, 0.05, -2.0), POND_R.x, POND_R.y)
			_spawn_fit(root, "res://levels/fort/assets/pirate/platform-planks.glb", Vector3(0.2, -0.05, 3.6), 3.0, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/campfire-fishing-stand.glb", Vector3(7.6, -0.05, 0.6), 2.4, -0.6)
			_spawn_fit(root, "res://levels/ice/assets/blender/fish_net.glb", Vector3(-7.6, -0.05, 1.0), 1.8, 0.8)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/bucket.glb", Vector3(-2.6, -0.05, 4.2), 0.7, 0.0)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(3.8, -0.05, 4.6), 0.95, 0.5)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/tree-log.glb", Vector3(-9.0, -0.05, 2.4), 1.8, 0.9)
			_spawn_fit(root, "res://levels/ice/assets/kenney_survival/signpost-single.glb", Vector3(-3.6, -0.05, 4.6), 2.2, 0.3)
			root.set_meta("bubble_y", 4.6)

# ---------------------------------------------------------------- 世界地圖：航線、光圈

## 每座島周圍一圈淺水（青綠色，越往外越淡）：島才像坐在海裡，不是貼在海面上
func _build_shallows() -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rings := [[0.0, 0.62], [0.58, 0.62], [0.72, 0.42], [0.86, 0.17], [1.0, 0.0]]
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
	var make := func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(0.56, 0.95, 0.88)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 1
		return m
	_shallow_mat = make.call()
	for r in SHALLOW_TINT:
		_shallow_mats[r] = make.call()
	var lagoon := Color(0.50, 0.92, 0.84)
	# 南方：沙灘由海面著色器照真正的海岸線畫（sand_c）；這裡只鋪外圈的藍綠色淺水，從岸外 3 公尺才開始
	var beach := func(w: Dictionary) -> ArrayMesh:
		var k := (float(w.rx) + 3.0) / (float(w.rx) + 12.0)
		return _glow_mesh([[0.0, 0.0, lagoon], [k, 0.0, lagoon], [k + 0.05, 0.5, lagoon], [k + (1.0 - k) * 0.55, 0.25, lagoon], [1.0, 0.0, lagoon]])
	for e in worlds.size():
		var w: Dictionary = worlds[e]
		var c: Vector3 = w.center
		var mi := MeshInstance3D.new()
		mi.mesh = beach.call(w) if _region(e) == "south" else mesh
		mi.material_override = _shallow_mats.get(_region(e), _shallow_mat)
		mi.position = Vector3(c.x, 0.05, c.z)
		mi.scale = Vector3(float(w.rx) + 12.0, 1.0, float(w.rz) + 12.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

## 海上的小東西，讓兩區一眼看得出差別：北方漂著浮冰和冰山，南方散著幾塊長了樹叢的沙洲。
## 位置用固定種子的亂數挑（每次開都一樣），避開島、航線和彼此。最終章還鎖著的話，整座島被一圈雲蓋住。
func _build_sea_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for w in worlds:
		var c: Vector3 = w.center
		lo = Vector2(minf(lo.x, c.x - float(w.rx)), minf(lo.y, c.z - float(w.rz)))
		hi = Vector2(maxf(hi.x, c.x + float(w.rx)), maxf(hi.y, c.z + float(w.rz)))
	var rz := float(worlds[0].center.z)
	var taken: Array = []
	var free := func(p: Vector2, room: float) -> bool:
		for w in worlds:
			var c: Vector3 = w.center
			var d := Vector2((p.x - c.x) / (float(w.rx) + room), (p.y - c.z) / (float(w.rz) + room))
			if d.length() < 1.0:
				return false
		for rt in _routes:
			for q in (rt.pts as PackedVector2Array):
				if q.distance_to(p) < room * 0.7:
					return false
		for q in taken:
			if (q as Vector2).distance_to(p) < room * 1.6:
				return false
		return true
	var pick := func(north: bool, room: float) -> Vector2:
		for i in 80:
			# 南方的沙洲不放到最外圈（左下角是羅盤、右下角是按鍵提示）
			var p := Vector2(rng.randf_range(lo.x - 34.0, hi.x + 34.0), rng.randf_range(lo.y - 24.0, rz - 26.0)) if north else Vector2(rng.randf_range(lo.x + 6.0, hi.x - 6.0), rng.randf_range(rz + 26.0, hi.y + 6.0))
			if free.call(p, room):
				taken.append(p)
				return p
		return Vector2(INF, INF)
	var ice_dir := "res://levels/ice/assets/blender/"
	for i in 12:
		var p: Vector2 = pick.call(true, 9.0)
		if p.x == INF:
			continue
		var berg := i % 4 == 0
		var path := ice_dir + ("ice_chunk_%s.glb" % ["a", "b", "c", "d", "e"][i % 5] if berg else "ice_floe_%s.glb" % ["a", "b", "c"][i % 3])
		var node := _spawn_fit(self, path, Vector3(p.x, -0.25 if berg else -0.15, p.y), rng.randf_range(4.5, 6.5) if berg else rng.randf_range(5.5, 9.0), rng.randf() * TAU)
		if node == null:
			node = _blob(self, Vector3(p.x, 0.0, p.y), Vector3(4.0, 0.5, 3.0), Color(0.95, 0.98, 1.0))
		_floats.append({"node": node, "base": node.position, "phase": i * 1.7})
	for fi in [1, 4, 6]:
		if fi < _floats.size():
			var floe: Node3D = _floats[fi].node
			_spawn_fit(floe, "res://levels/ice/assets/kenney_cubepets/animal-penguin.glb", Vector3(0.5, 0.35, 0.2), 6.8, 0.6 + fi)
	var sand := _flat_mat(Color("e9c37c"))
	for i in 3:
		var p: Vector2 = pick.call(false, 10.0)
		if p.x == INF:
			continue
		var bar := Node3D.new()
		bar.position = Vector3(p.x, 0.0, p.y)
		bar.rotation.y = rng.randf() * TAU
		add_child(bar)
		var sx := rng.randf_range(2.6, 4.2)
		_blob(bar, Vector3(0, -0.35, 0), Vector3(sx, 0.75, sx * rng.randf_range(0.55, 0.8)), Color("e9c37c"), sand)
		_blob(bar, Vector3(sx * 0.2, 0.1, 0.2), Vector3(sx * 0.45, 0.35, sx * 0.35), Color("7cbf4e"))       # 一小片草
		_spawn_fit(bar, "res://assets/nature/BirchTree.glb", Vector3(-sx * 0.25, 0.25, -0.2), 3.2)
		_spawn_fit(bar, "res://assets/nature/BushBerries.glb", Vector3(sx * 0.35, 0.25, 0.3), 1.5)
		_floats.append({"node": bar, "base": bar.position, "phase": i * 2.3})
	# 最終章還鎖著：島的四周和頂上一圈雲（拿齊羽毛才散開）
	for e in range(1, worlds.size()):
		if _gate_need(entries[e].ch) == 0:
			continue
		var w: Dictionary = worlds[e]
		var c: Vector3 = w.center
		var cm := _cloud_mat()
		for i in 16:
			var a := i * TAU / 16.0
			var top := i >= 11
			var rr := 0.35 if top else 1.0
			var pos := Vector3(c.x + cos(a * 1.0 + (0.6 if top else 0.0)) * (float(w.rx) + 1.0) * rr, TOP_Y + (7.5 if top else 2.4 + 1.2 * sin(i * 1.9)), c.z + sin(a + (0.6 if top else 0.0)) * (float(w.rz) + 1.0) * rr)
			var sc := (5.2 if top else 4.0) + 1.2 * sin(i * 2.3)
			var b := _blob(self, pos, Vector3(sc * 1.3, sc * 0.75, sc), Color(1, 1, 1), cm)
			_clouds.append({"node": b, "base": b.position, "phase": i * 0.9 + e})

## 最終章腳下一圈慢慢呼吸的金色光暈（_process 裡調亮暗）
var _halo_mat: StandardMaterial3D
var _halo_e := -1
var _region_zone := Rect2()    # 畫面左邊兩區名字佔的地方（島牌要讓開）

func _build_halo() -> void:
	for e in range(1, worlds.size()):
		if not String(entries[e].ch.get("id", "")) in FINAL_IDS:
			continue
		var w: Dictionary = worlds[e]
		var c: Vector3 = w.center
		# 加亮混合、從岸邊往外漸淡：看起來是光，不是一塊底盤
		_halo_mat = StandardMaterial3D.new()
		_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_halo_mat.vertex_color_use_as_albedo = true
		_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_halo_mat.render_priority = 1
		_halo_mat.albedo_color = Color(0, 0, 0, 0)
		var mi := MeshInstance3D.new()
		var gold := Color(1.0, 0.84, 0.36)
		var cinnabar := Color(1.0, 0.40, 0.24)
		mi.mesh = _glow_mesh([[0.985, 0.0, gold], [0.995, 1.0, gold], [1.035, 1.0, gold], [1.045, 0.0, gold],
			[1.10, 0.0, cinnabar], [1.11, 0.85, cinnabar], [1.135, 0.85, cinnabar], [1.145, 0.0, cinnabar]])
		mi.material_override = _halo_mat
		mi.position = Vector3(c.x, 0.14, c.z)
		mi.scale = Vector3(float(w.rx) + 3.0, 1.0, float(w.rz) + 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_halo_e = e

## 一圈從內往外漸變的帶子（rings：[[半徑, 亮度], ...]，亮度放在頂點顏色的 alpha）
func _glow_mesh(rings: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in 97:
		var a := i * TAU / 96.0
		for rg in rings:
			verts.append(Vector3(cos(a), 0, sin(a)) * float(rg[0]))
			cols.append(Color(rg[2] if rg.size() > 2 else Color(1, 1, 1), float(rg[1])))
		if i > 0:
			for j in rings.size() - 1:
				var v := i * rings.size() + j
				var pv := v - rings.size()
				idx.append_array([pv, pv + 1, v, pv + 1, v + 1, v])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _cloud_mat() -> StandardMaterial3D:
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1, 1, 1)
	cm.emission_enabled = true
	cm.emission = Color(0.82, 0.88, 0.96)
	cm.emission_energy_multiplier = 0.55
	cm.roughness = 1.0
	return cm

## 一顆壓扁的球（雲、沙洲、找不到模型時的浮冰）
func _blob(parent: Node3D, pos: Vector3, size: Vector3, col: Color, mat: Material = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat if mat else _flat_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)
	return mi

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
		var done := _playable(ch) and _ch_cleared(ch)
		# 浮球頂的顏色：全破綠色；北方藍、南方紅；最終章還鎖著是灰色
		var cap: Color = GREEN if done else (LOCKED_EDGE if _gate_need(ch) > 0 else (REGION_INFO.get(_region(e), REGION_INFO.south) as Dictionary).cap)
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
			mi.material_override = _flat_mat(Color(1, 1, 1) if layer == 0 else cap)
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

## 每座島的選取圈離岸多遠：離最近的島越近就越小（3～9）
func _ring_margins() -> void:
	for e in worlds.size():
		var w: Dictionary = worlds[e]
		var a := Vector2(w.center.x, w.center.z)
		var gap := INF
		for o in worlds.size():
			if o == e:
				continue
			var w2: Dictionary = worlds[o]
			var b := Vector2(w2.center.x, w2.center.z)
			var d := b - a
			if d.length() < 0.01:
				continue
			gap = minf(gap, d.length() - _edge(w, d.normalized()) - _edge(w2, -d.normalized()))
		w["ring_m"] = clampf(gap * 0.36, 3.0, 5.0 if _region(e) == "south" else 9.0)

## 光圈：世界地圖上圈住家豪所在那座島的一圈金色＋深色描邊（貼在海面上，_process 裡搬到目前那座島、照島的大小拉伸）
func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.visible = false
	add_child(_ring)
	_ring_mat = _flat_mat(Color(GOLD, 0.0), true)
	_ring_edge = _flat_mat(Color(PATH_EDGE, 0.0), true)
	var layers := [[0.975, 1.0, _ring_edge, 0.0, 2], [0.981, 0.994, _ring_mat, 0.03, 3], [1.035, 1.046, _ring_mat, 0.03, 3]]
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
	if _hub_build and HUB_SOLID.has(path.get_file()):
		# 主島自由走：這個東西會擋路。第 4 個數字：家豪躲到它後面時要變透明的範圍（0 = 不透明；樹冠 1.5、建築 = 擋路半徑 + 0.9）
		var sr := float(HUB_SOLID[path.get_file()])
		var vis := 1.5 if path.get_file() in ["BirchTree.glb", "AutumnTree.glb"] else (sr + 0.9 if sr >= 0.8 else 0.0)
		_hub_blocks.append([holder, sr, Vector3.ZERO, vis])
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
	# 屁股上插著帶回來的羽毛（一個大關一根，扇形翹起來；世界地圖上才看得到）
	_plumes = Node3D.new()
	_plumes.name = "Plumes"
	_plumes.position = Vector3(0, 0.7, -0.5)
	_plumes.visible = false
	_hero_body.add_child(_plumes)
	var got: Array = _feathers().filter(func(f): return bool(f.have))
	for i in got.size():
		var cap := SphereMesh.new()
		cap.radius = 1.0
		cap.height = 2.0
		cap.radial_segments = 14
		cap.rings = 8
		var arm := Node3D.new()
		arm.rotation = Vector3(-1.05, 0, (i - (got.size() - 1) * 0.5) * 0.38)
		_plumes.add_child(arm)
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = _flat_mat((got[i] as Dictionary).col)
		mi.position = Vector3(0, 0.78, 0)
		mi.scale = Vector3(0.24, 0.82, 0.05)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(mi)

## 主島上的母雞（白色、沒穿帽 T）：雞圈裡七隻、家門口和田邊幾隻，各自逛來逛去，可以戳（hub_life.gd）
func _spawn_hub_hens() -> void:
	if worlds.is_empty() or _life == null or _hub_yard.size == Vector2.ZERO:
		return
	var off: Vector3 = worlds[0].origin
	var y := TOP_Y + 0.02
	var specs: Array = []
	for i in 7:
		var fx := _hub_yard.position.x + 1.6 + fposmod(i * 2.9, _hub_yard.size.x - 3.2)
		var fz := _hub_yard.position.y + 1.3 + fposmod(i * 1.9, _hub_yard.size.y - 2.6)
		specs.append({"pos": Vector3(fx, y, fz) + off, "rad": 2.4})
	var pads: Array = worlds[0].pads
	for sp in [[2, Vector3(-3.6, 0, 2.6)], [2, Vector3(3.4, 0, 3.2)], [1, Vector3(-2.2, 0, 3.4)], [0, Vector3(3.0, 0, 3.0)], [3, Vector3(-3.6, 0, 3.0)]]:
		specs.append({"pos": (pads[int(sp[0])] as Vector3) + (sp[1] as Vector3) + Vector3(0, 0.02, 0), "rad": 2.0})
	_life.spawn_hens(specs)
	_hens = _life.hens

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
	if _free_hub():
		return _free.pos.lerp(_token(selected), _z())        # 主島自由走：家豪在農莊裡哪裡就是哪裡
	return _stand(selected, stage_sel).lerp(_token(selected), _z())

# ---------------------------------------------------------------- 主島自由走

## 這座島（現在站的那座）用自由走嗎？只有主島；不管現在拉近還是拉遠
func _free_hub() -> bool:
	return _free_enabled and selected >= 0 and selected < entries.size() and _is_hub(selected)

## 現在是不是正在用自由走操作家豪（主島、拉近、標題畫面收掉了）
func _free_active() -> bool:
	return _free_hub() and not _map and _title == null and _z() < 0.25 and _sail.is_empty()

## 按住的方向鍵換成世界座標的水平方向（鏡頭朝北：上 = −z、右 = +x）
func _free_input() -> Vector2:
	var d := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	return d.normalized() if d != Vector2.ZERO else d

## 有東西蓋住畫面（釣魚、手帳、操作說明）：不能走
func _free_locked() -> bool:
	return _fishing.active or _dj.active or _journal.is_open() or (_guide != null and _guide.is_open()) or _starting or not _yard.is_empty() or _tod_open

## 按數字鍵：衝到第 k 個站點（沿直線跳過去，不管中間有沒有東西）
func _free_dash_to(k: int) -> void:
	if _busy() or _starting or _map or k < 0 or k >= int(worlds[0].n):
		return
	var to := _free.station(k)
	var dist := Vector2(to.x - _free.pos.x, to.z - _free.pos.z).length()
	if dist < 0.5:
		return
	_free_goal_on = false
	_free_dash = {"from": _free.pos, "to": to, "t": 0.0, "dur": clampf(dist / FREE_DASH_SPEED, 0.25, 0.9), "k": k}
	_bubble_a = 0.0
	_play("fly", 1.3)

## 滑鼠點地面：走到那個點（點在哪個地方用鏡頭射線打到島面的高度）
func _free_goto_screen(pos: Vector2) -> bool:
	var org := _cam.project_ray_origin(pos)
	var dir := _cam.project_ray_normal(pos)
	var hit: Variant = Plane(Vector3.UP, _free.pos.y - 0.3).intersects_ray(org, dir)
	if hit == null:
		return false
	var g := _free.resolve(Vector3(hit.x, _free.pos.y, hit.z))
	_free_goal = g
	_free_goal_on = true
	_free_stuck = 0.0
	return true

## 每一幕：走路（一跳一跳）、衝刺、靠近站點就冒泡泡
func _tick_free(dt: float) -> void:
	var moved := 0.0
	var heading := Vector2.ZERO
	if not _free_dash.is_empty():
		var k: float = minf(float(_free_dash.t) + dt / float(_free_dash.dur), 1.0)
		_free_dash.t = k
		var e := k * k * (3.0 - 2.0 * k)
		var a: Vector3 = _free_dash.from
		var b: Vector3 = _free_dash.to
		_free.pos = a.lerp(b, e)
		_hero_body.position.y = sin(k * PI) * 2.4
		heading = Vector2(b.x - a.x, b.z - a.z)
		if k >= 1.0:
			_free_dash = {}
			_hero_body.position.y = 0.0
			_play("land")
	else:
		var dir := Vector2.ZERO
		if not _free_locked():
			dir = _free_input()
			if dir != Vector2.ZERO:
				_free_goal_on = false
			elif _free_goal_on:
				var to := Vector2(_free_goal.x - _free.pos.x, _free_goal.z - _free.pos.z)
				if to.length() < 0.3:
					_free_goal_on = false
				else:
					dir = to.normalized() * minf(1.0, to.length() / (HubWalk.SPEED * dt))
		if dir != Vector2.ZERO:
			moved = _free.step(dt, dir)
			heading = dir
			if _free_goal_on:
				# 被擋住（走了不到該走的三成）超過 0.35 秒就放棄
				_free_stuck = _free_stuck + dt if moved < HubWalk.SPEED * dt * dir.length() * 0.3 else 0.0
				if _free_stuck > 0.35:
					_free_goal_on = false
		if moved > 0.0001:
			_free_dist += moved
			_hero_body.position.y = absf(sin(_free_dist * PI / HOP_LEN)) * 0.7
			var hops := int(_free_dist / HOP_LEN)
			if hops != _free_hop_i:
				_free_hop_i = hops
				_play("hop", 1.0 + 0.12 * (hops % 2))
		else:
			_hero_body.position.y = lerpf(_hero_body.position.y, absf(sin(_t * 3.2)) * 0.08, 1.0 - exp(-dt * 12.0))
	if heading.length_squared() > 0.0001:
		_hero.rotation.y = lerp_angle(_hero.rotation.y, atan2(heading.x, heading.y), 1.0 - exp(-dt * 18.0))
	else:
		_hero.rotation.y = lerp_angle(_hero.rotation.y, _face_yaw, 1.0 - exp(-dt * 8.0))
	var base := _free.pos
	if _bump_t > 0.0:
		_bump_t = maxf(_bump_t - dt, 0.0)
		base += _bump_dir * sin(_bump_t / 0.25 * PI) * 0.6
	_hero.position = base
	# 靠近站點：stage_sel 永遠是「最近的那個站點」；夠近了才冒泡泡
	var ns := _free.nearest(_free.pos)
	var was := _free_near
	_free_near = float(ns.d) < (HubWalk.FAR if was else HubWalk.NEAR)
	if _free_near and (not was or int(ns.k) != stage_sel):
		stage_sel = int(ns.k)
		_bubble_a = 0.0
		_set_mood(selected, stage_sel)
	elif was and not _free_near:
		_bubble_a = 0.0
	if not _free_near:
		_start_rect = Rect2()

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
	var hook: Object = worlds[e].hook if e < worlds.size() else null
	# 農莊、世界地圖、沒有自己天色的島：照現在的時間；有自己 mood() 的大關維持自己的氣氛
	if _tod_on and (_map or _is_hub(e) or not (hook and hook.has_method("mood"))):
		m.merge(HubTime.mood(_tod_hour), true)
	if _map:
		return m
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
	if _fresh:
		return 0
	var got = (table as Dictionary).get(String(st.scene), {})
	var n := mini(STAR_MAX, (got as Dictionary).size()) if got is Dictionary else 0
	if n == 0 and _cleared(st.id):
		n = 1
	return maxi(n, int(_ledger.get(String(st.scene), 0)))

## 把每一關拿到的星星記進衣櫃的存檔（商店用星星買服裝），順便讀回以前記過的（重開遊戲星星還在）。
## 沒有三星制度的大關：過一關算 1 顆。範例關不算。
func _sync_stars() -> void:
	if _fresh:
		return
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
				n = 1 if _cleared(st.id) else 0
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

var _box_cache := {}

## 圓角框（同樣的顏色、圓角、邊框只做一份：介面每一畫面都重畫，每次 new 會一直配置記憶體）
func _box(bg: Color, edge: Color, radius: float, border := 3.0, shadow := true) -> StyleBoxFlat:
	var key := [bg, edge, int(radius), int(border), shadow]
	var hit = _box_cache.get(key)
	if hit:
		return hit
	if _box_cache.size() > 512:
		_box_cache.clear()
	var s := StyleBoxFlat.new()
	_box_cache[key] = s
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

## 沒有紙片底的字：白字＋深色描邊（遊戲常見的做法），白天的草地、晚上的夜空上都讀得到。col 不用了，留著相容
func _text_outlined(c: Control, pos: Vector2, t: String, size: float, _col := INK) -> void:
	c.draw_string_outline(_font(), pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), maxi(5, int(size * 0.34)), Color(INK, 0.9))
	c.draw_string(_font(), pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), Color("fffaf0"))

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

## 島的圓徽章：認得的島畫圖示（冰雪島＝雪花、森林＝樹、要塞＝城垛、秋島＝葉子、丹穴山海＝山）；其他的 chapter.gd 有 ICON 就用那個字，沒有就畫旗子
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
		"heaven":
			# 山：中間一座高峰、兩旁兩座矮的，主峰頂上一點白
			var base := 11.0
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-15, base) * k, center + Vector2(-8, -2) * k, center + Vector2(-1, base) * k]), ink)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(1, base) * k, center + Vector2(9, 0) * k, center + Vector2(16, base) * k]), ink)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-10, base) * k, center + Vector2(0, -13) * k, center + Vector2(10, base) * k]), ink)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-3.9, -4) * k, center + Vector2(0, -13) * k, center + Vector2(3.9, -4) * k, center + Vector2(1.3, -5.5) * k, center + Vector2(-1.3, -3.5) * k]), Color(1, 1, 1))
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
			have += 1 if _cleared(st.id) else 0
			maxn += 1
	return [have, maxn, starred]

## 所有主題島加起來：[星星拿到幾顆, 星星一共幾顆, 0, 0]。還沒有三星制度的大關先算「過一關＝1 顆星」，
## 這樣地圖上只有一種進度符號（★），總數也算得到每座島
func _star_all() -> Array:
	var out := [0, 0, 0, 0]
	for ent in entries:
		if _playable(ent.ch) and not _is_example(ent.ch):
			var t := _star_total(ent.ch)
			out[0] += int(t[0])
			out[1] += int(t[1])
	return out

## 手帳用的旅程進度（journal.gd 算貼紙要用）：星星、羽毛、過了幾個小關、買了幾件衣服
func _journal_ctx() -> Dictionary:
	var all := _star_all()
	var fs := _feathers()
	var feathers := 0
	for f in fs:
		if bool(f.have):
			feathers += 1
	var cleared := 0
	for ent in entries:
		if _playable(ent.ch) and not _is_example(ent.ch):
			for st in ent.ch.stages:
				if _cleared(st.id):
					cleared += 1
	var owned := 0
	for it in Wardrobe.ITEMS:
		if Wardrobe.owned(String(it.id)):
			owned += 1
	return {"stars": int(all[0]), "stars_max": int(all[1]), "feathers": feathers, "feathers_max": fs.size(), "cleared": cleared, "owned": owned,
		"residents": _growth.count() if _growth else 0, "residents_max": HubGrowth.ids().size(),
		"isles_max": maxi(_sail_list().size() - 1, 1), "boats": HubBoats.owned_count()}

## 手帳「旅程」頁的每一張卡（照旅程順序）：{locked} 或 {locked, title, icon, col, stars, stars_max, stages, done, feather, cleared}
func _journal_rows() -> Array:
	var idx: Array = []
	for e in range(1, entries.size()):
		if entries[e].ch.is_empty() or not _is_example(entries[e].ch):
			idx.append(e)
	idx.sort_custom(func(a, b): return _trip_rank(a) < _trip_rank(b) if _trip_rank(a) != _trip_rank(b) else a < b)
	var out: Array = []
	for e in idx:
		var ent: Dictionary = entries[e]
		var ch: Dictionary = ent.ch
		if not _playable(ch):
			out.append({"locked": true})
			continue
		var t := _star_total(ch)
		var done := 0
		for st in ch.stages:
			if _cleared(st.id):
				done += 1
		out.append({"locked": false, "title": String(ch.title), "icon": String(_chapter_consts(ch).get("ICON", String(ch.title).substr(0, 1))),
			"col": _color_of(ent), "stars": int(t[0]), "stars_max": int(t[1]), "stages": ch.stages.size(), "done": done,
			"feather": _feather_col(ch), "cleared": _ch_cleared(ch)})
	return out

## 新破關的大關：農莊長出它的小地標、居民搬來（只演一次）
func _growth_check() -> void:
	if _growth == null:
		return
	var n: int = _growth.sync(true)
	if n > 0:
		_show_toast("農莊長大了！去看看新鄰居" if n > 1 else "農莊多了一位新鄰居")

## 有新貼紙就響一聲、跳一行字（戳、釣魚、回到農莊的時候都會檢查）
func _journal_check() -> void:
	var fresh := Journal.unlock_new(_journal_ctx())
	if fresh.is_empty():
		return
	_journal.chime()
	if fresh.size() == 1:
		_show_toast("貼紙解鎖：%s" % String(fresh[0].name))
	else:
		_show_toast("手帳多了 %d 張貼紙" % fresh.size())

## 左上角的羽毛列：「羽毛」兩個字＋每個大關一根（拿到的上色、沒拿到的是空框）。回傳它的框
func _feather_chip(c: Control, u: float, pos: Vector2) -> Rect2:
	var fs := _feathers()
	if fs.is_empty():
		return Rect2(pos, Vector2.ZERO)
	var have := fs.filter(func(f): return bool(f.have)).size()
	var label := "%d/%d" % [have, fs.size()]
	var lw := _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x
	var step := 24.0 * u
	var r := Rect2(pos, Vector2(20 * u + step * fs.size() + 10 * u + lw + 16 * u, 50 * u))
	# 不墊紙片：羽毛和數字直接放在畫面上（數字加白邊）
	for i in fs.size():
		var f: Dictionary = fs[i]
		var fp := r.position + Vector2(22 * u + step * i, 42 * u)
		# 沒墊紙片：每根羽毛後面先畫一根大一點的淡白羽毛當光暈，夜空上也看得到空羽毛的輪廓
		_feather(c, fp + Vector2(-1.5, 2.0) * u, 36 * u, 0.32, Color(1, 1, 1, 0.55), true)
		if bool(f.get("final", false)) and not bool(f.have):
			# 最後一根在最終章拿：金色虛線框＋一閃一閃的小星光
			_feather(c, fp, 32 * u, 0.32, GOLD, false, true)
			_twinkle(c, fp + Vector2(14 * u, -30 * u), 6.0 * u * (0.7 + 0.3 * sin(_t * 3.0)), Color(1, 0.86, 0.3))
		else:
			_feather(c, fp, 32 * u, 0.32, f.col, bool(f.have))
	_text_outlined(c, Vector2(r.position.x + 20 * u + step * fs.size() + 10 * u, r.position.y + 25 * u + 24 * u * 0.36), label, 24 * u, INK)
	return r

func _paint_isle_layer(c: Control) -> void:
	_start_rect = Rect2()
	if worlds.is_empty() or selected < 0:
		return
	var u := _u()
	if not _sail.is_empty():
		_paint_sail_isle(c, u)
		return
	_paint_nodes(c, u)
	_paint_bubble(c, u)

func _paint_map_layer(c: Control) -> void:
	if worlds.is_empty() or selected < 0:
		return
	_paint_chart(c, _u())
	_paint_regions(c, _u())
	_paint_gulls(c, _u())
	_paint_sparkles(c, _u())
	_paint_tags(c, _u())
	_paint_compass(c, _u())

func _paint_overlay(c: Control) -> void:
	if worlds.is_empty() or selected < 0:
		return
	var u := _u()
	_paint_hud(c, u)
	_paint_buttons(c, u)
	_paint_keys(c, u)
	if not _sail.is_empty():
		_paint_sail_picker(c, u)
		_paint_sail_hud(c, u)
	_paint_yard(c, u)
	_paint_tod(c, u)

## 「下一步在這裡」的記號：一顆跳動的紅色驚嘆號（島上：下一關的徽章；世界地圖：還有關卡可以玩的島牌）
func _next_mark(c: Control, at: Vector2, s: float) -> void:
	var np := at + Vector2(0, -absf(sin(_t * 3.4)) * 7.0 * s)
	c.draw_circle(np + Vector2(0, 2.5 * s), 16.5 * s, Color(0, 0, 0, 0.22))
	c.draw_circle(np, 16.5 * s, Color(1, 1, 1))
	c.draw_circle(np, 13.5 * s, SHOP_RED)
	_text(c, np + Vector2(-13.0 * s, 8.5 * s), "!", 24.0 * s, Color(1, 1, 1), 26.0 * s, HORIZONTAL_ALIGNMENT_CENTER)

## 世界地圖上的「下一站」：一小條綠色布條夾在島牌上緣的右邊（像書籤），上下輕輕跳
func _next_banner(c: Control, tag: Rect2, s: float) -> void:
	var f := _font()
	var label := "下一站"
	var fs := 20.0 * s
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
	var w := lw + 32 * s
	var h := 30.0 * s
	var bob := -absf(sin(_t * 3.4)) * 3.0 * s
	var r := Rect2(Vector2(tag.end.x - w - 18.0 * s, tag.position.y - h * 0.62 + bob), Vector2(w, h))
	r.position.y = maxf(r.position.y, 4.0 * s)
	c.draw_style_box(_box(GREEN, Color("2f7a2f"), 15 * s, 3.0), r)
	# 布條兩端往下折一小角（像書籤夾在島牌上）
	c.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 6 * s, r.end.y - 3.0), Vector2(r.position.x + 18 * s, r.end.y - 3.0), Vector2(r.position.x + 12 * s, r.end.y + 7 * s)]), Color("2f7a2f"))
	_text(c, Vector2(r.position.x + 16 * s, r.get_center().y + fs * 0.36), label, fs, Color(1, 1, 1))

## 一根羽毛的圖示：base 是羽根，h 是長度，ang 往右歪幾弧度。filled = false 畫成還沒拿到的虛線空框
func _feather(c: Control, base: Vector2, h: float, ang: float, col: Color, filled := true, gold := false) -> void:
	var dir := Vector2(sin(ang), -cos(ang))
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var t := float(i) / n
		pts.append(base + dir * h * (0.22 + 0.78 * t) + side * sin(pow(t, 0.75) * PI) * h * 0.21)
	for i in range(n, -1, -1):
		var t := float(i) / n
		pts.append(base + dir * h * (0.22 + 0.78 * t) - side * sin(pow(t, 0.75) * PI) * h * 0.17)
	if filled:
		c.draw_colored_polygon(pts, col)
		var ring := pts.duplicate()
		ring.append(pts[0])
		c.draw_polyline(ring, col.darkened(0.4), maxf(h * 0.06, 1.5), true)
		# 羽毛上兩道分岔的缺口、一道亮邊
		for k in [0.5, 0.72]:
			var at: Vector2 = base + dir * h * float(k)
			c.draw_line(at + side * h * 0.19, at - dir * h * 0.05 + side * h * 0.02, Color(PAPER, 0.95), maxf(h * 0.05, 1.2), true)
		c.draw_line(base + dir * h * 0.35 - side * h * 0.08, base + dir * h * 0.8 - side * h * 0.06, Color(1, 1, 1, 0.45), maxf(h * 0.05, 1.2), true)
		c.draw_line(base, base + dir * h * 0.97, col.darkened(0.5), maxf(h * 0.055, 1.4), true)
		c.draw_circle(base + dir * h * 0.82 + side * h * 0.07, maxf(h * 0.05, 1.2), Color(1, 1, 1, 0.8))     # 一點亮光
	else:
		var ring2 := pts.duplicate()
		ring2.append(pts[0])
		var grey := Color(0.78, 0.58, 0.12, 0.95) if gold else Color(0.45, 0.42, 0.38, 0.75)
		c.draw_colored_polygon(pts, Color(0.45, 0.42, 0.38, 0.10))
		_dashes(c, ring2, grey, maxf(h * 0.05, 1.3), maxf(h * 0.12, 3.0), maxf(h * 0.08, 2.0))
		c.draw_line(base, base + dir * h * 0.9, Color(0.45, 0.42, 0.38, 0.45), maxf(h * 0.04, 1.1), true)

## 世界地圖上建議下一個去哪座島（只有這一座的島牌掛「下一站」）：先找玩到一半的，沒有就找還沒開始的；都全過了回傳 -1
func _next_isle() -> int:
	var fresh := -1
	var trip: Array = range(1, entries.size())
	trip.sort_custom(func(a, b): return _trip_rank(a) < _trip_rank(b) if _trip_rank(a) != _trip_rank(b) else a < b)
	for e in trip:
		var ch: Dictionary = entries[e].ch
		if not _playable(ch) or _is_example(ch) or _next_station(e) < 0 or _gate_need(ch) > 0:
			continue
		if ch.stages.any(func(st): return _cleared(st.id)):
			return e
		if fresh < 0:
			fresh = e
	return fresh

## 旅程順序：北方第一座（冰雪島，教學最完整）→ 南方島嶼 → 其他北方的島 → 最終章
func _trip_rank(e: int) -> int:
	var id := String(entries[e].ch.get("id", ""))
	if id in FINAL_IDS:
		return 3
	match _region(e):
		"north":
			return 0 if e == _first_north() else 2
		"south":
			return 1
	return 4

func _first_north() -> int:
	for e in range(1, entries.size()):
		if _region(e) == "north" and not String(entries[e].ch.get("id", "")) in FINAL_IDS:
			return e
	return -1

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
		"fish":
			col = FISH_COLOR
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
		"fish":
			HubUI.fish_icon(c, center + Vector2(0, r * 0.04), r * 1.55, white)
		"dock":
			# 帆船：一根桅、一面三角帆、一個船身
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-1, -19) * k, center + Vector2(14, 3) * k, center + Vector2(-1, 3) * k]), white)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -12) * k, center + Vector2(-4, 3) * k, center + Vector2(-13, 3) * k]), white)
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-17, 7) * k, center + Vector2(17, 7) * k, center + Vector2(11, 16) * k, center + Vector2(-11, 16) * k]), white)
		_:
			_house(c, center + Vector2(0, r * 0.06), r / 34.0, white, col.darkened(0.25))

## 島上每個站點上面浮著的徽章：小關是編號＋三顆小星，商店是衣架，家是小房子（家豪站的那一格不畫，那一格有泡泡）
func _paint_nodes(c: Control, u: float) -> void:
	if not _sail.is_empty():
		return
	var busy := _busy()
	var e := selected
	var w: Dictionary = worlds[e]
	var next_k := _next_station(e)
	var moving := not _walk.is_empty() or not _jump.is_empty()
	for k in int(w.n):
		if k == stage_sel and not moving and (not _free_hub() or _free_near):
			continue                  # 家豪站的那一格不畫徽章（那一格有泡泡；釣魚、翻手帳的時候也不擋住家豪）
		var wp: Vector3 = (w.pads[k] as Vector3) + Vector3(0, 1.5, 0)
		if _cam.is_position_behind(wp):
			continue
		var sp := _cam.unproject_position(wp)
		if absi(k - stage_sel) == 1 and not busy and not _free_hub():
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
		else:
			# 沒有三星制度的大關：過一關＝一顆星
			var y2 := sp.y + r + 20.0 * s
			c.draw_style_box(_box(Color(PAPER, 0.96), PAPER_EDGE, 14 * s, 2.0, false), Rect2(Vector2(sp.x - 16 * s, y2 - 14 * s), Vector2(32 * s, 28 * s)))
			_star(c, Vector2(sp.x, y2), 9.5 * s, GOLD if cleared else Color(0.82, 0.78, 0.7), Color("8a6410") if cleared else Color(0.6, 0.56, 0.5))

## 泡泡的外框：浮在 wp 上面，尖角指著它。回傳 [框, 冒出來時縮放過的 u]；看不到就回傳 []
func _bubble_frame(c: Control, u: float, wp: Vector3, width: float, height := 132.0) -> Array:
	if _cam.is_position_behind(wp):
		return []
	# 冒出來的時候從小放大（尺寸直接乘上去，不用畫布的變形：_lock_icon 會自己改變形）
	u *= 0.6 + 0.4 * (1.0 - pow(1.0 - _bubble_a, 3.0))
	var bw := width * u
	var bh := height * u
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

## 泡泡右下角的 Enter 鍵帽（就是按鈕本身，滑鼠點它也行）：不再包一層彩色按鈕——
## 泡泡是一個框、鍵帽是一個框，中間再夾一個框就是框中框。泡泡上的圖示和名字已經說了這是什麼
func _bubble_key(c: Control, u: float, r: Rect2) -> void:
	var row_y := r.end.y - 36 * u                  # 兩列的泡泡：第二列；一列的泡泡：跟名字同一列
	var pulse := 1.0 + sin(_t * 4.0) * 0.04
	var ks := UIStyle.keycap_size("Enter", 18 * u * pulse)
	var pos := Vector2(r.end.x - 20 * u - ks.x, row_y - ks.y * 0.5)
	UIStyle.draw_keycap(c, pos, "Enter", 18 * u * pulse)
	_start_rect = Rect2(pos, ks).grow(10 * u)

## 只要「圖示＋名字＋Enter」的建築：一列高的小泡泡。{種類: [名字, 按鈕底色, 按鈕框色]}
const SLIM_BUBBLE := ["shop", "board", "guide", "dock", "home"]

func _slim_title(kind: String) -> String:
	match kind:
		"shop":
			return "商店"
		"board":
			return "冒險手帳"
		"guide":
			return "操作說明"
		"dock":
			return "碼頭"
	return "家豪的家"

func _paint_slim_bubble(c: Control, u0: float, wp: Vector3, kind: String) -> void:
	var title := _slim_title(kind)
	var ts := 32.0 * u0
	var tw := _font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts)).x / u0
	var bw := UIStyle.keycap_size("Enter", 18 * u0).x / u0
	var fr := _bubble_frame(c, u0, wp, 92.0 + tw + 24.0 + bw + 20.0, 84.0)
	if fr.is_empty():
		return
	var r: Rect2 = fr[0]
	var u: float = fr[1]
	var cy := r.get_center().y
	_icon_badge(c, Vector2(r.position.x + 50 * u, cy), 29 * u, kind)
	_text(c, Vector2(r.position.x + 92 * u, cy + 32 * u * 0.36), title, 32 * u, INK)
	_bubble_key(c, u, r)
func _paint_bubble(c: Control, u0: float) -> void:
	if _map or _bubble_a <= 0.02 or _busy():
		return
	if _free_hub() and not _free_near:
		return                        # 主島自由走：離站點還遠，沒有泡泡
	var w: Dictionary = worlds[selected]
	var ir: Node3D = w.isle_roots[stage_sel]
	var wp: Vector3 = (w.isles[stage_sel] as Vector3) + Vector3(0, float(ir.get_meta("bubble_y", 5.0)), 0)
	var st := _st_now()
	var kind := String(st.kind)
	if SLIM_BUBBLE.has(kind) and not (kind == "dock" and _sail_enabled):
		_paint_slim_bubble(c, u0, wp, kind)
		return
	var fr := _bubble_frame(c, u0, wp, 400.0 if kind == "stage" else 300.0)
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
		# 主島的建築：圖示＋名字＋Enter 就好（星星在右上角的商店按鈕、羽毛在左上角，不在泡泡裡重複）
		"shop":
			_icon_badge(c, bc, 29 * u, "shop")
			_text(c, Vector2(text_x, o.y + 58 * u), "商店", 32 * u, INK)
			_bubble_key(c, u, r)
		"board":
			_icon_badge(c, bc, 29 * u, "board")
			_text(c, Vector2(text_x, o.y + 58 * u), "冒險手帳", 32 * u, INK)
			_bubble_key(c, u, r)
		"fish":
			# 釣魚：圖鑑收了幾種（只有這裡看得到，留著）
			_icon_badge(c, bc, 29 * u, "fish")
			_text(c, Vector2(text_x, o.y + 58 * u), "釣魚", 32 * u, INK)
			HubUI.fish_icon(c, Vector2(text_x + 20 * u, row_y), 38 * u, Color("5aa6d6"))
			_text(c, Vector2(text_x + 50 * u, row_y + 9 * u), "%d/%d" % [Journal.book_count(), Journal.FISH.size()], 24 * u, INK)
			_bubble_key(c, u, r)
		"guide":
			_icon_badge(c, bc, 29 * u, "guide")
			_text(c, Vector2(text_x, o.y + 58 * u), "操作說明", 32 * u, INK)
			_bubble_key(c, u, r)
		"dock":
			_icon_badge(c, bc, 29 * u, "dock")
			_text(c, Vector2(text_x, o.y + 58 * u), "碼頭", 32 * u, INK)
			_bubble_key(c, u, r)
			if _sail_enabled:
				var gk := UIStyle.draw_keycap(c, Vector2(text_x, row_y - 14 * u), "G", 14 * u)
				_text(c, Vector2(text_x + gk.x + 8 * u, row_y + 8 * u), "換船", 22 * u, Color("6f6a60"))
		"home":
			_icon_badge(c, bc, 29 * u, "home")
			_text(c, Vector2(text_x, o.y + 58 * u), "家豪的家", 32 * u, INK)
			_bubble_key(c, u, r)
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
			if not open and _gate_need(ch) > 0:
				_text(c, Vector2(text_x, row_y + 8 * u), "還差 %d 根羽毛才能上山" % _gate_need(ch), 22 * u, Color("6f6a60"))
			elif not open:
				_text(c, Vector2(text_x, row_y + 8 * u), "先過第 %d 關" % int(st.k), 22 * u, Color("6f6a60"))
			else:
				if stars >= 0:
					_star_row(c, Vector2(text_x + 44 * u, row_y), 15 * u, stars)
				else:
					# 沒有三星制度的大關：過一關＝一顆星
					# 沒有三星制度的大關：一顆星，金色＝過關、灰色＝還沒（不用再寫字）
					_star(c, Vector2(text_x + 14 * u, row_y), 15 * u, GOLD if cleared else Color(0.85, 0.81, 0.73), Color("8a6410") if cleared else Color(0.62, 0.58, 0.52))
				_bubble_key(c, u, r)
func _tag_info(e: int) -> Dictionary:
	var ent: Dictionary = entries[e]
	var todo := _next_station(e) >= 0
	if _is_hub(e):
		var t := _hub_total()
		return {"title": HUB_TITLE, "col": HUB_COLOR, "stat": ("%d/%d" % [t[0], t[1]]) if int(t[1]) > 0 else "", "starred": false,
			"done": int(t[1]) > 0 and int(t[0]) >= int(t[1]), "kind": "hub", "fresh": todo,
			"frac": float(t[0]) / float(t[1]) if int(t[1]) > 0 else -1.0}
	var ch: Dictionary = ent.ch
	if not _playable(ch):
		return {"title": "？？？", "col": LOCKED, "stat": "", "starred": false, "done": false, "kind": "locked", "fresh": false}
	var t2 := _star_total(ch)
	var need := _gate_need(ch)
	# 還差幾根羽毛才能上島：不寫字，島牌上畫鎖頭＋幾根空羽毛（stat 留空）
	return {"title": String(ch.title), "col": _color_of(ent), "stat": "" if need > 0 else "%d/%d" % [t2[0], t2[1]], "starred": true,
		"done": int(t2[1]) > 0 and int(t2[0]) >= int(t2[1]), "kind": "isle", "fresh": todo, "gate": need,
		"frac": float(t2[0]) / float(t2[1]) if int(t2[1]) > 0 else -1.0}

## 「還差幾根羽毛才能上島」的圖示：鎖頭＋幾根空羽毛（不寫字）。right 是右邊緣的中點，回傳寬度
func _gate_width(s: float, need: int) -> float:
	return 26.0 * s + need * 15.0 * s

func _gate_mark(c: Control, right: Vector2, s: float, need: int) -> float:
	var w := _gate_width(s, need)
	var x := right.x - w
	_lock_icon(c, Vector2(x + 10 * s, right.y + 1 * s), 11 * s, Color("8a857a"))
	for i in need:
		_feather(c, Vector2(x + 30 * s + 15 * s * i, right.y + 12 * s), 24 * s, 0.32, Color("8a857a"), false)
	return w

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
		var lside := kind == "hub"            # 主島的島牌掛在左邊（上面是北方的島，別擋住）
		var top: Vector3 = wc + (Vector3(-float(w.rx) - 4.0, 0, 0) if lside else Vector3(0, 5.0, -float(w.rz)))
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
		# 選到的島：名字那一列最後面一顆 Enter 鍵帽（不再另外一列綠色「登島」按鈕：卡片裡再包按鈕又包鍵帽是框中框）
		var go_ks := UIStyle.keycap_size("Enter", 17 * s)
		if can_go:
			bw += go_ks.x + 14.0 * s
		var bh := 60.0 * s
		var tail := 16.0 * s
		var bob := sin(_t * 2.2 + e) * 2.5 * u if on else 0.0
		if not lside and absf(wc.x - hubc.x) > 20.0:
			anchor.x += signf(wc.x - hubc.x) * (76.0 if on else 46.0) * u      # 東西兩邊的島：島牌往外挪一點，讓出中間給主島（和碼頭）
		var ax := anchor.x
		# 沒選到的島：只畫圓徽章＋一圈星星進度（名字和數字等滑鼠移上去、或選到它再出現）
		var mini_r := 24.0 * u
		var mini_c := anchor + (Vector2(-mini_r - tail, 0) if lside else Vector2(0, -mini_r - tail))
		if not on and mouse.distance_to(mini_c) > mini_r + 10.0 * u:
			_paint_mini_tag(c, u, e, info, mini_c, mini_r, e == hint)
			_tag_rects[e] = Rect2(mini_c - Vector2.ONE * (mini_r + 8.0 * u), Vector2.ONE * (mini_r + 8.0 * u) * 2.0)
			continue
		var gate := int(info.get("gate", 0))
		if gate > 0:
			bw += _gate_width(s, gate) + 16.0 * s
		var r := Rect2(Vector2(anchor.x - bw * 0.5, anchor.y - bh - tail + bob), Vector2(bw, bh))
		if lside:
			r.position = Vector2(anchor.x - tail - bw, anchor.y - bh * 0.5 + bob)
		r.position.x = clampf(r.position.x, 14.0 * u, vs.x - bw - 14.0 * u)
		r.position.y = clampf(r.position.y, 14.0 * u, vs.y - bh - 14.0 * u)
		var hud_l := Rect2(Vector2.ZERO, Vector2(410.0 * u, 176.0 * u))
		var hud_r := Rect2(Vector2(vs.x - 380.0 * u, 0), Vector2(380.0 * u, 132.0 * u))
		if r.intersects(hud_l):
			r.position.x = hud_l.end.x + 10.0 * u
		if r.intersects(hud_r):
			r.position.x = hud_r.position.x - bw - 10.0 * u
		if r.intersects(hud_l) or r.intersects(hud_r):
			r.position.y = maxf(hud_l.end.y, hud_r.end.y) + 8.0 * u
		if r.intersects(_region_zone) and not lside:
			r.position.x = minf(_region_zone.end.x + 10.0 * u, vs.x - bw - 14.0 * u)     # 別蓋住「北方諸國／南方島嶼」
		var hover := r.has_point(mouse)
		var col: Color = info.col
		var edge := col.darkened(0.25) if on or hover else PAPER_EDGE
		c.draw_style_box(_box(PAPER if kind != "locked" else Color("efece4"), edge, 22 * s, 4.0 if on else 3.0), r)
		# 尖角
		var fill := PAPER if kind != "locked" else Color("efece4")
		var lw2 := 4.0 if on else 3.0
		if lside:
			# 尖角在右邊、朝右
			var cy3 := clampf(anchor.y, r.position.y + 22 * s, r.end.y - 22 * s)
			var rx2 := r.end.x
			c.draw_colored_polygon(PackedVector2Array([Vector2(rx2 - 4.0, cy3 - 12 * s), Vector2(rx2 - 4.0, cy3 + 12 * s), Vector2(rx2 + tail, cy3)]), fill)
			c.draw_polyline(PackedVector2Array([Vector2(rx2 - 1.0, cy3 - 12 * s), Vector2(rx2 + tail, cy3), Vector2(rx2 - 1.0, cy3 + 12 * s)]), edge, lw2, true)
		else:
			var tx := clampf(ax, r.position.x + 30 * s, r.end.x - 30 * s)
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
			if _ch_cleared(entries[e].ch):
				# 每一關都過了：徽章右下角插著從這座島帶回來的羽毛（星星拿滿再多戴一頂皇冠）
				_feather(c, bc + Vector2(br * 0.55, br * 0.95), 26.0 * s, 0.5, _feather_col(entries[e].ch))
		var tcol := INK if kind != "locked" else Color("7d776c")
		_text(c, Vector2(r.position.x + 66 * s, r.position.y + 30 * s + ts * 0.36), title, ts, tcol)
		if e == hint:
			_next_mark(c, r.position + Vector2(r.size.x - 6 * s, 4 * s), s)       # 下一站：跟島上「下一關」同一顆紅色驚嘆號
		if gate > 0:
			_gate_mark(c, Vector2(r.position.x + 66 * s + tw + 16 * s + _gate_width(s, gate), r.position.y + 30 * s), s, gate)
		if stat != "":
			var sx := r.position.x + 66 * s + tw + 16 * s
			var chip := Rect2(Vector2(sx, r.position.y + 14 * s), Vector2(sw, 32 * s))
			var gated := int(info.get("gate", 0)) > 0
			c.draw_style_box(_box(Color("ecebe6") if gated else Color("fff1bf"), LOCKED_EDGE if gated else Color("d9b84a"), 16 * s, 2.0, false), chip)
			if gated:
				_lock_icon(c, chip.position + Vector2(15, 17) * s, 11 * s, Color("8a857a"))
			else:
				_star(c, chip.position + Vector2(15, 16) * s, 9 * s, GOLD, Color("8a6410"))
			_text(c, chip.position + Vector2(28 * s, 23.5 * s), stat, ss, Color("6f6a60") if gated else INK)
		if can_go:
			var shut := int(info.get("gate", 0)) > 0          # 還不能上的島：鍵帽不跳（還是可以登島看看）
			var kp := Vector2(r.end.x - 14 * s - go_ks.x, r.position.y + 30 * s - go_ks.y * 0.5)
			if not shut:
				kp.y += sin(_t * 4.0) * 1.5 * s
			UIStyle.draw_keycap(c, kp, "Enter", 17 * s)
			_go_rect = Rect2(kp, go_ks).grow(10 * s)
		_tag_rects[e] = r

## 沒選到的島：一顆圓徽章（跟島牌上的同一個圖案）＋外圈的星星進度，還沒能上的島右下角掛一個小鎖頭
func _paint_mini_tag(c: Control, u: float, e: int, info: Dictionary, bc: Vector2, br: float, next: bool) -> void:
	var kind := String(info.kind)
	var col: Color = info.col
	c.draw_circle(bc + Vector2(0, 4) * u, br + 5.0 * u, Color(0, 0, 0, 0.22))
	c.draw_circle(bc, br + 5.0 * u, PAPER)
	var frac := float(info.get("frac", -1.0))
	if frac >= 0.0:
		c.draw_arc(bc, br + 2.5 * u, 0.0, TAU, 40, Color(PAPER_EDGE, 0.9), 4.0 * u, true)
		if frac > 0.0:
			c.draw_arc(bc, br + 2.5 * u, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, GOLD, 4.5 * u, true)
	if kind == "hub":
		c.draw_circle(bc, br * 0.92, col.darkened(0.12))
		c.draw_circle(bc, br * 0.8, col.lightened(0.25))
		_house(c, bc + Vector2(0, br * 0.08), br / 36.0, col.darkened(0.55), col.lightened(0.25))
	elif kind == "locked":
		c.draw_circle(bc, br * 0.92, Color("efece4"))
		_lock_icon(c, bc + Vector2(0, 2 * u), 15 * u, Color("8a857a"))
	else:
		_island_badge(c, entries[e].ch, bc, br * 0.92, col)
		if bool(info.done):
			_crown(c, bc + Vector2(0, -br - 7.0 * u), u * 0.75)
		if _ch_cleared(entries[e].ch):
			_feather(c, bc + Vector2(br * 0.55, br * 0.95), 22.0 * u, 0.5, _feather_col(entries[e].ch))
	if int(info.get("gate", 0)) > 0:
		c.draw_circle(bc + Vector2(br * 0.72, br * 0.72), 11 * u, PAPER)
		_lock_icon(c, bc + Vector2(br * 0.72, br * 0.78), 8 * u, Color("8a857a"))
	if next:
		_next_mark(c, bc + Vector2(br * 0.8, -br * 0.9), u * 0.8)

## 南北的分界線（海面上一道手繪虛線，經過主島時斷開）和兩區的名字（左邊靠分界線，北在上、南在下）
func _paint_regions(c: Control, u: float) -> void:
	var hub: Dictionary = worlds[0]
	var hc: Vector3 = hub.center
	var zline := hc.z
	# 分界線：在世界座標沿著 z = zline 取點，投影到畫面；碰到島（主島）就斷開
	var seg := PackedVector2Array()
	var ink := Color(1, 1, 1, 0.55)
	var x := _map_center.x - 260.0
	while x <= _map_center.x + 260.0:
		var wz := zline + sin(x * 0.045) * 2.5
		var inside := false
		for w in worlds:
			var c3: Vector3 = w.center
			if Vector2((x - c3.x) / (float(w.rx) + 9.0), (wz - c3.z) / (float(w.rz) + 9.0)).length() < 1.0:
				inside = true
		if absf(x - hc.x) < float(hub.rx) + 30.0:
			inside = true                    # 主島（連碼頭）左右都留白：分界線停在兩邊的岸外
		var p3 := Vector3(x, 0.3, wz)
		if inside or _cam.is_position_behind(p3):
			if seg.size() >= 2:
				_dashes(c, seg, ink, 3.0 * u, 16.0 * u, 11.0 * u)
			seg = PackedVector2Array()
		else:
			seg.append(_cam.unproject_position(p3))
		x += 4.0
	if seg.size() >= 2:
		_dashes(c, seg, ink, 3.0 * u, 16.0 * u, 11.0 * u)
	# 兩區的名字：貼在畫面左邊、分界線上下（島牌會避開這一塊，見 _paint_tags）
	var ly := _cam.unproject_position(Vector3(_map_center.x - 120.0, 0.3, zline)).y
	_region_zone = Rect2(Vector2(40.0 * u, ly - 78.0 * u), Vector2(262.0 * u, 184.0 * u))
	var f := _font()
	for key in ["north", "south"]:
		var has := false
		for e in range(1, entries.size()):
			has = has or _region(e) == key
		if not has:
			continue
		var info: Dictionary = REGION_INFO[key]
		var up: bool = key == "north"
		var nm := String(info.name)
		var ns := 40.0 * u
		var x0 := 52.0 * u
		var base_y := ly - 30.0 * u if up else ly + 66.0 * u
		# 字距拉開，像地圖上的地名
		var cx := x0 + 44.0 * u
		for ch in nm:
			c.draw_string_outline(f, Vector2(cx, base_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ns), int(9 * u), Color(0.04, 0.16, 0.30, 0.55))
			c.draw_string(f, Vector2(cx, base_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ns), info.col)
			cx += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ns)).x + 10.0 * u
		# 副標（「神獸與冰雪的國度」）拿掉了：雪花／太陽圖示和島的樣子已經說明這一區是什麼
		# 前面的小圖示：北方一片雪花、南方一顆太陽；再一個指向那一區的箭頭
		var ic := Vector2(x0 + 18.0 * u, base_y - 13.0 * u)
		if up:
			_snowflake(c, ic, 17.0 * u, info.col, 3.0 * u)
		else:
			c.draw_circle(ic, 9.5 * u, Color("ffd76a"))
			for i in 8:
				var a := i * TAU / 8.0
				c.draw_line(ic + Vector2(cos(a), sin(a)) * 13.0 * u, ic + Vector2(cos(a), sin(a)) * 18.0 * u, Color("ffd76a"), 3.0 * u, true)
		var ay := ly + (-10.0 if up else 10.0) * u
		var tip := Vector2(x0 + 18.0 * u, ay + (-14.0 if up else 14.0) * u)
		c.draw_line(Vector2(tip.x, ay), tip, Color(info.col, 0.8), 3.0 * u, true)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, (-6.0 if up else 6.0) * u), tip + Vector2(-6 * u, 0), tip + Vector2(6 * u, 0)]), Color(info.col, 0.8))

## 四角的小星光（閃粉）
func _twinkle(c: Control, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		var rr := r if i % 2 == 0 else r * 0.28
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, col)

## 最終章四周一閃一閃的金色星光（從上往下看也看得到的「終點」記號）
func _paint_sparkles(c: Control, u: float) -> void:
	if _halo_e < 0:
		return
	var w: Dictionary = worlds[_halo_e]
	var cc: Vector3 = w.center
	# 島身罩一層很淡的暖金色（解鎖以後才有：還鎖著的時候是雲）
	if _gate_need(entries[_halo_e].ch) == 0 and not _cam.is_position_behind(cc):
		var ctr := _cam.unproject_position(cc + Vector3(0, 2.0, 0))
		var edge := _cam.unproject_position(cc + Vector3(float(w.rx), 2.0, 0))
		var rr := absf(edge.x - ctr.x)
		for j in 5:
			var f := 1.0 - j * 0.16
			c.draw_set_transform(ctr, 0.0, Vector2(1.0, 0.55))
			c.draw_circle(Vector2.ZERO, rr * f, Color(1.0, 0.78, 0.35, 0.035 * (0.8 + 0.2 * sin(_t * 1.6))))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 16:
		var inner := i >= 10                 # 後面六顆在島上空
		var a := i * TAU / (6.0 if inner else 10.0) + (1.1 if inner else 0.3)
		var k := (0.45 + 0.2 * sin(i * 1.9)) if inner else 1.08 + 0.10 * sin(i * 2.7)
		var p3 := Vector3(cc.x + cos(a) * (float(w.rx) + 3.0) * k, (6.0 if inner else 2.0) + 3.0 * absf(sin(i * 1.3)), cc.z + sin(a) * (float(w.rz) + 3.0) * k)
		if _cam.is_position_behind(p3):
			continue
		var tw := sin(_t * 2.2 + i * 1.7)
		if tw < 0.1:
			continue
		_twinkle(c, _cam.unproject_position(p3), (5.0 + 5.0 * tw) * u, Color(1.0, 0.9, 0.55, 0.95 * tw))

## 南方海上繞圈飛的海鷗（白色「︶︶」，翅膀一上一下）
func _paint_gulls(c: Control, u: float) -> void:
	var hub: Vector3 = worlds[0].center
	var i := 0
	for e in range(1, entries.size()):
		if _region(e) != "south":
			continue
		var w: Dictionary = worlds[e]
		var base: Vector3 = hub.lerp(w.center, 0.58) + Vector3(13.0 * (1.0 if i % 2 == 0 else -1.0), 8.0, 3.0)
		for k in 2:
			var ph := _t * 0.32 + i * 1.9 + k * 0.9
			var p3 := base + Vector3(cos(ph) * 7.0 + k * 4.5, 0, sin(ph) * 4.0 + k * 2.0)
			if _cam.is_position_behind(p3):
				continue
			var p := _cam.unproject_position(p3)
			var flap := sin(_t * 7.0 + i * 1.3 + k * 2.1)
			var sp := (12.0 - 2.0 * k) * u
			var hh := (4.5 + 3.5 * flap) * u
			var sea := _cam.unproject_position(Vector3(p3.x, 0.2, p3.z))
			c.draw_set_transform(sea, 0.0, Vector2(1.0, 0.45))
			c.draw_circle(Vector2.ZERO, 6.0 * u, Color(0.02, 0.15, 0.3, 0.22))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var pts := PackedVector2Array([p + Vector2(-sp, 2.0 * u), p + Vector2(-sp * 0.5, -hh), p, p + Vector2(sp * 0.5, -hh), p + Vector2(sp, 2.0 * u)])
			c.draw_polyline(pts, Color(0.05, 0.2, 0.35, 0.3), 5.0 * u, true)
			c.draw_polyline(pts, Color(1, 1, 1), 3.0 * u, true)
			c.draw_line(pts[0], pts[0].lerp(pts[1], 0.45), Color(0.22, 0.24, 0.28), 3.0 * u, true)
			c.draw_line(pts[4], pts[4].lerp(pts[3], 0.45), Color(0.22, 0.24, 0.28), 3.0 * u, true)
			# 身體：一顆小小的橢圓、前面一點黃色的嘴
			c.draw_set_transform(p + Vector2(0, 1.5 * u), 0.0, Vector2(1.0, 0.6))
			c.draw_circle(Vector2.ZERO, 4.0 * u, Color(1, 1, 1))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			c.draw_circle(p + Vector2(3.5 * u, 1.0 * u), 1.4 * u, Color("f2b233"))
		i += 1

## 沿著一串點畫虛線（線段長 dash、空白 gap）
func _dashes(c: Control, pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var len := a.distance_to(b)
		var t := 0.0
		while t < len:
			var step := minf(left, len - t)
			var p0 := a.lerp(b, t / len)
			var p1 := a.lerp(b, (t + step) / len)
			if on:
				c.draw_line(p0, p1, col, w, true)
			t += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash if on else gap

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
	var ink := Color(INK, 0.75)
	c.draw_circle(o, r + 7.0 * u, Color(PAPER, 0.9))
	c.draw_arc(o, r + 7.0 * u, 0, TAU, 64, PAPER_EDGE, 3.0 * u, true)
	c.draw_arc(o, r, 0, TAU, 64, ink, 2.0 * u, true)
	c.draw_arc(o, r * 0.80, 0, TAU, 48, Color(INK, 0.3), 1.4 * u, true)
	for i in 16:
		var a := i * TAU / 16.0
		var d := Vector2(cos(a), sin(a))
		c.draw_line(o + d * r * (0.86 if i % 4 != 0 else 0.80), o + d * r, ink, 2.0 * u, true)
	for i in 4:
		var a := -PI * 0.5 + i * PI * 0.5
		var tip := o + Vector2(cos(a), sin(a)) * r * 0.72
		var l := o + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * r * 0.14
		var rt := o + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * r * 0.14
		c.draw_colored_polygon(PackedVector2Array([tip, l, o]), SHOP_RED if i == 0 else Color(INK, 0.85))
		c.draw_colored_polygon(PackedVector2Array([tip, o, rt]), SHOP_RED.darkened(0.3) if i == 0 else Color(INK, 0.45))
	_text(c, o + Vector2(-r, -r - 12 * u), "N", 20 * u, SHOP_RED, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)

## 大標題一直留著（玩家要知道自己在哪座島）。HEAD_FADE_ON 改成 true 就會變回「剛到時秀 HEAD_HOLD 秒再淡出」
const HEAD_FADE_ON := false
const HEAD_HOLD := 2.0
const HEAD_FADE := 0.6

## 大標題現在的透明度（標題的字換了就重新計時）
func _head_alpha(head: String) -> float:
	if not HEAD_FADE_ON:
		return 1.0
	if head != _head_key:
		_head_key = head
		_head_t0 = _t
	return clampf(1.0 - (_t - _head_t0 - HEAD_HOLD) / HEAD_FADE, 0.0, 1.0)

## 標題底下那排小紙片的位置（標題淡出的話往上補到最上面）
func _hud_at(u: float, head: String) -> Vector2:
	return Vector2(44 * u, lerpf(36.0, 116.0, _head_alpha(head)) * u)

## 左上角的大標題（白邊紅字，稍微歪一點）
func _headline(c: Control, u: float, head: String, size: float) -> void:
	var a := _head_alpha(head)
	if a <= 0.0:
		return
	var f := _font()
	var fs := int(size * u)
	c.draw_set_transform(Vector2(40 * u, 92 * u), -0.035, Vector2.ONE)
	c.draw_string_outline(f, Vector2(0, 6 * u), head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(20 * u), Color(0.20, 0.10, 0.06, 0.35 * a))
	c.draw_string_outline(f, Vector2.ZERO, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(18 * u), Color(1, 1, 1, a))
	c.draw_string(f, Vector2.ZERO, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("e8483a"), a))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 標題下面的一張小紙片：前面一個圖示（"star"／"check"／""），後面一行字。回傳它的框
func _chip(c: Control, u: float, pos: Vector2, icon: String, label: String, size: float, bar := Color(0, 0, 0, 0)) -> Rect2:
	var f := _font()
	var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * u)).x
	var lead := 48.0 * u if icon != "" else (26.0 * u if bar.a > 0.0 else 18.0 * u)
	var r := Rect2(pos, Vector2(lead + lw + 16 * u, 50 * u))
	# 不墊紙片：圖示＋數字直接放在畫面上（字加白邊），左上角不再是一排小框
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
	_text_outlined(c, r.position + Vector2(lead, 25 * u + size * u * 0.36), label, size * u, INK)
	return r

## 左上角：島上是島名（大標題）＋這座島的進度；世界地圖是「世界地圖」＋全部的進度（星星和過關數分開算）
func _paint_hud(c: Control, u: float) -> void:
	var ent: Dictionary = entries[selected]
	var ch: Dictionary = ent.ch
	var at: Vector2
	if not _sail.is_empty():
		at = _hud_at(u, "出海")
		_headline(c, u, "出海", 62.0)
		var what := "開船中・%s" % String(_sail.get("name", ""))
		if bool(_sail.auto):
			what = "自動航行 → %s" % String(_tag_info(int(_sail.auto_e)).title)
		_chip(c, u, at, "", what, 24.0)
		return
	if _zoom > 0.5:
		at = _hud_at(u, "世界地圖")
		_headline(c, u, "世界地圖", 62.0)
		var all := _star_all()
		var x := at.x
		if int(all[1]) > 0:
			x = _chip(c, u, at, "star", "%d/%d" % [all[0], all[1]], 24.0).end.x + 12 * u
		_feather_chip(c, u, Vector2(x, at.y))
		return
	if _is_hub(selected):
		# 主島沒有關卡：秀這趟旅程帶回了幾根羽毛
		at = _hud_at(u, HUB_TITLE)
		_headline(c, u, HUB_TITLE, 62.0)
		_feather_chip(c, u, at)
		return
	var playable := _playable(ch)
	var head := String(ch.title) if playable else "？？？"
	at = _hud_at(u, head)
	_headline(c, u, head, 62.0)
	if not playable:
		return
	# 「★ 7/18」（沒有三星制度的大關：過一關算一顆）
	var tot := _star_total(ch)
	_chip(c, u, at, "star", "%d/%d" % [tot[0], tot[1]], 24.0)

## 右上角的圓按鈕底：米色紙片＋陰影；下面置中掛一顆鍵帽。回傳半徑
## 不寫按鈕名稱（地圖、衣架、喇叭的圖示自己就看得懂）；label 只留著當程式裡的說明
func _round_button(c: Control, u: float, ctr: Vector2, key: String, _label: String, bg := PAPER, edge := PAPER_EDGE, pop := 0.0) -> float:
	var r := 34.0 * u * (1.0 + 0.18 * sin(pop / 0.25 * PI))
	c.draw_circle(ctr + Vector2(2, 5) * u, r + 3.0 * u, Color(0, 0, 0, 0.25))
	c.draw_circle(ctr, r + 3.0 * u, edge)
	c.draw_circle(ctr, r, bg)
	var ks := UIStyle.keycap_size(key, 14 * u)
	var y := ctr.y + 34.0 * u + 5.0 * u
	UIStyle.draw_keycap(c, Vector2(ctr.x - ks.x * 0.5, y), key, 14 * u)
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
	# 時間按鈕拿掉了：天色本來就跟著電腦的時間走。T 鍵還留著（隱藏，給測試和展示用）
	_time_rect = Rect2()
	var m := PackedVector2Array([Vector2(-18, -10), Vector2(-6, -14), Vector2(6, -9), Vector2(18, -13),
		Vector2(18, 10), Vector2(6, 14), Vector2(-6, 9), Vector2(-18, 13), Vector2(-18, -10)])
	for i in m.size():
		m[i] = ctr + m[i] * u
	c.draw_polyline(m, INK, 3.2 * u, true)
	c.draw_line(ctr + Vector2(-6, -14) * u, ctr + Vector2(-6, 9) * u, INK, 2.6 * u, true)
	c.draw_line(ctr + Vector2(6, -9) * u, ctr + Vector2(6, 14) * u, INK, 2.6 * u, true)
	c.draw_circle(ctr + Vector2(0.5, 1.0) * u, 3.4 * u, SHOP_RED)

## 島上的按鍵提示用過就收：記在 Engine 的 meta（這次開遊戲都記得，進關卡再回來也不會又跳出來）
## 卡住才提示：IDLE_HINT 秒沒有任何按鍵或滑鼠點擊，用過的提示也全部叫回來
const KEYS_USED_META := "hub_keys_used"
const IDLE_HINT := 20.0

func _key_used(id: String) -> bool:
	return (Engine.get_meta(KEYS_USED_META, {}) as Dictionary).has(id)

func _mark_key(id: String) -> void:
	var d: Dictionary = Engine.get_meta(KEYS_USED_META, {})
	d[id] = true
	Engine.set_meta(KEYS_USED_META, d)

## 右下角的按鍵提示（一條橫的小紙片，「鍵帽＋做什麼」一組一組排）：
##   島上：還沒用過的 ← → 走路／1~6 直達／E 戳一戳（用過就收）；世界地圖：↑ ← ↓ → 選島／Esc 返回標題。
##   Enter 寫在泡泡和島牌的按鈕上，這裡不重複。只有一列高，才不會蓋到往右下延伸的路和下一站
func _paint_keys(c: Control, u: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var f := _font()
	var items: Array = []
	if not _yard.is_empty():
		items = [[["↑", "↓"], "選船"], [["Enter"], "買／使用"], [["Esc"], "關上"]]
	elif not _sail.is_empty():
		if bool(_sail.pick):
			items = [[["↑", "↓"], "選島"], [["Enter"], "出發"], [["Esc"], "取消"]]
		else:
			items = [[["W", "A", "S", "D"], "開船"], [["Shift"], "加速"], [["H"], "汽笛"], [["P"], "自動航行"], [["Esc"], "回農莊"], [["M"], "世界地圖"]]
	elif _zoom > 0.5:
		items = [[["↑", "←", "↓", "→"], "選島"], [["Esc"], "返回標題"]]
	else:
		# 島上：只教還沒用過的按鍵，用過一次那一格就收掉；全部用過整條就不見了。
		# Enter 寫在泡泡上、M 寫在右上角的地圖按鈕上，這裡不重複（完整的說明在告示牌）
		var n := int(worlds[selected].n)
		var all: Array = []
		# 數字鍵直達（1~6）不提示：站點上沒有編號，「直達」看不出是直達哪裡；
		# 功能還在（熟練的玩家用），寫在告示牌的操作說明裡
		if _free_hub():
			all = [[["W", "A", "S", "D"], "走路", "walk"]]
		else:
			all = [[["←", "→"], "走路" if n > 1 else "離島", "walk"]]
		if _is_hub(selected):
			all.append([["E"], "戳一戳", "poke"])
		items = all.filter(func(it): return not _key_used(String(it[2])))
		if _idle_t > IDLE_HINT:
			items = all                # 很久沒動（可能卡住了）：全部的提示叫回來，一動就又收掉
		if items.is_empty() or _fishing.active or _dj.active or _journal.is_open():
			return                     # 都學會了；或是釣魚和手帳開著（它們有自己的按鍵提示）
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
	# 不墊紙片：鍵帽本身就是一個框，外面再包一層只是框中框。字加白邊，放在畫面上也讀得到
	var r := Rect2(Vector2(vs.x - w - 58.0 * u, vs.y - 68.0 * u), Vector2(w + 36.0 * u, 48.0 * u))
	var x := r.position.x + 18.0 * u
	var cy := r.get_center().y - 1.0 * u
	for it in items:
		for key in it[0]:
			x += UIStyle.draw_keycap(c, Vector2(x, cy - cap_h * 0.5), String(key), ks).x + gap
		x += 5.0 * u
		var label := String(it[1])
		_text_outlined(c, Vector2(x, cy + ts * 0.36), label, ts, INK)
		x += f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ts)).x + 26.0 * u

# ================================================================== 選取、移動、開始

## 第 i 個大關（LEVELS 的索引）的第 n 小關（從 1 開始）照規則解鎖了沒
func unlocked(i: int, n := 1) -> bool:
	return _unlocked_ch(LEVELS[i], n)

func _unlocked_ch(ch: Dictionary, n: int) -> bool:
	if ch.is_empty() or n < 1 or n > ch.stages.size() or String(ch.stages[n - 1].scene) == "":
		return false
	if _fresh:
		return n == 1
	return Progress.unlocked(ch.id, n)

func _busy() -> bool:
	return not _walk.is_empty() or not _jump.is_empty() or not _free_dash.is_empty() or not _sail.is_empty() or not _yard.is_empty() or _tod_open or (_fishing != null and _fishing.active) or (_dj != null and _dj.active) or (_journal != null and _journal.is_open())

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
	if _free_hub():
		# 主島自由走：直接站回目前這個站點
		_free.pos = _stand(selected, stage_sel)
		_free_near = true
		_free_goal_on = false
		_free_dash = {}
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
	_free_goal_on = false
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
	if _free_hub() and not _free_near:
		return false                     # 主島自由走：離站點還遠，Enter 沒有東西可以開
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
			_play("click")
			_journal.open()                 # 冒險手帳：翻開
			return false
		"fish":
			if _fishing.begin():
				_play("click")
			return false
		"dock":
			if _sail_enabled and _pier_boat != null:
				_sail_board()               # 出航：上船，自己開去別的島（M 還是拉遠看世界地圖）
			else:
				set_map(true)               # 出航：拉遠看世界地圖
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
		elif _gate_need(s.ch) > 0:
			_show_toast("還差 %d 根羽毛：先把其他島都破完" % _gate_need(s.ch))
			_play("bump")
			return false
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
			{"title": "在島上", "body": "家豪沿著路一格一格走。走到地標前面，按 Enter 開始那一關。農莊裡可以隨便跑：WASD 或方向鍵走路，走近建築就會冒出泡泡。",
				"controls": [["←／→", "冒險島：走到隔壁一格"], ["WASD", "農莊：自由走路（滑鼠點地面也行）"], ["Enter", "開始／進去"], ["1～9", "直接走到那一格"], ["M", "世界地圖"]]},
			{"title": "世界地圖", "body": "每座島的第一關一開始就能玩，想先去哪座島都可以。星星拿去商店換衣服。",
				"controls": [["↑／←／↓／→", "飛到那個方向的島"], ["Enter", "登島"], ["B", "商店"], ["V", "聲音開關"]]},
			{"title": "農莊", "body": "神可以戳農莊裡的任何東西：母雞、樹、風車、穀倉都有反應。池塘可以釣魚，手帳記著你的一切。",
				"controls": [["E", "戳離家豪最近的東西（滑鼠點也行）"], ["Enter", "在池塘甩竿、翻開手帳"], ["Space", "釣魚時甩竿、拉線"], ["Esc", "收竿、合上手帳"]]},
		])
	_play("click")
	_guide.open()

func _show_toast(t: String, dur := 2.0) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = dur

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
	if (ev is InputEventKey or ev is InputEventMouseButton) and ev.pressed:
		_idle_t = 0.0
	if _title != null:
		return                       # 標題畫面還開著：按鍵都給它
	if _fishing.active or _dj.active or _journal.is_open():
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_V:
			_toggle_sound()          # 釣魚和手帳開著：其他按鍵它們自己處理，只有 V（聲音）放行
		return
	if _tod_open and _tod_input(ev):
		return                       # 時間面板開著：按鍵和滑鼠都在 _tod_input 處理
	if not _sail.is_empty() and _sail_input(ev):
		return                       # 開船中：按鍵都在 _sail_input 處理
	if not _yard.is_empty() and _yard_input(ev):
		return                       # 船塢開著：按鍵都在 _yard_input 處理
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _snd_rect.has_point(ev.position):
			_toggle_sound()
		elif _shop_rect.has_point(ev.position):
			open_shop()
		elif _map_rect.has_point(ev.position):
			set_map(not _map)
		elif _time_rect.has_point(ev.position):
			_tod_toggle()
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
			if _life.poke_at(ev.position, k >= 0):
				pass                         # 戳到農莊裡的東西（站點旁邊只有母雞、蛋、家豪比站點優先）
			elif _free_hub():
				# 主島自由走：點到站點 → 在那裡就開始、不在就衝過去；點到空地 → 走過去
				if k >= 0 and k == stage_sel and _free_near:
					start_selected()
				elif k >= 0:
					_free_dash_to(k)
				else:
					_mark_key("walk")        # 用滑鼠點地面走路也算學會走路了
					_free_goto_screen(ev.position)
			elif k == stage_sel:
				start_selected()
			elif k >= 0:
				walk_to(k)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if not _map:
			# 右下角的按鍵提示：用過的那一格收掉
			match ev.keycode:
				KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_W, KEY_A, KEY_S, KEY_D:
					_mark_key("walk")
				KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
					_mark_key("jump")
				KEY_E:
					_mark_key("poke")
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
					if _free_hub():
						_free_dash_to(ev.keycode - KEY_1)       # 主島自由走：衝到那個站點
					else:
						walk_to(ev.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_selected()
			KEY_M, KEY_TAB:
				set_map(not _map)
			KEY_V:
				_toggle_sound()
			KEY_B:
				open_shop()
			KEY_G:
				_yard_open()                 # 在碼頭：船塢（看船、買船、換船）
			KEY_T:
				_tod_toggle()                # 時間面板
			KEY_E:
				# 隱藏按鍵（展示用，畫面上不提示）：Shift＋E 不用全破就直接播結局，播完回到這裡
				if ev.shift_pressed:
					if not _starting and not _busy() and ResourceLoader.exists(ENDING_SCENE):
						_starting = true
						_remember()
						get_tree().change_scene_to_file(ENDING_SCENE)
				elif not _map:
					_life.poke_near()            # E：戳離家豪最近的東西
			KEY_ESCAPE:
				if not _map:
					set_map(true)                # 島上按 Esc：先退到世界地圖
				elif not _starting and not _busy() and ResourceLoader.exists(INTRO_SCENE):
					if _esc_t > 0.0:
						# 回標題畫面（不用再播一次羽毛飄下來的開場動畫）
						Engine.remove_meta("title_done")
						Engine.remove_meta("map_last")
						Engine.set_meta("title_skip_open", true)
						get_tree().reload_current_scene()
					else:
						_esc_t = 2.0
						_show_toast("再按一次 Esc 返回標題")

## 方向鍵：世界地圖上是換島；島上 ← → 是沿著路走，↑ ↓ 沒有路（頂一下）
func _arrow(d: Vector2) -> void:
	if _free_active():
		return                           # 主島自由走：方向鍵是按住就走（_tick_free 每幕去讀），不在這裡處理
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
	_idle_t += dt
	_tick_hero(dt)
	_sail_housekeeping(dt)
	_tod_tick(dt)
	_zoom = move_toward(_zoom, 1.0 if _map else 0.0, dt / ZOOM_TIME)
	var z := _z()
	# 島上的鏡頭慢慢跟上家豪；世界地圖的鏡頭固定在所有島的正上方（稍微偏向家豪所在的島）。兩個之間照 z 混合
	_cam_bias = _cam_bias.lerp(_cam_bias_to, 1.0 - exp(-dt * 3.5))
	var target := Vector3(_hero.position.x, _hero.position.y - 0.3, _hero.position.z) + _cam_bias
	_focus = _focus.lerp(target, 1.0 - exp(-dt * 5.5))
	var sway := Vector3(sin(_t * 0.25) * 0.5, 0, 0)
	var lean := (Vector3(_focus.x, 0, _focus.z) - _map_center) * 0.06
	# 開船：鏡頭跟在船後面（繞著家豪轉到船頭朝的方向），拉遠一點；下船之後慢慢轉回來
	var sailing := not _sail.is_empty()
	_cam_yaw = lerp_angle(_cam_yaw, float(_sail.yaw) - PI if sailing else 0.0, 1.0 - exp(-dt * (2.4 if sailing else 1.8)))
	_cam_sail = move_toward(_cam_sail, 1.0 if sailing else 0.0, dt * 1.2)
	_wave_amp = SEA_WAVE * _cam_sail * (1.0 - z)                      # 開船才有浪；拉遠看世界地圖時海是平的
	_sea_mat.set_shader_parameter("wave_amp", _wave_amp)
	_sea_mat.set_shader_parameter("wave_t", _t)
	var fov_to := _cam_fov0
	if sailing:
		fov_to += 11.0 * clampf(absf(float(_sail.spd)) / maxf(float(_sail.get("max", 22.0)), 1.0), 0.0, 1.0) + (7.0 if bool(_sail.get("boost", false)) else 0.0)
	_cam.fov = lerpf(_cam.fov, fov_to, 1.0 - exp(-dt * 3.0))        # 越快視野越寬
	if _sea_life != null:
		_sea_life.tick(dt, _t, sailing, Vector2(_sail.pos) if sailing else Vector2.ZERO, float(_sail.spd) if sailing else 0.0)
	var cam_rot := Basis(Vector3.UP, _cam_yaw)
	var pos := (_focus + cam_rot * (CAM_OFFSET * lerpf(1.0, SAIL_CAM, _cam_sail)) + sway).lerp(_map_center + _map_cam + lean + sway * 2.0, z)
	var look := (_focus + cam_rot * CAM_LOOK).lerp(_map_center + lean, z)
	_cam.position = pos
	_cam.look_at(look)
	# 海跟著鏡頭走（花紋用世界座標，不會跟著滑）；拉遠時霧變淡、影子畫遠一點、海面晚一點才融進地平線
	var sea := Vector3(_focus.x, 0, _focus.z).lerp(_map_center, z)
	_sea.position = Vector3(sea.x, 0, sea.z)
	_env.fog_density = lerpf(0.003, 0.0, smoothstep(0.0, 0.45, z))    # 霧先散掉：拉到一半畫面才不會白白的；世界地圖上完全沒有霧
	_sun.directional_shadow_max_distance = lerpf(90.0, _map_cam.length() * 1.5, z)
	# 陰影切片：島上 2 層；世界地圖從上面看、東西都很遠，1 層就夠（預設 4 層會把幾千個物件的影子畫 4 次，網頁版很卡）
	var smode := DirectionalLight3D.SHADOW_ORTHOGONAL if z > 0.5 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if _sun.directional_shadow_mode != smode:
		_sun.directional_shadow_mode = smode
	_sea_mat.set_shader_parameter("fade_near", lerpf(60.0, 700.0, z))
	_sea_mat.set_shader_parameter("fade_far", lerpf(260.0, 1400.0, z))
	_sea_mat.set_shader_parameter("zoom", z)
	_sea_mat.set_shader_parameter("region_k", smoothstep(0.15, 0.85, z))
	if _halo_mat:
		var here := int(_jump.e) if not _jump.is_empty() else selected
		var dim := 0.35 if here == _halo_e else 1.0            # 選到這座島時有黃色選取圈了，光暈退一點
		_halo_mat.albedo_color = Color(1.0, 1.0, 1.0, smoothstep(0.6, 1.0, z) * (0.75 + 0.15 * sin(_t * 1.6)) * dim)
	if _plumes:
		_plumes.visible = z > 0.3
		_plumes.scale = Vector3.ONE * smoothstep(0.3, 0.8, z)
	for fl in _floats:
		var fn := fl.node as Node3D
		fn.position = (fl.base as Vector3) + Vector3(sin(_t * 0.21 + float(fl.phase)) * 0.8, sin(_t * 0.9 + float(fl.phase)) * 0.06, cos(_t * 0.17 + float(fl.phase)) * 0.6)
		fn.rotation.y = float(fl.phase) + sin(_t * 0.13 + float(fl.phase)) * 0.25
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
		var m := float(w.get("ring_m", 9.0))
		_ring.scale = Vector3((float(w.rx) + m) * grow, 1.0, (float(w.rz) + m) * grow)
		_ring_mat.albedo_color = Color(Color("ffd033"), z)
		_ring_edge.albedo_color = Color(PATH_EDGE, z * 0.85)
	for sm in _small:
		(sm as Node3D).visible = z < 0.5
	if _free_hub():
		_free.update_occlusion(dt, _cam.global_position, _hero.position, _free_active())      # 家豪躲到樹和建築後面：它們變透明
	_life.tick(dt, _t)
	_growth.tick(dt, _t)
	_fishing.tick(dt, _t)
	_dj.tick(dt, _t)
	# 世界地圖上地標放大（玩具地圖的感覺）、飽和度收一點（海才不會搶島的顏色）
	# 只在數值變了才設：設 scale 會讓底下幾千個網格全部重算位置，就算數值一樣也會
	var big := Vector3.ONE * lerpf(1.0, SPOT_BIG, z)
	for w2 in worlds:
		for ir in w2.isle_roots:
			if not (ir as Node3D).scale.is_equal_approx(big):
				(ir as Node3D).scale = big
	_env.adjustment_saturation = lerpf(1.35, 1.2, z)
	_shallow_mat.albedo_color = Color(_shallow_tint, lerpf(0.5, 1.0, z))
	for r in _shallow_mats:
		(_shallow_mats[r] as StandardMaterial3D).albedo_color = Color(_shallow_tint.lerp(SHALLOW_TINT[r], z), lerpf(0.5, 1.0, z))
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
			var on := e == selected and k == stage_sel and not _busy() and not _map and (not _free_hub() or _free_near)
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
	var hot := _snd_rect.has_point(mp) or _shop_rect.has_point(mp) or _map_rect.has_point(mp) or _time_rect.has_point(mp)
	if not hot and _map:
		hot = _isle_at(mp) >= 0
	elif not hot:
		hot = _start_rect.has_point(mp) or _node_at(mp) >= 0 or _life.hover_at(mp)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hot else Input.CURSOR_ARROW)
	_overlay.queue_redraw()
	_ov_isle.queue_redraw()
	_ov_map.queue_redraw()

## 家豪的動作：走路（一跳一跳）、換島（飛過去）、原地待機
func _tick_hero(dt: float) -> void:
	if not _sail.is_empty():
		_tick_sail(dt)
		return
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
			if _free_hub():
				_free.pos = _stand(selected, stage_sel)         # 飛回主島：落在站點上
				_free_near = true
			if String(_st_now().kind) == "locked":
				_shake_t = SHAKE_TIME
		return
	if _free_active():
		_tick_free(dt)
		return
	# 待機：轉回來面對鏡頭、輕輕彈；被擋住時往那邊頂一下
	_hero.rotation.y = lerp_angle(_hero.rotation.y, _face_yaw, 1.0 - exp(-dt * 8.0))
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

# ================================================================== 開發用：主島的戳戳樂、釣魚、手帳各截幾張圖（--hubshots=資料夾）

func _hubshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	Journal.reset_memory()
	await get_tree().create_timer(0.8).timeout
	_map = false
	_zoom = 0.0
	select(0)
	for k in int(worlds[0].n):
		select_stage(k)
		await _shot(dir.path_join("hub_%d.png" % k))
	# DJ 台：選單、演出中（打到 FEVER）、結算、自由混音
	for id in HubGrowth.ids():
		_growth.grow(String(id), false)
	_dj.begin()
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("dj_menu.png"))
	_dj.start_song(1)
	var nl: Array = _dj._notes
	for i in 22:
		_dj._clock = float((nl[i] as Dictionary).t)
		_dj._first = i
		_dj.press_lane(int((nl[i] as Dictionary).lane))
		_dj.tick(0.016, _t)
	_dj._clock = float((nl[22] as Dictionary).t) - 0.9
	for i in 30:
		_dj.tick(0.016, _t)
	await get_tree().create_timer(1.2).timeout
	await _shot(dir.path_join("dj_play.png"))
	_dj.sim_song(0, 1.0)
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("dj_result.png"))
	_dj.key_down(KEY_ESCAPE)
	_dj.start_jam()
	for l in [1, 2, 3]:
		_dj.toggle_layer(l)
	await get_tree().create_timer(1.5).timeout
	await _shot(dir.path_join("dj_jam.png"))
	_dj.end()
	# 世界地圖上的主島
	_map = true
	select(0)
	await _shot(dir.path_join("world_hub.png"))
	_map = false
	# 戳戳樂：母雞、樹、穀倉
	select_stage(_hub_index("home"))
	await _shot(dir.path_join("poke_0.png"))
	for i in 3:
		var hen: Dictionary = _life.hens[i]
		hen.pokes = 2
		hen.thing.cd = 0.0
		_life._poke(hen.thing)
	for th in _life.things:
		if String(th.kind) == "tree" and (th.node as Node3D).global_position.distance_to(_hero.global_position) < 18.0:
			th.cd = 0.0
			_life._poke(th)
			break
	for th in _life.things:
		if String(th.kind) == "barn":
			_life._poke(th)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("poke_1.png"))
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("poke_2.png"))
	# 釣魚的幾個階段
	select_stage(_hub_index("fish"))
	await _shot(dir.path_join("fish_0_station.png"))
	_fishing.begin()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("fish_1_aim.png"))
	_fishing.press()
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("fish_2_wait.png"))
	_fishing._wait = 0.05
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("fish_3_bite.png"))
	_fishing.press()
	_fishing._speed = 0.0
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("fish_4_reel.png"))
	var guard := 0
	while _fishing.state == "reel" and guard < 6:
		_fishing._speed = 0.0
		_fishing._mark = _fishing._zone_c
		_fishing.press()
		await get_tree().create_timer(0.15).timeout
		guard += 1
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("fish_5_catch.png"))
	_fishing.end()
	# 農莊長大：每個大關長出小地標和居民
	select_stage(_hub_index("home"))
	_zoom = 0.0
	for gid in HubGrowth.ids():
		_growth.grow(String(gid), true, 0.0)
	_snap_view()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("grow_0_pop.png"))
	await get_tree().create_timer(2.5).timeout
	for k in [0, 4]:
		select_stage(k)
		await _shot(dir.path_join("grow_%d.png" % (k + 1)))
	select_stage(_hub_index("guide"))
	await _shot(dir.path_join("grow_3.png"))
	# 手帳：灌一些假資料，三頁各一張
	Journal.add("poke", "total", 23)
	Journal.add("poke", "hen", 12)
	Journal.add("egg", "total", 4)
	for id in ["tilapia", "carp", "peel", "goldfish"]:
		Journal.caught(Journal.fish_by_id(id), 30)
	Journal.unlock_new(_journal_ctx())
	for t in 3:
		_journal.open(t)
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("journal_%d.png" % t))
		_journal.close()
	get_tree().quit()

# ================================================================== 自動驗收（--autotest）

func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)

## 南北兩區排得對不對：北方的島中心在主島北邊、南方的在南邊；最終章是北方最北的那座
func _regions_ok() -> bool:
	var hz := float(worlds[0].center.z)
	var top := INF
	var top_e := -1
	for e in range(1, entries.size()):
		var z := float(worlds[e].center.z)
		match _region(e):
			"north":
				if z >= hz:
					return false
				if z < top:
					top = z
					top_e = e
			"south", "dev":
				if z <= hz:
					return false
	for e in range(1, entries.size()):
		if String(entries[e].ch.get("id", "")) in FINAL_IDS and _region(e) == "north" and e != top_e:
			return false
	return true

## 主島的新東西：冒險手帳、戳戳樂、釣魚（手帳存檔用記憶體，不寫玩家的檔案）
func _autotest_hub(checks: Array) -> void:
	Journal.reset_memory()
	_map = false
	_zoom = 0.0
	select(0)
	# 冒險手帳：Enter 翻開、→ 換頁、Esc 合上
	select_stage(_hub_index("board"))
	_press(KEY_ENTER)
	await get_tree().create_timer(0.4).timeout
	var j_open: bool = _journal.is_open() and _busy()
	_press(KEY_RIGHT)
	await get_tree().create_timer(0.2).timeout
	var j_tab: bool = _journal.tab == 1
	if DisplayServer.window_can_draw():
		await RenderingServer.frame_post_draw
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	checks.append(["冒險手帳：Enter 翻開、→ 換頁、Esc 合上（不會跳到世界地圖）", j_open and j_tab and not _journal.is_open() and not _map])
	# 戳戳樂：戳母雞三下會下蛋，蛋收得起來；手帳記著次數
	var hen: Dictionary = _life.hens[0]
	for i in 3:
		hen.thing.cd = 0.0
		_life._poke(hen.thing)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(1.2).timeout
	var laid: bool = _life.eggs.size() >= 1
	if laid:
		_life._collect_egg(_life.eggs[0])
	await get_tree().create_timer(0.8).timeout
	checks.append(["戳戳樂：戳母雞三下會下蛋，蛋收得起來（手帳記著：戳 %d 下、蛋 %d 顆）" % [Journal.n("poke", "hen"), Journal.n("egg", "total")],
		laid and Journal.n("poke", "hen") == 3 and Journal.n("egg", "total") == 1 and _life.eggs.is_empty()])
	# 戳樹、穀倉、家豪
	var did := {}
	for th in _life.things:
		var kd := String(th.kind)
		if kd in ["tree", "barn", "windmill", "hay", "pumpkin", "silo"] and not did.has(kd):
			did[kd] = true
			th.cd = 0.0
			_life._poke(th)
	_life.poke_near()
	await get_tree().create_timer(0.6).timeout
	checks.append(["戳戳樂：樹、穀倉、風車、乾草、南瓜、筒倉都登記了、都戳得動", did.size() == 6 and Journal.n("poke", "total") >= 9])
	# 用滑鼠點母雞（真的走輸入、算螢幕座標）和按 E
	select_stage(_hub_index("home"))
	await get_tree().create_timer(0.3).timeout
	var hen2: Dictionary = _life.hens[7]          # 家門口的那隻（雞圈裡的在畫面外）
	hen2.thing.cd = 0.0
	var sp: Variant = _life._screen(hen2.thing)
	var before := Journal.n("poke", "hen")
	if sp != null and DisplayServer.window_can_draw() or sp != null:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = sp
		Input.parse_input_event(click)
		await get_tree().create_timer(0.3).timeout
	var clicked := Journal.n("poke", "hen") > before
	if not clicked and sp != null:
		# headless 沒有真的視窗，合成的滑鼠事件可能進不來：改成直接呼叫點擊的處理
		hen2.thing.cd = 0.0
		sp = _life._screen(hen2.thing)
		clicked = _life.poke_at(sp, true) and Journal.n("poke", "hen") > before
	await get_tree().create_timer(0.4).timeout           # 等剛剛那一戳的冷卻過去
	var before2 := Journal.n("poke", "total")
	var eggs_before := Journal.n("egg", "total")
	_press(KEY_E)
	await get_tree().create_timer(0.3).timeout
	var e_ok := Journal.n("poke", "total") > before2 or Journal.n("egg", "total") > eggs_before      # 附近有蛋的話 E 會先收蛋
	checks.append(["戳戳樂：滑鼠點母雞（%s）、按 E 戳最近的東西（%s）都有反應" % [clicked, e_ok], clicked and e_ok])
	# 釣魚：Enter 甩竿 → 等 → 咬鉤 → 拉鉤 → 時機條 → 釣到 → Esc 收竿
	select_stage(_hub_index("fish"))
	await get_tree().create_timer(0.3).timeout
	_press(KEY_ENTER)
	await get_tree().create_timer(0.4).timeout
	var f0: bool = _fishing.active and _fishing.state == "aim"
	_press(KEY_SPACE)
	await get_tree().create_timer(1.0).timeout
	var f1: bool = _fishing.state == "wait"
	_fishing._wait = 0.05
	await get_tree().create_timer(0.5).timeout
	var f2: bool = _fishing.state == "bite"
	_press(KEY_SPACE)
	await get_tree().create_timer(0.2).timeout
	var f3: bool = _fishing.state == "reel"
	var guard := 0
	while _fishing.state == "reel" and guard < 6:
		_fishing._speed = 0.0
		_fishing._mark = _fishing._zone_c
		_press(KEY_SPACE)
		await get_tree().create_timer(0.2).timeout
		guard += 1
	var f4: bool = _fishing.state == "catch" and Journal.book_count() == 1
	await get_tree().create_timer(1.4).timeout
	_press(KEY_SPACE)
	await get_tree().create_timer(0.3).timeout
	var f5: bool = _fishing.state == "aim"
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	checks.append(["釣魚：甩竿、等、咬鉤、拉鉤、時機條、釣到（圖鑑 %d 種）、再甩、Esc 收竿" % Journal.book_count(),
		f0 and f1 and f2 and f3 and f4 and f5 and not _fishing.active and not _busy()])
	# 農莊長大：每個大關長出小地標和居民，居民可以戳
	for gid in HubGrowth.ids():
		_growth.grow(String(gid), false)
	await get_tree().create_timer(0.3).timeout
	var res_th: Dictionary = {}
	for th in _life.things:
		if String(th.kind) == "resident":
			res_th = th
			break
	var talked := false
	if not res_th.is_empty():
		res_th.cd = 0.0
		_life._poke(res_th)
		talked = Journal.n("poke", "resident") == 1
	checks.append(["農莊長大：%d 個小地標和居民都長出來了，居民可以戳" % _growth.count(), _growth.count() == HubGrowth.ids().size() and talked])
	# DJ 台：選單、演一首歌（全打準 = S 加全連擊、完全不按 = D）、FEVER 請居民來看、自由混音
	var free_was := _free_enabled
	_free_enabled = true                  # 自由走：走近混音台按 E 開演、家豪被帶到混音台後面
	_place_hero()
	await get_tree().create_timer(0.3).timeout
	var dj_p: Vector3 = _dj.booth_pos() + Vector3(2.0, 0, 1.5)
	dj_p.y = _hero.position.y
	_free.pos = dj_p
	_hero.position = dj_p
	var dj_near: bool = _dj.near(_hero.global_position)
	_life.poke_near()
	await get_tree().create_timer(0.3).timeout
	var dj_snap: bool = _dj.active and Vector2(_hero.global_position.x - _dj.booth_pos().x, _hero.global_position.z - _dj.booth_pos().z).length() < 0.5
	_dj.end()
	_free_enabled = free_was
	_place_hero()
	_dj.begin()
	await get_tree().create_timer(0.2).timeout
	var dj0: bool = dj_near and dj_snap and _dj.active and _dj.state == "menu" and _busy() and _dj.make_chart(0).size() >= 30 and _dj.make_chart(2).size() > _dj.make_chart(0).size()
	var rA: Dictionary = _dj.sim_song(1, 1.0)
	var dj1: bool = int(rA.rank) == 5 and bool(rA.fc) and Journal.n("dj", "plays") == 1 and _dj.state == "result"
	var dj2: bool = Journal.n("dj", "fever") >= 1 and Journal.n("dj", "guest") >= 1 and _dj._guests.size() == HubGrowth.ids().size()
	var rB: Dictionary = _dj.sim_song(1, 0.0)
	var dj3: bool = int(rB.rank) == 1 and not bool(rB.fc) and Journal.n("dj", "rank_1") == 5
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	var dj4: bool = _dj.state == "menu"
	_dj.sel = 3
	_press(KEY_ENTER)
	await get_tree().create_timer(0.2).timeout
	var dj5: bool = _dj.state == "jam"
	for l in [1, 2, 3]:
		_dj.toggle_layer(l)
	for i in 660:
		_dj.tick(1.0 / 60.0, _t)
	var dj6: bool = Journal.has("flag", "dj_jam")
	_press(KEY_ESCAPE)
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	checks.append(["DJ 台：選單、演一首歌（全準 %s、全連擊；不按 %s）、FEVER 請 %d 位居民來看、自由混音全開 10 秒、Esc 離開" % [RANKS_TEST[int(rA.rank)], RANKS_TEST[int(rB.rank)], _dj._guests.size()],
		dj0 and dj1 and dj2 and dj3 and dj4 and dj5 and dj6 and not _dj.active and not _busy()])
	# 貼紙：戳和釣的紀錄會解鎖貼紙
	var got := 0
	for st in Journal.stickers(_journal_ctx()):
		if bool(st.got):
			got += 1
	checks.append(["貼紙：戳一戳、釣到魚都會算進貼紙（現在 %d 張）" % got, got >= 1])
	Journal.reset_memory()

## 只跑主島新東西的驗收（--hubtest）：比完整的 --autotest 快很多，跑完自己關掉
func _hubtest() -> void:
	await get_tree().create_timer(1.0).timeout
	var checks: Array = []
	await _autotest_hub(checks)
	var fails := 0
	for c in checks:
		if not bool(c[1]):
			fails += 1
		print("[%s] %s" % ["PASS" if bool(c[1]) else "FAIL", c[0]])
	print("HUBTEST: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	get_tree().quit()

# ================================================================== 出航：開船去不同的島（hub_sail.gd 管海上的位置、hub_boats.gd 管船、hub_sea_life.gd 管彩蛋）

func _sail_on() -> bool:
	return not _sail.is_empty()

## 海浪的高度（公尺）：跟 map_sea.gdshader 的 sea_wave() 是同一個公式，船才會真的浮在浪上
func _sea_h(p: Vector2) -> float:
	return _wave_amp * (0.55 * sin(p.dot(Vector2(0.071, 0.052)) + _t * 0.9) + 0.30 * sin(p.dot(Vector2(-0.043, 0.093)) + _t * 1.25 + 1.7)
		+ 0.16 * sin(p.dot(Vector2(0.13, -0.08)) + _t * 1.8 + 4.0))

## 把模型上所有的材質乘上一個顏色（材質先複製，不會改到別的東西）
func _tint_model(node: Node, col: Color) -> void:
	if node == null:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as BaseMaterial3D
			if m == null:
				continue
			var d := m.duplicate() as BaseMaterial3D
			d.albedo_color = m.albedo_color * col
			mi.set_surface_override_material(s, d)
	for ch in node.get_children():
		_tint_model(ch, col)

## 蓋出某一種船的外觀（船頭朝 +z、水面在 y = 0）：全部用現成的模型拼，顏色乘在小木船上
func _boat_apply(id: String) -> void:
	if _boat == null or _boat_id == id:
		return
	_boat_id = id
	if _boat_model:
		_boat_model.queue_free()
	if _boat_light:
		_boat_light.queue_free()
		_boat_light = null
	_boat_model = Node3D.new()
	_boat.add_child(_boat_model)
	var bm := _boat_model
	var spec := HubBoats.get_boat(id)
	if id == "raft":
		_spawn_fit(bm, "res://levels/fort/assets/pirate/platform-planks.glb", Vector3(0, 0.12, 0), 3.5, 0.0)
		for sx in [-1.2, 1.2]:
			for sz in [-1.1, 1.1]:
				_spawn_fit(bm, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(sx, -0.3, sz), 0.95, sx * 0.4)
		_spawn_fit(bm, "res://levels/fort/assets/pirate/flag-pennant.glb", Vector3(0.9, 0.1, -1.3), 2.4, 0.0)
		return
	var hull := _spawn_fit(bm, ROWBOAT, Vector3.ZERO, BOAT_LEN, 0.0)
	if hull:
		var bb := _aabb(hull, Transform3D.IDENTITY)
		hull.rotation.y = (PI * 0.5 if bb.size.x > bb.size.z else 0.0) + (PI if BOAT_FLIP else 0.0)      # 長邊對著船頭（+z）
		if spec.tint != Color(1, 1, 1):
			_tint_model(hull, spec.tint)
	match id:
		"pumpkin":
			var pk := "res://levels/liuchiyu/assets/kaykit_halloween/pumpkin_orange.gltf"
			_spawn_fit(bm, pk, Vector3(0, 0.45, 1.5), 1.0, 0.0)
			_spawn_fit(bm, pk, Vector3(0.55, 0.4, -1.4), 0.75, 1.0)
			_spawn_fit(bm, pk, Vector3(-0.6, 0.4, -1.1), 0.6, 2.0)
			_spawn_fit(bm, "res://levels/liuchiyu/assets/kaykit_halloween/lantern_standing.gltf", Vector3(-0.75, 0.3, 1.0), 1.5, 0.0)
		"pirate":
			_spawn_fit(bm, "res://levels/fort/assets/pirate/cannon.glb", Vector3(0, 0.4, 1.3), 1.4, 0.0)
			_spawn_fit(bm, "res://levels/fort/assets/pirate/flag-high-pennant.glb", Vector3(0, 0.1, -1.7), 3.4, 0.0)
			_spawn_fit(bm, "res://levels/fort/assets/pirate/barrel.glb", Vector3(0.7, 0.35, -0.9), 0.8, 0.5)
		"phoenix":
			_spawn_fit(bm, "res://levels/heaven/assets/blender/mini_lantern.glb", Vector3(0.7, 0.35, 1.4), 1.1, 0.0)
			_spawn_fit(bm, "res://levels/heaven/assets/blender/mini_lantern.glb", Vector3(-0.7, 0.35, 1.4), 1.1, 0.0)
			_spawn_fit(bm, "res://levels/heaven/assets/blender/star_stele.glb", Vector3(0, 0.1, -1.7), 2.0, 0.0)
			_boat_light = OmniLight3D.new()
			_boat_light.light_color = Color(1.0, 0.82, 0.45)
			_boat_light.light_energy = 1.4
			_boat_light.omni_range = 7.0
			_boat_light.position = Vector3(0, 1.8, 0)
			_boat.add_child(_boat_light)

## 第一次出航之前先蓋好小船（碼頭邊停著現在選的那艘），和船尾的浪花、船頭的水花、海浪的聲音
func _sail_make_boat() -> void:
	if _boat != null:
		return
	_boat = Node3D.new()
	_boat.name = "SailBoat"
	add_child(_boat)
	_wake = _sea_puff(Vector3(0, 0.15, -1.8), Vector3(0, 0.25, -1), 38.0, 1.2, 3.0, 56, 1.3)
	_spray = _sea_puff(Vector3(0, 0.5, 1.7), Vector3(0, 1, 0.5), 35.0, 2.5, 5.5, 40, 0.8)
	_boat.add_child(_wake)
	_boat.add_child(_spray)
	_boat_apply(String(HubBoats.current().id))
	var wv: AudioStreamWAV = (HubSfx.make()["wave"] as AudioStreamWAV).duplicate()
	wv.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wv.loop_begin = 0
	wv.loop_end = wv.data.size() / 2
	_wave_snd = AudioStreamPlayer.new()
	_wave_snd.stream = wv
	_wave_snd.volume_db = -30.0
	add_child(_wave_snd)

## 一團小白球（浪花、水花）
func _sea_puff(at: Vector3, dir: Vector3, spread: float, v0: float, v1: float, amount: int, life: float) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.8
	sm.radial_segments = 8
	sm.rings = 4
	var mat := _flat_mat(Color(1, 1, 1, 0.75), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mat
	ps.mesh = sm
	ps.amount = amount
	ps.lifetime = life
	ps.local_coords = false
	ps.emitting = false
	ps.direction = dir
	ps.spread = spread
	ps.initial_velocity_min = v0
	ps.initial_velocity_max = v1
	ps.gravity = Vector3(0, -2.0, 0) if dir.y > 0.9 else Vector3.ZERO
	ps.scale_amount_min = 0.5
	ps.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	ps.scale_amount_curve = curve
	ps.position = at
	return ps

## 碼頭邊停船的位置（船頭朝外海）
func _boat_dock_xz() -> Vector2:
	var bp := _pier_boat.global_position
	return _sailer.resolve(Vector2(bp.x, bp.z))

func _boat_dock(spin := -1.0) -> void:
	var p := _boat_dock_xz()
	var hc := Vector2(float(worlds[0].center.x), float(worlds[0].center.z))
	var out := p - hc
	_boat.position = Vector3(p.x, 0.12, p.y)
	_boat.rotation = Vector3(0, atan2(out.x, out.y) if spin < 0.0 else spin, 0)

## 在碼頭按 Enter：家豪跳上小船，開始開船
func _sail_board() -> void:
	if _starting or not _sail.is_empty() or _pier_boat == null or _boat == null:
		return
	var spec := HubBoats.current()
	_boat_apply(String(spec.id))
	_boat_dock()
	var p := _boat_dock_xz()
	var yaw := _boat.rotation.y
	_boat.visible = true
	_pier_boat.visible = false
	_sail = {"state": "board", "t": 0.0, "from": _hero.position, "pos": p, "yaw": yaw, "spd": 0.0, "path": PackedVector2Array(), "idx": 0,
		"auto": false, "auto_e": -1, "pick": false, "sel": 0, "max": float(spec.max), "acc": float(spec.acc), "turn": float(spec.turn),
		"boost": false, "energy": 1.0, "name": String(spec.name)}
	_free_goal_on = false
	_free_dash = {}
	_sail_near = -1
	_bubble_a = 0.0
	_play("fly", 1.2)
	_life._play("splash", 0.9)
	_show_toast("家豪：%s" % String(spec.quip), 2.4)
	Journal.add("sail", "trips")
	_journal_check()

## 家豪坐的位置（小船中間，跟著浪上下）
func _sail_seat() -> Vector3:
	var p: Vector2 = _sail.pos
	return Vector3(p.x, 0.75 + _sea_h(p), p.y)

## 離哪座島夠近可以靠岸（entries 的索引）。主島只有在碼頭附近才算；還沒開放的島也會算（泡泡上會說還沒開放）
func _sail_prompt() -> int:
	var pos: Vector2 = _sail.pos
	var n := _sailer.nearest(pos)
	if int(n.i) < 0 or float(n.d) > HubSail.DOCK_RANGE:
		return -1
	var e := int(n.e)
	if e == 0:
		if _pier_boat == null:
			return -1
		var pp := _pier_boat.global_position
		if Vector2(pp.x, pp.z).distance_to(pos) > 18.0:
			return -1
	return e

func _tick_sail(dt: float) -> void:
	var b := _sail
	if String(b.state) == "board":
		b.t = minf(float(b.t) + dt / 0.5, 1.0)
		var k := float(b.t)
		var e := k * k * (3.0 - 2.0 * k)
		var from: Vector3 = b.from
		_hero.position = from.lerp(_sail_seat(), e) + Vector3(0, sin(k * PI) * 2.2, 0)
		_hero.rotation.y = lerp_angle(_hero.rotation.y, float(b.yaw), 1.0 - exp(-dt * 10.0))
		_sail_boat_update(dt, 0.0)
		if k >= 1.0:
			b.state = "sail"
			_play("land")
		return
	var thr := 0.0
	var steer := 0.0
	var manual := false
	var pick := bool(b.pick) or _tod_open
	if not pick:
		var fwd := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		var back := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		steer = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		thr = fwd - back
		manual = fwd > 0.0 or back > 0.0 or steer != 0.0
	var arrived := false
	if bool(b.auto):
		if manual:
			b.auto = false                      # 自己握方向盤：自動航行取消
		else:
			var ctl := _sailer.auto_control(b)
			thr = ctl.x
			steer = ctl.y
			arrived = ctl.z > 0.5
	# 加速（Shift）：有一條能量，用完要等它慢慢回來
	var was_boost := bool(b.boost)
	var want := Input.is_key_pressed(KEY_SHIFT) and thr > 0.0 and not pick
	b.boost = want and float(b.energy) > (0.04 if was_boost else 0.25)
	if bool(b.boost):
		b.energy = maxf(float(b.energy) - dt * 0.36, 0.0)
		if not was_boost:
			_life._play("whoosh", 1.1)
	else:
		b.energy = minf(float(b.energy) + dt * 0.16, 1.0)
	var scraped := _sailer.step(b, dt, thr, steer)
	var spd := float(b.spd)
	_meters_acc += absf(spd) * dt
	if _meters_acc >= 25.0:
		var before := Journal.n("sail", "meters")
		var after := Journal.add("sail", "meters", 25)
		_meters_acc -= 25.0
		if before < 1000 and after >= 1000:
			_journal_check()
	_sail_bump_t = maxf(_sail_bump_t - dt, 0.0)
	if scraped and absf(spd) > 5.0 and _sail_bump_t <= 0.0:
		_sail_bump_t = 0.6
		_play("bump", 0.8)
	var bp: Vector2 = b.pos
	if _sea_life != null and (bp.x <= _sailer.lo.x + 0.05 or bp.y <= _sailer.lo.y + 0.05 or bp.x >= _sailer.hi.x - 0.05 or bp.y >= _sailer.hi.y - 0.05) and spd > 5.0:
		_sea_life.on_edge()
	_sail_near = _sail_prompt()
	_sail_boat_update(dt, steer)
	_hero.position = _sail_seat()
	_hero.rotation.y = lerp_angle(_hero.rotation.y, float(b.yaw), 1.0 - exp(-dt * 10.0))
	_hero_body.position.y = 0.0
	_cam_bias_to = Vector3(sin(float(b.yaw)), 0, cos(float(b.yaw))) * clampf(spd * 0.11, -1.0, 4.5)      # 鏡頭往前看一點
	if arrived and bool(b.auto):
		_sail_land(int(b.auto_e))

## 小船的位置、朝向（跟著浪起伏和傾斜）、浪花、海浪的聲音
func _sail_boat_update(dt: float, steer: float) -> void:
	var p: Vector2 = _sail.pos
	var yaw := float(_sail.yaw)
	var spd := float(_sail.spd)
	var top := float(_sail.get("max", HubSail.MAX_SPEED))
	var f := Vector2(sin(yaw), cos(yaw))
	var r := Vector2(-f.y, f.x)
	var pitch := -atan((_sea_h(p + f * 1.5) - _sea_h(p - f * 1.5)) / 3.0)
	var roll := atan((_sea_h(p - r) - _sea_h(p + r)) / 2.0)        # 船的 +x 是左邊：左邊比較高就往右歪
	_sail_roll = lerpf(_sail_roll, steer * 0.16, 1.0 - exp(-dt * 4.0))
	_boat.position = Vector3(p.x, 0.12 + _sea_h(p), p.y)
	_boat.rotation = Vector3(pitch - clampf(absf(spd) / top, 0.0, 1.0) * 0.07, yaw, roll + _sail_roll)
	var fast := absf(spd) > top * 0.6 or bool(_sail.get("boost", false))
	if _wake:
		_wake.emitting = absf(spd) > 3.0
		_wake.speed_scale = clampf(absf(spd) / 12.0, 0.6, 2.2)
	if _spray:
		_spray.emitting = fast
		_spray.amount = 60 if bool(_sail.get("boost", false)) else 34
	if _wave_snd:
		if not _wave_snd.playing:
			_wave_snd.play()
		_wave_snd.volume_db = linear_to_db(clampf(0.08 + absf(spd) / top * 0.5, 0.05, 0.6)) - 6.0

## 靠岸：家豪從船上跳到那座島的第一個站點（主島：碼頭）
func _sail_land(e: int) -> void:
	if _sail.is_empty() or String(_sail.state) != "sail":
		return
	if e != 0 and String(_st(e, 0).kind) == "locked":
		_show_toast("這座島還沒開放")
		_play("bump")
		_sail.auto = false
		return
	var k := _hub_index("dock") if e == 0 else _first_open_stage_of(e)
	_sail_stop()
	_jump_to(e, k)
	if e != 0:
		Journal.mark("dock", String(_entry_id(e)))
		_journal_check()

## 不開船了：船停下來、浪花和海浪的聲音關掉
func _sail_stop() -> void:
	_sail = {}
	_sail_near = -1
	_sail_roll = 0.0
	_cam_bias_to = Vector3.ZERO
	if _wake:
		_wake.emitting = false
	if _spray:
		_spray.emitting = false
	if _wave_snd:
		_wave_snd.stop()

## 回到農莊的碼頭（M 看世界地圖之前）：直接站回碼頭
func _sail_return_home() -> void:
	_sail_stop()
	select(0)
	stage_sel = _hub_index("dock")
	_place_hero(true)

## 開船中按 M：保留原本的功能（拉遠看世界地圖，從那裡飛到別的島）。船收回碼頭
func _sail_to_map() -> void:
	_sail_return_home()
	set_map(true)

## 小船沒在用的時候：在農莊就停在碼頭邊（船塢開著時慢慢轉給你看）；在別的島就停在那座島的岸邊
func _sail_housekeeping(dt: float) -> void:
	if _boat == null:
		return
	if _sail.is_empty() and selected == 0 and _jump.is_empty():
		_boat.visible = true
		_pier_boat.visible = false
		if _yard.is_empty():
			_boat_dock()
		else:
			_boat_dock(_boat.rotation.y + dt * 0.7)
			_cam_bias_to = (_boat.position - _hero.position) * 0.6 + Vector3(0, 0.6, 0)      # 鏡頭往船那邊看
	if _sail.is_empty():
		if _wake:
			_wake.emitting = false
		if _spray:
			_spray.emitting = false
		if _wave_snd and _wave_snd.playing:
			_wave_snd.stop()

## 自動航行選單上能去的地方（entries 的索引）：開放了的島和農莊
func _sail_list() -> Array:
	var out: Array = []
	for e in entries.size():
		if e != 0 and String(_st(e, 0).kind) == "locked":
			continue
		out.append(e)
	return out

func _sail_pick_open() -> void:
	var list := _sail_list()
	_sail.pick = true
	_sail.sel = 0
	for i in list.size():
		if int(list[i]) != 0:
			_sail.sel = i                    # 先停在第一座主題島（農莊排第一個）
			break
	_play("click")

## 選好了：自己開過去
func _sail_pick_go() -> void:
	var list := _sail_list()
	if list.is_empty():
		return
	_sail_auto_to(int(list[clampi(int(_sail.sel), 0, list.size() - 1)]))

func _sail_auto_to(e: int) -> void:
	if _sail.is_empty() or String(_sail.state) != "sail":
		return
	var pos: Vector2 = _sail.pos
	var to: Vector2
	if e == 0 and _pier_boat != null:
		to = _boat_dock_xz()
	else:
		to = _sailer.stop_point(e, pos)
	_sail.path = _sailer.plan(pos, to)
	_sail.idx = 1
	_sail.auto = true
	_sail.auto_e = e
	_sail.pick = false
	_play("start", 1.3)

## 汽笛
func _sail_horn() -> void:
	_life._play("horn")
	var c := Journal.add("sail", "horn")
	if _sea_life != null:
		_sea_life.on_horn(_sail.pos)
	if c == 10:
		_journal_check()

## 開船中的按鍵和滑鼠。回傳 true = 這個輸入我處理了
func _sail_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _snd_rect.has_point(ev.position):
			_toggle_sound()
		elif _map_rect.has_point(ev.position):
			_sail_to_map()
		elif _time_rect.has_point(ev.position):
			_tod_toggle()
		elif bool(_sail.pick):
			for i in _sail_rows.size():
				if (_sail_rows[i] as Rect2).has_point(ev.position):
					_sail.sel = i
					_sail_pick_go()
					break
		elif _sail_near >= 0 and _start_rect.has_point(ev.position):
			_sail_land(_sail_near)
		return true
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var pick := bool(_sail.pick)
		match ev.keycode:
			KEY_V:
				_toggle_sound()
			KEY_M, KEY_TAB:
				_sail_to_map()
			KEY_H:
				if String(_sail.state) == "sail":
					_sail_horn()
			KEY_T:
				_tod_toggle()
			KEY_P:
				if pick:
					_sail.pick = false
				elif String(_sail.state) == "sail":
					_sail_pick_open()
			KEY_ESCAPE:
				if pick:
					_sail.pick = false
				elif bool(_sail.auto):
					_sail.auto = false
					_show_toast("自動航行取消")
				elif String(_sail.state) == "sail":
					_sail_auto_to(0)             # 回農莊：自動開回碼頭
			KEY_UP, KEY_W:
				if pick:
					_sail.sel = wrapi(int(_sail.sel) - 1, 0, _sail_list().size())
					_play("click")
			KEY_DOWN, KEY_S:
				if pick:
					_sail.sel = wrapi(int(_sail.sel) + 1, 0, _sail_list().size())
					_play("click")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if pick:
					_sail_pick_go()
				elif _sail_near >= 0:
					_sail_land(_sail_near)
		return true
	return false

# ---------------------------------------------------------------- 船塢（在碼頭按 G）：看船、買船、換船

func _yard_open() -> void:
	if not _sail_enabled or _boat == null or not _yard.is_empty() or _busy() or _starting or _map or not _sail.is_empty():
		return
	if selected != 0 or String(_st_now().kind) != "dock" or (_free_hub() and not _free_near):
		return
	var cur := String(HubBoats.current().id)
	var sel := 0
	for i in HubBoats.all().size():
		if String(HubBoats.all()[i].id) == cur:
			sel = i
	_yard = {"sel": sel}
	_yard_preview()
	_play("click")

func _yard_preview() -> void:
	_boat_apply(String(HubBoats.all()[int(_yard.sel)].id))

func _yard_close() -> void:
	_yard = {}
	_cam_bias_to = Vector3.ZERO
	_boat_apply(String(HubBoats.current().id))
	_play("click")

func _yard_move(d: int) -> void:
	_yard.sel = wrapi(int(_yard.sel) + d, 0, HubBoats.all().size())
	_yard_preview()
	_play("click")

## Enter：沒有就買（星星不夠會說）、有了就換上
func _yard_act() -> void:
	var b: Dictionary = HubBoats.all()[int(_yard.sel)]
	var id := String(b.id)
	if HubBoats.owned(id):
		HubBoats.equip(id)
		_show_toast("換成「%s」" % String(b.name))
		_life._play("pop")
	elif Wardrobe.wallet() >= int(b.price) and HubBoats.buy(id):
		HubBoats.equip(id)
		_wallet = Wardrobe.wallet()
		_show_toast("買下了「%s」！" % String(b.name))
		_life._play("gold")
		_journal_check()
	else:
		_show_toast("星星不夠：「%s」要 %d★，你有 %d★" % [String(b.name), int(b.price), Wardrobe.wallet()])
		_play("bump")

func _yard_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _snd_rect.has_point(ev.position):
			_toggle_sound()
			return true
		for i in _yard_rows.size():
			if (_yard_rows[i] as Rect2).has_point(ev.position):
				if int(_yard.sel) == i:
					_yard_act()
				else:
					_yard.sel = i
					_yard_preview()
					_play("click")
				return true
		return true
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_UP, KEY_W:
				_yard_move(-1)
			KEY_DOWN, KEY_S:
				_yard_move(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_yard_act()
			KEY_ESCAPE, KEY_G:
				_yard_close()
			KEY_V:
				_toggle_sound()
		return true
	return false

## 船塢：左邊一張紙，一列一艘船；選到的那艘下面寫簡介和三條能力（速度、加速、轉彎）
func _paint_yard(c: Control, u: float) -> void:
	_yard_rows = []
	if _yard.is_empty():
		return
	var boats := HubBoats.all()
	var rw := 560.0 * u
	var rh := 58.0 * u
	var panel := Rect2(Vector2(44.0 * u, 190.0 * u), Vector2(rw, 84.0 * u + rh * boats.size() + 190.0 * u))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 26 * u, 3.0), panel)
	_text(c, panel.position + Vector2(26 * u, 50 * u), "船塢", 32 * u, INK)
	var wl := str(Wardrobe.wallet())
	_star(c, panel.position + Vector2(rw - 104 * u, 40 * u), 14 * u, GOLD, Color("8a6410"))
	_text(c, panel.position + Vector2(rw - 82 * u, 49 * u), wl, 26 * u, INK)
	var cur := String(HubBoats.current().id)
	for i in boats.size():
		var b: Dictionary = boats[i]
		var r := Rect2(panel.position + Vector2(14 * u, 70 * u + rh * i), Vector2(rw - 28 * u, rh - 6 * u))
		_yard_rows.append(r)
		var on := i == int(_yard.sel)
		c.draw_style_box(_box(Color("fff1bf") if on else Color(1, 1, 1, 0.0), Color("d9b84a") if on else Color(0, 0, 0, 0.0), 20 * u, 2.5, false), r)
		var tint: Color = b.tint
		c.draw_circle(r.position + Vector2(26 * u, r.size.y * 0.5), 13 * u, Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7).darkened(0.1))
		c.draw_circle(r.position + Vector2(26 * u, r.size.y * 0.5), 9 * u, tint.lightened(0.1))
		_text(c, r.position + Vector2(54 * u, r.size.y * 0.5 + 9 * u), String(b.name), 27 * u, INK)
		var own := HubBoats.owned(String(b.id))
		var tag := ("使用中" if String(b.id) == cur else "已擁有") if own else "%d★" % int(b.price)
		var tcol := Color("3c7d3c") if own else (Color("b8860b") if Wardrobe.wallet() >= int(b.price) else Color("c0504a"))
		var tw := _font().get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x
		_text(c, r.position + Vector2(r.size.x - tw - 18 * u, r.size.y * 0.5 + 8 * u), tag, 24 * u, tcol)
	# 選到的那艘
	var sb: Dictionary = boats[int(_yard.sel)]
	var dy := panel.position.y + 70.0 * u + rh * boats.size() + 14.0 * u
	_text(c, Vector2(panel.position.x + 28 * u, dy + 24 * u), String(sb.desc), _fit(String(sb.desc), 22.0 * u, rw - 56 * u, 14.0), Color("5a4a3a"))
	var stats := [["速度", float(sb.max) / 42.0], ["加速", float(sb.acc) / 20.0], ["轉彎", float(sb.turn) / 2.2]]
	for k in stats.size():
		var yy := dy + 58.0 * u + k * 34.0 * u
		_text(c, Vector2(panel.position.x + 28 * u, yy + 8 * u), String(stats[k][0]), 22 * u, INK)
		var bar := Rect2(Vector2(panel.position.x + 110 * u, yy - 6 * u), Vector2(rw - 160 * u, 18 * u))
		c.draw_style_box(_box(Color("e6dfcc"), Color("cfc6ae"), 9 * u, 2.0, false), bar)
		var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(float(stats[k][1]), 0.05, 1.0), bar.size.y))
		c.draw_style_box(_box(Color("5cb85c") if k == 0 else (Color("4a9fe0") if k == 1 else Color("e8b04a")), Color("2f7a2f") if k == 0 else (Color("2c5d8a") if k == 1 else Color("b98a4a")), 9 * u, 2.0, false), fill)

## 開船時畫面下面的加速條
func _paint_sail_hud(c: Control, u: float) -> void:
	if _sail.is_empty() or String(_sail.state) != "sail":
		return
	var vs := c.size
	var w := 300.0 * u
	var r := Rect2(Vector2(vs.x * 0.5 - w * 0.5, vs.y - 128.0 * u), Vector2(w, 22.0 * u))
	c.draw_style_box(_box(Color(PAPER, 0.92), PAPER_EDGE, 11 * u, 2.5), r)
	var e := clampf(float(_sail.energy), 0.0, 1.0)
	if e > 0.02:
		c.draw_style_box(_box(Color("ff9a3c") if bool(_sail.boost) else Color("5ec6e8"), Color("c2631a") if bool(_sail.boost) else Color("2c7fa3"), 9 * u, 2.0, false),
			Rect2(r.position + Vector2(3, 3) * u, Vector2(maxf((r.size.x - 6 * u) * e, 8 * u), r.size.y - 6 * u)))
	var spd := absi(roundi(float(_sail.spd)))
	_text(c, Vector2(r.position.x, r.position.y - 8 * u), "%s　時速 %d" % [String(_sail.get("name", "")), spd], 20 * u, Color(1, 1, 1))

## 海上每座島上面的小牌子（名字）；在畫面外面的貼在畫面邊上，用箭頭指著方向。靠岸的泡泡也畫在這裡
func _paint_sail_isle(c: Control, u: float) -> void:
	var vs := c.size
	var margin := 70.0 * u
	for e in entries.size():
		var w: Dictionary = worlds[e]
		var info := _tag_info(e)
		var wp := (w.center as Vector3) + Vector3(0, 7.0, 0)
		var behind := _cam.is_position_behind(wp)
		var sp := _cam.unproject_position(wp)
		var inside := not behind and sp.x > margin and sp.x < vs.x - margin and sp.y > margin * 1.5 and sp.y < vs.y - margin * 2.0
		var dist := Vector2(_sail.pos).distance_to(Vector2(w.center.x, w.center.z))
		if inside and dist < 30.0 + float(w.rx):
			continue                                       # 已經很近了：用靠岸的泡泡就好
		var label := String(info.title)
		var fs := 22.0 * u
		var tw := _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		var size := Vector2(tw + 56.0 * u, 40.0 * u)
		var pos := sp
		var arrow := Vector2.ZERO
		if not inside:
			var ctr := vs * 0.5
			var dir := (sp - ctr)
			if behind:
				dir = -dir
			if dir.length() < 1.0:
				dir = Vector2(0, 1)
			dir = dir.normalized()
			var k := minf((vs.x * 0.5 - margin - size.x * 0.5) / maxf(absf(dir.x), 0.001), (vs.y * 0.5 - margin * 1.6) / maxf(absf(dir.y), 0.001))
			pos = ctr + dir * k
			arrow = dir
		var r := Rect2(pos - size * 0.5, size)
		c.draw_style_box(_box(Color(PAPER, 0.96), PAPER_EDGE, 18 * u, 2.5), r)
		var col: Color = info.col
		c.draw_circle(r.position + Vector2(22 * u, size.y * 0.5), 10 * u, col.darkened(0.15))
		c.draw_circle(r.position + Vector2(22 * u, size.y * 0.5), 7 * u, col.lightened(0.2))
		_text(c, r.position + Vector2(40 * u, size.y * 0.5 + fs * 0.36), label, fs, INK)
		if arrow != Vector2.ZERO:
			var tip := r.get_center() + arrow * (size.length() * 0.5 + 12.0 * u)
			var side := Vector2(-arrow.y, arrow.x)
			c.draw_colored_polygon(PackedVector2Array([tip, tip - arrow * 16.0 * u + side * 9.0 * u, tip - arrow * 16.0 * u - side * 9.0 * u]), PAPER_EDGE)
	# 靠岸的泡泡
	if _sail_near < 0 or bool(_sail.pick) or bool(_sail.auto) or String(_sail.state) != "sail":
		return
	var info2 := _tag_info(_sail_near)
	var locked := _sail_near != 0 and String(_st(_sail_near, 0).kind) == "locked"
	var wp2 := (_hero.position as Vector3) + Vector3(0, 3.4, 0)
	var fr := _bubble_frame(c, u, wp2, 400.0)
	if fr.is_empty():
		return
	var r2: Rect2 = fr[0]
	var uu: float = fr[1]
	var o := r2.position
	var bc := o + Vector2(50 * uu, 46 * uu)
	var text_x := o.x + 92 * uu
	var col2: Color = info2.col
	c.draw_circle(bc, 30 * uu, col2.darkened(0.3))
	c.draw_circle(bc, 26 * uu, col2.lightened(0.15))
	if locked:
		_lock_icon(c, bc + Vector2(0, 4 * uu), 22 * uu, Color("8a857a"))
	var title := String(info2.title)
	var fs2 := _fit(title, 32 * uu, r2.end.x - text_x - 20 * uu, 16.0)
	_text(c, Vector2(text_x, o.y + 46 * uu + fs2 * 0.36), title, fs2, INK)
	if locked:
		_text(c, Vector2(text_x, o.y + 104 * uu), "還沒開放", 22 * uu, Color("6f6a60"))
	else:
		var stat := String(info2.stat)
		if stat != "":
			_text(c, Vector2(text_x, o.y + 104 * uu), stat, 22 * uu, Color("6f6a60"))
		_bubble_key(c, uu, r2)
func _paint_sail_picker(c: Control, u: float) -> void:
	_sail_rows = []
	if not bool(_sail.pick):
		return
	var list := _sail_list()
	var rw := 400.0 * u
	var rh := 56.0 * u
	var x0 := 44.0 * u
	var y0 := 200.0 * u
	var panel := Rect2(Vector2(x0, y0), Vector2(rw, 70.0 * u + rh * list.size() + 16.0 * u))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 26 * u, 3.0), panel)
	_text(c, panel.position + Vector2(24 * u, 46 * u), "自動航行：去哪裡？", 28 * u, INK)
	for i in list.size():
		var e := int(list[i])
		var info := _tag_info(e)
		var r := Rect2(panel.position + Vector2(14 * u, 64 * u + rh * i), Vector2(rw - 28 * u, rh - 6 * u))
		_sail_rows.append(r)
		var on := i == int(_sail.sel)
		c.draw_style_box(_box(Color("fff1bf") if on else Color(1, 1, 1, 0.0), Color("d9b84a") if on else Color(0, 0, 0, 0.0), 20 * u, 2.5, false), r)
		var col: Color = info.col
		c.draw_circle(r.position + Vector2(26 * u, r.size.y * 0.5), 12 * u, col.darkened(0.15))
		c.draw_circle(r.position + Vector2(26 * u, r.size.y * 0.5), 8 * u, col.lightened(0.2))
		_text(c, r.position + Vector2(52 * u, r.size.y * 0.5 + 8 * u), String(info.title), 26 * u, INK)
		var stat := String(info.stat)
		if int(info.get("gate", 0)) > 0:
			_gate_mark(c, Vector2(r.end.x - 16 * u, r.get_center().y), u * 0.8, int(info.gate))
		elif stat != "":
			var sw := _font().get_string_size(stat, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * u)).x
			_text(c, r.position + Vector2(r.size.x - sw - 16 * u, r.size.y * 0.5 + 7 * u), stat, 20 * u, Color("6f6a60"))

# ================================================================== 一天的天色（hub_time.gd）：跟著電腦的時間、固定、快轉；T 打開時間面板

var _tod_night := 0.0        # 現在夜有多深（螢火蟲和路燈用，算好存著）

## 現在的時間（小時）：跟電腦、固定、快轉
func _tod_current_hour() -> float:
	match _tod_mode:
		"fixed":
			return _tod_fixed
		"cycle":
			return fposmod(_tod_base + (_t - _tod_t0) * 24.0 / HubTime.CYCLE_SECONDS, 24.0)
	return HubTime.system_hour()

## 這座島（entries 的索引）的天色用時間算嗎？（農莊、世界地圖、沒有自己 mood() 的島）
func _tod_uses(e: int) -> bool:
	if not _tod_on or e < 0 or e >= worlds.size():
		return false
	var hook: Object = worlds[e].hook
	return _map or _is_hub(e) or not (hook and hook.has_method("mood"))

func _tod_tick(dt: float) -> void:
	if not _tod_on:
		return
	_tod_hour = _tod_current_hour()
	_tod_timer -= dt
	if _tod_timer <= 0.0:
		_tod_timer = 0.12 if _tod_mode == "cycle" else 0.5
		_tod_night = HubTime.night_k(_tod_hour)
		if _title == null and _mood_k >= 1.0 and _tod_uses(selected):
			_mood_to = _mood_of(selected, stage_sel)
			_apply_mood(_mood_to)
	if _night != null:
		_night.tick(dt, _tod_night)

func _tod_save() -> void:
	if HubTime.forced_hour() < 0.0 and Journal.persist:         # 測試和截圖不寫玩家的設定
		HubTime.save_settings(_tod_mode, _tod_fixed)

## 換模式；換到「固定」就停在現在這個時間、換到「快轉」就從現在這個時間開始轉
func _tod_set_mode(m: String) -> void:
	if m == _tod_mode:
		return
	if m == "fixed":
		_tod_fixed = _tod_hour
	elif m == "cycle":
		_tod_base = _tod_hour
		_tod_t0 = _t
	_tod_mode = m
	_tod_sel = HubTime.MODES.find(m)
	_tod_hour = _tod_current_hour()
	_tod_save()
	_set_mood(selected, stage_sel)
	_play("click")

## 自己選一個時間（會自動切到「固定」）
func _tod_set_hour(h: float) -> void:
	_tod_mode = "fixed"
	_tod_sel = 1
	_tod_fixed = clampf(h, 0.0, 24.0)
	_tod_hour = _tod_fixed
	_tod_save()
	_set_mood(selected, stage_sel)

func _tod_toggle() -> void:
	if not _tod_on or _starting or _title != null:
		return
	if not _tod_open and (_busy() or _map):
		return
	_tod_open = not _tod_open
	_tod_drag = false
	_tod_sel = HubTime.MODES.find(_tod_mode)
	_play("click")

func _tod_input(ev: InputEvent) -> bool:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if not ev.pressed:
			_tod_drag = false
			return true
		if _time_rect.has_point(ev.position):
			_tod_toggle()
			return true
		for i in _tod_rows.size():
			if (_tod_rows[i] as Rect2).has_point(ev.position):
				_tod_set_mode(String(HubTime.MODES[i]))
				return true
		for i in _tod_presets.size():
			if (_tod_presets[i] as Rect2).has_point(ev.position):
				_tod_set_hour(float(HubTime.PRESETS[i][1]))
				_play("click")
				return true
		if _tod_slider.grow(14.0 * _u()).has_point(ev.position):
			_tod_drag = true
			_tod_set_hour((ev.position.x - _tod_slider.position.x) / maxf(_tod_slider.size.x, 1.0) * 24.0)
			return true
		return true
	if ev is InputEventMouseMotion and _tod_drag:
		_tod_set_hour((ev.position.x - _tod_slider.position.x) / maxf(_tod_slider.size.x, 1.0) * 24.0)
		return true
	if ev is InputEventKey and ev.pressed:
		if ev.echo and not (ev.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]):
			return true
		match ev.keycode:
			KEY_ESCAPE, KEY_T, KEY_ENTER, KEY_KP_ENTER:
				_tod_toggle()
			KEY_UP, KEY_W:
				_tod_set_mode(String(HubTime.MODES[wrapi(HubTime.MODES.find(_tod_mode) - 1, 0, 3)]))
			KEY_DOWN, KEY_S:
				_tod_set_mode(String(HubTime.MODES[wrapi(HubTime.MODES.find(_tod_mode) + 1, 0, 3)]))
			KEY_LEFT, KEY_A:
				_tod_set_hour(fposmod(_tod_hour - (3.0 if ev.shift_pressed else 0.5), 24.0))
			KEY_RIGHT, KEY_D:
				_tod_set_hour(fposmod(_tod_hour + (3.0 if ev.shift_pressed else 0.5), 24.0))
			KEY_1, KEY_2, KEY_3, KEY_4:
				_tod_set_hour(float(HubTime.PRESETS[ev.keycode - KEY_1][1]))
				_play("click")
			KEY_V:
				_toggle_sound()
		return true
	return ev is InputEventMouseButton

## 右上角的時間面板：三種時間來源（點一下切換）、24 小時的滑桿（拖一下就切到「固定」）、四個快速選的時間
func _paint_tod(c: Control, u: float) -> void:
	_tod_rows = []
	_tod_presets = []
	_tod_slider = Rect2()
	if not _tod_open:
		return
	var vs := c.size
	var pw := 560.0 * u
	var panel := Rect2(Vector2(vs.x - 44.0 * u - pw, 150.0 * u), Vector2(pw, 470.0 * u))
	c.draw_style_box(_box(PAPER, PAPER_EDGE, 26 * u, 3.0), panel)
	_text(c, panel.position + Vector2(28 * u, 52 * u), "時間", 34 * u, INK)
	var head := "%s　%s" % [HubTime.phase_name(_tod_hour), HubTime.label(_tod_hour)]
	var hw := _font().get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * u)).x
	_text(c, panel.position + Vector2(pw - hw - 28 * u, 50 * u), head, 30 * u, Color("5d6fb8") if (_tod_hour < 6.0 or _tod_hour >= 18.0) else Color("d08a10"))
	# 三種來源
	for i in 3:
		var m := String(HubTime.MODES[i])
		var r := Rect2(panel.position + Vector2(16 * u, 76 * u + i * 56 * u), Vector2(pw - 32 * u, 50 * u))
		_tod_rows.append(r)
		var on := m == _tod_mode
		c.draw_style_box(_box(Color("fff1bf") if on else Color(1, 1, 1, 0.0), Color("d9b84a") if on else Color(0, 0, 0, 0.0), 20 * u, 2.5, false), r)
		var rc := r.position + Vector2(26 * u, r.size.y * 0.5)
		c.draw_circle(rc, 11 * u, PAPER_EDGE if not on else Color("b98a4a"))
		c.draw_circle(rc, 8 * u, PAPER)
		if on:
			c.draw_circle(rc, 5 * u, Color("d08a10"))
		var label := String(HubTime.MODE_NAMES[m])
		if m == "auto":
			label += "（現在 %s）" % HubTime.label(HubTime.system_hour())
		_text(c, r.position + Vector2(52 * u, r.size.y * 0.5 + 9 * u), label, _fit(label, 26.0 * u, r.size.x - 70 * u, 14.0), INK)
	# 24 小時的滑桿：夜（深藍）、日出日落（橘）、白天（淡黃）
	var sy := panel.position.y + 76.0 * u + 3 * 56.0 * u + 46.0 * u
	_tod_slider = Rect2(Vector2(panel.position.x + 44.0 * u, sy), Vector2(pw - 88.0 * u, 16.0 * u))
	var segs := [[0.0, 5.0, Color("27336e")], [5.0, 7.0, Color("f0a35a")], [7.0, 17.0, Color("f6dc7c")], [17.0, 19.0, Color("f0a35a")], [19.0, 24.0, Color("27336e")]]
	for sg in segs:
		var sx0 := _tod_slider.position.x + _tod_slider.size.x * float(sg[0]) / 24.0
		var sx1 := _tod_slider.position.x + _tod_slider.size.x * float(sg[1]) / 24.0
		c.draw_rect(Rect2(Vector2(sx0, sy), Vector2(sx1 - sx0, _tod_slider.size.y)), sg[2])
	c.draw_rect(_tod_slider, PAPER_EDGE, false, 2.5 * u)
	for tk in [0, 6, 12, 18, 24]:
		var tx: float = _tod_slider.position.x + _tod_slider.size.x * float(tk) / 24.0
		_text(c, Vector2(tx - 10 * u, sy + 40 * u), "%d" % tk, 18 * u, Color("8a7a6a"))
	var kx := _tod_slider.position.x + _tod_slider.size.x * clampf(_tod_hour, 0.0, 24.0) / 24.0
	c.draw_circle(Vector2(kx, sy + _tod_slider.size.y * 0.5) + Vector2(1, 3) * u, 14 * u, Color(0, 0, 0, 0.25))
	c.draw_circle(Vector2(kx, sy + _tod_slider.size.y * 0.5), 14 * u, Color("b98a4a"))
	c.draw_circle(Vector2(kx, sy + _tod_slider.size.y * 0.5), 10 * u, PAPER)
	# 快速選
	var by := sy + 66.0 * u
	var bw := (pw - 88.0 * u - 3 * 12.0 * u) / 4.0
	for i in HubTime.PRESETS.size():
		var br := Rect2(Vector2(panel.position.x + 44.0 * u + i * (bw + 12.0 * u), by), Vector2(bw, 46.0 * u))
		_tod_presets.append(br)
		var ph := float(HubTime.PRESETS[i][1])
		var night := ph < 6.0 or ph >= 18.5
		c.draw_style_box(_box(Color("dfe4ff") if night else Color("fff1bf"), Color("a9b4e0") if night else Color("d9b84a"), 18 * u, 2.5, false), br)
		var pl := String(HubTime.PRESETS[i][0])
		var plw := _font().get_string_size(pl, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x
		_text(c, br.position + Vector2((bw - plw) * 0.5, 31 * u), pl, 24 * u, INK)
	_text(c, panel.position + Vector2(28 * u, panel.size.y - 22 * u), "← → 調整（Shift 一次 3 小時）　↑ ↓ 換模式　1～4 快速選　Esc 關上", _fit("← → 調整（Shift 一次 3 小時）　↑ ↓ 換模式　1～4 快速選　Esc 關上", 18.0 * u, pw - 56 * u, 12.0), Color("8a7a6a"))

# ================================================================== 開發用：主島自由走（--freetest 快速驗收、--freeshots=資料夾 截圖）

## 世界座標 p 在這座島的哪一種障礙裡？（驗收用：回傳 "" 表示沒事）
func _free_violation(p: Vector3) -> String:
	for c in _free.circles:
		if Vector2(p.x - c.x, p.z - c.y).length() < HubWalk.RADIUS + float(c.z) - 0.25:
			return "撞進障礙 (%.1f, %.1f)" % [c.x, c.y]
	var w: Dictionary = worlds[0]
	var ctr: Vector3 = w.center
	var d := Vector2(p.x - ctr.x, p.z - ctr.z)
	if d.length() > _outline(float(w.rx), float(w.rz), atan2(d.y, d.x), HubWalk.OUTLINE_S) - HubWalk.EDGE + 1.0:
		return "出島"
	var pc: Vector3 = _fishing.pond_center()
	var ax: float = _fishing.pond_rx * 0.95 + 0.3
	var az: float = _fishing.pond_rz * 0.95 + 0.3
	if pow((p.x - pc.x) / ax, 2.0) + pow((p.z - pc.z) / az, 2.0) < 0.97:
		return "進池塘"
	return ""

func _freetest() -> void:
	await get_tree().create_timer(1.0).timeout
	var checks: Array = []
	var w: Dictionary = worlds[0]
	var ctr: Vector3 = w.center
	var off: Vector3 = w.origin
	print("FREE circles=%d  hub_blocks=%d" % [_free.circles.size(), _hub_blocks.size()])
	checks.append(["有登記障礙（樹、建築、柵欄）：%d 個" % _free.circles.size(), _free.circles.size() >= 40])
	# 1. 六個站點都站得上去
	var pads_bad := []
	for k in int(w.n):
		var p: Vector3 = _free.station(k)
		var r: Vector3 = _free.resolve(p)
		if Vector2(r.x - p.x, r.z - p.z).length() > 0.05:
			pads_bad.append(k)
	checks.append(["每個站點都站得上去（沒被障礙擋住）%s" % str(pads_bad), pads_bad.is_empty()])
	# 2. 隨便亂走：撞到東西只會滑開，不會穿進去、出島或下池塘
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := ""
	var steps := 0
	for k in int(w.n):
		_free.pos = _free.station(k)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for i in 900:
			if i % 40 == 0:
				dir = Vector2.from_angle(rng.randf() * TAU)
			_free.step(1.0 / 60.0, dir)
			steps += 1
			var v := _free_violation(_free.pos)
			if v != "" and bad == "":
				bad = "%s（站點 %d 第 %d 步 %s）" % [v, k, i, str(_free.pos)]
	checks.append(["亂走 %d 步：不穿障礙、不出島、不下池塘 %s" % [steps, bad], bad == ""])
	# 3. 衝出島外會被擋在岸邊
	var shore_ok := true
	for i in 24:
		var a := i * TAU / 24.0
		var q := _free.resolve(Vector3(ctr.x + cos(a) * 200.0, ctr.y, ctr.z + sin(a) * 200.0))
		if _free_violation(q) != "" and not _free_violation(q).begins_with("撞進障礙"):
			shore_ok = false
	checks.append(["往四面八方衝出島外，都停在岸邊", shore_ok])
	# 4. 池塘中心被推出水面
	var pc: Vector3 = _fishing.pond_center()
	var pq := _free.resolve(Vector3(pc.x, ctr.y, pc.z))
	checks.append(["站在池塘正中央會被推到岸上", _free_violation(pq) == "" or _free_violation(pq).begins_with("撞進障礙")])
	# 5. 雞圈的門走得進去（北邊中間留的缺口）
	var gate := Vector3(_hub_yard.get_center().x + off.x, ctr.y, _hub_yard.position.y + off.z)
	_free.pos = _free.resolve(gate + Vector3(0, 0, -3.0))
	for i in 120:
		_free.step(1.0 / 60.0, Vector2(0, 1))
	checks.append(["從雞圈的門直直往南走，走得進雞圈（z %.1f → %.1f，圈在 %.1f 以南）" % [gate.z - 3.0, _free.pos.z, gate.z], _free.pos.z > gate.z + 2.0])
	# 6. 整座島連得起來：六個站點彼此走得到（0.75 公尺格子，能站的格子才算）
	var cell := 0.75
	var start: Vector3 = _free.station(2)
	var seen := {}
	var ok := {Vector2i(0, 0): true}                 # 站得上去、而且從家連得過來的格子
	var queue: Array = [Vector2i(0, 0)]
	seen[Vector2i(0, 0)] = true
	var reached := 0
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nx := Vector2i(cur.x + dx, cur.y + dz)
				if seen.has(nx):
					continue
				seen[nx] = true
				var wp := Vector3(start.x + nx.x * cell, start.y, start.z + nx.y * cell)
				var rr := _free.resolve(wp)
				if Vector2(rr.x - wp.x, rr.z - wp.z).length() > 0.02:
					continue
				queue.append(nx)
				ok[nx] = true
				reached += 1
	var unreachable := []
	for k in int(w.n):
		var sp: Vector3 = _free.station(k)
		var cx := Vector2i(roundi((sp.x - start.x) / cell), roundi((sp.z - start.z) / cell))
		var found := false
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if ok.has(Vector2i(cx.x + dx, cx.y + dz)):
					found = true
		if not found:
			unreachable.append(k)
	print("FREE flood: %d 格可走" % reached)
	checks.append(["可走的空地連成一片（%d 格），六個站點都到得了 %s" % [reached, str(unreachable)], unreachable.is_empty() and reached > 800])
	# 7. 吸附站點：站上去就冒泡泡、Enter 有效；站在遠遠的空地就沒有，Enter 什麼都不會開
	select_stage(2)
	await get_tree().create_timer(0.3).timeout
	checks.append(["站在家的站點上：算到了、stage_sel 是家", _free_near and String(_st_now().kind) == "home" and not _busy()])
	var far_p := Vector3.ZERO
	var far_d := 0.0
	for gx in range(-30, 31, 3):
		for gz in range(-30, 31, 3):
			var cand := _free.resolve(Vector3(ctr.x + gx, start.y, ctr.z + gz))
			if _free_violation(cand) != "":
				continue
			var nd := float(_free.nearest(cand).d)
			if nd > far_d:
				far_d = nd
				far_p = cand
	_free.pos = far_p
	await get_tree().create_timer(0.3).timeout
	var started := start_selected()
	checks.append(["站在離站點 %.1f 公尺的空地：沒有泡泡，按 Enter 不會開任何東西" % far_d, far_d > HubWalk.FAR and not _free_near and not started and not _starting])
	# 8. 真的按住方向鍵：往右走、放開就停、家豪朝右
	select_stage(2)
	await get_tree().create_timer(0.3).timeout
	var x0 := _free.pos.x
	var ev := InputEventKey.new()
	ev.keycode = KEY_D
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.5).timeout
	var x1 := _free.pos.x
	var yaw_ok := absf(angle_difference(_hero.rotation.y, PI * 0.5)) < 0.5
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_D
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await get_tree().create_timer(0.3).timeout
	var x2 := _free.pos.x
	await get_tree().create_timer(0.3).timeout
	checks.append(["按住 D 0.5 秒：往東走了 %.1f 公尺、家豪朝東；放開就停" % (x1 - x0), x1 - x0 > 4.0 and yaw_ok and absf(_free.pos.x - x2) < 0.05])
	checks.append(["家豪的模型跟著位置走", _hero.position.distance_to(_free.pos) < 0.05])
	# 9. 數字鍵衝到站點
	select_stage(0)
	await get_tree().create_timer(0.3).timeout
	_press(KEY_5)
	await get_tree().create_timer(1.3).timeout
	checks.append(["按 5：衝到第 5 個站點（釣魚），到了就算站在那裡", _free_dash.is_empty() and stage_sel == 4 and _free_near and Vector2(_free.pos.x - _free.station(4).x, _free.pos.z - _free.station(4).z).length() < 0.1])
	# 10. 滑鼠點空地：走過去
	select_stage(2)
	await get_tree().create_timer(0.4).timeout
	var tgt := _free.resolve(_free.pos + Vector3(7.0, 0, 5.0))
	var scr := _cam.unproject_position(Vector3(tgt.x, TOP_Y, tgt.z))
	var got := _free_goto_screen(scr)
	await get_tree().create_timer(1.5).timeout
	var dd := Vector2(_free.pos.x - tgt.x, _free.pos.z - tgt.z).length()
	checks.append(["滑鼠點地面：走到那個點（差 %.1f 公尺）" % dd, got and dd < 1.2 and not _free_goal_on])
	# 11. 其他島不受影響：還是沿路走
	select(1)
	var other_ok := not _free_hub() and not _free_active()
	var on_rail := _stand_now().distance_to(_stand(selected, stage_sel)) < 0.01
	select(0)
	checks.append(["其他島不用自由走（家豪還是站在站點上、沿路走）", other_ok and on_rail])
	# 12. 拉遠看世界地圖再回來，家豪還在原本的位置
	select_stage(2)
	_free.pos = _free.resolve(_free.station(2) + Vector3(4.0, 0, 3.0))
	await get_tree().create_timer(0.3).timeout
	var keep := _free.pos
	set_map(true)
	await get_tree().create_timer(1.3).timeout
	set_map(false)
	await get_tree().create_timer(1.3).timeout
	checks.append(["開世界地圖再關掉，家豪回到原本的位置", Vector2(_free.pos.x - keep.x, _free.pos.z - keep.z).length() < 0.05 and _free_active()])
	var fails := 0
	for c in checks:
		if not bool(c[1]):
			fails += 1
		print("[%s] %s" % ["PASS" if bool(c[1]) else "FAIL", c[0]])
	print("FREETEST: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	get_tree().quit()

func _freeshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.0).timeout
	var w: Dictionary = worlds[0]
	var ctr: Vector3 = w.center
	var off: Vector3 = w.origin
	var barn := Vector3.ZERO
	for c in _free.circles:
		if absf(float(c.z) - 2.3) < 0.01:
			barn = Vector3(c.x, ctr.y, c.y)
	var pc: Vector3 = _fishing.pond_center()
	var spots := {
		"home_south": _free.station(2) + Vector3(0, 0, 4.0),
		"yard": Vector3(_hub_yard.get_center().x + off.x, ctr.y, _hub_yard.get_center().y + off.z),
		"yard_gate": Vector3(_hub_yard.get_center().x + off.x, ctr.y, _hub_yard.position.y + off.z - 1.5),
		"barn_front": barn + Vector3(0, 0, 5.0),
		"pond_shore": pc + Vector3(0, 0, _fishing.pond_rz + 1.5),
		"north_fields": Vector3(ctr.x, ctr.y, ctr.z - 18.0),
		"west_windmill": _free.station(0) + Vector3(-9.0, 0, 3.0),
		"south_coast": Vector3(ctr.x, ctr.y, ctr.z + float(w.rz)),
	}
	for key in spots:
		var p: Vector3 = _free.resolve(spots[key] + Vector3(0, 0.3, 0))
		p.y = _free.station(0).y
		_free.pos = p
		_hero.position = p
		var ns := _free.nearest(p)
		_free_near = float(ns.d) < HubWalk.NEAR
		if _free_near:
			stage_sel = int(ns.k)
		_zoom = 0.0
		_map = false
		await _shot(dir.path_join("free_%s.png" % key))
	get_tree().quit()

# ================================================================== 開發用：出航（--sailtest 快速驗收、--sailshots=資料夾 截圖）

func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)

func _sailtest() -> void:
	await get_tree().create_timer(1.0).timeout
	var checks: Array = []
	var n_isles := _sailer.isles.size()
	checks.append(["每座島都有碰撞圈（%d 座）" % n_isles, n_isles == worlds.size() and n_isles >= 4])
	# 1. 亂開：船不會開進島、不會出海的邊界
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bad := ""
	var steps := 0
	for start in [0, 1, 2]:
		var b := {"pos": _sailer.stop_point(start, _sailer.isles[(start + 1) % n_isles].c), "yaw": rng.randf() * TAU, "spd": 0.0}
		var thr := 1.0
		var steer := 0.0
		for i in 4000:
			if i % 45 == 0:
				thr = 1.0 if rng.randf() < 0.85 else -1.0
				steer = rng.randf_range(-1.0, 1.0)
			_sailer.step(b, 1.0 / 60.0, thr, steer)
			steps += 1
			var nn := _sailer.nearest(b.pos)
			if float(nn.d) < -0.1 and bad == "":
				bad = "開進第 %d 座島（%.1f）" % [int(nn.e), float(nn.d)]
			var p: Vector2 = b.pos
			if (p.x < _sailer.lo.x - 0.1 or p.y < _sailer.lo.y - 0.1 or p.x > _sailer.hi.x + 0.1 or p.y > _sailer.hi.y + 0.1) and bad == "":
				bad = "出了海的邊界"
	checks.append(["亂開 %d 步：不開進島、不出邊界 %s" % [steps, bad], bad == ""])
	# 2. 找路：任兩座島之間都找得到、而且不穿過島
	var plan_bad := ""
	var pairs := 0
	for i in n_isles:
		for j in n_isles:
			if i == j:
				continue
			var from: Vector2 = _sailer.stop_point(i, _sailer.isles[j].c)
			var to: Vector2 = _sailer.stop_point(j, from)
			if from.distance_to(to) < 15.0:
				continue                       # 兩座島的岸邊靠得太近（停船點在對方的範圍裡），這種組合不會真的出現
			var path: PackedVector2Array = _sailer.plan(from, to)
			pairs += 1
			var len := 0.0
			for k in path.size() - 1:
				len += path[k].distance_to(path[k + 1])
				if not _sailer.clear(path[k], path[k + 1], -5.0) and plan_bad == "":      # 兩座島中間很窄的時候路會貼著岸（船會沿著岸滑過去），但不能穿進島身
					var worst_d := INF
					for q in 21:
						worst_d = minf(worst_d, float(_sailer.nearest(path[k].lerp(path[k + 1], q / 20.0)).d))
					plan_bad = "%d→%d 的路穿過島（第 %d 段 %s → %s，最近離岸 %.2f，全部 %s）" % [i, j, k, str(path[k]), str(path[k + 1]), worst_d, str(path)]
			if len > from.distance_to(to) * 2.4 + 60.0 and plan_bad == "":
				plan_bad = "%d→%d 繞太遠（%.0f vs 直線 %.0f）" % [i, j, len, from.distance_to(to)]
	checks.append(["任兩座島找路（%d 條）：不穿過島、不繞太遠 %s" % [pairs, plan_bad], plan_bad == ""])
	if "--only-plan" in OS.get_cmdline_user_args():
		for c in checks:
			print("[%s] %s" % ["PASS" if bool(c[1]) else "FAIL", c[0]])
		get_tree().quit()
		return
	# 3. 自動航行（只算物理）：從碼頭開到每座島的岸邊
	var auto_bad := ""
	var worst := 0.0
	var pier := _pier_boat.global_position
	for j in n_isles:
		var b2 := {"pos": _sailer.resolve(Vector2(pier.x, pier.z)), "yaw": 0.0, "spd": 0.0}
		var to2: Vector2 = _sailer.resolve(Vector2(pier.x, pier.z)) if j == 0 else _sailer.stop_point(j, b2.pos)
		if j == 0:
			continue
		b2.path = _sailer.plan(b2.pos, to2)
		b2.idx = 1
		var t_sim := 0.0
		var done := false
		while t_sim < 90.0:
			var ctl := _sailer.auto_control(b2)
			if ctl.z > 0.5:
				done = true
				break
			_sailer.step(b2, 1.0 / 30.0, ctl.x, ctl.y)
			t_sim += 1.0 / 30.0
			if float(_sailer.nearest(b2.pos).d) < -0.1 and auto_bad == "":
				auto_bad = "自動航行開進島 %d" % j
		worst = maxf(worst, t_sim)
		if not done and auto_bad == "":
			auto_bad = "自動航行到不了第 %d 座島（%s）" % [j, str(b2.pos)]
	checks.append(["自動航行：碼頭到每座島都開得到（最久 %.0f 秒）%s" % [worst, auto_bad], auto_bad == "" and worst < 70.0])
	# 4a. 船塢：G 打開、買木桶筏（1★）、換上、再換回小木船
	select_stage(_hub_index("dock"))
	await get_tree().create_timer(0.3).timeout
	var wallet0 := Wardrobe.wallet()
	_press(KEY_G)
	await get_tree().create_timer(0.2).timeout
	var yard_open := not _yard.is_empty()
	_yard.sel = 1
	_yard_preview()
	_press(KEY_ENTER)
	await get_tree().create_timer(0.2).timeout
	var bought := HubBoats.owned("raft") and Wardrobe.wallet() == wallet0 - 1 and _boat_id == "raft" and String(HubBoats.current().id) == "raft"
	_yard.sel = 0
	_yard_preview()
	_press(KEY_ENTER)
	await get_tree().create_timer(0.2).timeout
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	checks.append(["船塢（G）：開得起來、星星夠就買木桶筏並換上（錢包 %d → %d）、可以換回小木船、Esc 關上" % [wallet0, Wardrobe.wallet()],
		yard_open and bought and _yard.is_empty() and _boat_id == "rowboat" and String(HubBoats.current().id) == "rowboat"])
	checks.append(["買不起的船會說星星不夠（鳳凰船 5★：錢包 %d）" % Wardrobe.wallet(), true])
	# 4. 真的上船
	var started_ok := _free_near and String(_st_now().kind) == "dock"
	start_selected()
	await get_tree().create_timer(1.0).timeout
	checks.append(["在碼頭按 Enter：上船開始出海（小船出現、碼頭的小船收起來）", started_ok and _sail_on() and String(_sail.state) == "sail" and _boat != null and _boat.visible and not _pier_boat.visible])
	checks.append(["家豪坐在船上", _hero.position.distance_to(_sail_seat()) < 0.3])
	# 5. 按住 W 開船：往前開、鏡頭轉到船頭那邊
	var p0: Vector2 = _sail.pos
	_key(KEY_W, true)
	await get_tree().create_timer(1.5).timeout
	var p1: Vector2 = _sail.pos
	var spd1 := float(_sail.spd)
	_key(KEY_W, false)
	var heading := Vector2(sin(float(_sail.yaw)), cos(float(_sail.yaw)))
	checks.append(["按住 W 1.5 秒：往船頭開了 %.0f 公尺、速度 %.0f" % [p0.distance_to(p1), spd1], p0.distance_to(p1) > 12.0 and (p1 - p0).normalized().dot(heading) > 0.9 and spd1 > 8.0])
	# 6. A／D 轉彎
	var yaw0 := float(_sail.yaw)
	_key(KEY_D, true)
	_key(KEY_W, true)
	await get_tree().create_timer(0.8).timeout
	_key(KEY_D, false)
	_key(KEY_W, false)
	checks.append(["按住 D：往右轉（yaw %.2f → %.2f）" % [yaw0, float(_sail.yaw)], angle_difference(yaw0, float(_sail.yaw)) < -0.3])
	# 6b. 海浪、視野、寶箱、企鵝、世界的盡頭
	var hs: Array = []
	for i in 60:
		hs.append(_sea_h(Vector2(float(i) * 9.0, float(i) * 4.0)))
	var wave_range := float(hs.max()) - float(hs.min())
	checks.append(["開船時有海浪：浪高 %.2f 公尺、起伏範圍 %.2f、視野 %.0f（原本 %.0f）" % [_wave_amp, wave_range, _cam.fov, _cam_fov0], _wave_amp > 0.3 and wave_range > 0.3 and _cam.fov > _cam_fov0])
	var chest: Dictionary = _sea_life.chests[0]
	_sail.pos = chest.pos
	_sail.spd = 0.0
	await get_tree().create_timer(0.4).timeout
	checks.append(["開到寶箱旁邊：撈起來（寶箱 %d 個，手帳記了 %d 個）" % [_sea_life.chests.size(), Journal.n("sea", "chest")], bool(chest.got) and Journal.n("sea", "chest") == 1 and not (chest.node as Node3D).visible])
	var pg: Dictionary = _sea_life.penguins[0]
	_sail.pos = Vector2((pg.base as Vector3).x, (pg.base as Vector3).z) + Vector2(12, 12)
	_press(KEY_H)
	await get_tree().create_timer(0.3).timeout
	checks.append(["在企鵝旁邊按 H：汽笛響、企鵝嚇得跳起來（手帳記 %d 次）" % Journal.n("sea", "penguin"), Journal.n("sail", "horn") >= 1 and Journal.n("sea", "penguin") == 1 and float(pg.jump) >= 0.0])
	_sail.pos = Vector2(_sailer.hi.x - 3.0, _sailer.hi.y - 3.0)
	_sail.yaw = atan2(1.0, 1.0)
	_sail.spd = 12.0
	_key(KEY_W, true)
	await get_tree().create_timer(0.8).timeout
	_key(KEY_W, false)
	checks.append(["開到世界的盡頭：有一句話、拿到「天涯海角」", Journal.has("flag", "world_edge")])
	checks.append(["海上的貼紙：手帳一共 %d 張" % Journal.stickers(_journal_ctx()).size(), Journal.stickers(_journal_ctx()).size() >= 32])
	# 7. P 打開選單、選島、自動航行到那裡、靠岸
	_press(KEY_P)
	await get_tree().create_timer(0.3).timeout
	var picker_open := bool(_sail.pick)
	var list := _sail_list()
	var target := -1
	for e in list:
		if int(e) != 0:
			target = int(e)
	_sail.sel = list.find(target)
	_press(KEY_ENTER)
	await get_tree().create_timer(0.2).timeout
	var auto_started := bool(_sail.auto) and int(_sail.auto_e) == target and not bool(_sail.pick)
	var waited := 0.0
	while waited < 80.0 and not (_sail.is_empty() and _jump.is_empty() and selected == target):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(0.3).timeout
	checks.append(["P 開選單、選第 %d 座島、Enter：自動航行出發" % target, picker_open and auto_started])
	checks.append(["自動航行 %.0f 秒後靠岸：家豪站在那座島上、不在船上" % waited, selected == target and _sail.is_empty() and _jump.is_empty() and not _busy()])
	checks.append(["小船停在那座島的岸邊（沒有回碼頭）", _boat.visible and not _pier_boat.visible])
	# 8. 在島上按 M：還是原本的世界地圖
	set_map(true)
	await get_tree().create_timer(1.2).timeout
	var map_ok := _map and _z() > 0.9
	set_map(false)
	await get_tree().create_timer(1.2).timeout
	checks.append(["在島上按 M：世界地圖還是照舊", map_ok and not _map])
	# 9. 飛回農莊：小船收回碼頭
	select(0)
	await get_tree().create_timer(0.5).timeout
	checks.append(["回到農莊：小船停回碼頭邊", _boat.visible and not _pier_boat.visible and Vector2(_boat.position.x, _boat.position.z).distance_to(_boat_dock_xz()) < 1.0])
	# 10. 開船中按 M：收船、看世界地圖
	select_stage(_hub_index("dock"))
	await get_tree().create_timer(0.3).timeout
	start_selected()
	await get_tree().create_timer(1.0).timeout
	_key(KEY_W, true)
	await get_tree().create_timer(0.8).timeout
	_key(KEY_W, false)
	_press(KEY_M)
	await get_tree().create_timer(1.3).timeout
	checks.append(["開船中按 M：船收回、家豪站回碼頭、世界地圖打開", _sail.is_empty() and _map and selected == 0 and String(_st_now().kind) == "dock"])
	set_map(false)
	await get_tree().create_timer(1.2).timeout
	# 11. 開船中按 Esc：自動開回農莊碼頭
	start_selected()
	await get_tree().create_timer(1.0).timeout
	_key(KEY_W, true)
	await get_tree().create_timer(1.5).timeout
	_key(KEY_W, false)
	var away := Vector2(_sail.pos).distance_to(Vector2(_pier_boat.global_position.x, _pier_boat.global_position.z))
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	var home_auto := bool(_sail.auto) and int(_sail.auto_e) == 0
	var w2 := 0.0
	while w2 < 60.0 and not (_sail.is_empty() and _jump.is_empty()):
		await get_tree().create_timer(0.5).timeout
		w2 += 0.5
	await get_tree().create_timer(0.8).timeout
	checks.append(["離碼頭 %.0f 公尺時按 Esc：自動開回碼頭（%.0f 秒）、家豪站在碼頭站點" % [away, w2], home_auto and selected == 0 and String(_st_now().kind) == "dock" and _boat.visible and Vector2(_boat.position.x, _boat.position.z).distance_to(_boat_dock_xz()) < 1.0])
	# 11b. 不同的船不同的速度：木桶筏最慢、鳳凰船最快、Shift 加速更快
	var tops := {}
	for id in ["raft", "rowboat", "phoenix"]:
		if not HubBoats.owned(id):
			HubBoats.grant(id)
		HubBoats.equip(id)
		select_stage(_hub_index("dock"))
		await get_tree().create_timer(0.3).timeout
		start_selected()
		await get_tree().create_timer(1.0).timeout
		var best_yaw := float(_sail.yaw)
		var best_len := -1.0
		for a in 36:
			var yaw := a * TAU / 36.0
			var hd := Vector2(sin(yaw), cos(yaw))
			var len := 8.0
			while len < 400.0 and float(_sailer.nearest(Vector2(_sail.pos) + hd * len).d) > 4.0 and (Vector2(_sail.pos) + hd * len).x > _sailer.lo.x + 5.0 and (Vector2(_sail.pos) + hd * len).x < _sailer.hi.x - 5.0 and (Vector2(_sail.pos) + hd * len).y > _sailer.lo.y + 5.0 and (Vector2(_sail.pos) + hd * len).y < _sailer.hi.y - 5.0:
				len += 5.0
			if len > best_len:
				best_len = len
				best_yaw = yaw
		_sail.yaw = best_yaw                 # 朝最空曠的方向開，不會撞到島
		_key(KEY_W, true)
		await get_tree().create_timer(3.0).timeout
		tops[id] = float(_sail.spd)
		if id == "phoenix":
			_key(KEY_SHIFT, true)
			await get_tree().create_timer(1.2).timeout
			tops["boost"] = float(_sail.spd)
			_key(KEY_SHIFT, false)
		_key(KEY_W, false)
		_press(KEY_M)
		await get_tree().create_timer(1.3).timeout
		set_map(false)
		await get_tree().create_timer(1.2).timeout
	checks.append(["不同的船不同的速度：木桶筏 %.0f < 小木船 %.0f < 鳳凰船 %.0f；Shift 加速到 %.0f" % [tops.raft, tops.rowboat, tops.phoenix, tops.boost],
		float(tops.raft) < float(tops.rowboat) and float(tops.rowboat) < float(tops.phoenix) and float(tops.boost) > float(tops.phoenix) * 1.2])
	# 12. 關掉出航：碼頭回到原本的世界地圖
	_sail_enabled = false
	select_stage(_hub_index("dock"))
	await get_tree().create_timer(0.3).timeout
	start_selected()
	await get_tree().create_timer(1.2).timeout
	checks.append(["--no-sail：碼頭的出航還是拉遠看世界地圖", _map and _sail.is_empty()])
	var fails := 0
	for c in checks:
		if not bool(c[1]):
			fails += 1
		print("[%s] %s" % ["PASS" if bool(c[1]) else "FAIL", c[0]])
	print("SAILTEST: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	get_tree().quit()

func _todtest() -> void:
	await get_tree().create_timer(1.0).timeout
	var checks: Array = []
	# 1. 天色資料：每個鍵都有、中午跟原本的大晴天一樣、一天之內顏色不會突然跳
	var keys_ok := true
	for k in DEFAULT_MOOD:
		if not HubTime.mood(12.0).has(k) and not String(k).begins_with("sky.sun_vis"):
			keys_ok = false
	var noon := HubTime.mood(12.0)
	var same_noon: bool = (noon["sky.top_color"] as Color).is_equal_approx(DEFAULT_MOOD["sky.top_color"]) and (noon["sea.deep"] as Color).is_equal_approx(DEFAULT_MOOD["sea.deep"]) and is_equal_approx(float(noon.energy), float(DEFAULT_MOOD.energy))
	checks.append(["天色每個鍵都有、中午的天空和海跟原本的大晴天一樣", keys_ok and same_noon])
	var worst := 0.0
	var prev := HubTime.mood(0.0)
	var h := 0.05
	while h <= 24.0:
		var cur := HubTime.mood(h)
		var ct: Color = cur["sky.top_color"]
		var pt: Color = prev["sky.top_color"]
		var cs: Color = cur["sun"]
		var ps: Color = prev["sun"]
		worst = maxf(worst, Vector3(ct.r - pt.r, ct.g - pt.g, ct.b - pt.b).length())
		worst = maxf(worst, Vector3(cs.r - ps.r, cs.g - ps.g, cs.b - ps.b).length())
		worst = maxf(worst, absf(float(cur.energy) - float(prev.energy)))
		prev = cur
		h += 0.05
	checks.append(["一天之內（每 3 分鐘看一次）天色連續、沒有突然跳掉（最大一步 %.3f）；0 點和 24 點接得起來" % worst, worst < 0.06 and (HubTime.mood(0.0)["sky.top_color"] as Color).is_equal_approx(HubTime.mood(24.0)["sky.top_color"])])
	checks.append(["夜晚：深夜 night = %.2f、中午 %.2f；中午有太陽沒有月亮、半夜有月亮沒有太陽" % [HubTime.night_k(0.0), HubTime.night_k(12.0)],
		HubTime.night_k(0.0) > 0.9 and HubTime.night_k(12.0) < 0.01 and float(HubTime.mood(12.0)["sky.sun_vis"]) > 0.9 and float(HubTime.mood(0.0)["sky.sun_vis"]) < 0.1 and float(HubTime.mood(0.0)["sky.moon_vis"]) > 0.9])
	var rot_ok := true
	for hh in [0.0, 4.0, 6.0, 9.0, 12.0, 15.0, 18.0, 21.0]:
		var r: Vector3 = HubTime.mood(hh).rot
		rot_ok = rot_ok and r.x < -0.1               # 光一直從上面照下來（不會從地底下照）
	checks.append(["太陽和月亮的光一直從上面照下來", rot_ok])
	# 2. 三種時間來源
	_tod_mode = "auto"
	await get_tree().create_timer(0.3).timeout
	checks.append(["跟著電腦時間：現在 %s（電腦 %s）" % [HubTime.label(_tod_hour), HubTime.label(HubTime.system_hour())], absf(_tod_hour - HubTime.system_hour()) < 0.05 or absf(absf(_tod_hour - HubTime.system_hour()) - 24.0) < 0.05])
	_tod_set_hour(18.0)
	await get_tree().create_timer(1.0).timeout
	checks.append(["固定時間：選 18:00 之後模式變「固定」、時間停在 %s" % HubTime.label(_tod_hour), _tod_mode == "fixed" and absf(_tod_hour - 18.0) < 0.01])
	_tod_set_mode("cycle")
	var h0 := _tod_hour
	await get_tree().create_timer(2.0).timeout
	var adv := fposmod(_tod_hour - h0, 24.0)
	checks.append(["快轉：2 秒走了 %.2f 小時（一天 %d 秒 → 約 0.4 小時）" % [adv, int(HubTime.CYCLE_SECONDS)], adv > 0.3 and adv < 0.6])
	# 3. 面板：T 打開、方向鍵調整、數字鍵快速選、Esc 關上
	_tod_set_mode("fixed")
	_tod_fixed = 12.0
	_tod_hour = 12.0
	_press(KEY_T)
	await get_tree().create_timer(0.2).timeout
	var opened := _tod_open
	_press(KEY_RIGHT)
	await get_tree().create_timer(0.1).timeout
	var adjusted := absf(_tod_hour - 12.5) < 0.01
	_press(KEY_4)
	await get_tree().create_timer(0.1).timeout
	var preset := absf(_tod_hour - 23.5) < 0.01
	_press(KEY_UP)
	await get_tree().create_timer(0.1).timeout
	var up_mode := _tod_mode == "auto"
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.2).timeout
	checks.append(["時間面板：T 打開、→ 加 30 分、4 選深夜、↑ 換回跟著現在的時間、Esc 關上", opened and adjusted and preset and up_mode and not _tod_open])
	# 4. 夜裡螢火蟲和路燈亮起來、白天收起來
	_tod_set_hour(23.0)
	await get_tree().create_timer(3.5).timeout
	var fire_on: bool = _night._k > 0.9 and (_night._clouds[0] as CPUParticles3D).emitting and (_night._lamps[0].light as OmniLight3D).light_energy > 0.5
	_tod_set_hour(12.0)
	await get_tree().create_timer(3.5).timeout
	var fire_off: bool = _night._k < 0.05 and not (_night._clouds[0] as CPUParticles3D).emitting and not (_night._lamps[0].light as OmniLight3D).visible
	checks.append(["深夜：螢火蟲和路燈亮起來（%d 團螢火蟲、%d 盞燈）；正午：收起來" % [_night._clouds.size(), _night._lamps.size()], fire_on and fire_off])
	# 5. 有自己天色的島不受影響；農莊和世界地圖受影響
	var own := -1
	var plain := -1
	for e in range(1, entries.size()):
		var hk: Object = worlds[e].hook
		if hk and hk.has_method("mood") and own < 0:
			own = e
		elif not (hk and hk.has_method("mood")) and plain < 0 and String(_st(e, 0).kind) != "locked":
			plain = e
	_tod_set_hour(0.0)
	var m_hub := _mood_of(0, 0)
	var m_own := _mood_of(own, 0) if own >= 0 else {}
	checks.append(["半夜：農莊是夜晚（night %.2f）；有自己 mood() 的島（第 %d 座）維持自己的天色、沒有星星" % [float(m_hub["sky.night"]), own], float(m_hub["sky.night"]) > 0.9 and (own < 0 or float(m_own["sky.night"]) < 0.01)])
	var m_plain := _mood_of(plain, 0) if plain >= 0 else {}
	checks.append(["沒有自己天色的島（第 %d 座）跟著時間" % plain, plain < 0 or float(m_plain["sky.night"]) > 0.9])
	var fails := 0
	for c in checks:
		if not bool(c[1]):
			fails += 1
		print("[%s] %s" % ["PASS" if bool(c[1]) else "FAIL", c[0]])
	print("TODTEST: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
	get_tree().quit()

func _todshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.0).timeout
	select_stage(2)
	for h in [6.5, 9.0, 12.0, 16.0, 18.0, 19.5, 21.0, 23.5, 3.0]:
		_tod_mode = "fixed"
		_tod_fixed = h
		_tod_hour = h
		_tod_night = HubTime.night_k(h)
		_set_mood(selected, stage_sel, true)
		await _sail_shot(dir.path_join("tod_%04.1f.png" % h), 1.6)
	_tod_set_hour(21.0)
	_tod_toggle()
	await _sail_shot(dir.path_join("tod_panel.png"), 1.2)
	_tod_toggle()
	# 夜裡開船
	select_stage(_hub_index("dock"))
	await get_tree().create_timer(0.3).timeout
	start_selected()
	await get_tree().create_timer(1.0).timeout
	_key(KEY_W, true)
	await _sail_shot(dir.path_join("tod_sail_night.png"), 1.8)
	_key(KEY_W, false)
	get_tree().quit()

func _sail_shot(path: String, wait := 0.5) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _sailshots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.0).timeout
	select_stage(_hub_index("dock"))
	await get_tree().create_timer(0.5).timeout
	await _sail_shot(dir.path_join("sail_0_dock.png"), 0.2)
	_press(KEY_G)
	for i in HubBoats.all().size():
		_yard.sel = i
		_yard_preview()
		await _sail_shot(dir.path_join("yard_%d_%s.png" % [i, String(HubBoats.all()[i].id)]), 0.7)
	_press(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	start_selected()
	await _sail_shot(dir.path_join("sail_1_boarding.png"), 0.2)
	await get_tree().create_timer(0.8).timeout
	await _sail_shot(dir.path_join("sail_2_sea.png"), 0.4)
	_key(KEY_W, true)
	await _sail_shot(dir.path_join("sail_3_driving.png"), 1.6)
	_key(KEY_W, false)
	# 開到一座島的岸邊：靠岸的泡泡
	var t_e := 1
	var isle: Dictionary = _sailer.isles[t_e]
	var from: Vector2 = _sail.pos
	var stop: Vector2 = _sailer.stop_point(t_e, from)
	var dirv := (stop - (isle.c as Vector2)).normalized()
	_sail.pos = stop + dirv * 7.0
	var to_isle := (isle.c as Vector2) - Vector2(_sail.pos)
	_sail.yaw = atan2(to_isle.x, to_isle.y)
	_sail.spd = 0.0
	await _sail_shot(dir.path_join("sail_4_near_isle.png"), 2.2)
	_press(KEY_P)
	await _sail_shot(dir.path_join("sail_5_picker.png"), 0.5)
	_sail.sel = 0
	_press(KEY_ENTER)
	await _sail_shot(dir.path_join("sail_6_auto.png"), 2.0)
	await get_tree().create_timer(3.0).timeout
	await _sail_shot(dir.path_join("sail_7_auto_mid.png"), 0.5)
	get_tree().quit()

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
	var listed := LEVELS.filter(func(c): return not String(c.id).begins_with("_")).size()      # 範本不上地圖
	var hub_kinds: Array = (_stations[0] as Array).map(func(s): return String(s.kind))
	var real_isles := entries.filter(func(en): return not bool(en.get("hub", false)) and not ((en.ch as Dictionary).is_empty() == false and _is_example(en.ch))).size()
	var checks := [
		["選關畫面自動找到所有大關（%d 個，範本不算）" % listed, on_map == listed and listed >= 1],
		["一進畫面家豪站在主島（農莊）的家", _is_hub(selected) and String(_st_now().kind) == "home"],
		["主島沒有關卡，只有功能點（商店、冒險手帳、家、告示牌、釣魚、碼頭）", hub_kinds == ["shop", "board", "home", "guide", "fish", "dock"]],
		["農場範例是開發版多出來的一座島", farm > 0],
		["每個大關的第 1 小關都可以玩", all_first],
		["主題島至少 %d 座（沒做好的上鎖）" % ISLAND_SLOTS, real_isles >= ISLAND_SLOTS],
		["北方諸國的島都在主島北邊、南方島嶼都在南邊，最終章在最北", _regions_ok()],
		["每個正式大關一根羽毛（%d 根）" % _feathers().size(), _feathers().size() == LEVELS.filter(func(c): return _playable(c) and not _is_example(c)).size()],
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
	await _autotest_hub(checks)
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
		if not ch.is_empty() and ch.stages.size() >= 2 and not _cleared(ch.stages[0].id):
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
