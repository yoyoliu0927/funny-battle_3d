#!/bin/bash
# 用法：bash levels/forest/tests/shots.sh <輸出資料夾> [--only=2] [--run=20]
# 背景開 Godot 截圖，不搶滑鼠；拍完才返回。
G=/Users/cdytim/Documents/Codex/2026-10-04/new-chat/work/godot-runtime/Godot.app
OUT="$1"; shift
rm -rf "$OUT"; mkdir -p "$OUT"
open -g -n -a "$G" --args --path "$(pwd)" --resolution 1280x720 -s res://levels/forest/tests/shots.gd -- --out="$OUT" "$@"
for i in $(seq 1 180); do [ -f "$OUT/DONE" ] && break; sleep 1; done
ls "$OUT"
