extends "res://levels/liuchiyu/island_battle.gd"
## 第一小關的戰局：圓形盆地，只用「風」（按住左鍵一直吹）。盆地三邊各有一樣可以吹的東西：
##   - 東南邊平台上的滾石：朝盆地裡面對它吹，石頭滾下去、衝上對面的平台，路上的人會被撞倒；到了對面可以再吹
##   - 西南邊的大風車：對著它一直吹，葉片越轉越快，轉到極限就整個順著風飛進盆地，砸到底下的人
##   - 北邊河岸的枯樹：農夫都倒下之後，天上會打下一道雷把它劈開，這時候朝河的方向吹，它才會倒下去變成橋
## 另外，對著農夫的臉吹，他會睜不開眼睛、好幾秒看不見，家豪可以趁機偷襲。
## 這些對家豪也有效：滾石和葉片會撞傷他，對著他的臉吹他也會看不見，所以要看清楚再吹。
## 橋搭好之後家豪會自己走過樹幹過河，然後接第二小關。

const WindItem := preload("res://levels/liuchiyu/items/wind_item.gd")
const ThunderItem := preload("res://levels/liuchiyu/items/thunder_item.gd")

const BASIN_C := Vector2(0.0, 1.0)      # 盆地中心（這一小關的座標）
const SHELF_R := 11.2                   # 滾石停在平台上的半徑
const ROCK_R := 1.7                     # 滾石多大（要跟 island_world.gd 的 ROCK_RADIUS 一樣）
const ROCK_HIT := 2.2                   # 離滾石多近會被撞
const ROCK_DAMAGE := 6.0                # 撞一下扣多少血（農夫有 8）
const ROCK_BIRD_DAMAGE := HIT_HALF      # 滾石撞到家豪扣多少血（半顆心）
const WHEEL_BIRD_DAMAGE := HIT_HALF     # 風車葉片砸到家豪扣多少血（半顆心）
const ROCK_GUST := 5.0                  # 風要吹在離滾石多近才吹得動
const MILL_GUST := 8.0                  # 風要吹在離風車多近才算
const MILL_NEED := 3.0                  # 轉到這個速度，葉片就飛出去
const MILL_RATE := 1.1                  # 按住吹的時候每秒快多少（大約吹三秒就飛出去）
const MILL_DECAY := 0.35                # 沒在吹的時候每秒慢多少
const BOLT_DELAY := 3.0                 # 農夫都倒下之後，過多久雷劈在枯樹上（這之前鏡頭已經先飛過去、停了一下）
const CLOSEUP_LEAD := 2.4               # 打雷前多久鏡頭就開始飛去看枯樹（飛到之後還會停一下才打雷）
const CLOSEUP_FLY := 1.1                # 鏡頭飛過去要幾秒
const CLOSEUP_HOLD := 3.2               # 雷劈下來之後，特寫再停多久才把鏡頭還給玩家（這段時間底下有一行提示）
const BOLT_HINT := "枯樹被雷劈開了……好像可以用風把它吹倒？"
const BOLT_HINT_TIME := 6.0             # 提示停幾秒（特寫結束、鏡頭還給玩家之後還會再留一下）
const WHEEL_FLY := 9.0                  # 葉片飛出去多遠（風車在盆地邊上，要飛進盆地裡）
const WHEEL_TIME := 1.1                 # 飛幾秒落地
const WHEEL_CRUSH := 5.0                # 落地時砸到多大一圈（葉片很大）
const WALK_SPEED := 5.0                 # 過關後家豪走去過橋的速度

var _rock: MeshInstance3D
var _rock_pos := Vector2.ZERO           # 滾石現在在哪（x, z）
var _rock_from := Vector2.ZERO
var _rock_to := Vector2.ZERO
var _rock_s := 0.0                      # 這一趟已經滾了多遠
var _rock_rolling := false
var _rock_hit: Array = []
var _rock_spin := 0.0
var _rock_dir := Vector3.RIGHT

