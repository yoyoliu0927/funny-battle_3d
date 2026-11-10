extends RefCounted
## 範例大關：農場（只當範例，給大家照著做；不屬於任何人的大關）
## 每個大關資料夾都要有一個 chapter.gd，選關地圖會自動找到它。

const TITLE := "範例：農場大門"
const CITY := ""            # 選關地圖上的城市：高雄 / 台南 / 台中 / 新竹 / 台北；空白就照 ORDER 自動排
const AUTHOR := "範例"
const ORDER := 0            # 地圖上的順序（小的排前面）
const DESC := "家豪的起義從這座人類農場開始。（範例關）"
## 小關：scene 寫相對於這個資料夾的路徑
const STAGES := [
	{"title": "農場大門", "desc": "用骨牌壓垮大穀倉裡的老闆。", "scene": "stage.tscn"},
]
