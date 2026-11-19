#!/bin/bash
# 仙境截圖：在背景開 Godot（不會跳到前面、不搶滑鼠），拍完自己關掉。
#   bash levels/heaven/tests/shots.sh <輸出資料夾> [--only=N] [--run]
# 環境變數 GODOT_APP 可以指定 Godot.app 的位置。
set -e
OUT="$1"; shift || true
APP="${GODOT_APP:-/Applications/Godot.app}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$OUT"; rm -f "$OUT/DONE"
open -g -n -a "$APP" --args --path "$ROOT" --resolution 1280x720 -s res://levels/heaven/tests/shots.gd -- --out="$OUT" "$@"
for i in $(seq 1 150); do
	[ -f "$OUT/DONE" ] && { echo "拍完了：$OUT"; exit 0; }
	sleep 1
done
echo "等了 150 秒還沒拍完（Godot 可能卡住了）"; exit 1
