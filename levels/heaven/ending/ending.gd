extends "res://scripts/ui/cutscene.gd"
## 結局動畫（丹穴山 3 過關後播）：神殿前 → 第一次有聲音 → 化成鳳凰 → 百鳥 → 鐵皮屋 → 回到屋頂 → 片尾的小雞
##
## 全部是播放，玩家不用操作：Enter 下一句、沒台詞的那幾拍自己會走（Enter 快轉）、Esc 跳過。
##
## ★ 台詞都在下面的 _lines()；劇本在 levels/ice/docs/開頭與結局劇情.md 第 5 節。
##   神殿那幾個鏡頭直接把「丹穴山 3」的場地搬過來用（拿掉戰局和玩家），屋頂用的是跟開場同一座農場。

const STAGE := "res://levels/heaven/stage_3/stage.tscn"
const HM := "res://levels/heaven/assets/blender/"
const MINI := "res://levels/ice/assets/kenney_mini/"
const BEAT := 0.4545                  # 配樂一拍幾秒（132 BPM）
const SHED_X := 300.0
const HEN_S := 0.82
const HERO_X := 1.1                   # 家豪在屋脊上站的位置（跟開場同一個）
## 五采：赤、黃、青、白、紫
const FEATHER_COLS := [Color(0.94, 0.22, 0.16), Color(1.0, 0.80, 0.16), Color(0.14, 0.76, 0.62), Color(1.0, 0.98, 0.92), Color(0.50, 0.30, 0.86)]
const FEATHER_NAMES := ["赤", "黃", "青", "白", "紫"]
const HEN_NUMS := ["12", "31", "07", "58", "40"]

func _lines() -> Array:
	return [
		{"shot": "temple", "who": "家豪", "text": "……其實每一關我都很怕。", "cue": "t_afraid", "snap": 2.0},
		{"shot": "temple", "who": "神明", "text": "我知道。你每次怕的時候，帽子都會拉更低。", "cue": "t_hood"},
		{"shot": "temple", "who": "家豪", "text": "……這個石門好像唱盤。", "cue": "t_gate", "snap": 2.6},
		{"shot": "sound", "hold": 8.6, "cue": "s_first"},
		{"shot": "sound", "who": "家豪", "text": "……你有聽到嗎？", "cue": "s_hear"},
		{"shot": "sound", "who": "神明", "text": "有。", "cue": "s_god"},
		{"shot": "sound", "who": "家豪", "text": "……再說一次。", "cue": "s_again"},
		{"shot": "sound", "who": "神明", "text": "聽得到。", "cue": "s_god2"},
		{"shot": "sound", "who": "家豪", "text": "……放了一輩子欸。……她會想聽的。", "cue": "s_tag"},
		{"shot": "phoenix", "who": "陸吾", "text": "百鳥朝鳳祭天舞。我三千年沒聽到了。", "cue": "p_luwu"},
		{"shot": "phoenix", "who": "陸吾", "text": "六十七號。您是鳳凰的後裔。", "cue": "p_heir"},
		{"shot": "phoenix", "who": "家豪", "text": "……你認錯了。我是肉雞。我從屋頂摔下來過三次。", "cue": "p_deny"},
		{"shot": "phoenix", "who": "神明", "text": "四次。", "cue": "p_four"},
		{"shot": "phoenix", "who": "陸吾", "text": "請再來一次。這次眼睛不要閉。", "cue": "p_again"},
		{"shot": "phoenix", "hold": 13.0, "cue": "p_change"},
		{"shot": "phoenix", "who": "家豪", "text": "……我在飛。……你先不要講話。我怕掉下去。", "cue": "p_fly"},
		{"shot": "phoenix", "who": "家豪", "text": "……所以天選之雞是真的喔。", "cue": "p_real"},
		{"shot": "phoenix", "who": "神明", "text": "我也是現在才知道。我那時候選的只是六十七號。", "cue": "p_only"},
		{"shot": "phoenix", "who": "家豪", "text": "……那現在呢。", "cue": "p_now"},
		{"shot": "phoenix", "who": "神明", "text": "還是六十七號。", "cue": "p_still"},
		{"shot": "birds", "hold": 5.2, "cue": "b_flock"},
		{"shot": "birds", "who": "阿水", "text": "那我們明天還要上班嗎？", "cue": "b_work"},
		{"shot": "birds", "who": "陸吾", "text": "您的位子在這裡！", "cue": "b_seat"},
		{"shot": "birds", "who": "家豪", "text": "我的位子在屋頂。", "cue": "b_roof", "snap": 1.0},
		{"shot": "shed", "hold": 15.0, "cue": "d_open", "fade_out": 0.8, "fade_in": 1.0},
		{"shot": "roof2", "hold": 5.4, "cue": "r_land", "fade_out": 1.2, "fade_in": 1.2},
		{"shot": "roof2", "who": "公雞", "text": "……家豪？你會飛喔。", "cue": "r_fly"},
		{"shot": "roof2", "who": "家豪", "text": "剛學的。", "cue": "r_new"},
		{"shot": "roof2", "who": "公雞", "text": "……有找到嘉欣嗎。", "cue": "r_found"},
		{"shot": "roof2", "who": "家豪", "text": "……沒有。", "cue": "r_no"},
		{"shot": "roof2", "who": "公雞", "text": "那個更好的地方呢？", "cue": "r_place"},
		{"shot": "roof2", "who": "家豪", "text": "……沒有那種地方。所以我回來了。", "cue": "r_back"},
		{"shot": "roof2", "hold": 10.5, "cue": "r_row"},
		{"shot": "roof2", "who": "公雞", "text": "……這次我好像懂了。", "cue": "r_get"},
		{"shot": "roof2", "who": "公雞", "text": "……欸。今天放什麼歌？", "cue": "r_song"},
		{"shot": "roof2", "hold": 3.4, "cue": "r_freeze"},
		{"shot": "roof2", "who": "家豪", "text": "……你自己聽，這首，就很你們懂吧。", "cue": "r_listen"},
		{"shot": "roof2", "hold": 7.2, "cue": "r_end"},
		{"shot": "post", "hold": 9.0, "cue": "post", "fade_out": 0.1, "fade_in": 1.6},
	]

func _skip_text() -> String:
	return "跳過結局"

var _stage: Node3D
var _world                        # 丹穴山 3 的場地（heaven_world.gd）
var _env_temple: Environment
var _sun_temple := {}
var _env_dawn: Environment
var _env_dusk: Environment
var _env_night: Environment
var P := Vector3(0, 0, -11.8)        # 唱盤的位置

var _farm: Dictionary = {}
var _shed: Node3D
var _door_l: Node3D
var _door_r: Node3D
var _lamp: OmniLight3D

var _hero: Dictionary = {}
var _cock: Dictionary = {}
var _chick: Dictionary = {}
var _hens: Array = []
var _cranes: Array = []          # {node, wl, wr, ph, mode, a, b}
var _workers: Array = []         # {node, anim}
var _luwu: Node3D
var _gate_birds: Array = []

var _tag66: Node3D
var _hood_parts: Array = []
var _hood_down: Node3D
var _tail: Node3D
var _feathers: Array = []
var _post_peel: Node3D

var _fin_mode := "off"           # off／tease（第一次有聲音）／full（化成鳳凰）
var _fin_clock := 0.0
var _hero_fly := false           # 家豪浮在唱盤上面（高度跟著場地那邊的鳳凰金光）
var _aura_follow := false        # 鳳凰金光跟著家豪飛
var _notes := ""                 # ""／"grey"（沒聲音、往下掉）／"gold"（有聲音、往上飄）
var _notes_t := 0.0
var _zzz_t := 0.0
var _god_spot: SpotLight3D

func _actor_of(who: String) -> Dictionary:
	match who:
		"家豪": return _hero
		"公雞": return _cock
	return {}

func _build() -> void:
	_build_temple()
	_farm = _build_farm(self)
	_env_dawn = _make_env(Color(0.34, 0.48, 0.80), Color(1.0, 0.80, 0.66), Color(0.86, 0.80, 0.86), 1.0, Color(1.0, 0.84, 0.74), 0.003)
	_env_dusk = _make_env(Color(0.17, 0.19, 0.46), Color(1.0, 0.60, 0.34), Color(0.80, 0.64, 0.76), 1.0, Color(0.98, 0.64, 0.46), 0.0035)
	_build_shed()
	_build_cast()
	_make_sounds()

# ================================================================== 小工具：位置

## 神殿：相對於唱盤的位置
func T(v: Vector3) -> Vector3:
	return P + v

