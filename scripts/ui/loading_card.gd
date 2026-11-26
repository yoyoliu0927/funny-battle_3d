extends CanvasLayer
## 換場景用的「載入中」：全黑底，正中間家豪的頭像一跳一跳，底下「載入中...」。
## 掛在 root 底下（不是哪個場景的子節點），換場景時不會跟著舊場景一起被拿掉。
##
## 為什麼要有：主畫面（level_select）要建一兩秒，網頁版只有一條執行緒、更久，
## 建好之前一幀都畫不出來，畫面會停在最後畫的那一幀（以前是引擎的灰底，後來是全黑，看起來都像當掉）。
## 先把這張卡片畫出來再換場景，等的時候停在「載入中」；新場景畫出來之後它自己淡掉、刪掉。
## （建場景那幾秒引擎完全不會畫新的畫面，所以那段時間頭像是停住的；建好之後才繼續跳、淡出）
##
## 用法：
##   var card := LoadingCard.new()
##   get_tree().root.add_child(card)
##   await card.shown                        # 卡片已經完整畫在畫面上了
##   get_tree().change_scene_to_file(path)   # 換完它自己收

signal shown

const UIStyle := preload("res://scripts/ui/ui_style.gd")   # 全遊戲共用的介面美術
const PORTRAIT := "res://assets/ui/jiahao_portrait.png"
const FADE_IN := 0.2
const FADE_OUT := 0.45
const NEW_FRAMES := 2            # 新場景畫了幾幀之後開始淡出
const GIVE_UP := 20.0            # 一直沒換場景（出錯）的話，幾秒後自己收掉
const MAX_DT := 1.0 / 30.0       # 建場景那一幀的 dt 有好幾秒：動畫一次最多走這麼多，淡出才不會一下子跳完

var _bg: ColorRect
var _box: VBoxContainer
var _face: TextureRect
var _label: Label
var _size := 120.0
var _hop := 16.0
var _t := 0.0
var _in := 0.0
var _out := -1.0
var _scene: Node                 # 蓋上去的時候是哪個場景；換成別的之後才開始數新場景畫了幾幀
var _new_drawn := 0
var _full_drawn := false         # 完全不透明的卡片已經畫出來過了
var _emitted := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene = get_tree().current_scene
	var u := get_viewport().get_visible_rect().size.y / 720.0
	_size = roundf(120.0 * u)
	_hop = roundf(16.0 * u)
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", int(10 * u))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	center.add_child(_box)
	# 頭像放在一個固定大小的框裡跳：跳起來不會推動底下的字
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(_size, _size + _hop)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(holder)
	_face = TextureRect.new()
	_face.texture = load(PORTRAIT) as Texture2D
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.size = Vector2(_size, _size)
	_face.pivot_offset = Vector2(_size * 0.5, _size)
	_face.position = Vector2(0, _hop)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_face)
	_label = Label.new()
	_label.label_settings = UIStyle.ls(int(30 * u), Color(1.0, 0.97, 0.9))
	_label.text = "載入中..."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 點點一個一個冒出來，但字的位置不動（排版照完整的「載入中...」算）
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_label)
	_animate()
	RenderingServer.frame_post_draw.connect(_on_drawn)

func _on_drawn() -> void:
	if _in >= 1.0:
		_full_drawn = true
	var now := get_tree().current_scene
	if _emitted and now != null and now != _scene:
		_new_drawn += 1

func _process(dt: float) -> void:
	dt = minf(dt, MAX_DT)
	_t += dt
	if _out < 0.0:
		_in = minf(_in + dt / FADE_IN, 1.0)
		_box.modulate.a = _in
		if _full_drawn and not _emitted:
			_emitted = true
			shown.emit()
		if _new_drawn >= NEW_FRAMES or _t > GIVE_UP:
			_out = 0.0
	else:
		_out = minf(_out + dt / FADE_OUT, 1.0)
		var a := 1.0 - _out
		_bg.color.a = a
		_box.modulate.a = a
		if _out >= 1.0:
			queue_free()
	_animate()

## 頭像一跳一跳（落地時壓扁一點），點點 0～3 個輪流
func _animate() -> void:
	var s := absf(sin(_t * 5.5))
	_face.position.y = _hop * (1.0 - s)
	var squash := clampf(1.0 - s * 3.0, 0.0, 1.0)
	_face.scale = Vector2(1.0 + 0.06 * squash, 1.0 - 0.06 * squash)
	_face.rotation = sin(_t * 2.75) * 0.05
	_label.visible_characters = 3 + int(_t * 3.0) % 4
