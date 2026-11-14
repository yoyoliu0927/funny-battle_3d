#!/bin/bash
# 飼料放在每塊薄冰上和周圍：第 3–6 關（stage_13–16）沒有任何一局拖到時間上限
source "$(dirname "$0")/lib.sh"
bad=0
for st in ${@:-13 14 15 16}; do
  out=$(gd 400 headless res://levels/ice/tests/feed_thin_sweep.gd $st | grep -E "^SLOW|^FEEDTHIN|SCRIPT ERROR|^HUNG")
  echo "$out" | tail -6
  echo "$out" | grep -q "PASS" || bad=1
done
rm -rf "$TMP"
[ $bad = 0 ] && echo "FEEDTHIN: ALL PASS" || echo "FEEDTHIN: FAIL"
