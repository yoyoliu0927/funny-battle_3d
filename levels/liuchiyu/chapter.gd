extends RefCounted
## 大關設定。複製整個 _template 資料夾、改成自己的名字（例如 levels/tainan/）之後，改這裡的內容。
## 選關地圖會自動找到這個檔案，不用改任何共用檔案。

const TITLE := "霧山楓燃"
const CITY := ""            # 選關地圖上的城市：高雄 / 台南 / 台中 / 新竹 / 台北；空白就照 ORDER 自動排
const AUTHOR := "劉起佑"          # 你的名字
const ORDER := 10           # 地圖上的順序（小的排前面）
const DESC := "一座秋天的油畫小島：南岸、北岸、中間的岩石高原，三個小關依序打上去。"
## 選關地圖：一座秋天的油畫島（風車、水池、火山），島的上空懸著神之手；三個小關是午後、黃昏、夜晚
const MAP_SCRIPT := "res://levels/liuchiyu/map_isles.gd"
const ICON := "神"
## 小關（至少 3 個）。scene 寫相對於這個資料夾的路徑
const STAGES := [
	{"title": "第一小關：南岸", "desc": "島南邊的低地：兩個敵人、一道圍欄、飼料和香蕉皮。", "scene": "stage_1/stage.tscn"},
	{"title": "第二小關：北岸", "desc": "島北邊的低地：水池＋自訂道具「鞭炮」，南邊有石階通到高原。", "scene": "stage_2/stage.tscn"},
	{"title": "第三小關：高原", "desc": "島中間的岩石高原：山坡讓巨石滾＋自訂敵人「睡覺的守衛」。", "scene": "stage_3/stage.tscn"},
]
