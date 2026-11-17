extends RefCounted
## 把一張用字元畫的小圖變成技能欄的圖示（像素風）。
## rows：每一列一個字串，一個字元一個像素；palette：字元 → 顏色；沒列在 palette 裡的字元是透明的。
## scale：一個像素放大成幾乘幾（13 格的圖配 4 倍，剛好是技能欄圖示的 52 像素，不會糊掉）

static func make(rows: Array, palette: Dictionary, scale := 4) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for row in rows:
		w = maxi(w, String(row).length())
	var img := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row := String(rows[y])
		for x in row.length():
			var ch := row[x]
			if palette.has(ch):
				img.fill_rect(Rect2i(x * scale, y * scale, scale, scale), palette[ch])
	return ImageTexture.create_from_image(img)
