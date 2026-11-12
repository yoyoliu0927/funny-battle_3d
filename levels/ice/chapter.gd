extends RefCounted
## 大關：冰雪島。島規則只有一條：冰雪對雞友善，對人類不友善。
##   雞不滑、人會滑；雞不破、人會破。家豪當誘餌，讓人類被冰整倒。

const TITLE := "冰雪島"
const CITY := ""            # 選關地圖上的位置；空白就照 ORDER 自動排
const AUTHOR := ""          # 你的名字
const ORDER := 10           # 地圖上的順序（小的排前面）
const DESC := "冰雪對雞友善，對人類不友善：雞不滑、人會滑，雞不破、人會破。"
## 小關（3~6 個）。scene 寫相對於這個資料夾的路徑
const STAGES := [
	{"title": "【實驗C】救企鵝 1", "desc": "香蕉皮丟在紅線的哪一段，工人就往那一段的方向滑。", "scene": "stage_9/stage.tscn"},
	{"title": "【實驗C】救企鵝 2", "desc": "守衛站著不動：把另一個工人撞過去。", "scene": "stage_10/stage.tscn"},
	{"title": "【實驗C】救企鵝 3", "desc": "一片香蕉皮、兩個人：抓準時機，讓他們撞在一起。", "scene": "stage_11/stage.tscn"},
	{"title": "【實驗A】冰上撞球", "desc": "家豪是球桿、工人是球、冰洞是球袋。等破綻，從對的方向啄。", "scene": "stage_5/stage.tscn"},
	{"title": "【實驗A】連環撞", "desc": "被啄飛的工人會把別人一起撞出去。", "scene": "stage_6/stage.tscn"},
	{"title": "【實驗B】冰湖＋倒帶", "desc": "原本的冰湖，多了「Q 倒帶 3 秒」。", "scene": "stage_7/stage.tscn"},
	{"title": "【實驗B】鹽＋倒帶", "desc": "原本的鹽關，多了「Q 倒帶 3 秒」。", "scene": "stage_8/stage.tscn"},
	{"title": "冰湖", "desc": "人在冰上轉不了彎。讓追過來的工人滑進冰洞。", "scene": "stage_1/stage.tscn"},
	{"title": "薄冰", "desc": "薄冰撐得住雞，撐不住人。帶家豪過湖，救出企鵝。", "scene": "stage_2/stage.tscn"},
	{"title": "鹽", "desc": "鹽會把厚冰融成薄冰：自己做陷阱。", "scene": "stage_3/stage.tscn"},
	{"title": "冰湖（路線版・對照）", "desc": "同一座冰湖，玩法換成撒一條飼料路：家豪照著跑，工人踩著腳印追。", "scene": "stage_4/stage.tscn"},
]