var _mill_level := 0.0
var _mill_gone := false                 # 葉片已經飛出去了
var _mill_blown := false                # 這一步有沒有被風吹到
var _bolt_t := -1.0                     # 過關之後倒數，到了就打雷劈枯樹（< 0 = 還沒開始數／已經劈過）
var _bolt_done := false
var _closeup := false                   # 現在鏡頭是不是被拿去拍枯樹的特寫
var _closeup_t := 0.0
var _cam_back := Transform3D.IDENTITY   # 特寫結束要把玩家放回哪裡
var _head_back := 0.0
var _wheel_t := -1.0                    # 葉片還有幾秒落地（< 0 = 沒在飛）
var _wheel_land := Vector3.ZERO


func _make_items() -> Array:
	return [
		WindItem.new().uses(0, -1),      # 開打後才有用，不限次數
	]

func _enemy_specs() -> Array:
	return [
		{"name": "農夫1", "hp": FARMER_HP, "kick_damage": FARMER_KICK, "route": [Vector3(-4, 0, 1), Vector3(4, 0, 1)], "loop": false, "pause": 1.5},
		{"name": "農夫2", "hp": FARMER_HP, "kick_damage": FARMER_KICK, "route": [Vector3(3, 0, -6), Vector3(-3, 0, -7), Vector3(0, 0, -3)], "loop": true, "pause": 1.0},
		{"name": "農夫3", "hp": FARMER_HP, "kick_damage": FARMER_KICK, "route": [Vector3(6, 0, 5), Vector3(7, 0, -2)], "loop": false, "pause": 1.2},
	]

## 開場只有一句（每個道具的說明在切換道具時會出現在技能欄上面）
func _tutorial_texts() -> Array:
	return ["按住左鍵吹風：風不能直接吹人，要吹沙地、吹滾石、吹風車。"]

func _prepare_hint() -> String:
	return "準備中：開打後按住左鍵吹風——吹沙地（沙子會飛向下風處的人）、吹滾石、吹風車　按 Enter 開始"

func _win_line() -> String:
	return "把河邊的枯樹吹倒當橋。"

func _next_stage() -> int:
	return 2

## 過關之後家豪要走的路：樹根旁邊 → 踩著倒下來的樹幹過河 → 對岸
func _exit_path() -> Array[Vector3]:
	return world.bridge_path() if world.has_method("bridge_path") else []

## 橋搭好了才能走上去
func _exit_open() -> bool:
	return world.bridge_ready()

func _next_hint() -> String:
	if world.has_method("bridge_ready") and world.bridge_ready():
		return "橋搭好了，家豪正在過河"
	if _bolt_done:
		if not _star_done and not _mill_gone:
			return "枯樹被雷劈開了：朝河吹倒它當橋。風車頂上還有一顆星星"
		return "枯樹被雷劈開了：朝河的方向對它吹風，把它吹倒當橋"
	return "……"


# ---------------------------------------------------------------- 機關

func _level_setup() -> void:
	super()
	world.forget_zones()        # 從第一小關重新開始：之前記的各關樣子都不算了
	_rock = MeshInstance3D.new()
	_rock.name = "RollingRock"
	var sm := SphereMesh.new()
	sm.radius = ROCK_R
	sm.height = ROCK_R * 2.0
	sm.radial_segments = 7
	sm.rings = 4
	_rock.mesh = sm
	_rock.material_override = world._cliff_material()
	world.add_child(_rock)
	_reset_gadgets()

func _level_reset() -> void:
	super()
	_reset_gadgets()

func _reset_gadgets() -> void:
	_rock_pos = world.ROCK_HOME        # 一開始在東南邊的平台上（離第二、第三小關最遠的那一側）
	_rock_rolling = false
	_rock_hit.clear()
	_rock_spin = 0.0
	_mill_level = 0.0
	_mill_gone = false
	_mill_blown = false
	_bolt_t = -1.0
	_bolt_done = false
	_end_closeup()
	_wheel_t = -1.0
	if world.has_method("windmill_reset"):
		world.windmill_reset()

## 星星：一開始在風車頂上。葉片被吹掉的時候跟著飛出來，落在盆地的正中間，這時候才拿得到
func _star_ready() -> bool:
	return _mill_gone and _wheel_t < 0.0

## 不管葉片往哪邊飛，星星都掉在盆地的正中間
func _star_pos() -> Vector3:
	var c: Vector2 = world.STAR1_LAND
	return Vector3(c.x, world.height_at(c.x, c.y), c.y)

