#!/bin/bash
# 臉的結構檢查（不用畫面）：表情是不是長在臉上。要看到 FACE_CHECK: ALL PASS。
# 有視窗、照遊戲實際每格跑的檢查（外加繞一圈的近照）是 face_watch.gd，用法寫在那個檔案開頭。
cd "$(dirname "$0")" && source ./lib.sh
gd 120 headless res://levels/ice/tests/face_check.gd | grep -E "^==|^  (ok|FAIL)|FACE_CHECK|SCRIPT ERROR|Parse Error"
