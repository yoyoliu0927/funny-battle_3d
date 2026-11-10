extends Node3D
## 主場景。帶 `-- --autotest` 參數啟動時會掛上自動驗收腳本。

func _ready() -> void:
	if "--autotest" in OS.get_cmdline_user_args():
		var t: Node = load("res://tools/autotest.gd").new()
		t.name = "AutoTest"
		add_child(t)
