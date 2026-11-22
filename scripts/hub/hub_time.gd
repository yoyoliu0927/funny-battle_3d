extends RefCounted
## 農莊的天色：一天 24 小時的天空、太陽月亮、光和海的顏色（做成「關鍵時刻」之間慢慢過渡）。
## 時間從哪來有三種（存在 user://settings.cfg 的 [time]）：
##   "auto"  跟著電腦現在的時間（預設）　"fixed"  固定在玩家選的時間　"cycle"  快轉：一天只要 CYCLE_SECONDS 秒（展示用）
## 只有農莊、世界地圖、還有沒有自己天色的島用這裡的天色；有自己 mood() 的大關維持自己的氣氛。
## 命令列：-- --hour=21.5 固定在 21:30（截圖用，不存檔）；自動測試／截圖預設不用，加 --tod 才開。

const SETTINGS_PATH := "user://settings.cfg"
const CYCLE_SECONDS := 120.0

const MODES := ["auto", "fixed", "cycle"]
const MODE_NAMES := {"auto": "跟著現在的時間", "fixed": "固定在這個時間", "cycle": "快轉：一天兩分鐘"}
## 快速選時間：[名字, 幾點]
const PRESETS := [["清晨", 6.5], ["正午", 12.0], ["黃昏", 18.0], ["深夜", 23.5]]

