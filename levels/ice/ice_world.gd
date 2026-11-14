extends "res://scripts/world/arena_world.gd"
## 冰雪島共用場地：一整塊浮在海上的雪原，中間是結冰的湖（冰面）、冰洞、薄冰。
## 各小關的 world.gd 寫 extends "res://levels/ice/ice_world.gd"，在 _ice_configure() 裡設定：
##   lakes      結冰的湖（橢圓）：人走上去會滑
##   ponds      冰洞（沿用共用的水池）：人掉進去就出局，家豪會飛過去
##   thin_spots 薄冰：家豪走得過去，人一踩就破
## 戰局規則（人怎麼滑、薄冰怎麼破）寫在 ice_battle.gd。
##
## 外觀的做法（都不影響玩法）：
##   - 地圖本體（雪地＋冰面＋邊緣垂下來的厚雪＋岩壁）是一張網格（art/isle_builder.gd），質感靠 shaders/ 的著色器和 assets/textures/ 的貼圖。
##   - 場上的東西（樹、石頭、雪堆、冰洞口、碎冰、薄冰、浮冰、營火、釣竿、籠子…）都是模型：
##     Kenney 的 CC0 素材包，或本組用 Blender 做的 GLB（見 assets/CREDITS.txt）。
##   - 地圖外面只有天空和海（少量浮冰、幾朵雲）。共用場地的森林、遠山在這裡都收起來。

## 結冰的湖：[{"center": Vector2, "rx": 橫向半徑, "rz": 縱向半徑}]
var lakes: Array = []
## 一開始就在的薄冰：[{"center": Vector2, "r": 半徑}]
var thin_spots: Array = []
## 雪人擺設（會擋路）：[Vector3, ...]
var snowmen: Array = []
## 建好的雪人：[{pos, node, head, home}]（head 是最上面那顆雪球，撞到時會掉下來）
var snowman_nodes: Array = []
## 冰湖邊的松樹（裝飾，會擋路）：[Vector3, ...]
var pines: Array = []
## 要畫成小樹的松樹（pines 裡的序號）。擋路的範圍一樣大，只是矮一半，不會擋住站在後面的人
var low_pines: Array = []
## 雪堆（不擋路）：滑出去停在雪堆旁的人會倒栽進去，只露出兩條腿。[Vector3, ...]
var snow_piles: Array = []
## 工人的冰釣營地（純裝飾）：[{"pos": Vector3, "yaw": 弧度}]，通常放在工人出發點後面
var camps: Array = []
## 外圈裝飾（雪松、石頭）要避開的點，例如籠子、家豪出發點：[Vector3, ...]
var keep_clear: Array = []
## 要不要自動擺外圈裝飾、冰洞釣具、下雪
var decor := true
## 冰湖周圍的擺設（純裝飾）。每一項 {"type": 種類, "pos": Vector3, "yaw": 弧度（可省）, …}：
##   "village"   冰釣小村（小屋、柴堆、雪橇、燈）。"huts": [[往前, 往右, 轉幾度, 大小], ...] 可以自己排小屋
##   "pier"      伸進湖裡的木棧道（往 yaw 方向）
##   "crystals"  發光的冰晶簇
##   "sculptures" 一排三座小冰雕
##   "statue"    一座冰雕。"kind": "penguin"／"fish"，"scale": 大小
##   "boat"      拖上岸的小木船。"scale"、"tilt"（歪幾度）
##   "net"       曬漁網的架子      "rack" 曬魚架      "crates" 一小堆木箱木桶
##   "stall"     夜市攤位（有一盞暖光）。"scale"
##   "string"    一串圓燈籠（兩根柱子中間）
##   "lantern"   一盞立燈（有一圈暖光）
##   "lighthouse" 燈塔（約 6.5 公尺高）　"belltower" 鐘樓（約 7.5 公尺高，yaw = 鐘面朝哪）　都可以給 "scale"
##   "lamps"     路兩旁的燈籠："from"、"to"
##   "creek"     結冰的小溪："from" 是源頭，"to" 通常接到湖邊；最多 3 條
var zones: Array = []
## 這一關的時段：只換光線、天空、海的顏色。
##   "morning" 早晨（低太陽、長影子）　"noon" 正午（頭頂的白光、短影子、最藍的天和海）　"overcast" 陰天細雪（灰白、幾乎沒有影子、雪下得密）
##   "golden" 金色傍晚（金黃的斜陽配藍影子）　"sunset" 黃昏（桃粉的雪、紫色的海）　"dusk" 極光夜（最後一關用）
var mood := "morning"
## 玩家鏡頭的視角（度）。共用場景預設是 72（廣角，遠的東西會變很小）；
## 救企鵝的關卡用 45 左右、鏡頭退遠一點，冰湖才會佔滿畫面中間，看起來像一個小模型。0 = 不改
var camera_fov := 0.0
## 地圖的輪廓（不用設：預設照遊玩範圍算，再自動放大到包住湖、籠子、出發點）。
## 想調就給其中幾項：{"c": Vector2 中心, "rx": 橫向半徑, "rz": 縱向半徑, "seed": 亂數（邊緣的形狀）, "pow": 越大越方}
var isle: Dictionary = {}
## 裝飾要讓開的路線（工人的紅線；家豪的黃線 rescue_world 會自己加）：[[Vector3, Vector3, ...], ...]
var clear_paths: Array = []
## 冰面上要保持乾淨的點（例如兩條路線的交叉點）：周圍 4 公尺不放碎冰之類的小東西。[Vector3, ...]
var clear_spots: Array = []
## 全章收尾（finale_show）建議的鏡頭：站在哪、看哪。不設就照地圖自動算（從南邊高處看整張地圖和北邊的天空）
var finale_cam_pos := Vector3.ZERO
var finale_cam_look := Vector3.ZERO
## 鏡頭前面那片雪地要不要自動放一小堆東西（雪橇、木頭）。關卡自己在 zones 裡擺了前景就關掉；腳印還是會有
var front_props := true

const KH := "res://levels/ice/assets/kenney_holiday/"
const KS := "res://levels/ice/assets/kenney_survival/"
const KP := "res://levels/ice/assets/kenney_platformer/"
const MB := "res://levels/ice/assets/blender/"
const KC := "res://levels/ice/assets/kenney_cubepets/"
const MP := KC                 # （舊名字：以前企鵝在 polypizza/，現在換成 Kenney Cube Pets）
const TX := "res://levels/ice/assets/textures/"
const SH := "res://levels/ice/shaders/"
const Isle := preload("res://levels/ice/art/isle_builder.gd")
const SEA_Y := -3.0            # 海面比雪地低多少

var _jump_fish: Array = []     # 冰洞裡偶爾跳出來的魚 {node, center, phase, r}
var _fires: Array = []         # 營火的光 {light, flame}
var _floaters: Array = []      # 漂在水上的碎冰、浮冰 {node, base, phase, amp}
var _snow_ps: GPUParticles3D
var _clutter: Array = []       # 過關演出時要收起來的小東西（釣竿、水桶、招牌字）
var _clouds: Node3D

## 執行中的薄冰：[{center, r, state ("solid" / "cracking" / "broken"), t, node, water, base, dynamic}]
var thin: Array = []

var _top_mat: ShaderMaterial       # 地圖頂面（雪＋冰＋冰洞）
var _snow_mat: ShaderMaterial      # 只有雪（雪堆模型、模型上的積雪）
var _cliff_mat: ShaderMaterial
var _ice_solid: ShaderMaterial     # 實心的冰（碎冰、冰柱、浮冰、冰雕）
var _wall_mat: ShaderMaterial      # 冰洞口的斷面（比較藍、比較亮）
var _water_mat: ShaderMaterial     # 冰洞裡的水
var _cloud_mat: ShaderMaterial
var _toon_cache := {}              # 模型原本的材質 → 卡通材質（kit_prop.gdshader）
var _tree_cache := {}              # 雪松原本的網格 → 加了頂點色（每層深淺）的網格
var _tree_mats := {}
var _penguin_mats := {}
var _thin_mat: ShaderMaterial      # 薄冰片：自己發光的霜白色（不管什麼時段都比旁邊的冰淺）
var _crack_mat: StandardMaterial3D # 薄冰上的裂痕：不吃光的深藍
var _statue_mat: ShaderMaterial    # 冰雕（比冰湖暗一點、帶一點時段的顏色，不跟冰湖搶）
var _sky_mat: ShaderMaterial
var _glow_mats: Array = []         # 會發光的燈籠材質 {mat, base}（收尾時閃爍）
var _finale_on := false
var _finale_t := 0.0
var _finale_root: Node3D           # 收尾時才有的東西（煙火、肚滑的企鵝）
var _finale_next := 0.0            # 下一發煙火的時間
var _sliders: Array = []           # 收尾時在冰湖上肚滑的企鵝 {node, k}
var _bumpers: Array = []           # 收尾時滑去撞人的企鵝 {node, from, dir, len, extra, start, speed}
var _finale_rng := RandomNumberGenerator.new()

