extends "res://scripts/battle/battle_base.gd"
## 第三小關：示範「自訂敵人」。睡覺的守衛（kind = "sleeper"）不巡邏、偵測範圍小，
## 被吵醒（看到家豪、聽到打鬥、被打）之後就跟一般農夫一樣。

const FeedItem := preload("res://scripts/items/feed_item.gd")
const RockItem := preload("res://scripts/items/rock_item.gd")
const FirecrackerItem := preload("res://levels/_template/items/firecracker_item.gd")

func _make_items() -> Array:
	return [
		FeedItem.new().uses(2, 3),
		RockItem.new().uses(1, 2),
		FirecrackerItem.new().uses_shared(1),
	]

func _enemy_specs() -> Array:
	return [
		{"name": "農夫1", "route": [Vector3(2, 0, 2), Vector3(6, 0, -4)], "loop": false, "pause": 1.2},
		{"name": "農夫2", "route": [Vector3(4, 0, -8), Vector3(-2, 0, -8)], "loop": false, "pause": 1.0},
		{"name": "睡覺的守衛", "kind": "sleeper", "route": [Vector3(-8, 0, -6)], "yaw": PI,
			"vision_range": 3.0, "hp": 12.0, "bar_y": 2.85},
	]

func _tick_enemy(f: Fighter, dt: float) -> void:
	if f.kind == "sleeper" and not f.aggro and f.state in ["idle", "patrol", "look"]:
		# 還在睡：原地不動，只檢查有沒有被吵醒
		f.t += dt
		if f.alert_t >= 0.0:
			f.alert_t -= dt
			if f.alert_t < 0.0:
				log_event("%s被吵醒了" % f.name)
				aggro(f)
		elif sees_bird(f):
			log_event("%s睜開眼睛看到家豪" % f.name)
			aggro(f)
		return
	super(f, dt)

func _prepare_hint() -> String:
	return "準備中：左上角那個守衛在睡覺，別吵醒他　按 Enter 開始"
