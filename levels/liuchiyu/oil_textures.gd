extends RefCounted
## 把預先畫好的貼圖（levels/liuchiyu/tools/bake_textures.gd 產生）設成油畫 shader 的預設貼圖。
## 每個 shader 設一次，所有用它的材質就都讀得到，各處建材質的程式不用一個一個設。
## oil_world.gd（關卡）和 map_isles.gd（選關地圖）一開始都會呼叫 apply()。

const NOISE := preload("res://levels/liuchiyu/assets/textures/noise4.png")
const GROUND_SHADE := preload("res://levels/liuchiyu/assets/textures/ground_shade.png")
const GROUND_SUN := preload("res://levels/liuchiyu/assets/textures/ground_sun.png")
const WATER := preload("res://levels/liuchiyu/assets/textures/water.png")
const GROUND_PHOTO := preload("res://levels/liuchiyu/assets/polyhaven/brown_mud_leaves_01_diff_1k.jpg")

const GROUND := preload("res://levels/liuchiyu/shaders/oil_ground.gdshader")
const ROCK := preload("res://levels/liuchiyu/shaders/oil_rock.gdshader")
const TRUNK := preload("res://levels/liuchiyu/shaders/oil_trunk.gdshader")
const SEA := preload("res://levels/liuchiyu/shaders/oil_sea.gdshader")
const RIVER := preload("res://levels/liuchiyu/shaders/oil_river.gdshader")

static func apply() -> void:
	GROUND.set_default_texture_parameter("shade_tex", GROUND_SHADE)
	GROUND.set_default_texture_parameter("sun_tex", GROUND_SUN)
	GROUND.set_default_texture_parameter("noise_tex", NOISE)
	GROUND.set_default_texture_parameter("photo_tex", GROUND_PHOTO)
	ROCK.set_default_texture_parameter("noise_tex", NOISE)
	TRUNK.set_default_texture_parameter("noise_tex", NOISE)
	SEA.set_default_texture_parameter("water_tex", WATER)
	RIVER.set_default_texture_parameter("water_tex", WATER)