## 每個時段的顏色
##   hor = 天空靠近地平線的顏色，band = 地平線那一條亮帶（海的遠處也是這個顏色），cliff = 冰崖上／中／下的顏色
const MOODS := {
	"morning": {"sun": Color(1.0, 0.93, 0.80), "energy": 1.5, "rot": Vector3(-0.52, 0.70, 0), "amb": Color(0.58, 0.72, 1.0), "amb_e": 0.78,
		"top": Color(0.20, 0.54, 0.93), "hor": Color(0.74, 0.90, 1.0), "band": Color(0.80, 0.93, 1.0), "glow_band": 0.85,
		"cloud": Color(1.0, 1.0, 1.0), "cloud_sh": Color(0.70, 0.82, 0.99), "sun_glow": Color(1.0, 0.92, 0.72), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(0.90, 0.94, 1.0), "snow_shade": Color(0.64, 0.76, 0.98), "exposure": 0.94,
		"ice_glow": 0.20, "ice_lit": 0.80, "sky_tint": Color(0.84, 0.94, 1.0), "water": 1.0, "lamp": 1.0,
		"sea_deep": Color(0.04, 0.27, 0.54), "sea_near": Color(0.10, 0.50, 0.74), "sea_stroke": Color(0.66, 0.92, 0.99), "sea_stroke2": Color(0.22, 0.64, 0.84),
		"cliff": [Color(0.74, 0.95, 0.98), Color(0.24, 0.74, 0.90), Color(0.06, 0.42, 0.70)], "cliff_glow": 0.18},
	"sunset": {"sun": Color(1.0, 0.72, 0.50), "energy": 1.6, "rot": Vector3(-0.55, 1.25, 0), "amb": Color(0.74, 0.66, 0.88), "amb_e": 0.75,
		"top": Color(0.38, 0.40, 0.80), "hor": Color(1.0, 0.72, 0.58), "band": Color(1.0, 0.78, 0.62), "glow_band": 0.85,
		"cloud": Color(1.0, 0.86, 0.78), "cloud_sh": Color(0.86, 0.58, 0.72), "sun_glow": Color(1.0, 0.62, 0.32), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(0.95, 0.94, 0.98), "snow_shade": Color(0.76, 0.76, 0.98), "exposure": 1.0,
		"ice_glow": 0.70, "ice_lit": 0.40, "sky_tint": Color(0.86, 0.94, 1.0), "water": 1.0, "lamp": 1.5,
		"ice_mid": Color(0.14, 0.72, 0.86), "ice_deep": Color(0.04, 0.38, 0.68),
		"statue": [Color(0.44, 0.40, 0.76), Color(0.90, 0.80, 0.96)],
		"sea_deep": Color(0.20, 0.22, 0.54), "sea_near": Color(0.42, 0.36, 0.68), "sea_stroke": Color(1.0, 0.80, 0.74), "sea_stroke2": Color(0.66, 0.50, 0.78),
		"cliff": [Color(0.86, 0.92, 0.98), Color(0.36, 0.72, 0.90), Color(0.16, 0.40, 0.72)], "cliff_glow": 0.40},
	# 正午：太陽在頭頂（影子短短的貼在腳下）、白光、天和海都是最飽和的藍，雪最白
	"noon": {"sun": Color(1.0, 0.99, 0.95), "energy": 1.65, "rot": Vector3(-1.18, 0.5, 0), "amb": Color(0.60, 0.76, 1.0), "amb_e": 0.95,
		"top": Color(0.08, 0.40, 0.92), "hor": Color(0.58, 0.84, 1.0), "band": Color(0.72, 0.92, 1.0), "glow_band": 0.7,
		"cloud": Color(1.0, 1.0, 1.0), "cloud_sh": Color(0.78, 0.88, 1.0), "sun_glow": Color(1.0, 0.98, 0.9), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(0.94, 0.97, 1.0), "snow_shade": Color(0.68, 0.82, 1.0), "exposure": 0.88,
		"ice_glow": 0.18, "ice_lit": 0.80, "sky_tint": Color(0.80, 0.94, 1.0), "water": 1.05, "lamp": 1.0,
		"ice_mid": Color(0.10, 0.70, 0.90), "ice_deep": Color(0.02, 0.36, 0.74),
		"sea_deep": Color(0.01, 0.30, 0.66), "sea_near": Color(0.06, 0.62, 0.84), "sea_stroke": Color(0.86, 0.98, 1.0), "sea_stroke2": Color(0.20, 0.76, 0.92),
		"cliff": [Color(0.78, 0.97, 1.0), Color(0.20, 0.78, 0.94), Color(0.04, 0.44, 0.76)], "cliff_glow": 0.16},
	# 陰天細雪：整片灰白的雲、柔光幾乎沒有影子、灰綠色的海、雪下得密；顏色最淡的一關
	"overcast": {"sun": Color(0.90, 0.93, 1.0), "energy": 0.45, "rot": Vector3(-0.95, 0.9, 0), "amb": Color(0.76, 0.80, 0.88), "amb_e": 1.25,
		"top": Color(0.60, 0.66, 0.76), "hor": Color(0.80, 0.84, 0.90), "band": Color(0.84, 0.87, 0.92), "glow_band": 0.6, "cloud_cover": 1.0,
		"cloud": Color(0.90, 0.92, 0.96), "cloud_sh": Color(0.62, 0.67, 0.76), "sun_glow": Color(0.0, 0.0, 0.0), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(0.90, 0.92, 0.96), "snow_shade": Color(0.72, 0.78, 0.90), "exposure": 0.96, "snow": 1100, "fog_density": 0.006,
		"ice_glow": 0.34, "ice_lit": 0.70, "sky_tint": Color(0.84, 0.88, 0.94), "water": 0.9, "lamp": 1.3,
		"ice_mid": Color(0.26, 0.60, 0.74), "ice_deep": Color(0.10, 0.34, 0.54),
		"sea_deep": Color(0.14, 0.26, 0.36), "sea_near": Color(0.28, 0.44, 0.52), "sea_stroke": Color(0.82, 0.90, 0.93), "sea_stroke2": Color(0.42, 0.58, 0.64),
		"sea_far": Color(0.74, 0.79, 0.85), "fog": Color(0.82, 0.85, 0.90),
		"cliff": [Color(0.80, 0.90, 0.94), Color(0.40, 0.66, 0.78), Color(0.18, 0.40, 0.56)], "cliff_glow": 0.22},
	# 金色傍晚：太陽很低、金黃色的斜光配藍色的長影子，海是深青綠帶金色波光（黃昏那一關是桃粉配紫，分得出來）
	"golden": {"sun": Color(1.0, 0.80, 0.42), "energy": 1.75, "rot": Vector3(-0.36, -1.05, 0), "amb": Color(0.60, 0.68, 0.92), "amb_e": 0.72,
		"top": Color(0.26, 0.50, 0.84), "hor": Color(1.0, 0.86, 0.52), "band": Color(1.0, 0.90, 0.60), "glow_band": 0.9,
		"cloud": Color(1.0, 0.92, 0.70), "cloud_sh": Color(0.86, 0.64, 0.50), "sun_glow": Color(1.0, 0.80, 0.36), "stars": 0.0, "aurora": 0.0,
		"snow_lit": Color(1.0, 0.96, 0.88), "snow_shade": Color(0.58, 0.68, 0.94), "exposure": 0.98,
		"ice_glow": 0.48, "ice_lit": 0.50, "sky_tint": Color(1.0, 0.94, 0.78), "water": 1.0, "lamp": 1.4,
		"ice_mid": Color(0.14, 0.68, 0.84), "ice_deep": Color(0.04, 0.36, 0.66),
		"sea_deep": Color(0.03, 0.26, 0.40), "sea_near": Color(0.22, 0.52, 0.56), "sea_stroke": Color(1.0, 0.92, 0.62), "sea_stroke2": Color(0.56, 0.70, 0.60),
		"statue": [Color(0.22, 0.46, 0.74), Color(0.80, 0.90, 0.98)],
		"cliff": [Color(0.94, 0.94, 0.90), Color(0.30, 0.72, 0.86), Color(0.08, 0.40, 0.66)], "cliff_glow": 0.34},
	# 夜晚：深靛色到青綠的夜空、星星、一條極光；桃紅只留在地平線。海是深青色，跟黃昏的紫色海分得出來。
	"dusk": {"sun": Color(0.74, 0.84, 1.0), "energy": 0.80, "rot": Vector3(-0.62, -0.7, 0), "amb": Color(0.42, 0.48, 0.64), "amb_e": 0.95,
		"aurora_refl": 1.0, "center_lift": 0.14, "statue": [Color(0.16, 0.40, 0.66), Color(0.60, 0.84, 0.94)],
		"top": Color(0.02, 0.04, 0.20), "hor": Color(0.06, 0.34, 0.44), "band": Color(1.0, 0.58, 0.56), "glow_band": 0.85, "band_thin": 26.0,
		"cloud": Color(0.34, 0.50, 0.66), "cloud_sh": Color(0.08, 0.16, 0.34), "sun_glow": Color(0.6, 0.75, 1.0), "stars": 1.0, "aurora": 1.0,
		"snow_lit": Color(0.90, 0.93, 1.0), "snow_shade": Color(0.60, 0.70, 0.90), "exposure": 1.05,
		"ice_glow": 0.46, "ice_lit": 0.60, "sky_tint": Color(0.50, 0.82, 0.92), "water": 1.25, "lamp": 2.6,
		"sea_deep": Color(0.02, 0.09, 0.22), "sea_near": Color(0.04, 0.25, 0.38), "sea_stroke": Color(0.40, 0.88, 0.84), "sea_stroke2": Color(0.08, 0.40, 0.54),
		"sea_far": Color(0.16, 0.24, 0.40), "fog": Color(0.10, 0.28, 0.42),
		"cliff": [Color(0.62, 0.92, 0.96), Color(0.16, 0.62, 0.80), Color(0.05, 0.30, 0.56)], "cliff_glow": 0.55},
}

## 子類別覆寫：設定 lakes、ponds、thin_spots、hero_start、camera_start…
func _ice_configure() -> void:
	pass

func _configure() -> void:
	hill_amount = 0.35
	grass_count = 0
	_ice_configure()
	# 測試用：場景還沒進樹之前用 set_meta 換時段、加薄冰（美術檢查的截圖腳本會用；正式遊戲不會設）
	if has_meta("test_mood"):
		mood = String(get_meta("test_mood"))
	if has_meta("test_thin"):
		thin_spots = thin_spots + (get_meta("test_thin") as Array)
	forest_band = 0.0            # 地圖外面是海，不要共用場地的外圈森林
	_fit_isle()

func _mood() -> Dictionary:
	return MOODS.get(mood, MOODS.morning)

## 暖色燈光的倍率：黃昏、傍晚的燈要夠亮，才照得亮雪地
func _lamp_gain() -> float:
	return float(_mood().lamp)

# ---------------------------------------------------------------- 地形

## 冰湖要平：把地面起伏扣掉，再往下壓一點點
func _extra_height(x: float, z: float) -> float:
	var w := lake_weight(x, z)
	if w <= 0.0:
		return 0.0
	return -(_bumps(x, z) + 0.12) * w

## 共用地形的起伏（跟 arena_world.gd 的公式一樣，用來把湖面整平）
func _bumps(x: float, z: float) -> float:
	var h := (_noise.get_noise_2d(x * 1.1 + 40.0, z * 1.1) * 1.9 + _noise.get_noise_2d(x * 2.6, z * 2.6 + 17.0) * 0.45) * hill_amount
	return h + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.08

## 1 = 在湖裡面，0 = 在湖外面（邊緣平滑過渡）
func lake_weight(x: float, z: float) -> float:
	var best := 0.0
	for l in lakes:
		best = maxf(best, 1.0 - sstep(0.92, 1.12, _lake_e(l, x, z)))
	return best

func _lake_e(l: Dictionary, x: float, z: float) -> float:
	var c: Vector2 = l.center
	return Vector2((x - c.x) / float(l.rx), (z - c.y) / float(l.rz)).length()

## 地圖的輪廓：預設照遊玩範圍；一定要包住會用到的地方（湖、出發點、籠子、松樹、雪人、路線），不夠大就整個放大
func _fit_isle() -> void:
	var base := {"c": (play_min + play_max) * 0.5, "rx": (play_max.x - play_min.x) * 0.5 + 1.5, "rz": (play_max.y - play_min.y) * 0.5 + 1.5,
		"seed": 1.0, "pow": 3.0, "wob": 0.7, "depth": 5.2, "slope": 0.8, "lobe": 2.4}
	base.merge(isle, true)
	isle = base
	var pts: Array = [hero_start]
	pts.append_array(pines)
	pts.append_array(snowmen)
	pts.append_array(snow_piles)
	for l in lakes:
		var lc: Vector2 = l.center
		for k in 8:
			var a := k * TAU / 8.0
			pts.append(Vector3(lc.x + cos(a) * float(l.rx) * 1.2, 0, lc.y + sin(a) * float(l.rz) * 1.2))
	for path in clear_paths:
		pts.append_array(path)
	var cg = get("cage")
	if cg != null:
		pts.append(cg)
	var bp = get("bird_path")
	if bp != null:
		pts.append_array(bp)
	var c: Vector2 = isle.c
	var worst := 0.0
	for p in pts:
		var d := Vector2(p.x - c.x, p.z - c.y)
		worst = maxf(worst, d.length() / Isle.radius(isle, atan2(d.y, d.x)))
	if worst > 0.86:
		isle.rx = float(isle.rx) * worst / 0.86
		isle.rz = float(isle.rz) * worst / 0.86
	if finale_cam_pos == Vector3.ZERO:
		# 收尾鏡頭：站在地圖南邊外面的高處往北看，整張地圖在畫面下半、北邊的天空（極光）在上半
		var south := c.y + float(isle.rz)
		finale_cam_pos = Vector3(c.x + 3.0, 15.0, south + 19.0)
		finale_cam_look = Vector3(c.x, 15.0 - 60.0 * tan(deg_to_rad(7.5)), finale_cam_pos.z - 60.0)

## 地圖頂面看起來的高度：跟 height_at 一樣，但冰洞底下不挖坑（冰面一路平到洞口），湖岸多一圈鼓起來的雪堤
func _top_y(x: float, z: float) -> float:
	var h := height_at(x, z)
	for p in ponds:
		var r: float = p.r
		h += 1.5 * (1.0 - sstep(r - 1.2, r + 0.3, Vector2(x, z).distance_to(p.center)))
	return h + _bank(x, z)

## 湖岸的雪堤：高高低低的一圈，讓湖像是陷在雪地裡（只是看起來鼓起來；路線經過的地方壓平，紅線黃線才不會被蓋住）
func _bank(x: float, z: float) -> float:
	var best := 0.0
	for l in lakes:
		var e := _lake_e(l, x, z)
		if e > 0.96 and e < 1.45:
			var d := (e - 1.0) * (float(l.rx) + float(l.rz)) * 0.5        # 大約離湖岸幾公尺
			var n := 0.60 + 0.40 * sin(x * 1.3 + z * 0.7) * sin(z * 1.1 - x * 0.5) + 0.22 * sin(x * 2.9 + z * 3.3)
			best = maxf(best, 0.34 * sstep(-0.05, 0.55, d) * (1.0 - sstep(0.8, 2.4, d)) * clampf(n, 0.2, 1.2))
	if best > 0.0:
		best *= sstep(0.8, 1.9, _path_dist(x, z))
		for p in ponds:
			best *= sstep(float(p.r) + 1.0, float(p.r) + 3.0, Vector2(x, z).distance_to(p.center))   # 冰洞旁邊也壓平（特寫鏡頭貼著冰洞拍）
	return best

# ---------------------------------------------------------------- 給戰局用的查詢

## 這裡是不是冰面（人會滑）
func on_ice(x: float, z: float) -> bool:
	for l in lakes:
		if _lake_e(l, x, z) < 1.0:
			return true
	return false

## 薄冰破掉的地方也算水
func in_water(x: float, z: float) -> bool:
	if super(x, z):
		return true
	for th in thin:
		if th.state == "broken" and Vector2(x, z).distance_to(th.center) < float(th.r) - 0.15:
			return true
	return false

