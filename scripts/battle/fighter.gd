extends RefCounted
## 戰局裡的一個角色（家豪或敵人）的資料。所有關卡共用。
## 敵人的各項數值由關卡的 _enemy_specs() 決定（見 battle_base.gd）。

var name := ""
var node: Node3D
var is_bird := false
var kind := "melee"            # 敵人種類："melee"＝一般近戰（農夫型），其他名字由關卡自己處理
var max_hp := 10.0
var hp := 10.0
var speed := 2.0
var reach := 1.0
var windup := 0.3
var recover := 0.8
var state := "idle"
var t := 0.0
var pos := Vector3.ZERO
var start_pos := Vector3.ZERO
var start_yaw := 0.0
var yaw := 0.0
var kb_vel := Vector3.ZERO
var air := 0.0
var anim: AnimationPlayer
var body: Node3D
var wings: Array = []
var heavy := false
var attack_n := 0
var fled_half := false
var fly_from := Vector3.ZERO
var fly_to := Vector3.ZERO
var fly_dur := 1.0
var fly_peak := 1.0
var after_fly := ""
var detouring := false
var chased := false

# 敵人用
var route: Array = []
var loop := true
var pause := 1.0
var wp := 1
var wp_dir := 1
var look_yaw := 0.0
var cone: MeshInstance3D
var is_boss := false
var shoot_cd := 0.0
var gun: Node3D
var aggro := false
var alert_t := -1.0
var target           # 家豪目前鎖定的敵人（Fighter）
var feed_target := -1
var data := {}       # 關卡自己要記的東西放這裡（例如 Boss 的狀態）

# 敵人的個別設定（預設值是「農夫型」）
var kick_damage := 2.0
var heavy_damage := 4.0
var vision_range := 7.0
var vision_half := deg_to_rad(50.0)
var has_cone := true           # 腳下畫紅色偵測扇形
var hears_noise := true        # 聽到附近打鬥會趕過來
var can_slip := true           # 會踩到香蕉皮
var immune_peck := false       # 家豪啄不痛
var immune_rock := false       # 巨石撞不倒
var target_last := false       # 家豪最後才去打他（其他敵人都倒了才打）
var hud_name := ""             # 右上角敵人欄顯示的名字（空的就用 name）
var face := "farmer"           # 右上角頭像的畫法："farmer" / "boss"；有 portrait 就用圖片
var portrait: Texture2D
var bar_y := 2.85              # 頭上血條的高度

# 血條
var bar: Control
var bar_fill: ColorRect
var bar_chip: ColorRect
var chip := 1.0

func set_state(s: String) -> void:
	state = s
	t = 0.0

func alive() -> bool:
	return state != "dead" and state != "drown"

func ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)
