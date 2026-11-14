#!/bin/bash
# 冒煙測試（共用的 tools/smoke_test.gd，只跑冰雪島）
source "$(dirname "$0")/lib.sh"
( cd "$PROJ" && "$G" --headless --log-file "$TMP/godot.log" --path . -s res://tools/smoke_test.gd -- --chapter=ice > "$TMP/smoke.txt" 2>&1 & P=$!
  for i in $(seq 1 400); do kill -0 $P 2>/dev/null || break; sleep 1; done; kill $P 2>/dev/null )
grep -E "SMOKE|FAIL|SCRIPT ERROR" "$TMP/smoke.txt" | tail -5
rm -rf "$TMP"
