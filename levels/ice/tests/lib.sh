#!/bin/bash
# 測試腳本共用：找 Godot、專案位置、暫存資料夾。Godot 位置用環境變數 GODOT 指定（沒設就用 PATH 裡的 Godot）。
TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$TESTS/../../.." && pwd)"
G="${GODOT:-Godot}"
TMP="${TMPDIR:-/tmp}/ice_tests.$$"
mkdir -p "$TMP"
# gd <秒數上限> <headless|window> <腳本> [參數…]　→ 把輸出印出來；卡住就中止
gd() {
  local lim=$1 mode=$2 script=$3; shift 3
  local flag=""; [ "$mode" = headless ] && flag="--headless"
  ( cd "$PROJ" && "$G" $flag --log-file "$TMP/godot.log" --path . --script "$script" -- "$@" > "$TMP/out.txt" 2>&1 & P=$!
    for i in $(seq 1 $lim); do kill -0 $P 2>/dev/null || break; sleep 1; done
    if kill -0 $P 2>/dev/null; then kill $P; echo "HUNG $script $*"; fi )
  cat "$TMP/out.txt"
}
# 回歸：舊三關 12 筆（stage_9／10／11，永遠不能變）＋新五關的代表走法（每顆星一筆、不放道具一筆）：名稱|關卡|策略
CASES="s9_none|9|none
s9_solve|9|prep:0,-1.5,-3.25
s9_decoy|9|prep:0,-4.5,-6
s9_hat|9|prep:0,-4.5,-6;prep:0,-1.0,-3.0
s10_none|10|none
s10_carom|10|prep:0,-6,-6.8
s10_lunge|10|prep:0,1.9,-6.1;prep:0,-2.6,-4
s11_none|11|none
s11_early|11|prep:0,-9,-6.5
s11_snow|11|prep:0,-6,-6.5
s11_clean|11|prep:0,-3.5,-6.5
s11_late|11|prep:0,-1.75,-6.5
s12_none|12|none
s12_two|12|prep:0,-6,-6.8;prep:0,-2.0,-7.8
s12_pile|12|prep:0,-6,-6.8;prep:0,-0.6,-5.0
s12_one|12|prep:0,-5,-6.8
s13_none|13|none
s13_feed|13|prep:1,5.7,-3.8
s13_all|13|prep:0,1.15,-6.3;prep:1,5.7,-3.8
s13_feed_on_thin|13|prep:1,5.0,-5.5
s14_none|14|none
s14_guard|14|prep:0,-3,-2;prep:0,-1.5,-2;prep:1,2.7,-3.8
s14_intact|14|prep:0,-3,-2;prep:0,-1.5,-2;prep:1,-3,-6.5
s15_none|15|none
s15_snow|15|prep:1,-2.7,0.7;prep:0,5,-3.4;prep:0,-6,-6.5
s15_clean|15|prep:1,-2.7,0.7;prep:0,5,-3.4;prep:0,-4,-6.5
s16_none|16|none
s16_base|16|prep:1,-2.7,-2.3;prep:0,-4,1.2;prep:0,-9,-6.5;prep:0,2.63,-7.65
s16_all|16|prep:1,-2.7,-2.3;prep:0,-4,1.2;prep:0,-4,-6.5
s16_nofeed|16|prep:0,-4,1.2;prep:0,-0.75,-3.94;prep:0,-4,-6.5"
# 一筆回歸的完整事件紀錄（事件列＋結果列）
case_log() { gd 60 headless res://levels/ice/tests/play.gd --stage=$1 "--strategy=$2" | grep -E "^  +[0-9.]+s |^RESULT|SCRIPT ERROR|^HUNG"; }
