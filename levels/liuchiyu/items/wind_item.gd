extends "res://scripts/items/item.gd"
## 神蹟「風」：按住左鍵，從神（鏡頭）所在的位置朝準心的方向一直吹。
## 風不會直接對人有任何作用（跟雷一樣：神不能直接干預凡人，只能動場地上的東西）：
##   - 對著場地上的「沙地」吹：沙子被捲起來順著風飛出去，下風處的人被沙子吹進眼睛，好幾秒看不見、站在原地，
##     家豪可以趁機偷襲。沙地一直都在，隔一小段時間可以再吹一次。家豪站在下風處也一樣會中。
##     （沙地在哪、吹得到誰，都在 island_battle.gd 的 blow_sand()；各小關用 _sand_specs() 擺沙地）
##   - 風不會把人吹動（推人的程式還留著，要開的話把 push 設成 true）
##   - 場地上吹得動的東西會有反應：滾石、風車、被雷劈過的樹……（各關自己的 on_wind()）
##   - 準心直接指著人的時候不能起風（island_battle.gd 的 _aimed_person()）
## 畫面上：用一條一條的白線表示風。吹在一般的地面上不會捲起任何東西，只有吹到沙地才會揚起沙。

const PixelIcon := preload("res://levels/liuchiyu/items/pixel_icon.gd")
const GUST_RADIUS := 6.0       # 風吹得到多大一圈
const PUSH_SPEED := 2.7         # 一直吹的時候，人每秒被往後推多遠（農夫自己走路是每秒 2）
const PUSH_BIRD := 2.0          # 家豪被推的速度
const PUSH_DELAY := 0.9         # 要連續按住這麼久之後，人才開始被推（剛吹的時候不會動）
const PUSH_RAMP := 0.6          # 開始推之後，再過這麼久才推到全速

var hint := ""                 # 切到這個道具時，技能欄上面那一行小字
var hold := true               # 按住持續施放（見 island_battle.gd 的 _hold_tick）
var any_aim := true            # 準心不用指到地面也能吹
var push := false              # 按住久了會不會把人往後推（現在每一關都關掉，只留吹沙地和吹機關）
var no_direct := true          # 準心直接指著人的時候不能用（神不能直接干預凡人）
var _fx: CPUParticles3D
var _held := 0.0               # 這一次已經連續按住多久

func _init() -> void:
	id = "wind"
	name = "風"
	tutorial = "按住左鍵，朝準心的方向一直吹風。\n風不能直接吹人，但吹得動場地上的東西。\n對著沙地吹，沙子會順著風飛出去，下風處的敵人好幾秒看不見。"
	color = Color(0.75, 0.92, 1.0)
	radius = GUST_RADIUS
	cooldown = 0.0
	hint = "按住左鍵：朝準心一直吹風（吹沙地、吹機關）"
	# 像素風圖示：三道捲起來的風
	icon = PixelIcon.make([
		".............",
		".....WWW.....",
		"....W...W....",
		"........W....",
		"WWWWWWWW.....",
		".............",
		".........BB..",
		"........B..B.",
		"...........B.",
		".BBBBBBBBBB..",
		".............",
		"..WWWWWW.W...",
		"........W....",
	], {"W": Color(0.96, 0.99, 1.0), "B": Color(0.62, 0.86, 1.0)})

## 關掉「把人往後推」（用法：WindItem.new().no_push().uses(0, -1)）
func no_push():
	push = false
	tutorial = "按住左鍵，朝準心的方向一直吹風。
風不能直接吹人，但吹得動場地上的東西。
對著沙地吹，沙子會順著風飛出去，下風處的敵人（還有家豪）好幾秒看不見。"
	return self

func placement_error(_bt, _p: Vector3) -> String:
	return ""

func reset(_bt) -> void:
	_held = 0.0
	_fx = null

## 按下去那一下共用程式會叫這個；風是按住才有效，所以這裡什麼都不做
func cast(_bt, _p: Vector3) -> void:
	pass

func step(_bt, _dt: float) -> void:
	pass

