extends "res://levels/ice/rescue_battle.gd"
## 測試用的臨時戰局：道具、人、旗標都從 Engine 的 meta "ice_test" 讀。

func _cfg() -> Dictionary:
	return Engine.get_meta("ice_test", {})

func _make_items() -> Array:
	var out: Array = []
	for it in _cfg().get("items", [["banana", 2]]):
		if String(it[0]) == "feed":
			out.append(load("res://levels/ice/items/rescue_feed_item.gd").new().uses(int(it[1]), 0).cooldown_sec(0.0))
		else:
			out.append(BananaItem.new().uses_shared(int(it[1])).cooldown_sec(0.0))
	return out

func _enemy_specs() -> Array:
	var out: Array = []
	for e in _cfg().get("enemies", []):
		if String(e[0]) == "guard":
			out.append(guard(String(e[1]), e[2]))
		else:
			out.append(rusher(String(e[1]), e[2], e[3]))
	return out

func _checklist() -> Array:
	var out: Array = [{"id": "rescue", "text": "救出企鵝"}]
	for id in _cfg().get("stars", []):
		out.append({"id": id, "text": id})
	return out

func _level_setup() -> void:
	super()
	var flags: Dictionary = _cfg().get("flags", {})
	for k in flags:
		set(k, flags[k])
