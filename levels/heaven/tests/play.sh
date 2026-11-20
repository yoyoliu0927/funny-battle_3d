#!/bin/bash
# 仙境試玩（不開視窗）：bash levels/heaven/tests/play.sh <關卡 1-3> ["<放法>"] [--brief]
#   放法例："banana,-6,-4;rock,2.4,-12"（道具,x,z；分號分隔）。環境變數 GODOT 指定 Godot 執行檔。
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
"$GODOT" --headless --path "$ROOT" --script res://levels/heaven/tests/play.gd -- "$@" 2>&1 | grep -v -E "^ERROR|^   at:|RID alloc|resources still|^Godot Engine|^$|leaked"