## 換關的時候記下來：滾石停在哪、風車的葉片還在不在（掉在哪）
func _save_state() -> void:
	world.remember_zone(1, {"rock": _rock_pos, "mill_gone": _mill_gone, "wheel": Vector2(_wheel_land.x, _wheel_land.z)})

## 風吹過來（按住吹的每一步，風道具會叫這個）：p 是準心的位置，dir 是風向
func on_wind(p: Vector3, dir: Vector3, dt: float) -> void:
	var d2 := Vector2(dir.x, dir.z).normalized()
	# 滾石：要朝盆地裡面吹才會動；沿著風向一路滾到對面的平台（直線和平台那一圈的另一個交點）
	if not _rock_rolling and Vector2(p.x, p.z).distance_to(_rock_pos) <= ROCK_GUST:
		if d2.dot((BASIN_C - _rock_pos).normalized()) >= 0.3:
			_rock_from = _rock_pos
			_rock_to = _rock_pos + d2 * (2.0 * (BASIN_C - _rock_pos).dot(d2))
			_rock_s = 0.0
			_rock_rolling = true
			_rock_hit.clear()
			_rock_dir = Vector3(d2.x, 0.0, d2.y)
			log_event("滾石被風吹動了")
	# 風車：吹著的時候越轉越快，轉到極限葉片就順著風飛出去
	var mp: Vector3 = world.windmill_pos()
	if not _mill_gone and flat_dist(p, mp) <= MILL_GUST:
		_mill_blown = true
		_mill_level += MILL_RATE * dt
		if _mill_level >= MILL_NEED:
			_mill_gone = true
			_wheel_t = WHEEL_TIME
			_wheel_land = Vector3(mp.x + dir.x * WHEEL_FLY, 0.0, mp.z + dir.z * WHEEL_FLY)
			world.windmill_launch(_wheel_land, WHEEL_TIME)
			log_event("風車的葉片飛出去了")

func _level_step(dt: float) -> void:
	super(dt)
	_step_gadgets(dt)

func _level_step_ended(dt: float) -> void:
	super(dt)
	_step_gadgets(dt)
	if _won():
		# 農夫都倒下了：過一下子，天上打下一道雷，把河邊的枯樹劈開（劈開之後風才吹得倒）
		if not _bolt_done:
			if _bolt_t < 0.0:
				_bolt_t = BOLT_DELAY
			_bolt_t -= dt
			if not _closeup and _bolt_t <= CLOSEUP_LEAD:
				_begin_closeup()
			if _bolt_t <= 0.0:
				_bolt_done = true
				var tp: Vector3 = world.dead_tree_pos()
				ThunderItem.new()._bolt(self, tp)
				world.lightning_strike(tp)
				log_event("一道雷劈在枯樹上")
				_closeup_t = CLOSEUP_HOLD
				_show_bolt_hint()
		elif _closeup:
			_closeup_t -= dt
			if _closeup_t <= 0.0:
				_end_closeup()

