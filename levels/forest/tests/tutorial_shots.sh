#!/bin/bash
# 用法：bash levels/forest/tests/tutorial_shots.sh <輸出資料夾> <第幾關>
# 背景開 Godot 把教學每一步截圖，不搶滑鼠。
G=/Users/cdytim/Documents/Codex/2026-10-04/new-chat/work/godot-runtime/Godot.app
OUT="$1"; ST="${2:-1}"
rm -rf "$OUT"; mkdir -p "$OUT"
open -g -n -a "$G" --args --path "$(pwd)" --resolution 1280x720 -s res://levels/forest/tests/tutorial_shots.gd -- --out="$OUT" --stage="$ST"
for i in $(seq 1 120); do [ -f "$OUT/DONE" ] && break; sleep 1; done
cat "$OUT/DONE"; ls "$OUT" | head -30
