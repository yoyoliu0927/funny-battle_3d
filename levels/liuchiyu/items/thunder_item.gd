extends "res://scripts/items/item.gd"
## 神蹟「雷」：按一下左鍵，一道閃電劈在準心指的地方。雷不會直接把人劈倒：
##   - 沒下雨：只有一聲巨響，旁邊的敵人嚇一跳，遠一點的還會聽到聲音跑過來（反而更糟）
##   - 劈在剛淋過雨、還濕著的地方：電會沿著水傳開，附近的敵人被電到、好幾秒動不了
## 雷也會劈開場地上的東西（例如河邊的枯樹、被雨淋大的樹），劈開之後風才吹得倒。

const PixelIcon := preload("res://levels/liuchiyu/items/pixel_icon.gd")
const SHOCK_RADIUS := 6.5      # 下雨時電傳得到多遠
const SHOCK_TIME := 4.5        # 被電到幾秒動不了
const SCARE_RADIUS := 3.0      # 沒下雨時嚇到多近的人
const CLOUD_SHADER := preload("res://levels/liuchiyu/shaders/oil_cloud.gdshader")
const CLOUD_HEIGHT := 13.0     # 烏雲在準心上面多高
const CLOUD_TIME := 1.1        # 烏雲停多久才散掉

var hint := ""                 # 切到這個道具時，技能欄上面那一行小字
var no_direct := true          # 準心直接指著人的時候不能用（神不能直接干預凡人；見 island_battle.gd）
var _ch := CLOUD_HEIGHT        # 這一次的烏雲多高

func _init() -> void:
	id = "thunder"
	name = "雷"
	tutorial = "按一下左鍵，一道閃電劈在準心的位置。\n劈在剛淋過雨、還濕著的地方，電會傳開，附近的敵人好幾秒動不了。\n劈在乾的地方只會嚇人一跳，還會把別的敵人引過來。"
	color = Color(1.0, 0.95, 0.5)
	hint = "按一下左鍵：閃電劈在準心"
	# 像素風圖示：一道閃電
	icon = PixelIcon.make([
		".......KKKK..",
		"......KYYYK..",
		".....KYYYK...",
		"....KYYYK....",
		"...KYYYK.....",
		"..KYYYYKKK...",
		"..KYYYYYYK...",
		"..KKKKYYK....",
		".....KYYK....",
		"....KYOK.....",
		"...KYOK......",
		"...KOK.......",
		"...KK........",
	], {"Y": Color(1.0, 0.90, 0.25), "O": Color(1.0, 0.62, 0.12), "K": Color(0.20, 0.16, 0.10)})
	radius = SHOCK_RADIUS
	cooldown = 0.0        # 沒有冷卻時間：想劈就劈（原本每次要等 3 秒）

func placement_error(_bt, _p: Vector3) -> String:
	return ""

func cast(bt, p: Vector3) -> void:
	_bolt(bt, p)
	bt.noise_at(p)
	# 場地上會被雷劈的東西（例如河邊的枯樹）
	if bt.world.has_method("lightning_strike"):
		bt.world.lightning_strike(p)
	# 這一關自己的機關（例如被雨淋大的樹）
	if bt.has_method("on_thunder"):
		bt.on_thunder(p)
	var raining: bool = bt.has_method("is_wet_at") and bt.is_wet_at(p)
	var n := 0
	for f in bt.enemies:
		if not f.alive() or f.data.get("hidden", false):
			continue        # 還沒上場的人（例如還在飛機上的騎士）不受影響
		var d: float = bt.flat_dist(f.pos, p)
		if raining and d <= SHOCK_RADIUS:
			f.data["blind_t"] = SHOCK_TIME
			f.data["blind_end"] = "%s回過神來" % f.name
			bt.log_event("%s被電到" % f.name)
			n += 1
		elif not raining and d <= SCARE_RADIUS and f.kind == "melee":
			f.kb_vel = Vector3.ZERO
			f.set_state("startled")
			bt.anim(f, "HitRecieve", 0.8)
			bt.log_event("%s被雷聲嚇到" % f.name)

## 閃電：一條從天上折下來的亮線，加一下閃光（只是畫面效果）
func _bolt(bt, p: Vector3) -> void:
	# 烏雲多高：戰局可以自己決定（例如劈火山的時候拉高，才不會擋住噴出來的岩漿球）
	_ch = CLOUD_HEIGHT
	if bt.has_method("thunder_cloud_height"):
		_ch = float(bt.thunder_cloud_height(p))
	var holder := Node3D.new()
	bt.fx_root.add_child(holder)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(p.x) * 131.0 + absf(p.z) * 71.0) + 7
	# 上面先聚一團烏雲（跟雨的烏雲同一種畫法），閃電從雲裡劈下來
	var cloud := Node3D.new()
	cloud.position = p + Vector3(0.0, _ch, 0.0)
	bt.fx_root.add_child(cloud)
	var cmat := ShaderMaterial.new()
	cmat.shader = CLOUD_SHADER
	for k in 12:
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 8
		sm.rings = 4
		puff.mesh = sm
		puff.material_override = cmat
		var a := TAU * float(k) / 12.0
		var rr := rng.randf_range(0.0, 3.0)
		var sc := rng.randf_range(1.4, 2.6)
		puff.position = Vector3(cos(a) * rr, sc * 0.35 + rng.randf_range(0.0, 0.5), sin(a) * rr)
		puff.scale = Vector3(sc, sc * 0.7, sc)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.add_child(puff)
	bt.get_tree().create_timer(CLOUD_TIME).timeout.connect(func() -> void:
		if is_instance_valid(cloud):
			cloud.queue_free())
	var prev := p
	var w := 0.16
	var seg_n := 10
	for k in seg_n:
		# 一路折到雲底
		var up := _ch * float(k + 1) / seg_n
		var wob := 1.4 * (1.0 - float(k + 1) / seg_n)
		var nxt := p + Vector3(rng.randf_range(-wob, wob), up, rng.randf_range(-wob, wob))
		# 兩片交叉的長條，從哪個角度看都有寬度
		for side in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
			var q := [prev - side, prev + side, nxt + side, nxt - side]
			for t in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[t])
		prev = nxt
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(4.0, 4.0, 5.0)        # 很亮，會發光
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 0.9, 1.0)
	light.light_energy = 14.0
	light.omni_range = 34.0
	light.position = p + Vector3(0.0, 4.0, 0.0)
	holder.add_child(light)
	bt.get_tree().create_timer(0.28).timeout.connect(func() -> void:
		if is_instance_valid(holder):
			holder.queue_free())
