extends Node3D
## 每一小關場景的根節點（scenes/stage_base.tscn）。
## 帶 `-- --autotest` 參數啟動時，農場範例關會掛上自動驗收腳本。

const FARM_SCENE := "res://examples/farm/stage.tscn"

func _ready() -> void:
	if "--autotest" in OS.get_cmdline_user_args() and scene_file_path == FARM_SCENE:
		var t: Node = load("res://tools/autotest.gd").new()
		t.name = "AutoTest"
		add_child(t)
