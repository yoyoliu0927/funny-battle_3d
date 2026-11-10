extends RefCounted
## 大關設定。複製整個 _template 資料夾、改成自己的名字（例如 levels/tainan/）之後，改這裡的內容。
## 選關地圖會自動找到這個檔案，不用改任何共用檔案。

const TITLE := "範本大關"
const CITY := ""            # 選關地圖上的城市：高雄 / 台南 / 台中 / 新竹 / 台北；空白就照 ORDER 自動排
const AUTHOR := ""          # 你的名字
const ORDER := 90           # 地圖上的順序（小的排前面）
const DESC := "複製這個資料夾開始做你的大關。"
## 小關（至少 3 個）。scene 寫相對於這個資料夾的路徑
const STAGES := [
	{"title": "第一小關：圍欄", "desc": "最基本的：兩個敵人、一道圍欄、飼料和香蕉皮。", "scene": "stage_1/stage.tscn"},
	{"title": "第二小關：水池", "desc": "水池＋自訂道具「鞭炮」。", "scene": "stage_2/stage.tscn"},
	{"title": "第三小關：山坡", "desc": "自訂地形（山坡讓巨石滾）＋自訂敵人「睡覺的守衛」。", "scene": "stage_3/stage.tscn"},
]
