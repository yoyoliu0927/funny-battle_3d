extends "res://scripts/items/feed_item.gd"
## 冰雪島的飼料：跟共用的飼料一樣，多了操作回饋。
##   - 撒下去的瞬間：通知戰局（音效、家豪頭上冒「！」或「聞不到」）
##   - 瞄準時：畫一條虛線，從家豪到準心（他會走的路）

func cast(bt, p: Vector3) -> void:
	super(bt, p)
	if bt.has_method("on_feed_cast"):
		bt.on_feed_cast(p)

func preview_path(bt, p: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a: Vector3 = bt.bird.pos
	var d: float = bt.flat_dist(a, p)
	if d > bt.FEED_SENSE:
		return out
	var n := maxi(int(d / 0.12), 2)
	for i in n + 1:
		var q := a.lerp(p, float(i) / n)
		out.append(Vector3(q.x, bt.world.height_at(q.x, q.z) + radius, q.z))
	return out
