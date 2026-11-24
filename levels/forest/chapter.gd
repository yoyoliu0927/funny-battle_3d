extends RefCounted
## 大關：駁大莖森。家豪要在樹被砍光、菸蒂把林子燒掉之前，打倒伐木工和抽菸的人，最後闖進木屋救出小紅帽。

const TITLE := "駁大莖森"
const ICON := "森"          # 選關地圖上用一個字代表這個大關的地方（島牌徽章、清單）都用「森」
const CITY := ""
const AUTHOR := ""
const ORDER := 5            # 比冰雪島（10）小，一進選關地圖就站在這座島上
const DESC := "別讓森林被砍光、燒光：伐木場、煙圈、狼外婆的木屋，三個小關依序打上去。"
const MAP_SCRIPT := "res://levels/forest/map_isles.gd"
const STARS_SCRIPT := "res://levels/forest/forest_battle.gd"
const STAGES := [
	{"title": "伐木場", "desc": "兩個伐木工一直砍樹：用引路點帶家豪去打人，用假獵物把伐木工引開，從樹後面偷襲。砍倒超過 5 棵就輸。", "scene": "stage_1/stage.tscn"},
	{"title": "煙圈", "desc": "抽菸的人彈的菸蒂會點著樹、火會延燒。新道具水桶：先淋濕、再救火。燒掉加砍倒超過 6 棵就輸。", "scene": "stage_2/stage.tscn"},
	{"title": "狼外婆的木屋", "desc": "狼外婆守著小紅帽：先把假獵物放在門口引開她，再把家豪送進木屋。天色會越來越暗，前兩關的招數全部要用上。", "scene": "stage_3/stage.tscn"},
]
