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
	{"title": "守衛", "desc": "守衛不怕香蕉皮：把別人撞過去。", "scene": "stage_12/stage.tscn"},
	{"title": "薄冰", "desc": "雞踩薄冰沒事，人一踩就破。飼料會讓家豪繞路。", "scene": "stage_13/stage.tscn"},
	{"title": "排隊", "desc": "兩個人走同一條紅線：前面的人先踩到。", "scene": "stage_14/stage.tscn"},
	{"title": "尖峰時刻", "desc": "三條紅線加一個守衛：有兩個人要同時到交叉點。", "scene": "stage_15/stage.tscn"},
	{"title": "全員泡湯", "desc": "五個人分兩批來，三片香蕉皮怎麼分？", "scene": "stage_16/stage.tscn"},
]
## 舊的第 2、3 關（stage_10 守衛、stage_11 時機）留著當回歸樣本和退路，不列進名單。
## 早期的原型關卡（檔案都還在，要測試時把下面這幾行搬回上面的 STAGES 就能玩）：
##   【實驗A】冰上撞球 stage_5、連環撞 stage_6；【實驗B】冰湖＋倒帶 stage_7、鹽＋倒帶 stage_8；
##   冰湖 stage_1、薄冰 stage_2、鹽 stage_3、冰湖（路線版）stage_4
