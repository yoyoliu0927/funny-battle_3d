#!/bin/bash
# 冰雪島前三關教學截圖：在背景開 Godot（不跳到前面、不搶滑鼠），拍完自己關掉。
#   bash levels/ice/tests/tut_shots.sh <輸出資料夾> [--only=9]
set -e
OUT="$1"; shift || true
APP="${GODOT_APP:-/Applications/Godot.app}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$OUT"; rm -f "$OUT/DONE" "$OUT"/*.png
open -g -n -a "$APP" --args --path "$ROOT" --resolution 1280x720 -s res://levels/ice/tests/tut_shots.gd -- --out="$OUT" "$@"
for i in $(seq 1 180); do
	[ -f "$OUT/DONE" ] && { echo "拍完了：$OUT"; exit 0; }
	sleep 1
done
echo "等了 180 秒還沒拍完"; exit 1
