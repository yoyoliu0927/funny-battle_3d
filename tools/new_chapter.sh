#!/bin/bash
# 建立自己的大關資料夾：從 levels/_template 複製一份，把裡面的路徑改成新名字。
# 用法（在專案根目錄）：  bash tools/new_chapter.sh tainan
# 名字只能用英文小寫、數字、底線，例如 tainan、taichung_night。
set -e
ID="$1"
if [[ -z "$ID" ]]; then
	echo "用法：bash tools/new_chapter.sh <大關名字>   例如：bash tools/new_chapter.sh tainan"
	exit 1
fi
if [[ ! "$ID" =~ ^[a-z][a-z0-9_]*$ ]]; then
	echo "名字只能用英文小寫開頭，後面接小寫、數字、底線：$ID"
	exit 1
fi
cd "$(dirname "$0")/.."
if [[ -e "levels/$ID" ]]; then
	echo "levels/$ID 已經存在了"
	exit 1
fi
cp -R levels/_template "levels/$ID"
# Godot 的 .uid 檔不能跟範本重複，刪掉讓 Godot 重新產生
find "levels/$ID" -name "*.uid" -delete
find "levels/$ID" -name "*.import" -delete
# 檔案裡指到 _template 的路徑全部換成新名字
grep -rl "levels/_template" "levels/$ID" | while read -r f; do
	sed -i.bak "s#levels/_template#levels/$ID#g" "$f" && rm -f "$f.bak"
done
sed -i.bak "s/const TITLE := \"範本大關\"/const TITLE := \"$ID\"/; s/const ORDER := 90/const ORDER := 10/" "levels/$ID/chapter.gd" && rm -f "levels/$ID/chapter.gd.bak"
echo "完成：levels/$ID"
echo "下一步：打開 levels/$ID/chapter.gd 改名字、城市、作者，然後開始改 stage_1 ~ stage_3。"
