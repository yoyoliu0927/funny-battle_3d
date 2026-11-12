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
	{"title": "冰湖", "desc": "人在冰上轉不了彎。讓追過來的工人滑進冰洞。", "scene": "stage_1/stage.tscn"},
	{"title": "薄冰", "desc": "薄冰撐得住雞，撐不住人。帶家豪過湖，救出企鵝。", "scene": "stage_2/stage.tscn"},
	{"title": "鹽", "desc": "鹽會把厚冰融成薄冰：自己做陷阱。", "scene": "stage_3/stage.tscn"},
	{"title": "冰湖（路線版・對照）", "desc": "同一座冰湖，玩法換成撒一條飼料路：家豪照著跑，工人踩著腳印追。", "scene": "stage_4/stage.tscn"},
]