## 水面高度：冰洞底下的地形是挖下去的，水面取洞口外一圈的高度；不在冰洞裡就是地面
func water_surface_y(x: float, z: float) -> float:
	for p in ponds:
		var c: Vector2 = p.center
		var r: float = p.r
		if Vector2(x, z).distance_to(c) < r + 0.3:
			var y := -INF
			for k in 8:
				var a := k * TAU / 8.0
				y = maxf(y, height_at(c.x + cos(a) * (r + 0.4), c.y + sin(a) * (r + 0.4)))
			return y
	return height_at(x, z)

## 雪人頭掉下來（被撞到的時候）；重試時放回去
func reset_snowmen() -> void:
	for sn in snowman_nodes:
		var h := sn.head as Node3D
		if h.get_parent() != sn.node:
			h.get_parent().remove_child(h)
			(sn.node as Node3D).add_child(h)
		h.transform = sn.home

## 這一點底下是哪一塊還沒破的薄冰（沒有回傳 -1）
func thin_at(x: float, z: float, margin := 0.0) -> int:
	for i in thin.size():
		var th: Dictionary = thin[i]
		if th.state != "broken" and Vector2(x, z).distance_to(th.center) < float(th.r) - margin:
			return i
	return -1

## 薄冰破掉：冰片消失，露出洞和水；碎冰往外噴、濺一圈水花（純畫面）
func break_thin(i: int) -> void:
	var th: Dictionary = thin[i]
	th.state = "broken"
	th.t = 0.0
	(th.node as Node3D).visible = false
	(th.water as Node3D).visible = true
	_refresh_holes()
	_break_fx(th)

func _break_fx(th: Dictionary) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var c := Vector3(th.center.x, height_at(th.center.x, th.center.y), th.center.y)
	var r: float = th.r
	var holder := Node3D.new()
	(th.water as Node3D).get_parent().add_child(holder)
	for k in 7:
		var a := k * TAU / 7.0 + 0.4
		var ch := _prop(holder, MB + "ice_chunk_" + ["e", "b", "a"][k % 3] + ".glb", c + Vector3(cos(a), 0, sin(a)) * r * 0.6, a, 0.22)
		if ch == null:
			continue
		# 碎冰要小、貼著冰面飛、很快縮掉：掉洞特寫的鏡頭就在洞邊，不能擋到泡在洞裡的人的臉
		var out := c + Vector3(cos(a), 0, sin(a)) * (r + 0.5 + 0.5 * (k % 2))
		var tw := ch.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ch, "position:x", out.x, 0.35)
		tw.tween_property(ch, "position:z", out.z, 0.35)
		tw.tween_property(ch, "position:y", c.y + 0.28, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(ch, "rotation:x", 3.0 + k, 0.35)
		tw.tween_property(ch, "scale", Vector3.ONE * 0.02, 0.2).set_delay(0.2)
		tw.chain().tween_property(ch, "position:y", c.y - 0.3, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	var ps := GPUParticles3D.new()
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.amount = 22
	ps.lifetime = 0.45
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = r * 0.8
	pm.emission_ring_inner_radius = r * 0.4
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, -9.0, 0)
	ps.process_material = pm
	ps.draw_pass_1 = _spark_quad(Color(0.9, 0.98, 1.0), 0.18, false)
	ps.position = c + Vector3(0, 0.1, 0)
	holder.add_child(ps)
	ps.emitting = true
	get_tree().create_timer(0.7).timeout.connect(holder.queue_free)

## 多一塊薄冰（鹽撒下去會用到）；parent 放 bt.fx_root，重試時會一起刪掉
func add_thin(center: Vector2, r: float, parent: Node3D) -> int:
	var th := _make_thin(center, r, parent)
	th.dynamic = true
	thin.append(th)
	return thin.size() - 1

## 重試：薄冰恢復原狀，鹽做出來的薄冰拿掉
func reset_ice() -> void:
	reset_snowmen()
	for i in range(thin.size() - 1, -1, -1):
		var th: Dictionary = thin[i]
		if th.dynamic:
			thin.remove_at(i)
			continue
		th.state = "solid"
		th.t = 0.0
		(th.node as Node3D).visible = true
		(th.node as Node3D).position = th.base
		(th.water as Node3D).visible = false
	_refresh_holes()

# ---------------------------------------------------------------- 小工具

## 放一個模型（找不到檔案就回傳 null，不會讓關卡壞掉）。放進場景後材質會換成這一關的卡通材質（見 _restyle）
func _prop(parent: Node3D, path: String, pos: Vector3, yaw := 0.0, scale := 1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("冰雪島：找不到模型 " + path)
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	_restyle(n)
	return n

func _g(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)

## (x, z) 離「要讓開的路線」多遠（家豪的黃線、工人的紅線）；沒有路線回傳很大的數
func _path_dist(x: float, z: float) -> float:
	var paths: Array = clear_paths.duplicate()
	var bp = get("bird_path")
	if bp != null and not (bp as Array).is_empty():
		var route: Array = [hero_start]
		route.append_array(bp)
		paths.append(route)
	var q := Vector2(x, z)
	var best := 999.0
	for path in paths:
		for i in (path as Array).size() - 1:
			var a := Vector2(path[i].x, path[i].z)
			var b := Vector2(path[i + 1].x, path[i + 1].z)
			var ab := b - a
			var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, q.distance_to(a + ab * t))
	return best

## (x, z) 是不是在冰洞旁邊（過關特寫的鏡頭貼著冰洞拍，旁邊不能有會擋鏡頭的東西）
func _near_hole(x: float, z: float, margin: float) -> bool:
	for p in ponds:
		if Vector2(x, z).distance_to(p.center) < float(p.r) + margin:
			return true
	for t in thin_spots:          # 薄冰破了就是冰洞，一樣要讓開
		if Vector2(x, z).distance_to(t.center) < float(t.r) + margin:
			return true
	return false

## (x, z) 是不是壓在薄冰上或緊貼著（小東西——碎冰、釣具——不能蓋住薄冰，不然看不出那塊冰不一樣）
func _on_thin(x: float, z: float, margin := 0.7) -> bool:
	for t in thin_spots:
		if Vector2(x, z).distance_to(t.center) < float(t.r) + margin:
			return true
	return false

## 模型的材質換成這一關的著色器：
##   Blender 裡取了名字的材質（snow、ice、water…）換成對應的雪／冰／水著色器；
##   其他的（Kenney 素材包的色票貼圖、木頭、石頭…）換成共用的卡通材質，光影和細節才會跟整個場景一致。
func _restyle(n: Node3D, shadows := true) -> void:
	if n == null:
		return
	var base_y := n.global_position.y if n.is_inside_tree() else -1000.0
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("base_y", base_y)       # 卡通材質用：離地面越近越暗
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			match String(mat.resource_name) if mat else "":
				"snow": mi.set_surface_override_material(i, _snow_mat)
				"ice": mi.set_surface_override_material(i, _ice_solid)
				"ice_wall": mi.set_surface_override_material(i, _wall_mat)
				"water":
					mi.set_surface_override_material(i, _water_mat)
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"cloud": mi.set_surface_override_material(i, _cloud_mat)
				"flame_outer": mi.set_surface_override_material(i, _flame_mat(Color(1.0, 0.36, 0.06), Color(1.0, 0.70, 0.16)))
				"flame_inner": mi.set_surface_override_material(i, _flame_mat(Color(1.0, 0.78, 0.22), Color(1.0, 0.97, 0.70)))
				"thin_ice": mi.set_surface_override_material(i, _thin_mat)
				"crack": mi.set_surface_override_material(i, _crack_mat)
				_:
					var tm := _toon_mat(mat)
					if tm:
						mi.set_surface_override_material(i, tm)

## 一般模型的卡通材質（同一個來源材質只做一份）。半透明的材質（冰晶）不換。
func _toon_mat(src: Material) -> ShaderMaterial:
	var sm := src as BaseMaterial3D
	if sm == null or sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	if _toon_cache.has(sm):
		return _toon_cache[sm]
	var m := ShaderMaterial.new()
	m.shader = load(SH + "kit_prop.gdshader")
	if sm.albedo_texture:
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
	m.set_shader_parameter("tint", sm.albedo_color)
	m.set_shader_parameter("detail_tex", load(TX + "snow_soft.png"))
	if String(sm.resource_name).begins_with("carrot"):
		# 大太陽底下橘色會被曬成金黃色（戴在工人頭上像一根角）：把綠色壓低，怎麼曬都還是紅蘿蔔的橘
		var cc := Color(sm.albedo_color.r * 0.92, sm.albedo_color.g * 0.58, sm.albedo_color.b)
		m.set_shader_parameter("tint", cc)
		m.set_shader_parameter("emission_c", cc * (0.10 + 0.14 * (_lamp_gain() - 1.0)))
		m.set_shader_parameter("ground_shade", 0.0)
		m.set_shader_parameter("detail", 0.0)
	if String(sm.resource_name) == "snowman":
		# 雪人自己帶一點白：夜裡背光的時候才不會變成一顆藍球（頭戴在工人頭上也認得出是雪）
		m.set_shader_parameter("emission_c", Color(0.9, 0.95, 1.0) * (0.06 + 0.12 * (_lamp_gain() - 1.0)))
		m.set_shader_parameter("ground_shade", 0.2)
	if sm.emission_enabled:
		# 會發光的（燈籠）：白天收斂一點，晚上亮一點
		var k := lerpf(0.5, 1.6, clampf((_lamp_gain() - 1.0) / 1.6, 0.0, 1.0)) if String(sm.resource_name).begins_with("lantern_glow") else 1.0
		m.set_shader_parameter("emission_c", sm.emission * sm.emission_energy_multiplier * k)
		if String(sm.resource_name).begins_with("lantern_glow"):
			_glow_mats.append({"mat": m, "base": sm.emission * sm.emission_energy_multiplier * k})
	_toon_cache[sm] = m
	return m

## 東西腳下的一團軟陰影（Decal 貼在雪地上）：東西才像是站在地上，不是浮著
func _blob_shadow(root: Node3D, pos: Vector3, r: float, strength := 0.5) -> void:
	var d := Decal.new()
	d.texture_albedo = load(TX + "shadow_blob.png")
	d.size = Vector3(r * 2.0, 1.0, r * 2.0)
	d.albedo_mix = strength
	d.upper_fade = 0.4
	d.lower_fade = 0.4
	d.position = pos
	root.add_child(d)

func _flame_mat(base: Color, tip: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + "flame.gdshader")
	m.set_shader_parameter("base_c", base)
	m.set_shader_parameter("tip_c", tip)
	m.set_shader_parameter("phase", base.g * 7.0)
	return m

func _warm_light(root: Node3D, p: Vector3, energy := 1.4, rng := 4.5) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = energy * _lamp_gain()
	l.omni_range = rng + 2.5 * (_lamp_gain() - 1.0)
	l.light_specular = 0.0            # 只照亮、不打高光：不然照在冰面上會變成一大顆過曝的白斑
	l.position = p
	root.add_child(l)
	return l

## 放一坨雪堆模型（Blender 做的 4 種：a 長、b 圓、c 一長串、d 小）
func _drift(root: Node3D, pos: Vector3, kind: String, yaw: float, scale: Vector3) -> Node3D:
	var n := _prop(root, MB + "snow_drift_" + kind + ".glb", pos, yaw, 1.0)
	if n:
		n.scale = scale
		_restyle(n, false)
	return n

# ---------------------------------------------------------------- 蓋東西

func _build_extra() -> void:
	_hide_base()
	_make_materials()
	var root := Node3D.new()
	root.name = "Ice"
	add_child(root)
	# 地圖本體：頂面（雪＋冰一張網格）和邊緣的岩壁
	var top := MeshInstance3D.new()
	top.name = "MapTop"
	top.mesh = Isle.build_top(isle, _top_y, 320, 46, 0.85)
	top.material_override = _top_mat
	root.add_child(top)
	var cliff := MeshInstance3D.new()
	cliff.name = "MapCliff"
	cliff.mesh = Isle.build_cliff(isle, func(a: float) -> float:
		var q := Isle.rim_point(isle, a)
		return _top_y(q.x, q.y), 320, 18)
	cliff.material_override = _cliff_mat
	root.add_child(cliff)
	for i in ponds.size():
		_build_hole(root, i)
	for s in thin_spots:
		thin.append(_make_thin(s.center, float(s.r), root))
	_refresh_holes()
	for p in snowmen:
		_snowman(root, p)
	for i in pines.size():
		_pine(root, pines[i], low_pines.has(i))
	for p in snow_piles:
		# 雪堆（工人會倒栽進去的那種）：兩坨疊在一起，比岸邊的雪大
		_drift(root, Vector3(p.x, height_at(p.x, p.z) - 0.05, p.z), "b", p.x, Vector3(1.75, 1.7, 1.75))
		_drift(root, Vector3(p.x + 0.7, height_at(p.x + 0.7, p.z + 0.3) - 0.05, p.z + 0.3), "d", p.x + 1.0, Vector3(1.5, 1.4, 1.5))
	_build_sea(root)
	if decor:
		_build_decor(root)
	_weather()

## 共用場地蓋的東西（地形、遠山、水池）都收起來；地形的碰撞留著（玩家的鏡頭還是會被地面擋住）
func _hide_base() -> void:
	for nm in ["Terrain", "FarGround", "DistantLayers", "RockWall", "Boulders"]:
		var n := find_child(nm, true, false) as Node3D
		if n:
			n.visible = false
	for n in find_children("Pond*", "MeshInstance3D", true, false):
		(n as Node3D).visible = false

## 共用場地最後才蓋的草叢、森林也收起來（這個函式是 _ready 的最後一步）
func _place_player() -> void:
	super()
	for nm in ["Grass", "ForestTrunks", "ForestCrowns"]:
		var n := find_child(nm, true, false) as Node3D
		if n:
			n.visible = false
	# 鏡頭視角：只在這一關的場景裡改（共用的場景檔不動）
	if camera_fov > 0.0:
		var pl := get_node_or_null(player_path)
		var cam := (pl.get_node_or_null("Head/Camera3D") if pl else null) as Camera3D
		if cam:
			cam.fov = camera_fov

func _make_materials() -> void:
	var md := _mood()
	_top_mat = _snow_material()
	var la := PackedVector4Array()
	for l in lakes:
		if la.size() < 4:
			la.append(Vector4(l.center.x, l.center.y, float(l.rx), float(l.rz)))
	_top_mat.set_shader_parameter("lake_count", la.size())
	la.resize(4)
	_top_mat.set_shader_parameter("lakes", la)
	var ca := PackedVector4Array()
	for z in zones:
		if String(z.type) == "creek" and ca.size() < 3:
			ca.append(Vector4(z.from.x, z.from.z, z.to.x, z.to.z))
	_top_mat.set_shader_parameter("creek_count", ca.size())
	ca.resize(3)
	_top_mat.set_shader_parameter("creeks", ca)
	_refresh_holes()
	_snow_mat = _snow_material()
	_cliff_mat = ShaderMaterial.new()
	_cliff_mat.shader = load(SH + "cliff.gdshader")
	_cliff_mat.set_shader_parameter("strata_tex", load(TX + "cliff_strata.png"))
	_cliff_mat.set_shader_parameter("col_top", md.cliff[0])
	_cliff_mat.set_shader_parameter("col_mid", md.cliff[1])
	_cliff_mat.set_shader_parameter("col_low", md.cliff[2])
	_cliff_mat.set_shader_parameter("sea_color", md.sea_near)
	_cliff_mat.set_shader_parameter("glow", md.cliff_glow)
	_cliff_mat.set_shader_parameter("wet_start", -SEA_Y - 0.9)
	_cliff_mat.set_shader_parameter("snow_color", (md.snow_shade as Color).lerp(md.snow_lit, 0.6))
	_ice_solid = ShaderMaterial.new()
	_ice_solid.shader = load(SH + "ice_solid.gdshader")
	_ice_solid.set_shader_parameter("crack_tex", load(TX + "ice_cracks.png"))
	_ice_solid.set_shader_parameter("inner", Color(0.13, 0.56, 0.84))
	_ice_solid.set_shader_parameter("outer", Color(0.74, 0.94, 1.0))
	_ice_solid.set_shader_parameter("frost_top", 0.3)
	_ice_solid.set_shader_parameter("glow", float(md.ice_glow) + 0.14)
	_wall_mat = _ice_solid.duplicate() as ShaderMaterial
	_wall_mat.set_shader_parameter("inner", Color(0.08, 0.60, 0.86))
	_wall_mat.set_shader_parameter("outer", Color(0.55, 0.94, 1.0))
	_wall_mat.set_shader_parameter("frost_top", 0.0)
	_wall_mat.set_shader_parameter("crack_amount", 0.15)
	_wall_mat.set_shader_parameter("glow", float(md.ice_glow) + 0.38)
	_thin_mat = _ice_solid.duplicate() as ShaderMaterial
	_thin_mat.set_shader_parameter("inner", Color(0.74, 0.92, 1.0))
	_thin_mat.set_shader_parameter("outer", Color(1.0, 1.0, 1.0))
	_thin_mat.set_shader_parameter("frost_top", 0.75)
	_thin_mat.set_shader_parameter("crack_amount", 0.5)
	_thin_mat.set_shader_parameter("glow", 0.55)
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_mat.albedo_color = Color(0.06, 0.24, 0.50)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load(SH + "hole_water.gdshader")
	_water_mat.set_shader_parameter("wave_tex", load(TX + "sea_waves.png"))
	_water_mat.set_shader_parameter("brightness", md.water)
	# 冰雕：比冰湖暗、帶一點這個時段的顏色（黃昏是粉紫），在畫面邊上才不會跟冰湖搶焦點
	var sc: Array = md.get("statue", [Color(0.18, 0.44, 0.72), Color(0.64, 0.84, 0.96)])
	_statue_mat = _ice_solid.duplicate() as ShaderMaterial
	_statue_mat.set_shader_parameter("inner", sc[0])
	_statue_mat.set_shader_parameter("outer", sc[1])
	_statue_mat.set_shader_parameter("glow", float(md.ice_glow) * 0.35)
	_statue_mat.set_shader_parameter("crack_amount", 0.2)
	_top_mat.set_shader_parameter("aurora_refl", md.get("aurora_refl", 0.0))
	_top_mat.set_shader_parameter("center_lift", md.get("center_lift", 0.0))
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = load(SH + "cloud_puff.gdshader")
	_cloud_mat.set_shader_parameter("light_c", md.cloud)
	_cloud_mat.set_shader_parameter("shade_c", md.cloud_sh)

func _snow_material() -> ShaderMaterial:
	var md := _mood()
	var m := ShaderMaterial.new()
	m.shader = load(SH + "island_top.gdshader")
	m.set_shader_parameter("crack_tex", load(TX + "ice_cracks.png"))
	m.set_shader_parameter("snow_tex", load(TX + "snow_soft.png"))
	m.set_shader_parameter("snow_lit", md.snow_lit)
	m.set_shader_parameter("snow_shade", md.snow_shade)
	m.set_shader_parameter("ice_glow", md.ice_glow)
	m.set_shader_parameter("ice_lit", md.ice_lit)
	m.set_shader_parameter("sky_tint", md.sky_tint)
	for key in ["ice_mid", "ice_deep", "ice_pale"]:
		if md.has(key):
			m.set_shader_parameter(key, md[key])
	return m

## 頂面要挖空的圓（冰洞＋破掉的薄冰）：有變動就重新告訴著色器（最多 8 個）
func _refresh_holes() -> void:
	if _top_mat == null:
		return
	var ha := PackedVector4Array()
	for p in ponds:
		if ha.size() < 8:
			ha.append(Vector4(p.center.x, p.center.y, float(p.r) * 1.17, 0.0))
	for th in thin:
		if th.state == "broken" and ha.size() < 8:
			ha.append(Vector4(th.center.x, th.center.y, float(th.r) * 1.17, 0.0))
	_top_mat.set_shader_parameter("hole_count", ha.size())
	ha.resize(8)
	_top_mat.set_shader_parameter("holes", ha)
	var ta := PackedVector4Array()
	for th in thin:
		if th.state != "broken" and ta.size() < 8:
			ta.append(Vector4(th.center.x, th.center.y, float(th.r), 0.0))
	_top_mat.set_shader_parameter("thin_count", ta.size())
	ta.resize(8)
	_top_mat.set_shader_parameter("thins", ta)

## 冰洞口的模型（Blender）：一圈被敲破、看得到厚度的冰，上面黏著碎冰，洞裡是水面。模型半徑 1，放大成實際半徑。
func _hole_rim(parent: Node3D, pos: Vector3, r: float, variant: int) -> Node3D:
	var rim := _prop(parent, MB + "ice_hole_rim_" + ["a", "b"][variant % 2] + ".glb", pos, variant * 1.9, 1.0)
	if rim:
		rim.scale = Vector3(r, 1.0, r)
		_restyle(rim, false)
	return rim

## 漂在水上的碎冰（會輕輕晃）
func _floating_chunks(parent: Node3D, center: Vector3, r: float, count: int, rng: RandomNumberGenerator) -> void:
	for k in count:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.68) * r
		var kind: String = ["b", "d", "e"][rng.randi() % 3]
		var fl := _prop(parent, MB + "ice_chunk_" + kind + ".glb", center + Vector3(cos(a) * d, -0.03, sin(a) * d), rng.randf() * TAU, 1.0)
		if fl:
			var s := rng.randf_range(0.7, 1.0) * float({"b": 0.42, "d": 0.32, "e": 0.6}[kind])
			fl.scale = Vector3(s, s * 0.7, s)
			_restyle(fl, false)
			_floaters.append({"node": fl, "base": fl.position, "phase": rng.randf() * TAU, "amp": 1.0})