## 關鍵時刻。欄位：h 幾點、sun 太陽（月亮）光色、e 光的強度、amb 環境光、amb_e、fog、top／hor／cloud／shade 天空、
## deep／near／stroke／foam／sh 海、night 星星多亮（0～1）。中午那一排就是原本的大晴天（DEFAULT_MOOD）。
const KEYS := [
	{"h": 0.0, "sun": Color(0.55, 0.66, 1.0), "e": 0.55, "amb": Color(0.26, 0.31, 0.55), "amb_e": 0.8, "fog": Color(0.10, 0.14, 0.28),
		"top": Color(0.03, 0.05, 0.17), "hor": Color(0.10, 0.17, 0.34), "cloud": Color(0.26, 0.31, 0.50), "shade": Color(0.11, 0.15, 0.30),
		"deep": Color(0.02, 0.07, 0.20), "near": Color(0.05, 0.20, 0.38), "stroke": Color(0.32, 0.52, 0.78), "foam": Color(0.72, 0.84, 1.0), "sh": Color(0.10, 0.17, 0.34), "night": 1.0},
	{"h": 5.0, "sun": Color(0.62, 0.62, 0.95), "e": 0.55, "amb": Color(0.34, 0.34, 0.56), "amb_e": 0.8, "fog": Color(0.30, 0.30, 0.46),
		"top": Color(0.10, 0.14, 0.34), "hor": Color(0.58, 0.46, 0.56), "cloud": Color(0.62, 0.52, 0.64), "shade": Color(0.36, 0.34, 0.52),
		"deep": Color(0.04, 0.14, 0.32), "near": Color(0.14, 0.30, 0.50), "stroke": Color(0.62, 0.62, 0.82), "foam": Color(0.9, 0.88, 0.98), "sh": Color(0.45, 0.42, 0.58), "night": 0.75},
	{"h": 6.5, "sun": Color(1.0, 0.64, 0.40), "e": 1.2, "amb": Color(0.76, 0.64, 0.72), "amb_e": 0.9, "fog": Color(0.96, 0.74, 0.64),
		"top": Color(0.38, 0.52, 0.80), "hor": Color(1.0, 0.74, 0.56), "cloud": Color(1.0, 0.84, 0.72), "shade": Color(0.86, 0.64, 0.62),
		"deep": Color(0.12, 0.30, 0.54), "near": Color(0.42, 0.56, 0.72), "stroke": Color(1.0, 0.82, 0.72), "foam": Color(1.0, 0.95, 0.9), "sh": Color(0.95, 0.78, 0.66), "night": 0.15},
	{"h": 9.0, "sun": Color(1.0, 0.94, 0.78), "e": 1.55, "amb": Color(0.66, 0.76, 0.92), "amb_e": 0.9, "fog": Color(0.76, 0.88, 0.92),
		"top": Color(0.32, 0.64, 0.90), "hor": Color(0.82, 0.92, 0.94), "cloud": Color(0.99, 0.99, 0.96), "shade": Color(0.78, 0.87, 0.91),
		"deep": Color(0.08, 0.44, 0.68), "near": Color(0.20, 0.64, 0.80), "stroke": Color(0.74, 0.94, 0.98), "foam": Color(1, 1, 1), "sh": Color(0.78, 0.91, 0.94), "night": 0.0},
	{"h": 12.0, "sun": Color(1.0, 0.90, 0.70), "e": 1.7, "amb": Color(0.62, 0.74, 0.90), "amb_e": 0.9, "fog": Color(0.74, 0.88, 0.92),
		"top": Color(0.30, 0.66, 0.90), "hor": Color(0.80, 0.92, 0.94), "cloud": Color(0.99, 0.99, 0.96), "shade": Color(0.76, 0.86, 0.90),
		"deep": Color(0.08, 0.44, 0.68), "near": Color(0.20, 0.64, 0.80), "stroke": Color(0.74, 0.94, 0.98), "foam": Color(1, 1, 1), "sh": Color(0.78, 0.91, 0.94), "night": 0.0},
	{"h": 16.0, "sun": Color(1.0, 0.88, 0.66), "e": 1.6, "amb": Color(0.68, 0.74, 0.88), "amb_e": 0.9, "fog": Color(0.82, 0.88, 0.88),
		"top": Color(0.32, 0.62, 0.88), "hor": Color(0.90, 0.92, 0.88), "cloud": Color(1.0, 0.97, 0.90), "shade": Color(0.82, 0.84, 0.86),
		"deep": Color(0.08, 0.42, 0.66), "near": Color(0.22, 0.62, 0.76), "stroke": Color(0.82, 0.94, 0.92), "foam": Color(1, 1, 0.96), "sh": Color(0.86, 0.9, 0.88), "night": 0.0},
	{"h": 18.0, "sun": Color(1.0, 0.68, 0.38), "e": 1.3, "amb": Color(0.78, 0.66, 0.70), "amb_e": 0.9, "fog": Color(0.98, 0.74, 0.56),
		"top": Color(0.30, 0.46, 0.78), "hor": Color(1.0, 0.72, 0.46), "cloud": Color(1.0, 0.82, 0.66), "shade": Color(0.86, 0.62, 0.58),
		"deep": Color(0.10, 0.32, 0.56), "near": Color(0.36, 0.52, 0.68), "stroke": Color(1.0, 0.80, 0.62), "foam": Color(1.0, 0.94, 0.86), "sh": Color(0.98, 0.74, 0.54), "night": 0.1},
	{"h": 19.5, "sun": Color(0.92, 0.46, 0.38), "e": 0.9, "amb": Color(0.52, 0.42, 0.62), "amb_e": 0.85, "fog": Color(0.74, 0.44, 0.50),
		"top": Color(0.16, 0.20, 0.50), "hor": Color(0.96, 0.46, 0.42), "cloud": Color(0.92, 0.56, 0.52), "shade": Color(0.48, 0.34, 0.50),
		"deep": Color(0.06, 0.20, 0.42), "near": Color(0.24, 0.34, 0.56), "stroke": Color(0.96, 0.58, 0.52), "foam": Color(1.0, 0.86, 0.82), "sh": Color(0.80, 0.46, 0.50), "night": 0.5},
	{"h": 21.0, "sun": Color(0.50, 0.58, 1.0), "e": 0.6, "amb": Color(0.30, 0.34, 0.58), "amb_e": 0.8, "fog": Color(0.16, 0.18, 0.36),
		"top": Color(0.05, 0.08, 0.24), "hor": Color(0.24, 0.26, 0.48), "cloud": Color(0.34, 0.38, 0.58), "shade": Color(0.16, 0.20, 0.38),
		"deep": Color(0.03, 0.10, 0.26), "near": Color(0.08, 0.24, 0.42), "stroke": Color(0.38, 0.56, 0.80), "foam": Color(0.78, 0.88, 1.0), "sh": Color(0.20, 0.24, 0.44), "night": 0.95},
]

# ---------------------------------------------------------------- 時間從哪來

## 命令列 --hour=21.5：固定這個時間（沒有就回傳 -1）
static func forced_hour() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hour="):
			return clampf(float(a.substr(7)), 0.0, 24.0)
	return -1.0

