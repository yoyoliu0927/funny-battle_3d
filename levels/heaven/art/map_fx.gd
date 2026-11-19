extends Node3D
## 選關地圖上丹穴山的小動畫（純裝飾）：掛在一個節點上，照 mode 讓它自己轉、上下飄，或繞著一個點飛（仙鶴）。
##   "spin"  ：繞 Y 軸慢慢轉（speed＝每秒幾弧度）
##   "bob"   ：上下飄（amp＝幅度、speed＝快慢、phase＝錯開的相位）
##   "orbit" ：繞著 center 飛一圈（rx、rz＝橢圓的半徑，h＝高度，speed＝每秒幾弧度，可以是負的）；有 WingL／WingR 就拍翅膀

var mode := "spin"
var speed := 0.3
var amp := 0.3
var phase := 0.0
var center := Vector3.ZERO
var rx := 10.0
var rz := 6.0
var h := 6.0
var _home := Vector3.ZERO
var _t := 0.0
var _wl: Node3D
var _wr: Node3D

func _ready() -> void:
	_home = position
	_wl = find_child("WingL", true, false) as Node3D
	_wr = find_child("WingR", true, false) as Node3D

func _process(dt: float) -> void:
	_t += dt
	match mode:
		"spin":
			rotation.y += speed * dt
		"bob":
			position = _home + Vector3(0, sin(_t * speed + phase) * amp, 0)
		"orbit":
			var a := _t * speed + phase
			position = center + Vector3(cos(a) * rx, h + sin(a * 2.0) * 0.5, sin(a) * rz)
			var vx := -sin(a) * rx * signf(speed)
			var vz := cos(a) * rz * signf(speed)
			rotation = Vector3(0, atan2(vx, vz), -0.2 * signf(speed))
			var fl := sin(_t * 5.0 + phase * 3.0) * (0.55 if fmod(_t * 0.22 + phase, 1.0) < 0.6 else 0.12)
			if _wl:
				_wl.rotation.z = -fl
			if _wr:
				_wr.rotation.z = fl