## 冰洞：頂面挖一個圓（著色器），蓋上破冰的洞口模型；洞邊散幾塊敲下來的碎冰，水上漂著碎冰
func _build_hole(root: Node3D, i: int) -> void:
	var c: Vector2 = ponds[i].center
	var r: float = ponds[i].r
	var ice_y := water_surface_y(c.x, c.y)       # 洞口冰面的高度
	_hole_rim(root, Vector3(c.x, ice_y, c.y), r, i)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 500 + i * 13
	# 洞邊散幾塊敲下來的碎冰：小小的、矮矮的（特寫鏡頭會從各個方向拍冰洞，不能擋到人）
	var n := int(r * 2.0) + 2
	var cam_a := atan2(camera_start.z - c.y, camera_start.x - c.x)
	for k in n:
		var a := k * TAU / n + rng.randf_range(-0.3, 0.3)
		var rr := r * 1.38 + rng.randf_range(0.05, 0.45)
		var kind: String = ["a", "b", "c", "d", "e", "e", "b"][rng.randi() % 7]
		var s := rng.randf_range(0.55, 0.9) * float({"a": 0.50, "b": 0.42, "c": 0.55, "d": 0.34, "e": 0.75}[kind])
		var tilt := Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22))
		var yaw := rng.randf() * TAU
		if absf(angle_difference(a, cam_a)) < 1.0:
			continue
		var px := c.x + cos(a) * rr
		var pz := c.y + sin(a) * rr
		var keep_out := _on_thin(px, pz)
		for sp in clear_spots:
			if Vector2(px - sp.x, pz - sp.z).length() < 4.2:
				keep_out = true
		if keep_out:
			continue
		var ch := _prop(root, MB + "ice_chunk_" + kind + ".glb", Vector3(px, _top_y(px, pz) - 0.03, pz), yaw, 1.0)
		if ch:
			ch.scale = Vector3(s, s * rng.randf_range(0.8, 1.2), s)
			ch.rotation.x = tilt.x
			ch.rotation.z = tilt.y
			_restyle(ch)
	_floating_chunks(root, Vector3(c.x, ice_y - 0.26, c.y), r, 2 + int(r), rng)

