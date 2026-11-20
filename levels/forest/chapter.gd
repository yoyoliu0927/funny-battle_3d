extends RefCounted
## 大關：森林。家豪要在樹被砍光、菸蒂把林子燒掉之前，闖進木屋救出小紅帽。

const TITLE := "森林"
const CITY := ""
const AUTHOR := ""
const ORDER := 5            # 比冰雪島（10）小，一進選關地圖就站在這座島上
const DESC := "把家豪送進木屋就過關。砍倒加燒掉的樹超過 10 棵就輸。"
const MAP_SCRIPT := "res://levels/forest/map_isles.gd"
const STARS_SCRIPT := "res://levels/forest/forest_battle.gd"
const STAGES := [
	{"title": "小紅帽", "desc": "狼外婆守著小紅帽：先用外婆的籃子引開她，再把家豪送進木屋就過關。砍倒加燒掉的樹超過 10 棵（菸蒂會點著樹），家豪還活著也算輸。80 秒內沒進門也輸。", "scene": "stage_1/stage.tscn"},
]
