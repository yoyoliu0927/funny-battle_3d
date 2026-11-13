extends RefCounted
## 大關：冰雪島。島規則只有一條：冰雪對雞友善，對人類不友善。
##   雞不滑、人會滑；雞不破、人會破。家豪當誘餌，讓人類被冰整倒。

const TITLE := "冰雪島"
const CITY := ""            # 選關地圖上的位置；空白就照 ORDER 自動排
const AUTHOR := ""          # 你的名字
const ORDER := 10           # 地圖上的順序（小的排前面）
const DESC := "救出被關起來的企鵝！人在冰上會滑，雞不會。"
## 小關（3~6 個）。scene 寫相對於這個資料夾的路徑
const STAGES := [
	{"title": "雪人與冰洞", "desc": "香蕉皮丟在紅線的哪一段，工人就往那一段的方向滑。", "scene": "stage_9/stage.tscn"},
	{"title": "守衛", "desc": "守衛站著不動：把另一個工人撞過去，或讓他自己撲上來。", "scene": "stage_10/stage.tscn"},
	{"title": "時機", "desc": "一片香蕉皮、兩個人：讓他們同時到交叉點。", "scene": "stage_11/stage.tscn"},
]
## 早期的原型關卡（檔案都還在，要測試時把下面這幾行搬回上面的 STAGES 就能玩）：
##   【實驗A】冰上撞球 stage_5、連環撞 stage_6；【實驗B】冰湖＋倒帶 stage_7、鹽＋倒帶 stage_8；
##   冰湖 stage_1、薄冰 stage_2、鹽 stage_3、冰湖（路線版）stage_4