## 神殿：地面上的點（相對於唱盤）
func G(x: float, z: float) -> Vector3:
	return Vector3(P.x + x, float(_world.height_at(P.x + x, P.z + z)), P.z + z)

func S(v: Vector3) -> Vector3:
	return v + Vector3(SHED_X, 0, 0)

func _hero_top() -> Vector3:
	return _ridge(_farm, HERO_X) + Vector3(0, 1.0, 0)

func _sun_behind(cam_pos: Vector3, target: Vector3, lift := 0.0) -> void:
	var d := (target - cam_pos).normalized()
	(_farm.sun as Node3D).global_position = cam_pos + d * 150.0 + Vector3(0, lift, 0)

# ================================================================== 神殿（丹穴山 3 的場地）

func _build_temple() -> void:
	_stage = (load(STAGE) as PackedScene).instantiate() as Node3D
	for nm in ["Battle", "Player", "HUD"]:
		var n := _stage.get_node_or_null(nm)
		if n:
			_stage.remove_child(n)
			n.free()
	add_child(_stage)
	_world = _stage.get_node("World")
	_env_node = _stage.get_node("WorldEnvironment") as WorldEnvironment
	_sun = _stage.get_node("Sun") as DirectionalLight3D
	_env_temple = _env_node.environment
	_sun_temple = {"c": _sun.light_color, "e": _sun.light_energy, "r": _sun.rotation}
	if _world.get("disc") is Vector3:
		P = _world.get("disc")
	_world.finale_show(true)          # 先把鳳凰金光和百鳥做出來
	_world.set("_fin_on", false)
	var lbl = _world.get("_cage_label")
	if lbl is Label3D:
		(lbl as Label3D).visible = false
	var lw = _world.get("luwu")
	if lw is Dictionary and (lw as Dictionary).get("node"):
		_luwu = (lw as Dictionary).node as Node3D
	var gate = _world.get("_gate_node")
	if gate is Node3D:
		for k in 12:
			var b := (gate as Node3D).find_child("Bird%d" % k, true, false)
			if b:
				_gate_birds.append(b)
	# 神明講話時從上面打下來的一點金光
	_god_spot = SpotLight3D.new()
	_god_spot.rotation.x = -PI * 0.5
	_god_spot.light_color = Color(1.0, 0.90, 0.62)
	_god_spot.light_energy = 0.0
	_god_spot.spot_range = 16.0
	_god_spot.spot_angle = 14.0
	add_child(_god_spot)

func _temple_light() -> void:
	_env_node.environment = _env_temple
	_sun.visible = true
	_sun.light_color = _sun_temple.c
	_sun.light_energy = _sun_temple.e
	_sun.rotation = _sun_temple.r

func _luwu_at(pos: Vector3, look: Vector3, bow := false) -> void:
	if _luwu == null:
		return
	_luwu.global_position = pos
	var d := look - pos
	_luwu.rotation.y = atan2(d.x, d.z)
	_world.set("_luwu_state", "sleep" if bow else "awake")

func _light_gate(n: int) -> void:
	for k in _gate_birds.size():
		var b := _gate_birds[k] as Node3D
		for m in b.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = _glow(Color(2.8, 2.1, 0.7)) if k < n else null

func _set_fin(mode: String) -> void:
	_fin_mode = mode
	_fin_clock = 0.0

# ================================================================== 鐵皮屋

func _build_shed() -> void:
	_shed = Node3D.new()
	_shed.name = "Shed"
	_shed.position = Vector3(SHED_X, 0, 0)
	add_child(_shed)
	_env_night = _make_env(Color(0.03, 0.05, 0.16), Color(0.30, 0.26, 0.42), Color(0.46, 0.54, 0.80), 0.75, Color(0.16, 0.18, 0.34), 0.006, 0.7)
	var gm := PlaneMesh.new()
	gm.size = Vector2(200, 200)
	_mesh(_shed, gm, Vector3.ZERO, _tex_mat("res://assets/textures/gravelly_sand_diff_1k.jpg", 40.0, Color(0.50, 0.52, 0.62)))
	# 沒有窗戶的鐵皮屋：拿穀倉的模型，窗戶拿掉、整棟換成浪板
	var barn := _glb(_shed, FARM + "Barn.glb", Vector3.ZERO, 0.0, 1.3)
	var tin := ShaderMaterial.new()
	tin.shader = load("res://levels/heaven/ending/tin.gdshader")
	var tin_d := ShaderMaterial.new()
	tin_d.shader = tin.shader
	tin_d.set_shader_parameter("tint", Color(0.36, 0.40, 0.46))
	for m in barn.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var nm := String(mi.name)
		if nm.contains("Window"):
			mi.visible = false
		elif nm.contains("Door2"):
			_door_l = mi
			mi.material_override = tin_d
		elif nm.contains("Door"):
			_door_r = mi
			mi.material_override = tin_d
		else:
			mi.material_override = tin
	# 門裡面：一片黑
	_box(_shed, Vector3(5.2, 3.2, 0.04), Vector3(-0.05, 1.6, 5.06), _glow(Color(0.01, 0.01, 0.02)))
	# 門上一盞冷冷的燈
	_box(_shed, Vector3(0.5, 0.12, 0.3), Vector3(0, 3.5, 5.5), _toon(Color(0.2, 0.22, 0.26)))
	_ball(_shed, 0.13, Vector3(0, 3.4, 5.55), _glow(Color(2.2, 2.3, 2.6)), Vector3.ONE, 10)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, 3.2, 6.6)
	_lamp.light_color = Color(0.80, 0.90, 1.0)
	_lamp.light_energy = 3.2
	_lamp.omni_range = 11.0
	_lamp.shadow_enabled = true
	_shed.add_child(_lamp)
	# 門口的雜物、鐵絲網的柱子
	_glb(_shed, "res://levels/ice/assets/kenney_platformer/crate-strong.glb", Vector3(4.6, 0, 6.2), 0.4, 1.3)
	_glb(_shed, "res://levels/ice/assets/kenney_platformer/crate.glb", Vector3(5.5, 0, 7.0), 1.0, 1.1)
	_glb(_shed, "res://levels/ice/assets/kenney_survival/barrel.glb", Vector3(-4.8, 0, 6.0), 0.0, 1.5)
	var post := _toon(Color(0.30, 0.32, 0.38))
	for k in 9:
		var x := -16.0 + k * 4.0
		_box(_shed, Vector3(0.12, 2.4, 0.12), Vector3(x, 1.2, -9.0), post)
		_box(_shed, Vector3(4.0, 0.03, 0.03), Vector3(x + 2.0, 2.2, -9.0), post)
		_box(_shed, Vector3(4.0, 0.03, 0.03), Vector3(x + 2.0, 1.4, -9.0), post)
	# 天邊一點點亮（快天亮了）和星星
	var r := RandomNumberGenerator.new()
	r.seed = 8
	for k in 80:
		var a := r.randf_range(0.0, TAU)
		_ball(_shed, r.randf_range(0.08, 0.2), Vector3(cos(a) * r.randf_range(30, 90), r.randf_range(14, 70), sin(a) * r.randf_range(30, 90) - 20.0), _glow(Color(1.6, 1.6, 1.4)), Vector3.ONE, 6)

func _doors(open: float) -> void:
	if _door_l:
		_door_l.position.x = -1.8 * open
	if _door_r:
		_door_r.position.x = 1.8 * open

# ================================================================== 角色

