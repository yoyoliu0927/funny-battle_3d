extends RefCounted
## 大關：駁大莖森。家豪要在樹被砍光、菸蒂把林子燒掉之前，闖進木屋救出小紅帽。
## 三個小關：林道（伐木工、學引路點和假獵物）→ 煙圈（抽菸的人、學菸蒂和起火）→ 小紅帽（狼外婆、外婆的籃子）。

const TITLE := "駁大莖森"
const ICON := "森"          # 選關地圖上用一個字代表這個大關的地方（島牌徽章、清單）都用「森」
const CITY := ""
const AUTHOR := ""
const ORDER := 5            # 比冰雪島（10）小，一進選關地圖就站在這座島上
const DESC := "狼外婆抓了小紅帽，林子裡還有人在砍樹、亂丟菸蒂。"
const MAP_SCRIPT := "res://levels/forest/map_isles.gd"
const STARS_SCRIPT := "res://levels/forest/forest_battle.gd"
const STAGES := [
	{"title": "林道", "desc": "打倒兩個伐木工就過關。倒下的樹超過 6 棵就輸。伐木工很壯，趁他看假獵物時從背後偷襲。", "scene": "stage_1/stage.tscn"},
	{"title": "煙圈", "desc": "打倒三個抽菸的人就過關。菸蒂會點著樹、火會延燒，燒掉超過 5 棵就輸。", "scene": "stage_2/stage.tscn"},
	{"title": "小紅帽", "desc": "狼外婆守著小紅帽：先用外婆的籃子引開她，再把家豪送進木屋就過關。砍倒加燒掉的樹超過 10 棵（菸蒂會點著樹），家豪還活著也算輸。80 秒內沒進門也輸。", "scene": "stage_3/stage.tscn"},
]