## 按住的每一步（1/60 秒）：p 是準心的位置，dir 是風向，fresh = 剛按下去的第一步
func hold_step(bt, p: Vector3, dir: Vector3, dt: float, fresh: bool) -> void:
	if fresh:
		_held = 0.0
		bt.log_event("起風（%.1f, %.1f）風向（%.2f, %.2f）" % [p.x, p.z, dir.x, dir.z])
	_held += dt
	# 吹在一般的地面上不會捲起任何東西（以前會捲起落葉，看起來像地面也被風影響了）：只有白線
	# 風吹到沙地：沙子飛起來，下風處的人看不見（見 island_battle.gd 的 blow_sand()）
	if bt.has_method("blow_sand"):
		bt.blow_sand(p, dir)
	_streaks(bt, p, dir)
	if bt.world.has_method("wind_gust"):
		bt.world.wind_gust(p, dir)
	if bt.has_method("on_wind"):
		bt.on_wind(p, dir, dt)
	if bt.phase != bt.Phase.RUNNING:
		return
	# 一直吹的時候，風吹得到的人會被順著風向往後推（推不出場地、推不過擋路的東西）。
	# 可以拿來把農夫吹進水池、吹到樹底下，或是把家豪吹離危險的地方
	# 剛開始吹的時候不會動，要連續按住一陣子才開始推，而且是慢慢加到全速
	var k := clampf((_held - PUSH_DELAY) / PUSH_RAMP, 0.0, 1.0)
	if push and k > 0.0:
		for f in bt.enemies:
			# data.rooted = 站崗不動的人（例如守門員），風吹不動
			if f.alive() and f.state != "down" and f.air < 0.5 and not f.data.get("rooted", false) and bt.flat_dist(f.pos, p) <= GUST_RADIUS:
				_push(bt, f, dir, PUSH_SPEED * k * dt)
		var bb = bt.bird
		if bb.alive() and bb.state != "fly" and bt.flat_dist(bb.pos, p) <= GUST_RADIUS:
			_push(bt, bb, dir, PUSH_BIRD * k * dt)

## 把一個角色順著風向推一小段：不會推出遊玩範圍，遇到擋路的東西（樹、倒下的樹幹）會被擋住
func _push(bt, f, dir: Vector3, dist: float) -> void:
	var nxt: Vector3 = f.pos + Vector3(dir.x, 0.0, dir.z) * dist
	f.pos = bt.ground(bt.world.clamp_play(bt._avoid(f.pos, nxt, 0.4)))

func hold_end(_bt) -> void:
	if _fx and is_instance_valid(_fx):
		_fx.emitting = false

## 風的樣子：一條一條從神這裡飛向準心的白線
func _streaks(bt, p: Vector3, dir: Vector3) -> void:
	if _fx == null or not is_instance_valid(_fx):
		# 細長的方條（不是面片），從哪個角度看都是一條線；長邊會順著飛的方向
		var qm := BoxMesh.new()
		qm.size = Vector3(0.04, 1.9, 0.04)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = m
		_fx = CPUParticles3D.new()
		_fx.mesh = qm
		_fx.amount = 70
		_fx.lifetime = 0.6
		_fx.local_coords = false
		_fx.particle_flag_align_y = true        # 白線的長邊順著飛的方向
		_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_fx.emission_box_extents = Vector3(1.6, 1.0, 1.6)
		_fx.spread = 3.0
		_fx.initial_velocity_min = 16.0
		_fx.initial_velocity_max = 24.0
		_fx.gravity = Vector3.ZERO
		_fx.scale_amount_min = 0.6
		_fx.scale_amount_max = 1.4
		bt.fx_root.add_child(_fx)
	# 白線從神（鏡頭）這裡出發，一路吹向準心指的地方：人在高處，風就從高處吹下去
	# 方向就是玩家現在看的方向：抬頭看，白線就往上飛
	var from: Vector3 = bt.camera.global_position
	var dist := (p - from).length()
	var d3: Vector3 = -bt.camera.global_basis.z
	if d3.length() < 0.5:
		d3 = dir
	_fx.direction = d3
	_fx.lifetime = clampf(dist / 20.0, 0.45, 1.6)        # 飛到準心那邊差不多就消失
	_fx.global_position = from + d3 * 2.5 - Vector3(0.0, 0.5, 0.0)
	_fx.emitting = true
