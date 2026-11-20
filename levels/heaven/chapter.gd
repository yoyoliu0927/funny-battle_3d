extends RefCounted
## 大關：仙境丹穴山（最終章）。規則沿用冰雪島的玩法，多兩樣新東西：畫門、陸吾。
## 規格在 docs/仙境關卡規格.md，全遊戲的故事在 levels/ice/docs/劇情故事.md。

const TITLE := "丹穴山"
const CITY := ""
const AUTHOR := ""
const ORDER := 90           # 最終章：排在所有大關後面
const ICON := "鳳"
const DESC := "山上的神獸不偏心，誰先到算誰的。"
## 三顆星記在冰雪島的戰局腳本裡（仙境的戰局繼承它，用同一張表）
const STARS_SCRIPT := "res://levels/ice/rescue_battle.gd"
const MAP_SCRIPT := "res://levels/heaven/map_isles.gd"
const STAGES := [
	{"title": "雲階", "desc": "滑進一幅畫，會從另一幅畫出來。", "scene": "stage_1/stage.tscn"},
	{"title": "山海迴廊", "desc": "陸吾只吹第一個到牠面前的，不管是誰。", "scene": "stage_2/stage.tscn"},
	{"title": "天門", "desc": "陸吾只能用一次：留給誰？最後一步是把家豪引上唱盤。", "scene": "stage_3/stage.tscn"},
]