func _build_cast() -> void:
	_hero = _actor(self, "hero", Vector3.ZERO, 0.0)
	_hero.beat = PI / BEAT
	_leg_tag(_hero, "67")
	var upper := (_hero.node as Node3D).find_child("Upper", true, false) as Node3D
	# 六十六號的腳牌：從開頭一路掛在脖子上
	_tag66 = _foot_tag("66", true)
	add_child(_tag66)
	_tag_on_neck()
	# 帽子：找出帽兜的零件，之後可以掀開
	var head := _hero.head as Node3D
	if head:
		for c in head.get_children():
			var mi := c as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var hood: bool = mi.mesh is SphereMesh and absf((mi.mesh as SphereMesh).radius - 0.16) < 0.004
			var rim: bool = mi.mesh is TorusMesh and absf((mi.mesh as TorusMesh).inner_radius - 0.105) < 0.004
			if hood or rim:
				_hood_parts.append(mi)
	if not _hood_parts.is_empty() and upper:
		_hood_down = _ball(upper, 0.13, Vector3(0, 0.72, -0.05), _toon(Color(0.10, 0.10, 0.11)), Vector3(1.1, 0.6, 1.0), 12)
		_hood_down.visible = false
	# 五色的尾羽
	if upper:
		_tail = Node3D.new()
		_tail.position = Vector3(0, 0.60, -0.30)
		upper.add_child(_tail)
		for k in 5:
			var f := _feather(0.98 - absf(k - 2.0) * 0.1, 0.17, FEATHER_COLS[k])
			_tail.add_child(f)
			f.set_meta("roll", (k - 2.0) * 0.42)
			f.rotation.z = (k - 2.0) * 0.42
			f.visible = false
			_feathers.append(f)
	_cock = _actor(self, "rooster", Vector3(-1.4, 0, 6.0), 0.0, 1.12)
	_cock.beat = PI / BEAT
	for k in 5:
		var h := _actor(self, "hen", Vector3.ZERO, 0.0, HEN_S)
		h.beat = PI / BEAT
		h["home"] = [Vector3(-3.6, 0, 5.2), Vector3(-5.2, 0, 3.4), Vector3(1.8, 0, 6.6), Vector3(3.2, 0, 4.6), Vector3(-2.4, 0, 3.2)][k]
		var tag := _foot_tag(HEN_NUMS[k])
		(h.node as Node3D).add_child(tag)
		tag.position = Vector3(0.17, 0.13, 0.43)
		tag.rotation = Vector3(-0.25, 0.3, 0.1)
		tag.scale = Vector3.ONE * 0.8
		h["tag"] = tag
		_hens.append(h)
	_chick = _actor(self, "chick", Vector3(0.2, 0, 6.9), 0.0)
	_chick.beat = PI / BEAT
	# 仙鶴（百鳥、拉開鐵門）
	for k in 12:
		var c := _glb(self, HM + "crane.glb", Vector3.ZERO, 0.0, 0.42 + 0.06 * (k % 3))
		if c == null:
			continue
		_no_shadow(c)
		_cranes.append({"node": c, "wl": c.find_child("WingL", true, false), "wr": c.find_child("WingR", true, false), "ph": k * 1.37, "from": Vector3.ZERO, "to": Vector3.ZERO, "t0": 0.0, "dur": 1.0, "hover": Vector3.ZERO, "mode": ""})
	# 人類（躺在步道上）
	for k in 3:
		var w := _glb(self, MINI + ("character-worker.glb" if k != 1 else "character-male-c.glb"), Vector3.ZERO, 0.0, 2.5)
		if w == null:
			continue
		var ap := w.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_workers.append({"node": w, "anim": ap})
	_post_peel = _peel(self, Vector3.ZERO, 0.9)
	_post_peel.visible = false