## 一塊薄冰：比較白、有放射狀裂痕的冰片（Blender 模型）；破掉之後換成洞口模型（頂面的著色器同時把那一圈挖空）
func _make_thin(center: Vector2, r: float, parent: Node3D) -> Dictionary:
	var y := height_at(center.x, center.y)
	var node := Node3D.new()
	node.name = "ThinIce"
	var base := Vector3(center.x, y + 0.03, center.y)
	node.position = base
	parent.add_child(node)
	var plate := _prop(node, MB + "thin_ice.glb", Vector3.ZERO, center.x * 1.7 + center.y, 1.0)
	if plate:
		plate.scale = Vector3(r, 1.0, r)
		for m in plate.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := Node3D.new()
	water.name = "BrokenIce"
	water.position = Vector3(center.x, y, center.y)
	water.visible = false
	parent.add_child(water)
	_hole_rim(water, Vector3.ZERO, r, int(absf(center.x * 3.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + int(center.x * 31.0 + center.y * 17.0)
	_floating_chunks(water, Vector3(0, -0.26, 0), r, 3, rng)
	# 第二層裂痕（平常藏著，開始裂的時候才從中心長出來）：同一個模型只留裂痕、轉個角度
	var cracks2: Node3D = null
	var extra := _prop(node, MB + "thin_ice.glb", Vector3(0, 0.012, 0), center.x * 1.7 + center.y + 0.45, 1.0)
	if extra:
		extra.scale = Vector3(r, 1.0, r)
		for m in extra.find_children("*", "MeshInstance3D", true, false):
			var emi := m as MeshInstance3D
			emi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if String(emi.name).begins_with("ThinIce"):
				emi.visible = false
		extra.visible = false
		cracks2 = extra
	return {"center": center, "r": r, "state": "solid", "t": 0.0, "node": node, "water": water, "base": base, "dynamic": false, "cracks2": cracks2}

## 雪人（Blender 模型）：頭是獨立的節點，可以被撞下來扣在工人頭上（水桶帽跟著頭走）
func _snowman(parent: Node3D, p: Vector3) -> void:
	var y := height_at(p.x, p.z)
	var node := Node3D.new()
	node.position = Vector3(p.x, y, p.z)
	node.rotation.y = p.x * 0.7
	parent.add_child(node)
	var hd: Node3D = null
	var model := _prop(node, MB + "snowman.glb", Vector3.ZERO, 0.0, 1.0)
	if model:
		hd = model.find_child("Head", true, false) as Node3D
	if hd:
		hd.reparent(node)
	else:
		hd = Node3D.new()             # 模型不見了：留一個空的頭，戰局才不會壞
		hd.position = Vector3(0, 1.68, 0)
		node.add_child(hd)
	_blob_shadow(parent, Vector3(p.x, y, p.z), 1.0)
	snowman_nodes.append({"pos": Vector3(p.x, y, p.z), "node": node, "head": hd, "home": hd.transform})
	obstacles.append([Vector2(p.x, p.z), 0.6])

## 會擋路的雪松（Kenney Holiday Kit）
func _pine(parent: Node3D, p: Vector3, low := false) -> void:
	_tree(parent, 0, Vector3(p.x, height_at(p.x, p.z), p.z), p.x, 1.45 if low else 2.8)
	obstacles.append([Vector2(p.x, p.z), 0.7])

## 放一棵雪松（Kenney Holiday Kit 的 tree-snow-a／b／c），加上每一層的深淺和腳下的陰影
func _tree(root: Node3D, kind: int, pos: Vector3, yaw: float, scale: float) -> Node3D:
	var n := _prop(root, KH + ["tree-snow-a", "tree-snow-b", "tree-snow-c"][kind % 3] + ".glb", pos, yaw, scale)
	_shade_tree(n)
	_blob_shadow(root, pos, 0.6 * scale)
	return n

## 雪松不要平塗：每一層樹葉的底部一圈深綠、積雪的下緣一條亮邊。
## 做法：載入時把每個三角形「在這一層裡的高度」寫進頂點色（同一個網格只算一次），卡通材質再照頂點色上深淺。
func _shade_tree(n: Node3D) -> void:
	if n == null:
		return
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src := mi.mesh
		if src == null:
			continue
		if not _tree_cache.has(src):
			_tree_cache[src] = _tree_mesh(src)
		for i in src.get_surface_count():
			mi.set_surface_override_material(i, null)
		mi.mesh = _tree_cache[src]

func _tree_mesh(src: Mesh) -> Mesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var mat := src.surface_get_material(s) as BaseMaterial3D
		var img: Image = null
		if mat and mat.albedo_texture:
			img = mat.albedo_texture.get_image()
			if img and img.is_compressed():
				img.decompress()
		var col := PackedColorArray()
		col.resize(v.size())
		col.fill(Color(1, 0, 0))
		var n_tri := (idx.size() if not idx.is_empty() else v.size()) / 3
		for t in n_tri:
			var ia: Array = [t * 3, t * 3 + 1, t * 3 + 2]
			if not idx.is_empty():
				ia = [idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]]
			var y0 := minf(v[ia[0]].y, minf(v[ia[1]].y, v[ia[2]].y))
			var y1 := maxf(v[ia[0]].y, maxf(v[ia[1]].y, v[ia[2]].y))
			var snow := 0.0
			if img and not uv.is_empty():
				var u: Vector2 = uv[ia[0]]
				var c := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
				snow = 1.0 if minf(c.r, minf(c.g, c.b)) > 0.7 else 0.0
			for k in 3:
				var vi: int = ia[k]
				var h := 1.0
				if y1 - y0 > 0.02:
					h = (v[vi].y - y0) / (y1 - y0)
				elif not nrm.is_empty() and nrm[vi].y < 0.0:
					h = 0.0                     # 每一層朝下的底面：整片深色
				col[vi] = Color(h, snow, 0.0)
		arr[Mesh.ARRAY_COLOR] = col
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if not _tree_mats.has(mat):
			var tm := _toon_mat(mat)
			if tm:
				tm = tm.duplicate() as ShaderMaterial
				tm.set_shader_parameter("tree_shade", 1.0)
			_tree_mats[mat] = tm
		out.surface_set_material(s, _tree_mats[mat] if _tree_mats[mat] else mat)
	return out

## 企鵝（Kenney Cube Pets，CC0）：方塊身體、大眼睛，跟工人同一家的造型。高度大約 1，臉朝 +Z。
## 素材包裡身體是灰藍色，這裡改成接近黑色（白肚子、橘色嘴和腳不動），加一圈輪廓光：夜裡站在籠子前面也看得出是企鵝。
## 模型自己帶動畫（idle／dance／walk…）：平常播 idle，要換就呼叫 penguin_anim()。
func make_penguin(parent: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(pos.x, height_at(pos.x, pos.z), pos.z)
	node.rotation.y = yaw
	parent.add_child(node)
	var m := _prop(node, KC + "animal-penguin.glb", Vector3.ZERO, 0.0, 0.6)
	if m:
		for c in m.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(i)
				if not _penguin_mats.has(src):
					var pm := _toon_mat(src)
					if pm:
						pm = pm.duplicate() as ShaderMaterial
						var night := clampf((_lamp_gain() - 1.0) / 1.6, 0.0, 1.0)
						pm.set_shader_parameter("dark_body", 1.0)
						pm.set_shader_parameter("rim", 0.30 + 0.45 * night)
						pm.set_shader_parameter("ground_shade", 0.1)
						pm.set_shader_parameter("emission_c", Color(0.9, 0.95, 1.0) * 0.05 * night)
					_penguin_mats[src] = pm
				if _penguin_mats[src]:
					mi.set_surface_override_material(i, _penguin_mats[src])
		penguin_anim(node, "idle")
	return node

## 讓企鵝播某個動畫（循環）。anim 給空字串 = 停在站好的姿勢（之後由程式自己擺翅膀）
func penguin_anim(penguin: Node3D, anim: String) -> void:
	var ap := penguin.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	if anim == "":
		if ap.has_animation("static"):
			ap.play("static")
			ap.advance(0.0)
		ap.pause()
	elif ap.has_animation(anim) and (ap.current_animation != anim or not ap.is_playing()):
		ap.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim, 0.2)

# ---------------------------------------------------------------- 海、天空、光線

## 地圖外面的海：一大片海面（著色器＋波浪筆觸貼圖，沿著地圖輪廓一圈會動的浪花），幾塊浮冰（Blender 模型），天上幾朵厚厚的雲
func _build_sea(root: Node3D) -> void:
	var md := _mood()
	var c: Vector2 = isle.c
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1600, 1600)
	sea.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load(SH + "sea.gdshader")
	sm.set_shader_parameter("wave_tex", load(TX + "sea_waves.png"))
	sm.set_shader_parameter("deep", md.sea_deep)
	sm.set_shader_parameter("near_c", md.sea_near)
	sm.set_shader_parameter("stroke_c", md.sea_stroke)
	sm.set_shader_parameter("stroke2_c", md.sea_stroke2)
	sm.set_shader_parameter("horizon_c", md.get("sea_far", (md.band as Color).lerp(md.sea_near, 0.25)))
	sm.set_shader_parameter("foam_c", (md.sea_stroke as Color).lerp(Color.WHITE, 0.7))
	sm.set_shader_parameter("center", c)
	# 地圖的吃水線（每個方向離中心多遠）：浪花沿著這條線畫
	var rim := PackedFloat32Array()
	for k in 96:
		rim.append(Isle.cliff_radius(isle, k * TAU / 96.0, -SEA_Y))
	sm.set_shader_parameter("rim", rim)
	sea.material_override = sm
	sea.position = Vector3(c.x, SEA_Y, c.y)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808 + int(float(isle.seed) * 100.0)
	# 浮冰：地圖四周漂幾塊，離岸有遠有近
	for k in 9:
		var a := (k + rng.randf_range(-0.35, 0.35)) * TAU / 9.0
		var d := Isle.cliff_radius(isle, a, -SEA_Y) + rng.randf_range(5.0, 26.0)
		var kind: String = ["a", "b", "c", "b", "c"][rng.randi() % 5]
		var fl := _prop(root, MB + "ice_floe_" + kind + ".glb", Vector3(c.x + cos(a) * d, SEA_Y, c.y + sin(a) * d), rng.randf() * TAU, rng.randf_range(0.8, 1.5))
		if fl:
			_restyle(fl, false)
			_floaters.append({"node": fl, "base": fl.position, "phase": rng.randf() * TAU, "amp": 2.0})
	# 雲：五朵有厚度的雲（Blender 模型），低低地掛在地平線上面，特寫鏡頭抬頭就看得到
	_clouds = Node3D.new()
	_clouds.name = "Clouds"
	_clouds.position = Vector3(c.x, 0, c.y)
	root.add_child(_clouds)
	for k in 5:
		var a := (k + rng.randf_range(-0.25, 0.25)) * TAU / 5.0 - 1.2
		var d := rng.randf_range(120.0, 190.0)
		var cl := _prop(_clouds, MB + "cloud_puff_" + ["a", "b", "c"][k % 3] + ".glb", Vector3(cos(a) * d, rng.randf_range(16.0, 34.0), sin(a) * d), a + PI * 0.5, rng.randf_range(6.5, 10.0))
		_restyle(cl, false)

## 光線、天空（依時段）
func _weather() -> void:
	var m := _mood()
	var env_node := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment.duplicate() as Environment
		env.ambient_light_color = m.amb
		env.ambient_light_energy = m.amb_e
		env.tonemap_exposure = m.exposure
		env.fog_enabled = true
		env.fog_light_color = m.get("fog", m.band)
		env.fog_density = m.get("fog_density", 0.0009)
		env.fog_sky_affect = 0.0
		env.fog_sun_scatter = 0.1
		# 不反射天空：黃昏粉紅色的天會把冰面洗成灰紫色（冰的反光由著色器自己畫）
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		# 東西和地面相接的地方暗一點（角色腳下、樹根、雪堆邊）
		env.ssao_enabled = true
		env.ssao_radius = 1.3
		env.ssao_intensity = 2.6
		env.ssao_power = 1.4
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.18
		env.adjustment_contrast = 1.06
		# 雪地很亮：泛光調小、門檻調高，白色才不會糊成一片（介面的 3D 牌子也不會被洗白）
		env.glow_enabled = true
		env.glow_bloom = 0.02
		env.glow_intensity = 0.34
		env.glow_hdr_threshold = 1.25
		var sky := Sky.new()
		var sm := ShaderMaterial.new()
		sm.shader = load(SH + "isle_sky.gdshader")
		sm.set_shader_parameter("top_color", m.top)
		sm.set_shader_parameter("horizon_color", m.hor)
		sm.set_shader_parameter("mist_color", m.band)
		sm.set_shader_parameter("abyss_color", m.get("sea_far", (m.band as Color).lerp(m.sea_near, 0.25)))
		sm.set_shader_parameter("glow_band", m.glow_band)
		sm.set_shader_parameter("cloud_cover", m.get("cloud_cover", 0.0))
		sm.set_shader_parameter("band_thin", m.get("band_thin", 11.0))
		sm.set_shader_parameter("cloud_color", m.cloud)
		sm.set_shader_parameter("cloud_shade", m.cloud_sh)
		sm.set_shader_parameter("sun_glow", m.sun_glow)
		sm.set_shader_parameter("stars", m.stars)
		sm.set_shader_parameter("aurora", m.aurora)
		sky.sky_material = sm
		_sky_mat = sm
		env.sky = sky
		env_node.environment = env
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = m.sun
		sun.light_energy = m.energy
		sun.rotation = m.rot
		sun.shadow_blur = 1.8

# ---------------------------------------------------------------- 裝飾（都是模型：Kenney CC0 素材包＋本組 Blender 自製，見 assets/CREDITS.txt）

func _build_decor(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + int(float(isle.seed) * 100.0)
	for l in lakes:
		_shore_drifts(root, l, rng)
	_rim_decor(root, rng)
	_rim_fence(root)
	# 冰洞＝工人的釣魚洞：旁邊有釣竿、水桶、魚；洞裡的魚偶爾跳出來
	for p in ponds:
		_fishing_hole(root, p.center, float(p.r), rng)
	for c in camps:
		_camp(root, c.pos, float(c.get("yaw", 0.0)))
	for z in zones:
		_zone_item(root, z)
	_foreground(root)
	_snowfall(root)

## zones 裡的一項擺設（種類見最上面的說明）
func _zone_item(root: Node3D, z: Dictionary) -> void:
	var yaw: float = z.get("yaw", 0.0)
	var sc: float = z.get("scale", 1.0)
	var g := Vector3.ZERO
	if z.has("pos"):
		g = _g(z.pos.x, z.pos.z)
	match String(z.type):
		"village": _village(root, z.pos, yaw, z.get("huts", []))
		"pier": _prop(root, MB + "pier.glb", g, yaw, 1.0)
		"crystals": _crystals(root, z.pos, sc)
		"sculptures": _sculptures(root, z.pos, yaw)
		"lamps": _lamps(root, z.from, z.to)
		"creek": _creek_banks(root, z.from, z.to)
		"statue":
			_ice_statue(root, g, (KS + "fish-large.glb") if String(z.get("kind", "penguin")) == "fish" else (KC + "animal-penguin.glb"), yaw, sc)
		"boat":
			var b := _prop(root, MB + "rowboat.glb", g + Vector3(0, -0.12, 0), yaw, sc)
			if b:
				b.rotation.z = float(z.get("tilt", 0.10))
			_blob_shadow(root, g, 2.1 * sc)
		"net":
			_prop(root, MB + "fish_net.glb", g, yaw, sc)
			_blob_shadow(root, g, 1.7 * sc, 0.4)
		"rack":
			_prop(root, KS + "campfire-fishing-stand.glb", g, yaw, 2.2 * sc)
			_blob_shadow(root, g, 0.9 * sc, 0.4)
		"crates":
			_prop(root, KP + "crate.glb", g, yaw + 0.5, 1.7 * sc)
			_prop(root, KS + "barrel.glb", _g(z.pos.x + 1.0 * sc, z.pos.z + 0.35 * sc), yaw, 1.6 * sc)
			_prop(root, KS + "fish-large.glb", g + Vector3(0, 0.86 * sc, 0), yaw + 1.2, 1.2 * sc)
			_blob_shadow(root, g + Vector3(0.4, 0, 0.1), 1.2 * sc)
		"stall":
			_prop(root, MB + "market_stall.glb", g, yaw, 1.25 * sc)
			_blob_shadow(root, g, 1.9 * sc)
			_warm_light(root, g + Vector3(sin(yaw), 0, cos(yaw)) * 1.2 + Vector3(0, 1.9, 0), 1.0, 4.0)
		"string":
			_prop(root, MB + "lantern_string.glb", g, yaw, sc)
			_warm_light(root, g + Vector3(0, 2.3, 0), 1.2, 5.5)
		"lantern":
			_prop(root, KH + "lantern.glb", g, yaw, 1.6 * sc)
			_warm_light(root, g + Vector3(0, 1.7, 0), 1.3, 4.6)
		"lighthouse":
			# 【地標】紅白條紋的燈塔（Blender 模型）：站在石頭底座上，燈室會發光，照亮周圍的雪地
			_prop(root, MB + "lighthouse.glb", g + Vector3(0, -0.1, 0), yaw, sc)
			_blob_shadow(root, g, 3.0 * sc, 0.55)
			_warm_light(root, g + Vector3(0, 6.2 * sc, 0), 2.2, 11.0)
		"belltower":
			# 【地標】木頭鐘樓（Blender 模型）：石頭基座、正面一個鐘面、頂上一口金色的鐘
			_prop(root, MB + "belltower.glb", g + Vector3(0, -0.1, 0), yaw, sc)
			_blob_shadow(root, g, 2.6 * sc, 0.55)
			_warm_light(root, g + Vector3(sin(yaw), 0, cos(yaw)) * 1.8 + Vector3(0, 1.6, 0), 1.0, 4.5)

## 這個位置能不能放外圈的裝飾（在地圖上、不在湖上、冰洞旁、路線上、籠子和出發點旁、其他擺設旁）
func _decor_ok(x: float, z: float, room := 3.4) -> bool:
	if not Isle.inside(isle, x, z, 1.1):
		return false                       # 海灣把岸邊凹進去的地方
	# 冰洞周圍 8 公尺不放高的東西：過關特寫的鏡頭會繞著冰洞拍
	if lake_weight(x, z) > 0.0 or _near_hole(x, z, 8.0) or _path_dist(x, z) < 2.4:
		return false
	var clear: Array = keep_clear.duplicate()
	clear.append(hero_start)
	for c in clear:
		if Vector2(x - c.x, z - c.z).length() < room:
			return false
	for c in camps:
		if Vector2(x - c.pos.x, z - c.pos.z).length() < 5.2:
			return false
	for zn in zones:
		if zn.has("pos"):
			var need: float = {"lighthouse": 4.5, "belltower": 4.0, "village": 7.0, "boat": 3.4, "net": 2.8, "stall": 3.2, "string": 3.4, "statue": 2.4 * float(zn.get("scale", 1.0)) + 1.0,
				"crystals": 3.6, "sculptures": 3.6}.get(String(zn.type), 2.6)
			if Vector2(x - zn.pos.x, z - zn.pos.z).length() < need:
				return false
		if zn.has("from"):
			var a := Vector2(zn.from.x, zn.from.z)
			var ab := Vector2(zn.to.x, zn.to.z) - a
			var t := clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if Vector2(x, z).distance_to(a + ab * t) < 2.6:
				return false
	return true

## 湖岸雪堤上再疊幾坨雪堆模型（半埋在雪裡、有大有小），岸邊才不會是一圈太整齊的隆起
func _shore_drifts(root: Node3D, l: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = l.center
	var rx: float = l.rx
	var rz: float = l.rz
	var n := int((rx + rz) * 0.9)
	for k in n:
		var a := k * TAU / n + rng.randf_range(-0.12, 0.12)
		var kk := rng.randf_range(1.05, 1.15)
		var kind: String = ["a", "b", "c", "d", "a", "c"][rng.randi() % 6]
		var s := rng.randf_range(0.6, 1.1)
		var sy := rng.randf_range(0.5, 0.85)
		var yaw := -a + PI * 0.5 + rng.randf_range(-0.35, 0.35)     # 長邊順著湖岸
		if rng.randf() < 0.35:
			continue                                                  # 隨機缺幾塊
		var bx := c.x + cos(a) * (rx * kk + 0.3)
		var bz := c.y + sin(a) * (rz * kk + 0.3)
		if _path_dist(bx, bz) < 1.7 or _near_hole(bx, bz, 4.5):
			continue
		_drift(root, Vector3(bx, _top_y(bx, bz) - 0.10, bz), kind, yaw, Vector3(s, s * sy, s))

## 地圖外圈一圈：雪松（圓錐形的同一家）、圓鈍的大石、雪堆（不放在湖上、路線上、籠子旁、鏡頭前）
func _rim_decor(root: Node3D, rng: RandomNumberGenerator) -> void:
	var cam2 := Vector2(camera_start.x, camera_start.z)
	var hero2 := Vector2(hero_start.x, hero_start.z)
	var per := (float(isle.rx) + float(isle.rz)) * 0.5
	var n := int(per * 5.0)
	for i in n:
		var a := (i + rng.randf_range(-0.4, 0.4)) * TAU / n
		var q := Isle.rim_point(isle, a, rng.randf_range(1.6, 6.2))
		var roll := rng.randf()
		var yaw := rng.randf() * TAU
		var sc := rng.randf()
		if not _decor_ok(q.x, q.y):
			continue
		var p := Vector3(q.x, height_at(q.x, q.y), q.y)
		# 鏡頭那一側不放高的東西（只放矮矮的雪堆），免得擋住畫面
		if q.distance_to(cam2) < hero2.distance_to(cam2) + 11.0:
			if roll < 0.3:
				_drift(root, p - Vector3(0, 0.07, 0), ["a", "c", "d"][int(sc * 2.99)], yaw, Vector3(1, 0.7, 1) * lerpf(0.6, 1.0, sc))
			continue
		if roll < 0.66:
			_tree(root, int(sc * 2.99), p, yaw, lerpf(1.7, 2.9, fposmod(sc * 3.7, 1.0)))
		elif roll < 0.80:
			var s := lerpf(0.9, 1.5, sc)
			_prop(root, MB + ["snow_rock_a", "snow_rock_b"][int(sc * 1.99)] + ".glb", p - Vector3(0, 0.12, 0), yaw, s)
			_blob_shadow(root, p, 1.3 * s)
		else:
			_drift(root, p - Vector3(0, 0.05, 0), ["a", "b", "c", "d"][int(sc * 3.99)], yaw, Vector3.ONE * lerpf(0.8, 1.5, sc))
	# 邊緣的雪簷底下掛幾串冰柱（Blender 模型）
	for k in int(per * 1.6):
		var a := rng.randf() * TAU
		var q := Isle.rim_point(isle, a, -0.30)
		var rp := Isle.rim_point(isle, a)
		var ic := _prop(root, MB + "icicles_" + ["a", "b", "c"][rng.randi() % 3] + ".glb", Vector3(q.x, _top_y(rp.x, rp.y) - 0.62, q.y), -a + PI * 0.5, rng.randf_range(0.8, 1.6))
		_restyle(ic, false)

## 地圖南緣（家豪出發點後面）的繩欄（Kenney Platformer Kit）：矮矮的，不擋畫面
func _rim_fence(root: Node3D) -> void:
	var c: Vector2 = isle.c
	var a0 := atan2(hero_start.z - c.y + 6.0, hero_start.x - c.x)      # 家豪出發點正後方的邊緣
	for k in range(-5, 6):
		var a := a0 + k * 2.25 / Isle.radius(isle, a0)
		var q := Isle.rim_point(isle, a, 0.8)
		var q2 := Isle.rim_point(isle, a + 0.02, 0.8)
		var t := (q2 - q).normalized()
		_prop(root, KP + "fence-rope.glb", Vector3(q.x, height_at(q.x, q.y) - 0.03, q.y), atan2(-t.y, t.x), 2.3)

func _fishing_hole(root: Node3D, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# 釣具放在冰洞「離鏡頭遠」的那一側，特寫時才不會橫在畫面前面
	var a := atan2(c.y - camera_start.z, c.x - camera_start.x) + rng.randf_range(-0.6, 0.6)
	var ice_y := water_surface_y(c.x, c.y)
	var edge := Vector3(c.x + cos(a) * (r * 1.4 + 0.45), ice_y, c.y + sin(a) * (r * 1.4 + 0.45))
	if _on_thin(edge.x, edge.z, 1.4):
		return                      # 釣具會壓到旁邊的薄冰：這個洞就不擺
	_clutter.append(_prop(root, KS + "bucket.glb", edge, a, 1.4))
	var f := _prop(root, KS + "fish.glb", edge + Vector3(cos(a + 1.3) * 0.55, 0.02, sin(a + 1.3) * 0.55), a + 0.6, 1.2)
	_clutter.append(f)
	if f:
		f.rotation.z = PI * 0.5   # 躺在冰上的魚
	# 釣竿（Blender 模型）：插在洞邊，竿尖伸到洞口上方，魚線垂到水面的浮標
	var bp := Vector3(c.x + cos(a + 0.5) * (r + 0.42), ice_y + 0.05, c.y + sin(a + 0.5) * (r + 0.42))
	_clutter.append(_prop(root, MB + "fishing_rod.glb", bp, atan2(c.x - bp.x, c.y - bp.z), 1.0))
	var jf := _prop(root, KS + "fish.glb", Vector3(c.x, -5, c.y), 0.0, 1.3)
	if jf:
		jf.visible = false
		_jump_fish.append({"node": jf, "center": Vector3(c.x, ice_y - 0.2, c.y), "phase": rng.randf() * 5.0, "r": r})

## 工人的冰釣營地：帳篷、營火＋烤魚架、木桶、木箱、雪橇、燈籠、路標（沒有字）、旗子
func _camp(root: Node3D, p: Vector3, yaw: float) -> void:
	var fw := Vector3(sin(yaw), 0, cos(yaw))
	var rt := fw.cross(Vector3.UP)
	var at := func(f: float, r: float) -> Vector3: return _g(p.x + fw.x * f + rt.x * r, p.z + fw.z * f + rt.z * r)
	_prop(root, KS + "tent.glb", at.call(-1.6, -1.8), yaw + PI, 2.4)
	_blob_shadow(root, at.call(-1.6, -1.8), 2.0)
	var fire_p: Vector3 = at.call(0.4, 0.6)
	_prop(root, KS + "campfire-pit.glb", fire_p, yaw, 1.8)
	_prop(root, KS + "campfire-fishing-stand.glb", fire_p, yaw + 0.3, 1.8)
	_prop(root, KS + "barrel.glb", at.call(-0.6, 2.4), yaw, 1.6)
	_prop(root, KS + "box-large.glb", at.call(-1.4, 2.6), yaw + 0.4, 1.5)
	_prop(root, KS + "box.glb", at.call(-0.9, 3.3), yaw + 0.9, 1.4)
	_blob_shadow(root, at.call(-1.0, 2.8), 1.3)
	_prop(root, KP + "crate-strong.glb", at.call(-2.6, 1.6), yaw + 0.3, 1.9)
	_prop(root, KP + "flag.glb", at.call(-3.0, -0.2), yaw + 0.8, 3.0)
	_prop(root, KH + "sled-long.glb", at.call(1.5, -1.6), yaw + 0.8, 1.8)
	_prop(root, KS + "fish-large.glb", at.call(1.6, -1.6) + Vector3(0, 0.45, 0), yaw + 0.8, 1.3)
	_blob_shadow(root, at.call(1.5, -1.6), 1.2)
	_prop(root, KH + "lantern.glb", at.call(-0.3, -0.6), yaw, 1.6)
	_prop(root, KS + "signpost-single.glb", at.call(1.2, 1.9), yaw + PI, 2.0)
	# 營火：會閃的光＋火焰（Blender 模型＋會晃的著色器）
	var light := _warm_light(root, fire_p + Vector3(0, 0.8, 0), 2.2, 5.0)
	light.light_color = Color(1.0, 0.6, 0.25)
	var flame := _prop(root, MB + "flame.glb", fire_p + Vector3(0, 0.12, 0), yaw, 0.75)
	_restyle(flame, false)
	_fires.append({"light": light, "flame": flame})

## 冰釣小村：幾間小屋（Blender 自製）、柴堆、雪橇、木桶木箱、掛燈。
## huts = [[往前, 往右, 多轉幾度, 大小], ...]（不給就用預設的三間）
func _village(root: Node3D, p: Vector3, yaw: float, huts: Array = []) -> void:
	var fw := Vector3(sin(yaw), 0, cos(yaw))
	var rt := fw.cross(Vector3.UP)
	var at := func(f: float, r: float) -> Vector3: return _g(p.x + fw.x * f + rt.x * r, p.z + fw.z * f + rt.z * r)
	if huts.is_empty():
		huts = [[0.0, 0.0, 0.0, 1.15], [-2.2, 3.0, 0.35, 1.0], [-1.0, -3.2, -0.3, 0.95]]
	for h in huts:
		_prop(root, MB + "fishing_hut.glb", at.call(h[0], h[1]), yaw + float(h[2]), float(h[3]))
		_blob_shadow(root, at.call(h[0], h[1]), 2.2 * float(h[3]))
		if _lamp_gain() > 1.2:
			# 黃昏、傍晚：每間小屋門口一盞暖光
			_warm_light(root, (at.call(float(h[0]) + 1.2, h[1]) as Vector3) + Vector3(0, 1.0, 0), 0.7, 3.0)
	_prop(root, KS + "resource-wood.glb", at.call(-1.9, 1.7), yaw + 0.5, 1.8)
	_prop(root, KH + "sled.glb", at.call(1.9, -1.9), yaw + 1.2, 1.6)
	_prop(root, KS + "barrel.glb", at.call(1.7, 1.5), yaw, 1.5)
	_prop(root, KH + "lantern.glb", at.call(2.0, 0.2), yaw, 1.8)
	_warm_light(root, at.call(2.0, 0.2) + Vector3(0, 1.4, 0))

## 冰晶簇（Blender 自製，半透明會發光）＋淡藍色的光
func _crystals(root: Node3D, p: Vector3, k := 1.0) -> void:
	_prop(root, MB + "ice_crystals.glb", _g(p.x, p.z), p.x, 1.6 * k)
	_prop(root, MB + "ice_crystals.glb", _g(p.x + 1.1 * k, p.z + 0.6 * k), p.x + 1.0, 1.0 * k)
	_prop(root, MB + "ice_crystals.glb", _g(p.x - 0.8 * k, p.z + 0.9 * k), p.x + 2.0, 0.8 * k)
	_blob_shadow(root, _g(p.x, p.z), 1.6 * k, 0.35)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.85, 1.0)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.light_specular = 0.0
	l.position = _g(p.x, p.z) + Vector3(0, 1.4, 0)
	root.add_child(l)

## 一座冰雕：冰台座（Blender 模型）上放一個冰做的模型
func _ice_statue(root: Node3D, q: Vector3, model: String, yaw: float, scale: float) -> void:
	var ped := _prop(root, MB + "ice_pedestal.glb", q + Vector3(0, -0.04, 0), yaw + q.x, 1.0 * maxf(scale / 1.2, 1.0))
	if ped:
		for m in ped.find_children("*", "MeshInstance3D", true, false):
			var pmi := m as MeshInstance3D
			for i in pmi.mesh.get_surface_count():
				var pmat := pmi.mesh.surface_get_material(i)
				if pmat and String(pmat.resource_name) == "ice":
					pmi.set_surface_override_material(i, _statue_mat)
	_blob_shadow(root, q, 0.95 * maxf(scale / 1.2, 1.0), 0.4)
	var st := _prop(root, model, q + Vector3(0, 0.5 * maxf(scale / 1.2, 1.0), 0), yaw, scale)
	if st:
		var ap := st.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.stop()                 # 冰雕不會動
		for m in st.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = _statue_mat

## 冰雕（小）：三座排一排——兩隻冰企鵝、一條冰魚
func _sculptures(root: Node3D, p: Vector3, yaw: float) -> void:
	var rt := Vector3(cos(yaw), 0, -sin(yaw))
	for sp in [[-1.6, KC + "animal-penguin.glb", 0.9], [0.0, KC + "animal-penguin.glb", 1.2], [1.6, KS + "fish-large.glb", 2.2]]:
		var q: Vector3 = p + rt * float(sp[0])
		_ice_statue(root, _g(q.x, q.z), String(sp[1]), yaw, float(sp[2]))

## 鏡頭前面那一片空雪地放一點東西（都矮矮的，不擋家豪和路線）：家豪走過來的一串腳印、左右各一小堆露營的東西
func _foreground(root: Node3D) -> void:
	var c: Vector2 = isle.c
	var h := Vector2(hero_start.x, hero_start.z)
	var south := Isle.rim_point(isle, atan2(h.y + 8.0 - c.y, h.x - c.x), 1.6)
	# 腳印：從地圖南緣一路走到出發點（兩步一張貼圖，稍微歪歪的）
	var steps := int(h.distance_to(south) / 0.9)
	for k in steps:
		var t := (k + 0.5) / maxf(steps, 1.0)
		var q := south.lerp(h, t * 0.86) + Vector2(sin(k * 1.9) * 0.10, 0.0)
		var d := Decal.new()
		d.texture_albedo = load(TX + "bird_tracks.png")
		d.size = Vector3(0.62, 0.8, 0.9)
		d.albedo_mix = 0.85
		d.position = Vector3(q.x, height_at(q.x, q.y), q.y)
		d.rotation.y = atan2(-(h.x - south.x), -(h.y - south.y)) + sin(k * 2.7) * 0.12
		root.add_child(d)
	if not front_props:
		return
	# 左右各一小堆：雪橇＋睡袋、木頭＋鏟子（離路線遠一點）
	# （位置照鏡頭的左右算，不是照家豪：家豪不一定站在畫面正中間；左下角是道具格、右下角是開始鈕，都要讓開）
	for sgn in [-1.0, 1.0]:
		var q := Vector2(camera_start.x + sgn * 5.0, h.y + 0.8)
		if q.distance_to(h) < 3.2 or _path_dist(q.x, q.y) < 2.5 or lake_weight(q.x, q.y) > 0.0 or not Isle.inside(isle, q.x, q.y, 2.0):
			continue
		var g := _g(q.x, q.y)
		if sgn < 0.0:
			_prop(root, KH + "sled.glb", g, 0.7, 1.7)
			_prop(root, KS + "bedroll-packed.glb", _g(q.x - 0.9, q.y + 0.5), 0.3, 1.6)
			_drift(root, _g(q.x + 0.6, q.y - 0.9) - Vector3(0, 0.08, 0), "d", 0.4, Vector3(0.9, 0.7, 0.9))
		else:
			_prop(root, KS + "tree-log.glb", g, -0.5, 1.8)
			var sh := _prop(root, KS + "tool-shovel.glb", _g(q.x + 0.9, q.y - 0.3) + Vector3(0, 0.55, 0), 0.4, 1.8)
			if sh:
				sh.rotation.x = PI * 0.92          # 鏟子倒插在雪裡
			_drift(root, _g(q.x + 0.9, q.y - 0.3) - Vector3(0, 0.06, 0), "b", 1.0, Vector3(0.8, 0.7, 0.8))
		_blob_shadow(root, g, 1.2, 0.4)

## 路兩旁的燈籠（Kenney Holiday Kit），每盞一圈暖光
func _lamps(root: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	d.y = 0.0
	var n := maxi(int(d.length() / 2.5), 1)
	var side := d.normalized().cross(Vector3.UP) * 2.6
	for k in n + 1:
		var q := a.lerp(b, float(k) / n)
		for sgn in [-1.0, 1.0]:
			var pos: Vector3 = q + side * sgn
			_prop(root, KH + "lantern.glb", _g(pos.x, pos.z), 0.0, 1.5)
			_warm_light(root, _g(pos.x, pos.z) + Vector3(0, 1.5, 0), 1.1, 4.0)

## 結冰的小溪：冰面是頂面的著色器畫的（_make_materials 傳位置），這裡只在兩岸放幾坨雪堆
func _creek_banks(root: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	d.y = 0.0
	var n := maxi(int(d.length() / 2.6), 1)
	var side := d.normalized().cross(Vector3.UP)
	for k in n:
		var t0 := (k + 0.5) / n
		var q := a.lerp(b, t0) + side * (sin(t0 * d.length() * 0.75) * 0.55 + (1.7 if k % 2 == 0 else -1.7))
		if lake_weight(q.x, q.z) > 0.0 or _path_dist(q.x, q.z) < 1.7:
			continue
		_drift(root, _g(q.x, q.z) - Vector3(0, 0.08, 0), ["a", "d", "c"][k % 3], atan2(d.x, d.z) + 0.3 * sin(k * 2.0), Vector3(0.8, 0.6, 0.8))

## 下雪：大範圍、慢慢飄的圓雪花
func _snowfall(root: Node3D) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = int(_mood().get("snow", 320))
	ps.lifetime = 9.0
	ps.preprocess = 9.0
	ps.visibility_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 26, 48))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 0.5, 22)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -0.3, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	ps.process_material = pm
	# 雪花是一張朝著鏡頭的小貼圖（中間白、邊緣淡出的圓點）
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_color = Color(1, 1, 1, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 飄到鏡頭前面的雪花會變成一大團白光（特寫鏡頭尤其明顯）：靠近鏡頭 2.5 公尺內就淡出
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.5
	m.distance_fade_max_distance = 6.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.02)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	q.material = m
	ps.draw_pass_1 = q
	ps.position = Vector3(isle.c.x, 18, isle.c.y)
	root.add_child(ps)
	_snow_ps = ps

func _process(dt: float) -> void:
	_animate_decor()
	# 正在裂的薄冰：第二層裂痕從中心往外長（戰局把 state 設成 "cracking" 就會有）
	for th in thin:
		var c2 = th.get("cracks2")
		if c2 != null and is_instance_valid(c2):
			var on: bool = th.state == "cracking"
			(c2 as Node3D).visible = on
			if on:
				var k := clampf(float(th.t) / 0.3, 0.0, 1.0)
				(c2 as Node3D).scale = Vector3.ONE * lerpf(0.35, 1.0, k)
	if _finale_on:
		_tick_finale(dt)

# ---------------------------------------------------------------- 全章收尾的場景效果

## 全章收尾：on = 極光變亮流動（夜晚才有）、夜市（沒有夜市就是營地）上空放煙火、燈籠閃爍、四隻企鵝在冰湖上排成一排肚滑；off = 還原。
## 任何時段都可以呼叫。鏡頭建議擺在 finale_cam_pos、看向 finale_cam_look（從南邊高處看整張地圖和北邊的天空）。
func finale_show(on: bool) -> void:
	if on == _finale_on:
		return
	_finale_on = on
	_finale_t = 0.0
	_finale_next = 0.35
	var m := _mood()
	if _sky_mat:
		_sky_mat.set_shader_parameter("aurora", float(m.aurora) * (1.6 if on else 1.0))
		_sky_mat.set_shader_parameter("aurora_elev", 0.15 if on else 0.28)       # 壓低一點，整條極光才進得了收尾鏡頭
		_sky_mat.set_shader_parameter("aurora_speed", 4.0 if on else 1.0)
	if _top_mat:
		_top_mat.set_shader_parameter("aurora_refl", float(m.get("aurora_refl", 0.0)) * (1.8 if on else 1.0))
	if not on:
		if _finale_root:
			_finale_root.queue_free()
			_finale_root = null
		_sliders.clear()
		_bumpers.clear()
		for g in _glow_mats:
			(g.mat as ShaderMaterial).set_shader_parameter("emission_c", g.base)
		return
	_finale_root = Node3D.new()
	_finale_root.name = "Finale"
	add_child(_finale_root)
	_finale_rng.seed = 20261117
	# 四隻企鵝排成一排，肚子貼著冰面滑過湖（後面拖一道雪痕、濺起冰屑）
	if lakes.is_empty():
		return
	for k in 4:
		var node := _make_slider(Vector3(lakes[0].center.x, 0, lakes[0].center.y))
		_sliders.append({"node": node, "k": k})
	_tick_finale(0.0)

## 一隻肚滑的企鵝（收尾用）：放大一點、腳後面拖一道雪痕、濺起冰屑。位置和朝向由呼叫的人每格設定
func _make_slider(pos: Vector3) -> Node3D:
	var node := make_penguin(_finale_root, pos, 0.0)
	node.scale = Vector3.ONE * 1.5            # 收尾鏡頭很遠：放大一點才看得到
	var trail := Decal.new()
	trail.texture_albedo = load(TX + "shadow_blob.png")
	trail.size = Vector3(0.9, 1.0, 3.4)
	trail.albedo_mix = 0.5
	trail.position = Vector3(0, -1.7, 0.0)       # 企鵝趴下之後，自己的 +Y 朝前（頭的方向）：雪痕拖在腳後面
	trail.rotation.x = -PI * 0.5
	node.add_child(trail)
	var spray := GPUParticles3D.new()
	spray.amount = 18
	spray.lifetime = 0.6
	spray.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 55.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	spray.process_material = pm
	spray.draw_pass_1 = _spark_quad(Color(0.9, 0.98, 1.0), 0.34, false)
	spray.position = Vector3(0, 0.3, 0)
	node.add_child(spray)
	return node

## 收尾時多一隻肚滑的企鵝去撞人（戰局在 finale_show(true) 之後呼叫，每個要被撞的人一次；純演出）：
## 收尾開始後第 start 秒出現在 from，以 speed 公尺／秒直線滑到 to（那個人的腳邊），
## 到了之後沿同方向再滑一小段（最多 3 公尺，前面是冰洞就在洞邊停住）然後縮小收掉。finale_show(false) 會一起清掉。
func finale_bump(from: Vector3, to: Vector3, start: float, speed := 7.0) -> void:
	if not _finale_on or _finale_root == null:
		return
	var d := to - from
	d.y = 0.0
	var length := d.length()
	if length < 0.01:
		return
	var dir := d / length
	# 撞到人之後還能往前滑多遠：碰到水（冰洞、破掉的薄冰）之前停下來
	var extra := 0.0
	while extra < 3.0:
		var q := to + dir * (extra + 0.9)
		if in_water(q.x, q.z):
			break
		extra += 0.2
	# 來的路上有東西擋著（攤位、樹、籠子、地標…）就從擋住的地方之後才出現，晚一點出發，撞到人的時間不變
	var run := 2.5
	while run < length:
		var q2 := to - dir * (run + 0.4)
		if _bump_blocked(q2.x, q2.z):
			break
		run += 0.4
	run = minf(run, length)
	var spd := maxf(speed, 0.1)
	var node := _make_slider(to - dir * run)
	node.visible = false
	_bumpers.append({"node": node, "from": to - dir * run, "dir": dir, "len": run, "extra": extra, "start": start + (length - run) / spd, "speed": spd})

## 撞人的企鵝不能滑過去的地方：地圖外面、水裡、會擋路的東西、裝飾和地標
func _bump_blocked(x: float, z: float) -> bool:
	if not Isle.inside(isle, x, z, 0.6) or in_water(x, z):
		return true
	var p := Vector2(x, z)
	for o in obstacles:
		if p.distance_to(o[0]) < float(o[1]) + 0.9:
			return true
	if get("cage") != null and p.distance_to(Vector2(get("cage").x, get("cage").z)) < 2.6:
		return true
	for c in camps:
		if p.distance_to(Vector2(c.pos.x, c.pos.z)) < 2.6:
			return true
	for zn in zones:
		if not zn.has("pos"):
			continue
		var need: float = {"lighthouse": 2.6, "belltower": 2.4, "village": 3.6, "stall": 2.4, "string": 2.4, "pier": 2.6, "boat": 2.0, "net": 1.8, "rack": 1.6}.get(String(zn.type), 1.2) * float(zn.get("scale", 1.0))
		if p.distance_to(Vector2(zn.pos.x, zn.pos.z)) < maxf(need, 1.0):
			return true
	return false

func _tick_finale(dt: float) -> void:
	_finale_t += dt
	var t := _finale_t
	for i in _glow_mats.size():
		var g: Dictionary = _glow_mats[i]
		(g.mat as ShaderMaterial).set_shader_parameter("emission_c", (g.base as Color) * (0.80 + 0.55 * sin(t * 7.0 + i * 2.1)))
	if not lakes.is_empty():
		var l: Dictionary = lakes[0]
		var c: Vector2 = l.center
		# 滑的那條線：在湖裡挑一條離冰洞、薄冰、雪人最遠的東西向直線
		var zline := c.y
		var best := -1.0
		for kk in [0.36, -0.36, 0.0, 0.55, -0.55, 0.18, -0.18]:
			var zc: float = c.y + float(l.rz) * float(kk)
			var room := 99.0
			for p in ponds:
				room = minf(room, absf(p.center.y - zc) - float(p.r))
			for ts in thin_spots:
				room = minf(room, absf(ts.center.y - zc) - float(ts.r))
			for sm in snowmen:
				room = minf(room, absf(sm.z - zc) - 0.6)
			if room > best + 0.01:
				best = room
				zline = zc
		var x0 := c.x - float(l.rx) * 0.74
		var span := float(l.rx) * 1.42
		for sl in _sliders:
			var u := fposmod(t * 3.8 + (3 - int(sl.k)) * 1.9, span * 2.0)       # 一隻跟一隻，滑到頭再滑回來
			var fwd := 1.0 if u < span else -1.0
			var x := x0 + (u if u < span else span * 2.0 - u)
			var z := zline + sin(x * 0.45 + int(sl.k)) * 0.35
			var n := sl.node as Node3D
			n.position = Vector3(x, height_at(x, z) + 0.6, z)
			n.basis = Basis(Vector3.UP, PI * 0.5 * fwd) * Basis(Vector3.RIGHT, 1.35)      # 臉朝前、整隻趴下
	for b in _bumpers:
		var n := b.node as Node3D
		var run := (t - float(b.start)) * float(b.speed)
		var total: float = float(b.len) + float(b.extra)
		# 撞到人之後慢下來滑完剩下那一段，最後 0.3 秒縮小不見
		var after := (run - float(b.len)) / float(b.speed)
		var dist := run
		var k := 1.0
		if after > 0.0:
			var u := clampf(after / 0.6, 0.0, 1.0)
			dist = float(b.len) + float(b.extra) * (1.0 - (1.0 - u) * (1.0 - u))
			k = clampf((0.9 - after) / 0.3, 0.0, 1.0)
		n.visible = run >= 0.0 and k > 0.0
		if not n.visible:
			continue
		dist = minf(dist, total)
		var p: Vector3 = (b.from as Vector3) + (b.dir as Vector3) * dist
		n.position = Vector3(p.x, height_at(p.x, p.z) + 0.6, p.z)
		n.basis = Basis(Vector3.UP, atan2(b.dir.x, b.dir.z)) * Basis(Vector3.RIGHT, 1.35)
		n.scale = Vector3.ONE * 1.5 * k
	if t >= _finale_next and _finale_root:
		_firework()
		_finale_next = t + _finale_rng.randf_range(0.65, 1.05)

## 煙火的中心：夜市上空；沒有夜市就在第一個營地、再沒有就在地圖北邊
func _firework_origin() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for z in zones:
		if String(z.type) in ["stall", "string"]:
			sum += z.pos
			n += 1
	if n > 0:
		return sum / n
	if not camps.is_empty():
		return camps[0].pos
	return Vector3(isle.c.x, 0, isle.c.y - float(isle.rz) * 0.5)

## 一發煙火：一團往四面八方散開、慢慢落下淡掉的亮點（貼圖粒子），加一下子照亮雪地的光
func _firework() -> void:
	var rng := _finale_rng
	var o := _firework_origin()
	var pos := Vector3(o.x + rng.randf_range(-7.0, 12.0), rng.randf_range(13.0, 22.0), o.z + rng.randf_range(-12.0, 0.0))
	var col: Color = [Color(0.35, 1.0, 0.80), Color(1.0, 0.42, 0.82), Color(1.0, 0.84, 0.38)][rng.randi() % 3]     # 青綠、洋紅、金（配極光）
	var ps := GPUParticles3D.new()
	ps.one_shot = true
	ps.explosiveness = 1.0
	ps.amount = 72
	ps.lifetime = 1.7
	ps.visibility_aabb = AABB(Vector3(-14, -14, -14), Vector3(28, 28, 28))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 2.4
	pm.damping_max = 3.4
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	pm.color = col
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	ps.process_material = pm
	ps.draw_pass_1 = _spark_quad(Color(1, 1, 1), 0.95, true)
	ps.position = pos
	_finale_root.add_child(ps)
	ps.emitting = true
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.6
	l.omni_range = 30.0
	l.light_specular = 0.0
	l.position = pos
	_finale_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.9)
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ps):
			ps.queue_free()
		l.queue_free())

