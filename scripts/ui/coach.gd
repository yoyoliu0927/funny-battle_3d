extends VBoxContainer
## 當下提示（所有大關共用）：取代「一進場就跳出整頁教學」。不暫停遊戲、不擋畫面，放在道具欄上方。
##   show_start(n)        剛開始：「1~n 選道具・左鍵 放下」（白字＋深色描邊，不墊紙片）
##   show_item(item, dir) 第一次選到某個道具：一張小卡片＝示範動畫（或道具圖示）＋名字＋一句說明
##   clear()              做到了（放下第一個道具）就收掉
## 什麼時候顯示、什麼時候收由 battle_base.gd 決定（每個大關這次開遊戲只教一次）。

const UIStyle := preload("res://scripts/ui/ui_style.gd")
const TutorialPopup := preload("res://scripts/ui/tutorial_popup.gd")   # 借用影格表的格子大小（FW、FH、COLS、FPS）
const CLIP := Vector2(256, 144)

var _hint: HBoxContainer
var _card: PanelContainer
var _clip: TextureRect
var _atlas := AtlasTexture.new()
var _frames := 0
var _clip_t := 0.0
var _name: Label
var _line: Label
var wanted: Callable             # 回傳 false 時整個藏起來（例如速查卡開著、這局結束了）；遊戲暫停時也會問

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS   # 速查卡打開時遊戲是暫停的，還是要能把自己藏起來
	add_theme_constant_override("separation", 10)
	alignment = BoxContainer.ALIGNMENT_END
	# 小卡片：示範動畫在左，名字和一句說明在右（只有這一層紙片）
	_card = PanelContainer.new()
	UIStyle.slip(_card, Vector2(12, 10))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_card.visible = false
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_clip = TextureRect.new()
	_clip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clip.custom_minimum_size = CLIP
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_clip)
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	_name = Label.new()
	_name.label_settings = UIStyle.ls(24, UIStyle.accent())
	info.add_child(_name)
	_line = Label.new()
	_line.label_settings = UIStyle.ls(18, UIStyle.INK)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(230, 0)
	info.add_child(_line)
	# 一行按鍵提示（不墊紙片）
	_hint = HBoxContainer.new()
	_hint.add_theme_constant_override("separation", 10)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)

func show_start(n: int) -> void:
	for c in _hint.get_children():
		c.queue_free()
	if n > 1:
		_hint.add_child(UIStyle.key_hint("1~%d" % n, "選道具", 16))
	_hint.add_child(UIStyle.mouse_hint("left", "放下", 16))
	UIStyle.outline_hint_labels(_hint)
	_hint.visible = true

## 第一次選到這個道具：示範動畫（<clip_dir>/<道具 id>.jpg，沒有就放道具圖示）＋名字＋一句說明
func show_item(item, clip_dir: String) -> void:
	_name.text = String(item.name)
	_line.text = first_sentence(String(item.tutorial))
	_line.visible = _line.text != ""
	var tex: Texture2D = null
	var path := clip_dir.path_join(String(item.id) + ".jpg") if clip_dir != "" else ""
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	_frames = 0
	if tex:
		_atlas.atlas = tex
		_frames = TutorialPopup.COLS * int(tex.get_height() / TutorialPopup.FH)
		_clip_t = 0.0
		_set_frame(0)
		_clip.texture = _atlas
		_clip.custom_minimum_size = CLIP
		_clip.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		_clip.texture = item.icon_tex if item.icon_tex else item.icon
		_clip.custom_minimum_size = Vector2(72, 72)
		_clip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clip.visible = _clip.texture != null
	_card.visible = true

## 只取第一句（到第一個「。」或換行）：當下提示只說一句，其他的看示範動畫
static func first_sentence(t: String) -> String:
	t = t.strip_edges().get_slice("\n", 0)
	var cut := t.find("。")
	return t.substr(0, cut + 1) if cut >= 0 else t

func clear() -> void:
	_card.visible = false
	_hint.visible = false

func showing() -> bool:
	return _card.visible or _hint.visible

func _set_frame(n: int) -> void:
	var fw := TutorialPopup.FW
	var fh := TutorialPopup.FH
	_atlas.region = Rect2((n % TutorialPopup.COLS) * fw, (n / TutorialPopup.COLS) * fh, fw, fh)

func _process(dt: float) -> void:
	if wanted.is_valid():
		visible = bool(wanted.call())
	if not visible or not _card.visible or _frames <= 0 or get_tree().paused:
		return
	_clip_t += dt
	var total := _frames / TutorialPopup.FPS + TutorialPopup.HOLD
	if _clip_t >= total:
		_clip_t = fmod(_clip_t, total)
	_set_frame(mini(int(_clip_t * TutorialPopup.FPS), _frames - 1))
