extends Node3D
## 要塞東南邊的「東門」：城牆上本來就有的一座小城門（兩側小塔、拱、鐵柵門），外觀由 fort_world.gd 的
## _build_side_gate() 用城堡素材蓋好，這個腳本只管開關。
## 戰鬥中鐵柵門一直放下（關著）；2-1、2-2 過關後 set_open() 把它升起來，家豪從這裡走出去、接到下一小關。
## 2-3 也有這座門，只是一直關著。

var inward := Vector3.FORWARD   # 從門口朝院子裡的方向（水平、單位向量）
var portcullis: Node3D          # 鐵柵門（升起來 = 開門）
var closed_y := 0.0
var lift := 3.6                 # 全開時升多高
var glow: MeshInstance3D        # 門開了之後門口地上的光圈
var open_k := 0.0

## 院子這一側、門口前面家豪要先停的地方
func front_point(dist := 2.6) -> Vector3:
	return global_position + inward * dist

## 走出門外的終點
func inside_point() -> Vector3:
	return global_position - inward * 1.8

## k = 0 關著、1 全開：鐵柵門平順地升上去，光圈跟著亮
func set_open(k: float) -> void:
	open_k = clampf(k, 0.0, 1.0)
	var e := open_k * open_k * (3.0 - 2.0 * open_k)
	if portcullis:
		portcullis.position.y = closed_y + lift * e
	if glow:
		(glow.material_override as StandardMaterial3D).albedo_color.a = 0.5 * e
		glow.visible = e > 0.01
