#!/bin/bash
# 拍分鏡：storyboards.sh <輸出資料夾> [名稱…]　（不寫名稱＝舊三關 12 支）。要開視窗，不能 headless。
# 新關卡：storyboards.sh <輸出資料夾> "名稱|關卡號碼或場景路徑|秒,道具,x,z;…"（秒 = -1 是準備階段）
source "$(dirname "$0")/lib.sh"
OUT=$1; shift
mkdir -p "$OUT"
run() {
  rm -rf "$OUT/$1"; mkdir -p "$OUT/$1"
  gd 150 window res://levels/ice/tests/storyboard.gd "$2" "$OUT/$1" "$3" > "$OUT/$1.log"
  echo "$1: $(grep -c "^frame" "$OUT/$1.log") 張, $(grep "^outcome" "$OUT/$1.log"), $(grep -c "SCRIPT ERROR" "$OUT/$1.log") 個錯誤"
}
if [ $# -eq 0 ]; then
  while IFS='|' read name stage strat; do
    casts=""; [ "$strat" != none ] && casts=$(echo "$strat" | sed 's/prep:/-1,/g')
    run $name $stage "$casts"
  done <<< "$CASES"
else
  for spec in "$@"; do IFS='|' read name stage casts <<< "$spec"; run "$name" "$stage" "$casts"; done
fi
rm -rf "$TMP"
