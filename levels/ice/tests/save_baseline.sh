#!/bin/bash
# 把舊三關 12 筆回歸的完整事件紀錄存成基準（只在確定要換基準時才跑）
source "$(dirname "$0")/lib.sh"
echo "$CASES" | while IFS='|' read name stage strat; do
  case_log $stage "$strat" > "$TESTS/baseline/$name.txt"
  echo "$name: $(tail -1 "$TESTS/baseline/$name.txt")"
done
# 第 11 關（時機）沿阿土紅線的掃線結果：第 5 關拿來對照
gd 200 headless res://levels/ice/tests/sweep.gd 11 0 -11.75,-6.5 -0.5,-6.5 0.25 | grep -E "^\(" > "$TESTS/baseline/sweep_s11_atu.txt"
echo "sweep_s11_atu: $(wc -l < "$TESTS/baseline/sweep_s11_atu.txt") 筆"
rm -rf "$TMP"
