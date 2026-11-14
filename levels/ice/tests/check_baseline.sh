#!/bin/bash
# 舊三關 12 筆回歸：完整事件紀錄要和基準逐字相同。加參數 sweep 會連第 11 關的掃線一起比。
source "$(dirname "$0")/lib.sh"
bad=0
while IFS='|' read name stage strat; do
  case_log $stage "$strat" > "$TMP/$name.txt"
  if diff -q "$TESTS/baseline/$name.txt" "$TMP/$name.txt" > /dev/null; then
    echo "same  $name  $(tail -1 "$TMP/$name.txt" | sed 's/RESULT //; s/ bird_hp.*//')"
  else
    echo "DIFF  $name"; diff "$TESTS/baseline/$name.txt" "$TMP/$name.txt" | head -8; bad=1
  fi
done <<< "$CASES"
if [ "$1" = sweep ]; then
  gd 200 headless res://levels/ice/tests/sweep.gd 11 0 -11.75,-6.5 -0.5,-6.5 0.25 | grep -E "^\(" > "$TMP/sweep.txt"
  if diff -q "$TESTS/baseline/sweep_s11_atu.txt" "$TMP/sweep.txt" > /dev/null; then echo "same  sweep_s11_atu"; else echo "DIFF  sweep_s11_atu"; diff "$TESTS/baseline/sweep_s11_atu.txt" "$TMP/sweep.txt" | head -8; bad=1; fi
fi
rm -rf "$TMP"
[ $bad = 0 ] && echo "BASELINE: ALL SAME" || echo "BASELINE: CHANGED"
exit $bad
