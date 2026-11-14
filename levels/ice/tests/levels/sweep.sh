#!/bin/bash
# 用法：sweep.sh <關卡號碼> <jobs 檔> [--verbose]　→ 每一筆印一行；超過 LIMIT 秒（預設 300）自動中止
source "$(dirname "$0")/../lib.sh"
gd ${LIMIT:-300} headless res://levels/ice/tests/levels/jobs_sweep.gd --stage=$1 --jobs=$2 $3 > "$TMP/sweep.txt"
grep -E "^JOB|SCRIPT ERROR|Parse Error|^HUNG" "$TMP/sweep.txt" | sed 's/^JOB //'
rm -rf "$TMP"
