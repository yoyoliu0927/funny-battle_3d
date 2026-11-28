#!/bin/bash
# 大關開場動畫什麼時候播（opening_flow.gd）：在背景開 Godot（不跳到前面、不搶滑鼠、沒有聲音），
# 用一個空的 HOME 跑（開場會記「看過了」，不能寫到玩家的存檔）。跑完印出結果，全過才回傳 0。
#   bash levels/ice/tests/opening_flow.sh [輸出資料夾]
set -e
OUT="${1:-${TMPDIR:-/tmp}/opening_flow}"
APP="${GODOT_APP:-/Applications/Godot.app}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$OUT"; rm -f "$OUT/DONE" "$OUT/result.txt" "$OUT"/*.jpg
FAKE_HOME="$(mktemp -d)"
open -g -n -a "$APP" --stdout "$OUT/stdout.txt" --stderr "$OUT/stderr.txt" \
	--env HOME="$FAKE_HOME" --env OPENING_OUT="$OUT" \
	--args --path "$ROOT" --audio-driver Dummy --resolution 1280x720 -s res://levels/ice/tests/opening_flow.gd
for i in $(seq 1 400); do
	if [ -f "$OUT/DONE" ]; then
		cat "$OUT/result.txt"
		rm -rf "$FAKE_HOME"
		grep -q "SUMMARY ALL PASS" "$OUT/result.txt"
		exit $?
	fi
	sleep 1
done
echo "等了 400 秒還沒跑完（看 $OUT/stderr.txt）"; exit 1