func _step_gadgets(dt: float) -> void:
	# 滾石：下坡越滾越快，上坡慢下來，到對面的平台就停住
	if _rock_rolling:
		var top: float = world.height_at(_rock_from.x, _rock_from.y)
		var here: float = world.height_at(_rock_pos.x, _rock_pos.y)
		var speed := sqrt(maxf(9.0 + 2.0 * 9.8 * (top - here), 6.0)) * 0.8
		_rock_s += speed * dt
		_rock_spin += speed * dt / ROCK_R
		var total := _rock_from.distance_to(_rock_to)
		_rock_pos = _rock_from.lerp(_rock_to, clampf(_rock_s / total, 0.0, 1.0))
		var cur := Vector3(_rock_pos.x, 0.0, _rock_pos.y)
		for f in enemies:
			if f.alive() and not _rock_hit.has(f) and f.air < 0.5 and flat_dist(f.pos, cur) < ROCK_HIT:
				_rock_hit.append(f)
				f.hp = maxf(f.hp - ROCK_DAMAGE, 0.0)
				f.data.erase("blind_t")
				noise_at(cur)
				aggro(f)
				f.heavy = false
				f.kb_vel = _rock_dir * 3.0
				anim(f, "Death")
				f.set_state("dead" if f.hp <= 0.0 else "down")
				log_event("滾石撞倒%s（剩 %d）" % [f.name, ceili(f.hp)])
		# 家豪站在路上也一樣會被撞
		if bird.alive() and not _rock_hit.has(bird) and bird.air < 0.5 and flat_dist(bird.pos, cur) < ROCK_HIT:
			_rock_hit.append(bird)
			log_event("滾石撞到家豪")
			hit_bird(minf(ROCK_BIRD_DAMAGE, maxf(bird.hp - 1.0, 0.0)), true, cur - _rock_dir)        # 最多撞到剩 1 滴血
			say_as(bird, "咕啊——！")
		if _rock_s >= total:
			_rock_rolling = false
			if _rock_hit.is_empty():
				log_event("滾石滾到對面，沒撞到人")
	# 風車：沒在吹就慢慢慢下來；葉片落地的時候砸到底下的人
	if not _mill_gone and not _mill_blown and _mill_level > 0.0:
		_mill_level = maxf(_mill_level - MILL_DECAY * dt, 0.0)
	_mill_blown = false
	if world.has_method("windmill_set_level") and not _mill_gone:
		world.windmill_set_level(_mill_level)
	if _wheel_t >= 0.0:
		_wheel_t -= dt
		if _wheel_t < 0.0:
			var n := 0
			for f in enemies:
				if f.alive() and flat_dist(f.pos, _wheel_land) <= WHEEL_CRUSH:
					f.hp = 0.0
					f.data.erase("blind_t")
					f.set_state("dead")
					anim(f, "Death")
					log_event("風車的葉片砸倒%s" % f.name)
					n += 1
			if bird.alive() and bird.air < 0.5 and flat_dist(bird.pos, _wheel_land) <= WHEEL_CRUSH:
				log_event("風車的葉片砸到家豪")
				hit_bird(minf(WHEEL_BIRD_DAMAGE, maxf(bird.hp - 1.0, 0.0)), true, _wheel_land)
			noise_at(_wheel_land)        # 落地的巨響，還站著的人會聽到
			if n == 0:
				log_event("風車的葉片掉在地上，沒砸到人")

## 滾石的模型跟著位置走、順著滾的方向轉
func _level_visuals() -> void:
	super()
	_update_highlights_aim()
	# 星星：還在風車上 → 葉片飛出去的時候跟著飛出來 → 落在盆地正中間（拿到的動畫由 island_battle 接手）
	var sn: Node3D = world.star_node(1)
	if sn and is_instance_valid(sn) and not _star_done and _star_fx < 0.0:
		var home: Vector3 = world.star_home(1)
		var land := _star_pos() + Vector3(0.0, 1.3, 0.0)
		if not _mill_gone:
			sn.global_position = home
		elif _wheel_t >= 0.0:
			var k := 1.0 - clampf(_wheel_t / WHEEL_TIME, 0.0, 1.0)
			var p := home.lerp(land, k)
			p.y = lerpf(home.y, land.y, k * k) + sin(k * PI) * 3.0        # 拋物線：先往上甩一下，再越掉越快
			sn.global_position = p
		else:
			sn.global_position = land
	if _rock:
		var y: float = world.height_at(_rock_pos.x, _rock_pos.y) + ROCK_R * 0.85
		_rock.global_position = Vector3(_rock_pos.x, y, _rock_pos.y)
		var axis := Vector3.UP.cross(_rock_dir).normalized()
		_rock.global_basis = Basis(axis, _rock_spin) if axis.length() > 0.5 else Basis.IDENTITY

## 拿著風、準心指到吹得動的東西（滾石、風車、枯樹）的時候，那個東西變白，讓玩家知道現在吹下去會有反應
func _update_highlights_aim() -> void:
	if not world.has_method("set_highlight"):
		return
	var p := _aim_p()
	# 準備階段（還沒按 Enter）也會變白，先看得出哪些東西可以互動
	var can: bool = not _leaving and selected >= 0 and selected < items.size() and items[selected].id == "wind"
	world.set_highlight(_rock, can and not _rock_rolling and Vector2(p.x, p.z).distance_to(_rock_pos) <= ROCK_GUST)
	world.set_highlight(world.windmill_node(), can and not _mill_gone and flat_dist(p, world.windmill_pos()) <= MILL_GUST)
	world.set_highlight(world.dead_tree_node(), can and not _closeup and world.tree_in_reach(p))

