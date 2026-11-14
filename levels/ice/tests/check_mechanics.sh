#!/bin/bash
# 每個機制的自動檢查：check_mechanics.sh [只跑名字裡有這個字的項目]
source "$(dirname "$0")/lib.sh"
gd 300 headless res://levels/ice/tests/mechanics.gd "$@" | grep -E "^== |^  (ok|FAIL)|^MECHANICS|SCRIPT ERROR|^ERROR|^HUNG" | grep -v "at exit"
rm -rf "$TMP"