static func load_settings() -> Dictionary:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	var mode := String(cf.get_value("time", "mode", "auto"))
	return {"mode": mode if mode in MODES else "auto", "hour": clampf(float(cf.get_value("time", "hour", 12.0)), 0.0, 24.0)}

static func save_settings(mode: String, hour: float) -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("time", "mode", mode)
	cf.set_value("time", "hour", snappedf(hour, 0.01))
	cf.save(SETTINGS_PATH)

## 電腦現在是幾點（小時，含小數）
static func system_hour() -> float:
	var d := Time.get_time_dict_from_system()
	return float(d.hour) + float(d.minute) / 60.0 + float(d.second) / 3600.0

static func label(hour: float) -> String:
	var h := int(floor(hour)) % 24
	var m := int(floor((hour - floor(hour)) * 60.0))
	return "%02d:%02d" % [h, m]

## 一個「大概是什麼時候」的字（面板上顯示）
static func phase_name(hour: float) -> String:
	if hour < 5.0 or hour >= 21.0:
		return "夜晚"
	if hour < 7.5:
		return "日出"
	if hour < 11.0:
		return "早晨"
	if hour < 14.0:
		return "中午"
	if hour < 17.0:
		return "下午"
	if hour < 19.0:
		return "黃昏"
	return "入夜"

# ---------------------------------------------------------------- 天色

static func _wrap(hour: float) -> float:
	return fposmod(hour, 24.0)

## 太陽（月亮 = 太陽的 12 小時後）在天上的位置：仰角（弧度，負的 = 在地平線下面）和方位
static func body(hour: float) -> Vector2:
	var t := (_wrap(hour) - 6.0) / 12.0
	return Vector2(0.95 * sin(PI * t), 2.2 - t * 3.0)

## 一個小時的天色（鍵跟 level_select.gd 的 DEFAULT_MOOD 一樣）
static func mood(hour: float) -> Dictionary:
	var h := _wrap(hour)
	var a: Dictionary = KEYS[KEYS.size() - 1]
	var b: Dictionary = KEYS[0]
	var ha := float(a.h) - 24.0
	var hb := float(b.h)
	for i in KEYS.size():
		if float(KEYS[i].h) <= h:
			a = KEYS[i]
			ha = float(a.h)
			b = KEYS[(i + 1) % KEYS.size()]
			hb = float(b.h) + (24.0 if i + 1 >= KEYS.size() else 0.0)
	var k := clampf((h - ha) / maxf(hb - ha, 0.001), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var l := func(key: String):
		var x = a[key]
		var y = b[key]
		return (x as Color).lerp(y, k) if x is Color else lerpf(float(x), float(y), k)
	# 光從太陽來，太陽下去了就從月亮來（沿著各自的弧線）
	var sun := body(h)
	var moon := body(h + 12.0)
	var lit := sun if sun.x > 0.0 else moon
	var elev := maxf(lit.x, 0.14)
	var rot := Vector3(-elev, lit.y, 0)
	var to_sun := Basis.from_euler(Vector3(-sun.x, sun.y, 0)) * Vector3(0, 0, 1)
	var to_moon := Basis.from_euler(Vector3(-moon.x, moon.y, 0)) * Vector3(0, 0, 1)
	# 太陽剛好在地平線附近的時候，光慢慢換成月光（避免太陽下去的瞬間光突然跳）
	var sun_fade := smoothstep(-0.06, 0.10, sun.x)
	return {
		"sun": l.call("sun"), "energy": float(l.call("e")), "rot": rot,
		"amb": l.call("amb"), "amb_e": float(l.call("amb_e")), "fog": l.call("fog"),
		"sky.top_color": l.call("top"), "sky.horizon_color": l.call("hor"), "sky.cloud_color": l.call("cloud"), "sky.cloud_shade": l.call("shade"),
		"sky.night": float(l.call("night")), "sky.sun_dir": to_sun, "sky.moon_dir": to_moon,
		"sky.sun_vis": sun_fade, "sky.moon_vis": smoothstep(-0.02, 0.08, moon.x),
		"sea.deep": l.call("deep"), "sea.near_c": l.call("near"), "sea.stroke_c": l.call("stroke"), "sea.foam_c": l.call("foam"), "sea.horizon_c": l.call("sh"),
	}

## 夜有多深（0 = 白天、1 = 深夜）：螢火蟲、路燈用
static func night_k(hour: float) -> float:
	return float(mood(hour)["sky.night"])