## 一根長長的尾羽：往後、往上翹，尾端有一顆眼斑（兩面都看得到）
func _feather(length: float, width: float, col: Color) -> Node3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	var pc := col
	var eye := Vector3.ZERO
	for i in n + 1:
		var k := float(i) / n
		var c := Vector3(0, length * (0.8 * k - 0.6 * k * k), -length * 0.95 * k)
		var w := width * pow(sin(PI * minf(0.06 + k * 0.94, 1.0)), 0.7) * 0.5
		var cc := col.darkened(0.4).lerp(col, minf(k * 2.5, 1.0)).lerp(Color(1.0, 0.95, 0.7), maxf(k - 0.78, 0.0) * 2.4)
		var l := c + Vector3(-w, 0, 0)
		var r := c + Vector3(w, 0, 0)
		if i > 0:
			for v in [[pl, pc], [pr, pc], [r, cc], [pl, pc], [r, cc], [l, cc]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
		if i == 10:
			eye = c
		pl = l
		pr = r
		pc = cc
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	var spot := _ball(holder, width * 0.2, eye, _glow(Color(1.8, 1.5, 0.5)), Vector3(1.0, 0.25, 1.3), 10)
	_no_shadow(spot)
	# 羽軸
	var shaft := _glow(col.darkened(0.5))
	for i in 5:
		var k := (i + 0.5) / 5.0 * 0.8
		_no_shadow(_box(holder, Vector3(0.012, 0.012, length * 0.2), Vector3(0, length * (0.8 * k - 0.6 * k * k) + 0.004, -length * 0.95 * k), shaft, Vector3(atan2(0.8 - 1.2 * k, 0.95), 0, 0)))
	return holder

func _tag_on_neck() -> void:
	var upper := (_hero.node as Node3D).find_child("Upper", true, false) as Node3D
	if upper == null:
		return
	if _tag66.get_parent() != upper:
		_tag66.reparent(upper)
	_tag66.position = Vector3(0.115, 0.47, 0.335)
	_tag66.rotation = Vector3(0.12, 0.0, -0.18)
	_tag66.scale = Vector3.ONE * 0.5
	_tag66.visible = true

## 腳牌立在屋脊上、家豪旁邊那一格
func _tag_on_ridge() -> void:
	if _tag66.get_parent() != self:
		_tag66.reparent(self)
	_tag66.global_position = _ridge(_farm, HERO_X - 0.9) + Vector3(0, 0.2, 0.06)
	_tag66.rotation = Vector3(-0.22, 0.12, 0.08)
	_tag66.scale = Vector3.ONE * 1.5
	_tag66.visible = true

## 家豪現在是哪個樣子：phoenix＝帽子掀開、長出五色尾羽
func _form(phoenix: bool, hood_up := false) -> void:
	for h in _hood_parts:
		(h as Node3D).visible = not phoenix or hood_up
	if _hood_down:
		_hood_down.visible = phoenix and not hood_up
	for f in _feathers:
		(f as Node3D).visible = phoenix
		(f as Node3D).scale = Vector3.ONE

func _worker_pose(k: int, pos: Vector3, yaw: float, anim: String) -> void:
	if k >= _workers.size():
		return
	var w: Dictionary = _workers[k]
	var n := w.node as Node3D
	n.visible = true
	n.global_position = pos
	n.rotation = Vector3(0, yaw, 0)
	var ap := w.anim as AnimationPlayer
	if ap and ap.has_animation(anim):
		ap.play(anim)
		if anim == "die":
			ap.seek(ap.current_animation_length, true)
			ap.pause()

func _crane_hide() -> void:
	for c in _cranes:
		(c.node as Node3D).visible = false
		c.mode = ""

## 一隻仙鶴從 a 飛到 b（dur 秒）
func _crane_fly(k: int, a: Vector3, b: Vector3, dur: float, delay := 0.0) -> void:
	if k >= _cranes.size():
		return
	var c: Dictionary = _cranes[k]
	c.mode = "fly"
	c.from = a
	c.to = b
	c.t0 = _t + delay
	c.dur = dur
	(c.node as Node3D).visible = true
	(c.node as Node3D).global_position = a

## 一隻仙鶴在某個位置拍翅膀（拉門）
func _crane_hover(k: int, pos: Vector3, yaw: float) -> void:
	if k >= _cranes.size():
		return
	var c: Dictionary = _cranes[k]
	c.mode = "hover"
	c.hover = pos
	(c.node as Node3D).visible = true
	(c.node as Node3D).rotation = Vector3(0, yaw, 0)

# ================================================================== 換鏡頭

func _enter_shot(s: String) -> void:
	var temple := s in ["temple", "sound", "phoenix", "birds"]
	var farm := s in ["roof2", "post"]
	_world.visible = temple
	(_farm.root as Node3D).visible = farm
	_shed.visible = s == "shed"
	for a in [_cock, _chick] + _hens:
		(a.node as Node3D).visible = false
		a.look = null
	for w in _workers:
		(w.node as Node3D).visible = false
	_crane_hide()
	_post_peel.visible = false
	_hero.look = null
	_hero_fly = false
	_aura_follow = false
	_notes = ""
	_god_spot.light_energy = 0.0
	var hero := _hero.node as Node3D
	hero.visible = true
	hero.rotation = Vector3.ZERO
	(_hero.body as Node3D).rotation = Vector3.ZERO
	_set_anim(_hero, "idle")
	if not temple:
		_set_fin("off")
		_world.set("_fin_on", false)
	_light_gate(0)
	match s:
		"temple":
			_temple_light()
			_form(false)
			_tag_on_neck()
			_set_fin("off")
			hero.position = G(0.0, 9.0)
			hero.rotation.y = PI
			_luwu_at(G(13.0, 3.0), G(0, 0))
		"sound":
			_temple_light()
			_form(false)
			_tag_on_neck()
			_set_fin("off")
			hero.position = T(Vector3(0, 0.22, 0))
			_luwu_at(G(13.0, 3.0), G(0, 0))
		"phoenix":
			_temple_light()
			_form(false)
			_tag_on_neck()
			_set_fin("off")
			hero.position = T(Vector3(0, 0.22, 0))
			_luwu_at(G(4.4, 2.6), G(0, 0))
		"birds":
			_temple_light()
			_form(true)
			_tag_on_neck()
			_luwu_at(G(4.4, 2.6), G(2.0, 14.0))
			_worker_pose(0, G(-2.4, 19.0), 2.4, "die")
			_worker_pose(1, G(1.6, 21.0), 0.6, "die")
			_worker_pose(2, G(2.8, 17.2), -1.2, "die")
		"shed":
			_light(_env_night, Color(0.50, 0.62, 1.0), 0.45, Vector3(-0.9, 0.7, 0))
			_form(true)
			_tag_on_neck()
			_doors(0.0)
			hero.position = S(Vector3(-2.2, 0, 7.6))
			_face(_hero, S(Vector3(1.0, 0, 6.6)))
			for k in _hens.size():
				var h: Dictionary = _hens[k]
				(h.node as Node3D).visible = true
				(h.node as Node3D).position = S(Vector3(-0.6 + 0.3 * k, 0, 3.2))
				(h.tag as Node3D).visible = true
				_set_anim(h, "idle")
		"roof2":
			_light(_env_dawn, Color(1.0, 0.86, 0.70), 1.5, Vector3(-0.42, PI - 0.5, 0))
			_form(true)
			_tag_on_neck()
			_dawn_look(true)
			_farm_cast()
		"post":
			_light(_env_dusk, Color(1.0, 0.64, 0.38), 1.6, Vector3(-0.30, PI - 0.4, 0))
			_dawn_look(false)
			hero.visible = false
			_tag_on_ridge()
			_tag66.visible = false

## 屋頂那場的雲和太陽：清晨是粉金色，黃昏是橘紅色
func _dawn_look(dawn: bool) -> void:
	for c in _farm.clouds:
		_paint(c, _glow(Color(1.0, 0.86, 0.80) if dawn else Color(1.0, 0.72, 0.60)))
	(_farm.sun as MeshInstance3D).material_override = _glow(Color(1.5, 1.25, 0.85) if dawn else Color(1.0, 0.80, 0.42))

## 屋頂那場一開始：公雞、母雞、小雞都在地上（跟開場同樣的位置；腳牌都不見了）
func _farm_cast() -> void:
	(_cock.node as Node3D).visible = true
	(_cock.node as Node3D).position = Vector3(-1.4, 0, 6.0)
	_face(_cock, _hero_top())
	_set_anim(_cock, "idle")
	for h in _hens:
		(h.node as Node3D).visible = true
		(h.node as Node3D).position = h.home
		(h.tag as Node3D).visible = false
		_face(h, _hero_top())
		_set_anim(h, "idle")
	(_chick.node as Node3D).visible = true
	(_chick.node as Node3D).position = Vector3(0.2, 0, 6.9)
	_face(_chick, _hero_top())
	_set_anim(_chick, "idle")
	(_hero.node as Node3D).position = _ridge(_farm, HERO_X)
	(_hero.node as Node3D).rotation = Vector3.ZERO

## 大家都上了屋頂之後的位置：家豪、空一格（腳牌）、公雞、兩隻母雞；小雞在家豪另一邊
func _row_state() -> void:
	_tag_on_ridge()
	(_cock.node as Node3D).position = _ridge(_farm, HERO_X - 1.85)
	(_cock.node as Node3D).rotation = Vector3.ZERO
	for k in 2:
		(_hens[k].node as Node3D).position = _ridge(_farm, HERO_X - 2.7 - 0.82 * k)
		(_hens[k].node as Node3D).rotation = Vector3.ZERO
	(_chick.node as Node3D).position = _ridge(_farm, HERO_X + 1.0)
	(_chick.node as Node3D).rotation = Vector3.ZERO
	(_hero.node as Node3D).position = _ridge(_farm, HERO_X)
	(_hero.node as Node3D).rotation = Vector3.ZERO

# ================================================================== 每一句演什麼

func _on_line(l: Dictionary) -> void:
	var hero := _hero.node as Node3D
	var ry: float = _farm.ridge_y
	match String(l.get("cue", "")):
		# ---------------------------------------------------------- 神殿前
		"t_afraid":
			# 從背後看：他一個人沿著發光的步道走向圓門
			_shot_cam(T(Vector3(2.2, 4.0, 16.0)), T(Vector3(0, 0.9, -3.4)), 46.0, 0.0, Vector3(-0.05, -0.02, -0.3))
			hero.position = G(0.0, 9.0)
			_walk(_hero, G(0.0, 3.2), 3.0, "cower")
		"t_hood":
			# 從上面往下看（神明看他的角度）：他把帽子拉得更低
			hero.position = G(0.0, 3.2)
			hero.rotation.y = PI
			_shot_cam(T(Vector3(1.6, 4.2, 0.2)), T(Vector3(0, 0.2, 3.2)), 34.0, 0.0, Vector3(0, -0.05, 0.03))
			_set_anim(_hero, "cower")
			_god_spot.global_position = G(0.0, 3.2) + Vector3(0, 9, 0)
			_god_spot.light_energy = 6.0
			_at(1.6, func():
				_set_anim(_hero, "cool")
				_emote(_hero, "…", Color(1, 1, 1), 1.2, 0.9))
		"t_gate":
			# 低角度：他抬頭看那座圓門，然後跳上唱盤
			hero.position = G(0.0, 3.2)
			hero.rotation.y = PI
			_shot_cam(T(Vector3(1.9, 1.3, 6.6)), T(Vector3(0, 3.0, -3.4)), 46.0, 0.0, Vector3(-0.03, 0.02, -0.1))
			_set_anim(_hero, "lookup")
			_at(0.5, func():
				_emote(_hero, "？", Color(1, 1, 1), 1.1, 0.9)
				_play("pop", -12.0))
			_at(2.2, func(): _hop(_hero, T(Vector3(0, 0.22, 0)), 0.5, 0.9, 0.0, "idle"))
			_at(2.8, func():
				_face(_hero, T(Vector3(0.6, 0, 8)), 0.4)
				_play("thud", -14.0, 1.4))
		# ---------------------------------------------------------- 第一次有聲音
		"s_first":
			hero.position = T(Vector3(0, 0.22, 0))
			_face(_hero, T(Vector3(0.6, 0, 8)))
			_shot_cam(T(Vector3(1.5, 1.7, 4.4)), T(Vector3(0, 0.9, 0)), 36.0, 0.0, Vector3(-0.04, 0, -0.06))
			_set_anim(_hero, "dj", 0.8)
			_notes = "grey"
			# 安靜三秒，然後……
			_at(3.4, func():
				_notes = "gold"
				_set_fin("tease")
				_music_play("beat", -8.0)
				_flash(Color(1.0, 0.92, 0.7), 0.5, 0.5)
				_shake = 0.6
				_set_anim(_hero, "dj_big")
				_shot_cam(T(Vector3(-2.0, 6.2, 17.5)), T(Vector3(0, 2.0, -1.5)), 46.0, 0.0, Vector3(0.08, -0.04, -0.2)))
			_at(6.4, func():
				# 他自己嚇到，手停了
				_notes = ""
				_music_stop()
				_play("stop", -6.0)
				_set_fin("off")
				_set_anim(_hero, "shock")
				_emote(_hero, "！", Color(1.0, 0.9, 0.5), 1.0, 1.1)
				_shot_cam(T(Vector3(1.1, 1.6, 2.9)), T(Vector3(0, 0.95, 0)), 30.0))
			_at(7.4, func(): _set_anim(_hero, "cower"))
		"s_hear":
			_shot_cam(T(Vector3(1.0, 1.6, 2.8)), T(Vector3(0, 0.9, 0)), 28.0, 0.0, Vector3(-0.02, 0, -0.03))
			_set_anim(_hero, "lookup")
		"s_god":
			_god_view()
			_set_anim(_hero, "lookup")
		"s_again":
			_shot_cam(T(Vector3(-1.2, 1.5, 2.4)), T(Vector3(0, 0.9, 0)), 28.0, 0.0, Vector3(0.02, 0, -0.03))
			_set_anim(_hero, "lookup")
		"s_god2":
			_god_view()
			_set_anim(_hero, "lookup")
			_at(0.5, func(): _play("bell", -12.0, 1.0))
			_at(0.75, func(): _play("bell", -12.0, 1.5))
		"s_tag":
			# 他摸了摸脖子上的腳牌
			_shot_cam(T(Vector3(0.9, 1.45, 2.3)), T(Vector3(0.05, 0.85, 0)), 24.0, 0.0, Vector3(-0.02, 0, -0.04))
			_set_anim(_hero, "idle")
			_at(1.8, func():
				_set_anim(_hero, "point")
				_emote(T(Vector3(0.45, 1.5, 0.4)), "✦", Color(1.0, 0.95, 0.5), 0.9, 0.5, 0.15))
		# ---------------------------------------------------------- 化成鳳凰
		"p_luwu":
			# 陸吾走過來，低下頭
			_shot_cam(T(Vector3(1.6, 1.3, 6.2)), T(Vector3(3.4, 1.1, 2.4)), 40.0, 0.0, Vector3(0.05, 0, -0.05))
			_luwu_at(G(4.4, 2.6), G(0, 0), true)
			_set_anim(_hero, "idle")
			_hero.look = G(4.4, 2.6) + Vector3(0, 1.3, 0)
		"p_heir":
			_shot_cam(T(Vector3(-3.2, 1.9, 6.0)), T(Vector3(1.9, 0.8, 1.2)), 42.0, 0.0, Vector3(0.06, 0, -0.03))
			_luwu_at(G(4.4, 2.6), G(0, 0), true)
			_hero.look = G(4.4, 2.6) + Vector3(0, 1.3, 0)
			_at(1.4, func():
				_emote(_hero, "？", Color(1, 1, 1), 1.2, 0.9)
				_play("pop", -12.0))
		"p_deny":
			_shot_cam(T(Vector3(1.3, 1.6, 2.9)), T(Vector3(0, 0.9, 0)), 30.0, 0.0, Vector3(-0.02, 0, -0.03))
			_set_anim(_hero, "shrug")
			_hero.look = null
			_at(1.6, func(): _set_anim(_hero, "sad"))
		"p_four":
			# 神明補一刀；他抬頭瞪了一眼
			_god_view()
			_set_anim(_hero, "lookup")
			_at(0.5, func():
				_emote(_hero, "……", Color(1, 1, 1), 1.4, 0.9)
				_play("thud", -16.0, 1.5))
		"p_again":
			_shot_cam(T(Vector3(2.0, 1.2, 5.6)), T(Vector3(3.6, 1.2, 2.5)), 36.0, 0.0, Vector3(0.03, 0, -0.03))
			_luwu_at(G(4.4, 2.6), G(0, 0), false)
			_set_anim(_hero, "idle")
			_hero.look = G(4.4, 2.6) + Vector3(0, 1.3, 0)
		"p_change":
			_luwu_at(G(4.4, 2.6), G(0, 0), false)
			_hero.look = null
			hero.position = T(Vector3(0, 0.22, 0))
			_face(_hero, T(Vector3(0.6, 0, 8)))
			# 這次眼睛睜著：一開始就有聲音
			_shot_cam(T(Vector3(1.5, 1.7, 4.4)), T(Vector3(0, 0.9, 0)), 36.0, 0.0, Vector3(-0.04, 0, -0.06))
			_set_anim(_hero, "dj")
			_notes = "gold"
			_set_fin("tease")
			_music_play("beat", -8.0)
			# 圓門上的鳥一隻一隻亮起來
			_at(1.6, func(): _shot_cam(T(Vector3(0.6, 1.9, 7.0)), T(Vector3(0, 3.6, -3.4)), 44.0, 0.0, Vector3(0, 0.03, -0.12)))
			for k in 12:
				_at(1.9 + 0.13 * k, func():
					_light_gate(k + 1)
					_play("bell", -16.0, [1.0, 1.125, 1.25, 1.5, 1.667][k % 5] * (1.0 if k < 5 else 2.0)))
			# 風把帽子掀開
			_at(3.9, func():
				_shot_cam(T(Vector3(1.0, 1.7, 2.6)), T(Vector3(0, 1.0, 0)), 30.0, 0.0, Vector3(-0.02, 0, -0.04))
				_play("whoosh", -8.0, 0.8))
			_at(4.3, func():
				_form(true)
				for f in _feathers:
					(f as Node3D).visible = false
				_set_anim(_hero, "shock")
				_emote(_hero, "！", Color(1.0, 0.9, 0.5), 0.9, 1.0)
				_shake = 0.4)
			_at(5.0, func(): _set_anim(_hero, "dj_big"))
			# 從背後看：五色的尾羽一根一根長出來
			_at(5.3, func(): _shot_cam(T(Vector3(-1.9, 2.0, -2.2)), T(Vector3(0, 1.3, -0.3)), 42.0, 0.0, Vector3(0.05, 0.02, 0.0)))
			for k in 5:
				_at(5.7 + 0.5 * k, func():
					var f := _feathers[k] as Node3D
					f.visible = true
					f.scale = Vector3.ONE * 0.01
					var tw := create_tween()
					tw.tween_property(f, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					_play("bell", -9.0, [1.0, 1.125, 1.25, 1.5, 1.667][k])
					_emote(T(Vector3(-0.9 + 0.45 * k, 2.2 + 0.2 * (k % 2), -1.0)), FEATHER_NAMES[k], FEATHER_COLS[k], 1.1, 0.9, 0.4))
			# 腳離開地面
			_at(8.5, func():
				_form(true)
				_shot_cam(T(Vector3(3.0, 0.9, 8.0)), T(Vector3(0, 3.0, -0.6)), 50.0, 0.0, Vector3(-0.06, 0.03, -0.1))
				_set_fin("full")
				_hero_fly = true
				_set_anim(_hero, "fly")
				_flash(Color(1.0, 0.9, 0.6), 0.6, 0.8)
				_shake = 0.8
				_play("ding", -4.0, 0.75))
		"p_fly":
			_fly_state()
			_shot_cam(T(Vector3(1.8, 3.9, 3.4)), T(Vector3(0, 3.9, 0)), 34.0, 0.0, Vector3(-0.03, 0, -0.03))
			_set_anim(_hero, "fly")
			_at(1.6, func():
				_emote(_hero, "！？", Color(1, 1, 1), 1.0, 0.8)
				_shake = 0.3)
		"p_real":
			_fly_state()
			_shot_cam(T(Vector3(-1.6, 4.0, 3.0)), T(Vector3(0, 4.0, 0)), 32.0, 0.0, Vector3(0.03, 0, -0.03))
		"p_only":
			_fly_state()
			_god_view(6.0)
		"p_now":
			_fly_state()
			_shot_cam(T(Vector3(1.2, 4.2, 2.6)), T(Vector3(0, 4.05, 0)), 26.0, 0.0, Vector3(-0.02, 0, -0.03))
			_hero.look = T(Vector3(0.5, 12.0, 2.0))
		"p_still":
			# 很近地看牠腳上那塊牌子：六十七
			_fly_state()
			_shot_cam(T(Vector3(0.75, 3.45, 1.45)), T(Vector3(0.12, 3.36, 0.05)), 20.0, 0.0, Vector3(-0.01, 0.015, -0.01))
			_at(1.0, func(): _emote(T(Vector3(0.6, 3.6, 0.3)), "✦", Color(1.0, 0.95, 0.5), 0.9, 0.35, 0.1))
		# ---------------------------------------------------------- 百鳥
		"b_flock":
			# 整片天空的鳥跟著鳳凰往山下飛；躺在步道上的人抬頭看
			_set_fin("off")
			_aura_follow = true
			_music_play("beat", -9.0)
			_shot_cam(T(Vector3(-5.5, 1.5, 27.0)), T(Vector3(0.5, 5.6, 6.0)), 52.0, 0.0, Vector3(0.1, 0.0, 0.1))
			_set_anim(_hero, "glide")
			hero.position = T(Vector3(0, 3.4, 0))
			hero.rotation = Vector3.ZERO
			_tw().tween_property(hero, "position", T(Vector3(2.0, 7.0, 14.0)), 4.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			for k in _cranes.size():
				var a := T(Vector3(-9.0 + 1.6 * k, 5.0 + 2.2 * (k % 3), -8.0 - 2.0 * (k % 4)))
				_crane_fly(k, a, a + Vector3(2.0 - 0.4 * k, 4.0, 46.0), 5.0 + 0.3 * (k % 3), 0.15 * k)
			_at(2.4, func():
				for k in 3:
					if k < _workers.size():
						var ap := _workers[k].anim as AnimationPlayer
						if ap and ap.has_animation("sit"):
							ap.play("sit", 0.4)
						_emote(G([-2.4, 1.6, 2.8][k], [19.0, 21.0, 17.2][k]) + Vector3(0, 1.6, 0), "！", Color(1, 1, 1), 1.0, 0.8))
		"b_work":
			_birds_state()
			_shot_cam(T(Vector3(-0.2, 1.9, 25.4)), T(Vector3(-0.2, 0.3, 19.4)), 40.0, 0.0, Vector3(0.03, 0, -0.03))
			_at(1.5, func():
				_emote(G(1.6, 21.0) + Vector3(0, 1.7, 0), "？", Color(1, 1, 1), 1.2, 0.8)
				_play("pop", -12.0))
		"b_seat":
			_birds_state()
			_luwu_at(G(4.4, 2.6), G(2.0, 14.0), false)
			_shot_cam(T(Vector3(7.2, 1.2, -1.0)), T(Vector3(3.2, 3.6, 8.0)), 46.0, 0.0, Vector3(0, 0.02, 0.05))
		"b_roof":
			# 他回頭說完，往山下飛走
			_birds_state()
			_shot_cam(T(Vector3(4.0, 7.4, 10.6)), T(Vector3(2.0, 7.6, 14.0)), 36.0, 0.0, Vector3(0.0, 0.0, -0.04))
			_face(_hero, T(Vector3(4.4, 7.0, 2.6)))
			_set_anim(_hero, "fly")
			_at(2.2, func():
				_set_anim(_hero, "glide")
				_face(_hero, T(Vector3(4.0, 7.0, 80.0)), 0.4))
			_at(2.6, func(): _tw().tween_property(hero, "position", T(Vector3(5.0, 12.0, 70.0)), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
		# ---------------------------------------------------------- 鐵皮屋
		"d_open":
			_music_stop(1.2)
			_shot_cam(S(Vector3(-8.5, 2.4, 17.0)), S(Vector3(0.2, 1.9, 4.5)), 42.0, 0.0, Vector3(0.12, 0, -0.14))
			_set_anim(_hero, "idle")
			_hero.look = S(Vector3(0, 1.4, 5.2))
			# 鳥群拉開鐵門
			for k in 4:
				var side := -1.0 if k < 2 else 1.0
				_crane_hover(k, S(Vector3(side * (1.2 + 0.9 * (k % 2)), 2.5 + 0.7 * (k % 2), 6.0)), -side * 1.2)
			var tw := _tw()
			tw.tween_interval(0.9)
			tw.tween_callback(func(): _play("rumble", -6.0))
			var slide := func(v: float) -> void:
				_doors(v)
				for k in mini(4, _cranes.size()):
					var sd := -1.0 if k < 2 else 1.0
					_cranes[k].hover = S(Vector3(sd * (1.2 + 0.9 * (k % 2) + 1.9 * v), 2.5 + 0.7 * (k % 2), 6.0))
			tw.tween_method(slide, 0.0, 1.0, 2.2)
			tw.tween_callback(func():
				for k in mini(4, _cranes.size()):
					var c: Dictionary = _cranes[k]
					var p := (c.node as Node3D).global_position
					_crane_fly(k, p, p + Vector3(6.0 - 4.0 * k, 14.0, 10.0), 3.0))
			# 雞一隻一隻走出來；家豪一隻一隻看牠們的腳
			_at(3.4, func(): _shot_cam(S(Vector3(0.6, 1.7, 13.4)), S(Vector3(-0.4, 0.5, 6.6)), 36.0, 1.2, Vector3(0, 0, -0.05)))
			for k in _hens.size():
				var h: Dictionary = _hens[k]
				var t0 := 3.6 + 1.05 * k
				var mid := S(Vector3(0.9, 0, 7.0))
				_at(t0, func():
					(h.node as Node3D).position = S(Vector3(0.2, 0, 4.6))
					_walk(h, mid, 0.9, "walk"))
				_at(t0 + 0.9, func():
					_hero.look = mid + Vector3(0, 0.15, 0.3)
					_emote(mid + Vector3(0.3, 0.75, 0.4), HEN_NUMS[k], Color(1.0, 0.86, 0.3), 0.9, 0.6, 0.25)
					_play("pop", -15.0, 0.9 + 0.05 * k)
					_walk(h, S(Vector3(5.5 + 1.2 * k, 0, 12.5 + 0.8 * (k % 2))), 2.6, "peck"))
			# 門裡空了。他走到門口，站了很久
			_at(9.6, func():
				_hero.look = null
				_walk(_hero, S(Vector3(0.0, 0, 7.3)), 1.2, "idle"))
			_at(10.9, func():
				# 從門邊看他的臉：他對著黑黑的門裡面
				_face(_hero, S(Vector3(0.0, 0, 3.0)))
				_shot_cam(S(Vector3(1.6, 1.3, 5.45)), S(Vector3(0.0, 0.7, 7.3)), 42.0, 0.0, Vector3(-0.04, 0, 0.0))
				_hero.look = S(Vector3(0.4, 1.0, 3.0)))
			_at(12.6, func():
				_hero.look = null
				_set_anim(_hero, "sad"))
		# ---------------------------------------------------------- 回到屋頂
		"r_land":
			# 跟開頭同一個鏡頭：一隻長著五色尾羽的鳥降落在老位置
			var cp := Vector3(-9.0, 2.6, 14.5)
			_shot_cam(cp, Vector3(-0.2, 2.0, 2.0), 40.0, 0.0, Vector3(0.22, 0.0, -0.22))
			_sun_behind(cp, _hero_top(), 4.0)
			for k in _hens.size():
				_set_anim(_hens[k], "peck" if k % 2 == 0 else "idle")
			hero.position = Vector3(16.0, 15.0, -4.0)
			_face(_hero, _ridge(_farm, HERO_X))
			_set_anim(_hero, "glide")
			var tw2 := _tw()
			tw2.tween_interval(0.8)
			tw2.tween_property(hero, "position", _ridge(_farm, HERO_X) + Vector3(0.3, 1.2, 0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw2.tween_callback(func(): _set_anim(_hero, "flap"))
			tw2.tween_property(hero, "position", _ridge(_farm, HERO_X), 0.5)
			tw2.tween_callback(func():
				_set_anim(_hero, "idle")
				_face(_hero, Vector3(HERO_X - 1.0, 0, 20.0), 0.4)
				_play("thud", -14.0, 1.3)
				_set_anim(_cock, "shock")
				_emote(_cock, "！", Color(1.0, 0.9, 0.5), 1.0, 1.0)
				for h in _hens:
					_set_anim(h, "lookup")
				_set_anim(_chick, "flap"))
		"r_fly":
			_shot_cam(Vector3(-3.4, 1.9, 10.6), _hero_top() + Vector3(-1.2, -1.9, 1.0), 42.0, 0.0, Vector3(0.04, 0, -0.06))
			_roof_talk()
			_set_anim(_cock, "lookup")
		"r_new":
			_shot_cam(Vector3(2.9, ry + 1.2, 3.4), _hero_top() + Vector3(0, -0.2, 0), 28.0, 0.0, Vector3(-0.04, 0, -0.05))
			_sun_behind(Vector3(2.9, ry + 1.2, 3.4), _hero_top(), 16.0)
			_roof_talk()
			_set_anim(_hero, "cool")
		"r_found":
			_shot_cam(Vector3(-0.5, 1.75, 2.9), Vector3(-1.4, 0.55, 6.0), 34.0, 0.0, Vector3(-0.02, 0, 0.03))
			_roof_talk()
		"r_no":
			_shot_cam(Vector3(2.9, ry + 1.2, 3.4), _hero_top() + Vector3(0, -0.2, 0), 28.0, 0.0, Vector3(-0.04, 0, -0.05))
			_roof_talk()
			_set_anim(_hero, "sad")
		"r_place":
			_shot_cam(Vector3(8.0, 3.0, 10.5), Vector3(-0.2, 2.1, 2.6), 40.0, 0.0, Vector3(-0.06, 0, -0.05))
			_roof_talk()
			_set_anim(_hero, "sad")
		"r_back":
			_shot_cam(Vector3(2.4, ry + 1.5, 3.8), _hero_top() + Vector3(0, -0.25, 0), 30.0, 0.0, Vector3(-0.04, 0, -0.05))
			_roof_talk()
			_set_anim(_hero, "idle")
			_hero.look = Vector3(-1.4, 0.8, 6.0)
		"r_row":
			# 他把腳牌放在旁邊那一格，開始打碟——這次有聲音。雞一隻一隻上了屋頂，那一格沒有人去站
			_roof_talk()
			_hero.look = null
			_shot_cam(Vector3(2.6, ry + 1.2, 4.4), _ridge(_farm, HERO_X - 0.5) + Vector3(0, 0.45, 0), 32.0, 0.0, Vector3(-0.04, 0, -0.04))
			_set_anim(_hero, "peck")
			_face(_hero, _ridge(_farm, HERO_X - 0.9) + Vector3(0, 0, 1.0), 0.4)
			_at(1.1, func():
				_tag_on_ridge()
				_play("ding", -10.0)
				_emote(_ridge(_farm, HERO_X - 0.9) + Vector3(0, 0.6, 0.1), "✦", Color(1.0, 0.95, 0.5), 0.9, 0.5, 0.15))
			_at(1.6, func():
				_set_anim(_hero, "idle")
				_face(_hero, Vector3(HERO_X, 0, 20.0), 0.4))
			_at(2.4, func():
				_set_anim(_hero, "dj")
				_notes = "gold"
				_music_play("beat", -8.0)
				_shot_cam(Vector3(-2.2, 3.6, 14.0), Vector3(-0.6, 3.1, 0.5), 42.0, 0.0, Vector3(0.05, 0.02, -0.12))
				for a in [_cock, _chick] + _hens:
					_set_anim(a, "nod")
					a.look = null)
			# 一隻一隻跳上來
			var ups := [[_cock, HERO_X - 1.85], [_hens[0], HERO_X - 2.7], [_hens[1], HERO_X - 3.52], [_chick, HERO_X + 1.0]]
			for k in ups.size():
				var a: Dictionary = ups[k][0]
				var x: float = ups[k][1]
				_at(3.6 + 1.2 * k, func():
					_hop(a, Vector3(x, 0, 3.6), 0.35, 0.5)
					_hop(a, _ridge(_farm, x), 0.75, 2.6, 0.4, "nod")
					_at(1.2, func():
						(a.node as Node3D).rotation = Vector3.ZERO
						_play("thud", -18.0, 1.6)))
			_at(8.6, func(): _shot_cam(Vector3(-4.6, ry + 1.2, 5.6), _ridge(_farm, -0.6) + Vector3(0, 0.45, 0), 36.0, 0.0, Vector3(0.06, 0, -0.04)))
		"r_get":
			_row_state()
			_dance(true)
			_shot_cam(Vector3(-3.6, ry + 1.15, 4.4), _ridge(_farm, -0.5) + Vector3(0, 0.3, 0), 34.0, 0.0, Vector3(0.05, 0, -0.03))
		"r_song":
			_row_state()
			_dance(true)
			_shot_cam(Vector3(-1.9, ry + 1.2, 3.6), _ridge(_farm, 0.1) + Vector3(0, 0.4, 0), 32.0, 0.0, Vector3(0.03, 0, -0.03))
			_cock.look = _hero_top()
			_set_anim(_cock, "idle")
		"r_freeze":
			# 他的翅膀停在半空中，看了一眼旁邊的腳牌
			_row_state()
			_dance(true)
			_notes = ""
			_set_anim(_hero, "freeze")
			_cock.look = _hero_top()
			_set_anim(_cock, "idle")
			_music.volume_db = -26.0
			_shot_cam(Vector3(2.3, ry + 1.1, 3.0), _hero_top() + Vector3(-0.25, -0.35, 0), 28.0)
			_at(1.1, func():
				_shot_cam(Vector3(0.9, ry + 0.75, 2.3), _ridge(_farm, HERO_X - 0.9) + Vector3(0, 0.18, 0), 20.0, 0.0, Vector3(-0.02, 0, -0.05))
				_sun_behind(Vector3(0.9, ry + 0.75, 2.3), _ridge(_farm, HERO_X - 0.9) + Vector3(0, 0.3, 0), 10.0))
			_at(2.0, func():
				_play("bell", -12.0, 1.5)
				_emote(_ridge(_farm, HERO_X - 0.9) + Vector3(0.2, 0.55, 0.1), "✦", Color(1.0, 0.95, 0.5), 1.0, 0.4, 0.1))
		"r_listen":
			_row_state()
			_dance(true)
			_music_play("beat", -8.0)
			_notes = "gold"
			_set_anim(_hero, "cool")
			_cock.look = _hero_top()
			var cp2 := Vector3(2.6, ry + 1.2, 3.2)
			_shot_cam(cp2, _hero_top() + Vector3(0, -0.2, 0), 27.0, 0.0, Vector3(-0.04, 0, -0.05))
			_sun_behind(cp2, _hero_top(), 14.0)
		"r_end":
			# 他把帽子拉低，繼續打碟。鏡頭慢慢拉遠，黑幕；音樂沒有停
			_row_state()
			_dance(true)
			_music_play("beat", -8.0)
			_notes = "gold"
			_form(true, true)
			_set_anim(_hero, "dj_big")
			_play("whoosh", -14.0, 1.2)
			var cp3 := Vector3(-1.2, 3.0, 12.5)
			_shot_cam(cp3, Vector3(-0.6, ry - 0.6, 0.0), 38.0, 0.0, Vector3(-0.06, 0.1, 0.5))
			_sun_behind(cp3, _ridge(_farm, -0.4) + Vector3(0, 1.0, 0), 3.0)
			var tw3 := _tw()
			tw3.tween_interval(4.2)
			tw3.tween_callback(func(): _fade.color = Color(0, 0, 0, 0))
			tw3.tween_property(_fade, "color:a", 1.0, 2.6)
		# ---------------------------------------------------------- 片尾
		"post":
			# 空的屋頂。那隻小雞自己爬上來，學家豪的樣子比；沒有聲音。天上掉下來一片香蕉皮
			_music_stop(2.2)
			var cp4 := Vector3(-0.7, 2.6, 11.5)
			_shot_cam(cp4, _hero_top() + Vector3(0, -1.5, 0), 36.0, 0.0, Vector3(0.05, 0.14, -0.5))
			_sun_behind(cp4, _hero_top(), 1.5)
			(_chick.node as Node3D).visible = true
			(_chick.node as Node3D).position = _ridge(_farm, HERO_X)
			(_chick.node as Node3D).rotation = Vector3.ZERO
			_set_anim(_chick, "dj_big")
			_notes = "grey"
			_post_peel.visible = true
			_post_peel.position = _ridge(_farm, HERO_X - 0.9) + Vector3(0.4, 9.0, 0)
			var tw4 := _tw()
			tw4.tween_interval(3.6)
			tw4.set_parallel(true)
			tw4.tween_property(_post_peel, "position", _ridge(_farm, HERO_X - 0.9) + Vector3(0, 0.02, 0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw4.tween_property(_post_peel, "rotation:y", 6.0, 2.2)
			tw4.chain().tween_callback(func():
				_play("pop", -8.0, 0.8)
				_notes = ""
				_set_anim(_chick, "idle")
				_chick.look = _ridge(_farm, HERO_X - 0.9)
				_emote(_chick, "？", Color(1, 1, 1), 1.4, 0.7))
			tw4.chain().tween_interval(1.2)
			tw4.chain().tween_callback(func():
				_chick.look = null
				_set_anim(_chick, "lookup"))
			tw4.chain().tween_interval(0.5)
			tw4.chain().tween_callback(func(): _stamp("完　感謝遊玩", Color(1.0, 0.95, 0.82), 1.6, 64, -150.0))

## 神明講話：從正上方往下看（玩家平常看關卡的角度），一道金光打在家豪身上
func _god_view(h := 3.0) -> void:
	var hp := (_hero.node as Node3D).global_position
	_shot_cam(hp + Vector3(0.9, 6.5 + h * 0.2, 2.2), hp + Vector3(0, 0.7, 0), 36.0, 0.0, Vector3(0, 0.06, 0))
	_god_spot.global_position = hp + Vector3(0, 9.0, 0.2)
	_god_spot.light_energy = 7.0
	_hero.look = hp + Vector3(0.9, 8.0, 2.2)

## 已經化成鳳凰、浮在唱盤上面
func _fly_state() -> void:
	_form(true)
	_light_gate(12)
	_notes = "gold"
	_god_spot.light_energy = 0.0
	_hero.look = null
	if _fin_mode != "full":
		_set_fin("full")
		_fin_clock = 6.0
	_hero_fly = true
	_face(_hero, T(Vector3(0.6, 0, 8)))
	_set_anim(_hero, "fly")
	_music_play("beat", -11.0)

## 百鳥那一場後半：家豪停在半空中，底下的人坐起來了
func _birds_state() -> void:
	_form(true)
	_set_fin("off")
	_aura_follow = true
	(_hero.node as Node3D).position = T(Vector3(2.0, 7.0, 14.0))
	_set_anim(_hero, "fly")
	for k in _workers.size():
		var ap := _workers[k].anim as AnimationPlayer
		if ap and ap.has_animation("sit") and ap.current_animation != "sit":
			ap.play("sit")

## 屋頂上講話的那幾句：大家都還在原位，抬頭看家豪
func _roof_talk() -> void:
	(_hero.node as Node3D).position = _ridge(_farm, HERO_X)
	_face(_hero, Vector3(HERO_X - 1.0, 0, 20.0))
	_set_anim(_hero, "idle")
	_set_anim(_cock, "idle")
	_cock.look = _hero_top()
	for h in _hens:
		_set_anim(h, "idle")
		h.look = _hero_top()
	_set_anim(_chick, "idle")
	_chick.look = _hero_top()

## 大家跟著拍子點頭（地上的三隻母雞也是）
func _dance(on: bool) -> void:
	for a in [_cock, _chick] + _hens:
		_set_anim(a, "nod" if on else "idle")
		a.look = null
	_set_anim(_hero, "dj")

# ================================================================== 每一畫面

func _tick(dt: float) -> void:
	var hero := _hero.node as Node3D
	# 場地那邊的演出（唱盤、山海轉盤、鳳凰金光、百鳥）跟著這裡的時間走
	if _world.visible:
		_fin_clock += dt
		match _fin_mode:
			"tease":
				_world.set("_fin_on", true)
				_world.set("_fin_t", minf(0.4 + _fin_clock * 0.45, 2.3))
			"full":
				_world.set("_fin_on", true)
				_world.set("_fin_t", 2.4 + _fin_clock)
			_:
				_world.set("_fin_on", false)
		if _hero_fly and _fin_mode == "full":
			var rise: float = _world.fin_rise(2.4 + _fin_clock)
			hero.position = T(Vector3(0, 0.22 + rise + sin(_t * 2.2) * 0.12, 0))
		if _aura_follow:
			var ph = _world.get("_phoenix")
			if ph is Node3D:
				var flap := 1.0 - 0.10 * (0.5 + 0.5 * sin(_t * 3.2))
				(ph as Node3D).visible = hero.visible
				(ph as Node3D).scale = Vector3(1.6 * flap, 1.6, 1.6)
				var back := hero.global_position - _cam.global_position
				back.y = 0.0
				back = back.normalized()
				(ph as Node3D).global_position = hero.global_position + Vector3(0, -0.4, 0) + back * 0.4
				(ph as Node3D).global_rotation = Vector3(0, atan2(-back.x, -back.z), 0)
			var fk = _world.get("_flock")
			if fk is CPUParticles3D:
				(fk as CPUParticles3D).emitting = true
	# 尾羽輕輕擺
	for k in _feathers.size():
		var f := _feathers[k] as Node3D
		if f.visible:
			f.rotation.z = float(f.get_meta("roll")) + sin(_t * 2.0 + k) * 0.07
			f.rotation.x = sin(_t * 1.6 + k * 0.7) * 0.08 + 0.1 - (0.3 if String(_hero.anim) in ["fly", "glide"] else 0.0)
	# 音符：沒聲音的時候是灰的、往下掉；有聲音之後是金的、往上飄
	if _notes != "" and not _busy:
		_notes_t -= dt
		if _notes_t <= 0.0:
			_notes_t = BEAT
			var who := _chick if _shot == "post" else _hero
			var hp := (who.node as Node3D).global_position
			var side := 1.0 if int(_t / BEAT) % 2 == 0 else -1.0
			var up := 1.5 if who == _hero else 0.75
			if _notes == "grey":
				_emote(hp + Vector3(0.9 * side * (up / 1.5), up, 0.2), "♪" if side > 0.0 else "♫", Color(0.80, 0.80, 0.86), 1.2, 0.62 * (up / 1.5), -1.1 * (up / 1.5))
			else:
				_emote(hp + Vector3(1.0 * side, 1.6, 0.2), "♪" if side > 0.0 else "♫", Color(1.0, 0.86, 0.36), 1.3, 0.8, 1.2)
	# 仙鶴
	for c in _cranes:
		var n := c.node as Node3D
		if not n.visible:
			continue
		var fl := sin(_t * 9.0 + float(c.ph) * 3.0) * 0.6
		match String(c.mode):
			"fly":
				var k := clampf((_t - float(c.t0)) / float(c.dur), 0.0, 1.0)
				var a: Vector3 = c.from
				var b: Vector3 = c.to
				n.global_position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 1.5 + sin(_t * 3.0 + float(c.ph)) * 0.2, 0)
				var d := b - a
				n.rotation = Vector3(0, atan2(d.x, d.z), 0)
				if k >= 1.0:
					n.visible = false
			"hover":
				var h: Vector3 = c.hover
				n.global_position = h + Vector3(0, sin(_t * 9.0 + float(c.ph)) * 0.12, 0)
				fl = sin(_t * 16.0 + float(c.ph)) * 0.8
		if c.wl:
			(c.wl as Node3D).rotation.z = -fl
		if c.wr:
			(c.wr as Node3D).rotation.z = fl
	# 鐵皮屋的燈偶爾閃一下
	if _shed.visible:
		var ph2 := fmod(_t, 4.1)
		_lamp.light_energy = 3.2 * (0.5 if ph2 < 0.08 or (ph2 > 0.16 and ph2 < 0.2) else 1.0)

# ================================================================== 聲音：配樂是程式合成的

func _make_sounds() -> void:
	# 百鳥朝鳳祭天舞：四小節、宮調五聲音階的旋律，加大鼓、拍手、沙鈴和低音，最後幾聲鳥叫
	var bars := 4
	var b := s_buf(BEAT * 4.0 * bars)
	var mel := [
		[76, 79, 81, 79, 76, -1, 74, 76],
		[79, 81, 84, 81, 79, -1, 76, -1],
		[74, 76, 79, 76, 74, 72, 74, 76],
		[79, -1, 81, 79, 76, 74, 72, -1],
	]
	var bass := [48, 45, 50, 43]
	for bar in bars:
		var t0 := bar * BEAT * 4.0
		for beat in 4:
			var tb := t0 + beat * BEAT
			if beat == 0 or beat == 2:
				s_kick(b, tb, 0.75, true)
			if beat == 1:
				s_kick(b, tb + BEAT * 0.5, 0.55, true)
			if beat == 1 or beat == 3:
				s_noise(b, tb, 0.14, 0.34, 0.55, 11 + beat, 22.0, true)
				s_noise(b, tb + 0.012, 0.1, 0.2, 0.8, 17 + beat, 30.0, true)
			for h in 2:
				s_noise(b, tb + h * BEAT * 0.5, 0.05, 0.07 if h == 0 else 0.11, 0.95, 31 + beat * 2 + h, 70.0, true)
		for step in [0.0, 0.75, 1.5, 2.5, 3.25]:
			s_tone(b, t0 + step * BEAT, s_hz(bass[bar]), BEAT * 0.7, 0.42, 0.5, 7.0, true)
		for i in 8:
			var note: int = mel[bar][i]
			if note < 0:
				continue
			var at := t0 + i * BEAT * 0.5
			s_tone(b, at, s_hz(note), BEAT * 0.9, 0.24, 0.7, 5.5, true)
			s_tone(b, at, s_hz(note) * 2.003, BEAT * 0.5, 0.05, 0.2, 9.0, true)
	# 鳥叫：第二、第四小節尾巴幾聲往上的短音
	for bar in [1, 3]:
		for k in 3:
			s_glide(b, bar * BEAT * 4.0 + BEAT * (3.0 + 0.22 * k), 1900.0 + 200.0 * k, 3000.0 + 250.0 * k, 0.07, 0.10)
	_snd["beat"] = s_wav(b, true)
	# 鐘（圓門的鳥亮起來、尾羽長出來）
	var bl := s_buf(1.2)
	s_tone(bl, 0.0, s_hz(72), 1.2, 0.5, 0.45, 3.2)
	s_tone(bl, 0.0, s_hz(72) * 2.76, 0.6, 0.12, 0.1, 6.0)
	_snd["bell"] = s_wav(bl)
	# 唱片停下來的聲音
	var sp := s_buf(0.7)
	s_glide(sp, 0.0, 520.0, 50.0, 0.6, 0.6, 0.5)
	s_noise(sp, 0.0, 0.25, 0.25, 0.6, 5, 10.0)
	_snd["stop"] = s_wav(sp)
	# 鐵門拉開：低低的隆隆聲
	var rm := s_buf(2.4)
	s_noise(rm, 0.0, 2.4, 0.9, 0.035, 9, 0.9)
	s_noise(rm, 0.0, 2.4, 0.18, 0.5, 10, 1.2)
	_snd["rumble"] = s_wav(rm)
