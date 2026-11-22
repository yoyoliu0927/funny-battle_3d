extends CharacterBody3D
## 截圖用的鏡頭：跟 scripts/player.gd 同一組屬性，但完全不碰滑鼠（不鎖游標、不讀輸入）。
## tests/tut_shots.gd 在場景進樹之前把 Player 的腳本換成這個，所以截圖在背景跑也不會搶走滑鼠。
@export var move_speed := 4.5
@export var vertical_speed := 3.5
@export var acceleration := 10.0
@export var mouse_sensitivity := 0.0025
@export var pitch_limit_deg := 85.0
@export var bounds_min := Vector2(-19.0, -22.0)
@export var bounds_max := Vector2(19.0, 22.0)
@export var max_height := 35.0
var looking := false

func _set_looking(on: bool) -> void:
	looking = on
