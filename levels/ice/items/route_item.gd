extends "res://scripts/items/item.gd"
## 飼料路線：每點一下，就在路線尾端多撒一段飼料。家豪會沿著飼料一路吃過去，人類踩著家豪的腳印追。
## 準備階段：一段一段畫好路線（右鍵收回最後一段）。
## 開打後：點一下＝改道，家豪丟下剩下的路，馬上衝去新的點。
## 路線怎麼走、人怎麼追，寫在 levels/ice/route_battle.gd。

const MAX_SEG := 14.0           # 一段最長幾公尺

func _init() -> void:
	id = "route"
	name = "飼料路線"
	tutorial = "點一下撒一段飼料，家豪會沿著飼料一路跑。\n右鍵收回最後一段。開打後點一下＝改道。"
	color = Color(1.0, 0.85, 0.3)
	radius = 0.45
	cooldown = 0.15   # 只是防連點

func placement_error(bt, p: Vector3) -> String:
	if bt.world.in_water(p.x, p.z):
		return "不能撒在水裡"
	if not bt.world.walkable(p.x, p.z):
		return "這裡放不了"
	if bt.flat_dist(bt.route_tail(), p) > MAX_SEG:
		return "一段最長 %d 公尺" % int(MAX_SEG)
	if bt.flat_dist(bt.route_tail(), p) < 0.8:
		return "離上一個點太近了"
	return ""

func cast(bt, p: Vector3) -> void:
	bt.add_route_point(p)

## 瞄準時：從路線尾端畫一段虛線到準心
func preview_path(bt, p: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a: Vector3 = bt.route_tail()
	var d: float = bt.flat_dist(a, p)
	var n := maxi(int(d / 0.12), 2)
	for i in n + 1:
		var q := a.lerp(p, float(i) / n)
		out.append(Vector3(q.x, bt.world.height_at(q.x, q.z) + radius, q.z))
	return out
