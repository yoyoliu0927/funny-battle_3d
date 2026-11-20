extends RefCounted
## 森林道具的模型。場上放下去的東西和道具欄的圖示（tools/make_icons.gd 拍的）都用這裡，長得一模一樣。
## 用法：const Models := preload("res://levels/forest/items/models.gd")；Models.decoy(parent)

const TOON := "res://shaders/toon_color.gdshader"

static func toon(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	m.set_shader_parameter("albedo", c)
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func ball(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## 假獵物：一隻蹲著的棕色兔子（頭朝 +Z）
static func decoy(root: Node3D) -> void:
	var fur := toon(Color(0.62, 0.42, 0.24))
	var dark := toon(Color(0.45, 0.28, 0.16))
	var pale := toon(Color(0.93, 0.86, 0.74))
	var eye := toon(Color(0.08, 0.06, 0.05))
	box(root, Vector3(0.46, 0.3, 0.62), Vector3(0, 0.25, -0.04), fur)            # 身體
	box(root, Vector3(0.36, 0.14, 0.4), Vector3(0, 0.1, -0.12), fur)              # 後腿
	box(root, Vector3(0.3, 0.28, 0.3), Vector3(0, 0.48, 0.26), fur)               # 頭
	box(root, Vector3(0.16, 0.1, 0.06), Vector3(0, 0.42, 0.42), pale)             # 嘴邊
	box(root, Vector3(0.05, 0.04, 0.03), Vector3(0, 0.47, 0.45), toon(Color(0.9, 0.5, 0.55)))  # 鼻子
	box(root, Vector3(0.05, 0.06, 0.03), Vector3(-0.1, 0.53, 0.41), eye)
	box(root, Vector3(0.05, 0.06, 0.03), Vector3(0.1, 0.53, 0.41), eye)
	box(root, Vector3(0.1, 0.32, 0.07), Vector3(-0.09, 0.76, 0.22), dark, Vector3(-0.25, 0, 0.25))   # 耳朵
	box(root, Vector3(0.1, 0.32, 0.07), Vector3(0.09, 0.76, 0.22), dark, Vector3(-0.25, 0, -0.25))
	box(root, Vector3(0.05, 0.22, 0.03), Vector3(-0.09, 0.76, 0.26), pale, Vector3(-0.25, 0, 0.25))  # 耳朵裡面
	box(root, Vector3(0.05, 0.22, 0.03), Vector3(0.09, 0.76, 0.26), pale, Vector3(-0.25, 0, -0.25))
	ball(root, 0.09, Vector3(0, 0.3, -0.38), pale)                                # 尾巴
	box(root, Vector3(0.08, 0.06, 0.12), Vector3(-0.1, 0.03, 0.2), fur)           # 前腳
	box(root, Vector3(0.08, 0.06, 0.12), Vector3(0.1, 0.03, 0.2), fur)

## 引路點：插在地上的小旗子（label 另外加）
static func guide(root: Node3D) -> void:
	var pole := toon(Color(0.95, 0.82, 0.25))
	var flag := toon(Color(0.9, 0.25, 0.18))
	box(root, Vector3(0.07, 1.0, 0.07), Vector3(0, 0.5, 0), pole)
	ball(root, 0.06, Vector3(0, 1.02, 0), pole)
	# 三角旗：三條越來越短的布疊出來
	box(root, Vector3(0.05, 0.1, 0.42), Vector3(0, 0.9, 0.23), flag)
	box(root, Vector3(0.05, 0.08, 0.3), Vector3(0, 0.81, 0.17), flag)
	box(root, Vector3(0.05, 0.07, 0.16), Vector3(0, 0.74, 0.1), flag)
	box(root, Vector3(0.24, 0.04, 0.24), Vector3(0, 0.02, 0), toon(Color(0.42, 0.3, 0.16)))  # 插進土裡的小土堆

## 外婆的籃子：編織籃、紅格子布、提把，冒出一條麵包
static func basket(root: Node3D) -> void:
	var wicker := toon(Color(0.72, 0.52, 0.28))
	var weave := toon(Color(0.56, 0.38, 0.18))
	var cloth := toon(Color(0.86, 0.24, 0.22))
	var check := toon(Color(0.97, 0.94, 0.88))
	box(root, Vector3(0.5, 0.3, 0.36), Vector3(0, 0.15, 0), wicker)
	for y in [0.07, 0.17, 0.27]:
		box(root, Vector3(0.52, 0.035, 0.38), Vector3(0, y, 0), weave)          # 編織的紋
	box(root, Vector3(0.54, 0.05, 0.4), Vector3(0, 0.31, 0), cloth)
	for k in 3:
		box(root, Vector3(0.08, 0.052, 0.08), Vector3(-0.16 + 0.16 * k, 0.315, 0.1 if k % 2 == 0 else -0.1), check)
	box(root, Vector3(0.24, 0.1, 0.1), Vector3(0.1, 0.38, -0.04), toon(Color(0.86, 0.62, 0.3)), Vector3(0, 0.4, 0.35))  # 麵包
	box(root, Vector3(0.05, 0.34, 0.05), Vector3(-0.2, 0.47, 0), wicker)
	box(root, Vector3(0.05, 0.34, 0.05), Vector3(0.2, 0.47, 0), wicker)
	box(root, Vector3(0.45, 0.05, 0.05), Vector3(0, 0.64, 0), wicker)

## 水桶：Kenney 的木桶模型（放大一點），桶口有一圈水花
static func bucket(root: Node3D) -> Node3D:
	var ps := load("res://levels/forest/assets/kenney_survival/bucket.glb") as PackedScene
	var n := Node3D.new()
	root.add_child(n)
	if ps:
		var m := ps.instantiate() as Node3D
		m.scale = Vector3.ONE * 3.2
		n.add_child(m)
	return n

## 道具欄圖示；還沒拍（或檔案不見）就回傳 null，道具欄會畫原本的圓圈
static func icon(id: String) -> Texture2D:
	var path := "res://levels/forest/assets/icons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null