## 晚上會閃藍綠色的光的東西：還能互動的才閃
func _glow_nodes() -> Array:
	return [
		[_rock, not _rock_rolling],
		[world.windmill_node(), not _mill_gone],
		[world.dead_tree_node(), world.tree_struck() and not world.bridge_ready()],      # 被雷劈過之後才亮
	]

## 準心指著吹得動的東西（會變白的那幾樣）的時候，就算視線上有人也照樣可以吹
func _aim_on_interactive() -> bool:
	if super():
		return true
	if _held_id() != "wind":
		return false
	var p := _aim_p()
	return (not _rock_rolling and Vector2(p.x, p.z).distance_to(_rock_pos) <= ROCK_GUST) \
		or (not _mill_gone and flat_dist(p, world.windmill_pos()) <= MILL_GUST) \
		or (not _closeup and world.tree_in_reach(p))

## 可以用風吹的三樣東西（準心指在它們身上就算指到）
func _aim_targets() -> Array:
	var out: Array = []
	if not _rock_rolling:
		out.append({"pos": Vector3(_rock_pos.x, world.height_at(_rock_pos.x, _rock_pos.y), _rock_pos.y), "h": ROCK_R * 2.0, "r": ROCK_R + 0.6})
	if not _mill_gone:
		out.append({"pos": world.windmill_pos(), "h": 15.0, "r": 4.0})
	if world.tree_struck() and not world.bridge_ready() and not _closeup:
		out.append({"pos": world.dead_tree_pos(), "h": 11.0, "r": 2.6})
	return out

# ---------------------------------------------------------------- 雷劈枯樹的特寫

## 把鏡頭借走，擺到枯樹斜前方看著它（玩家這段時間不能動）；結束再放回原本的位置
func _begin_closeup() -> void:
	if _closeup or player == null:
		return
	_closeup = true
	_closeup_fly = 0.0
	_cam_back = player.global_transform
	var head := player.get_node_or_null("Head") as Node3D
	_head_back = head.rotation.x if head else 0.0

func _end_closeup() -> void:
	if not _closeup:
		return
	_closeup = false
	if player:
		player.global_transform = _cam_back
		var head := player.get_node_or_null("Head") as Node3D
		if head:
			head.rotation.x = _head_back
		player.set("velocity", Vector3.ZERO)

var _closeup_fly := 0.0        # 鏡頭飛去枯樹已經飛了幾秒

## 雷劈下來之後，技能欄上面浮一行小字提示（用的是道具說明那一行字，過幾秒自己淡掉）
func _show_bolt_hint() -> void:
	if _hint_label == null:
		return
	_hint_label.text = BOLT_HINT
	_hint_t = BOLT_HINT_TIME

func _process(dt: float) -> void:
	super(dt)
	if _closeup and player:
		var tp: Vector3 = world.dead_tree_pos()
		var from := tp + Vector3(7.5, 5.0, 9.0)
		var at := tp + Vector3(0.0, 4.5, 0.0)
		var d := at - from
		var head := player.get_node_or_null("Head") as Node3D
		# 鏡頭從玩家原本的位置平順地飛過去（慢慢起步、慢慢停下），不是一下子跳過去
		_closeup_fly = minf(_closeup_fly + dt, CLOSEUP_FLY)
		var k := smoothstep(0.0, 1.0, _closeup_fly / CLOSEUP_FLY)
		player.global_position = _cam_back.origin.lerp(from - Vector3(0.0, 1.65, 0.0), k)
		player.rotation = Vector3(0.0, lerp_angle(_cam_back.basis.get_euler().y, atan2(-d.x, -d.z), k), 0.0)
		player.set("velocity", Vector3.ZERO)
		if head:
			head.rotation.x = lerp_angle(_head_back, atan2(d.y, Vector2(d.x, d.z).length()), k)

