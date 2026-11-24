extends SceneTree
## 把森林道具的模型拍成道具欄圖示（透明背景 256×256＋深色描邊），存到 levels/forest/assets/icons/。
## 改了 items/models.gd 之後重拍一次（要開視窗，不能 --headless）：
##   Godot --path . --script res://levels/forest/tools/make_icons.gd
##   Godot --headless --path . --import      ← 讓新圖片產生 .import
const Models := preload("res://levels/forest/items/models.gd")
const OUT := "res://levels/forest/assets/icons"
const SIZE := 256
const INK := Color(0.16, 0.1, 0.06)

## id → [建模型的函式名, 鏡頭水平角度（從 +Z 往 +X 轉）, 俯角, 描邊粗細]
const SHOTS := {
	"decoy": ["decoy", 0.75, 0.32, 7],
	"guide": ["guide", 1.25, 0.18, 7],
	"basket": ["basket", 0.5, 0.42, 7],
	"tree": ["tree", 0.6, 0.25, 6],
	"stump": ["stump", 0.6, 0.3, 6],
	"log": ["log_down", 0.35, 0.55, 6],
	"hood": ["hood", 0.45, 0.18, 6],
	"flame": ["flame", 0.3, 0.2, 6],
	"bucket": ["bucket", 0.6, 0.38, 7],
}

var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE * 2, SIZE * 2)          # 先拍兩倍大再縮小，邊緣比較乾淨
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	for id in SHOTS:
		await _shoot(id, SHOTS[id])
	print("icons -> ", ProjectSettings.globalize_path(OUT))
	quit()

func _shoot(id: String, cfg: Array) -> void:
	for c in holder.get_children():
		holder.remove_child(c)
		c.free()
	var model := Node3D.new()
	holder.add_child(model)
	match String(cfg[0]):
		"decoy": Models.decoy(model)
		"guide": Models.guide(model)
		"basket": Models.basket(model)
		"tree": Models.tree(model)
		"stump": Models.stump(model)
		"log_down": Models.log_down(model)
		"hood": Models.hood(model)
		"flame": Models.flame(model)
		"bucket": Models.bucket(model)
	# 把整個模型框進畫面：用包圍盒的中心和大小決定鏡頭距離
	var box := _bounds(model)
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	var yaw := float(cfg[1])
	var pitch := float(cfg[2])
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	cam.position = center + dir * dist
	cam.look_at(center, Vector3.UP)
	for i in 6:
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	img = _outline(img, int(cfg[3]))
	var path := OUT.path_join(id + ".png")
	img.save_png(ProjectSettings.globalize_path(path))
	print("  ", path)

func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a: AABB = mi.global_transform * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out

## 不透明的地方往外長 w 個像素，塗成深色墊在底下
func _outline(src: Image, w: int) -> Image:
	var sz := src.get_size()
	var out := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var solid := PackedByteArray()
	solid.resize(sz.x * sz.y)
	for y in sz.y:
		for x in sz.x:
			solid[y * sz.x + x] = 1 if src.get_pixel(x, y).a > 0.4 else 0
	for y in sz.y:
		for x in sz.x:
			var hit := false
			for dy in range(-w, w + 1):
				var yy := y + dy
				if yy < 0 or yy >= sz.y:
					continue
				for dx in range(-w, w + 1):
					var xx := x + dx
					if xx < 0 or xx >= sz.x or dx * dx + dy * dy > w * w:
						continue
					if solid[yy * sz.x + xx] == 1:
						hit = true
						break
				if hit:
					break
			if hit:
				out.set_pixel(x, y, INK)
	out.blend_rect(src, Rect2i(Vector2i.ZERO, sz), Vector2i.ZERO)
	return out