## 粒子用的小方片：朝著鏡頭的一張軟圓點貼圖（煙火是加亮混合，冰屑是一般混合）
func _spark_quad(col: Color, size: float, additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.02)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	q.material = m
	return q

## 裝飾的動畫（純畫面，不影響戰局）：魚跳出冰洞、營火閃爍、碎冰和浮冰輕輕晃、雲慢慢飄
func _animate_decor() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for jf in _jump_fish:
		var n: Node3D = jf.node
		var k := fmod(t + float(jf.phase), 5.5)
		if k < 0.9:
			var s := k / 0.9
			var c: Vector3 = jf.center
			var r: float = jf.r
			n.visible = true
			n.position = c + Vector3(lerpf(-r * 0.4, r * 0.4, s), sin(s * PI) * 1.3 - 0.1, 0)
			n.rotation = Vector3(0, 0, lerpf(0.9, -0.9, s))
		else:
			n.visible = false
	for f in _fires:
		var fl: OmniLight3D = f.light
		fl.light_energy = (2.0 + sin(t * 13.0) * 0.4 + sin(t * 7.3) * 0.3) * _lamp_gain()
	for fl2 in _floaters:
		if not is_instance_valid(fl2.node):
			continue                       # 鹽做出來的薄冰重試時會被刪掉
		var fn: Node3D = fl2.node
		var ph: float = fl2.phase
		var amp: float = fl2.amp
		fn.position = (fl2.base as Vector3) + Vector3(sin(t * 0.5 + ph) * 0.05, sin(t * 1.3 + ph) * 0.025, cos(t * 0.4 + ph) * 0.05) * amp
		fn.rotation.y = ph + sin(t * 0.3 + ph) * 0.2
	if _clouds:
		_clouds.rotation.y = t * 0.003

## 過關演出時收起小道具（釣竿、水桶、招牌字），重來時放回
func set_clutter(on: bool) -> void:
	for n in _clutter:
		if n != null and is_instance_valid(n):
			(n as Node3D).visible = on

## 俯視時暫停下雪（雪花跟時間白點長得很像）
func set_snow(on: bool) -> void:
	if _snow_ps:
		_snow_ps.visible = on
