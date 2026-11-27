#!/usr/bin/env python3
"""網頁版載入畫面（assets/web/loading_shell.html）的小工具。

1. 嵌素材：匯出時只會帶走 loading_shell.html 這一個檔案，所以圖和字型要直接寫進去。
       python3 assets/web/make_loading_shell.py
   會做兩件事：
   - 家豪的手繪大眼：把 assets/characters/hero_eyes.png（遊戲裡同一張）縮成 256×128 嵌進去。
     眼睛圖換了就跑一次。縮圖要 Pillow（pip install Pillow），沒有的話就嵌原圖（比較大，但一樣能用）。
   - 字型：把粉圓體縮成只剩載入畫面用到的字。改了載入畫面上的字之後跑一次（沒跑也不會壞，缺的字會用系統字型補）。
     要 fonttools 和 brotli（pip install fonttools brotli），沒有的話這一步會跳過。

2. 不用匯出就看效果：產生一個用假引擎跑的預覽網頁，用瀏覽器打開。
       python3 assets/web/make_loading_shell.py --preview <輸出路徑.html>
   網址後面可以加：
       ?p=0.42       停在 42%
       ?stage=start  下載完、引擎啟動中（家豪吃飽了在跳）
       ?stage=error  載入失敗的樣子
       ?dur=20       假裝下載 20 秒（預設 10 秒），之後假裝啟動 3 秒就淡出
   預覽只需要 Python，不用 fonttools。

字型授權：jf open 粉圓 2.1（SIL OFL 1.1，見 assets/fonts/OFL-LICENSE.txt）。
保留字型名稱是 open huninn／huninn，縮過的字型算修改版，所以改名成 JiahaoRound。
"""
import base64
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.join(HERE, "loading_shell.html")
FONT = os.path.join(HERE, "..", "fonts", "jf-openhuninn-2.1.ttf")
NEW_NAME = "JiahaoRound"
FONT_SRC = re.compile(r"(url\(data:font/woff2;base64,)[A-Za-z0-9+/=]*(\))")
EYES = os.path.join(HERE, "..", "characters", "hero_eyes.png")
EYES_SRC = re.compile(r'(<image id="g-eyes"[^>]*?href="data:image/png;base64,)[A-Za-z0-9+/=]*(")')


def used_chars(html: str) -> str:
	"""畫面上可能出現的字：拿掉註解和嵌入的字型之後，所有非 ASCII 字＋全部可列印的 ASCII。"""
	text = FONT_SRC.sub(r"\1\2", html)
	text = EYES_SRC.sub(r"\1\2", text)
	text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
	text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
	text = re.sub(r"(^|\s)//\s[^\n]*", "", text)
	chars = {c for c in text if ord(c) > 0x7F and not c.isspace()}
	chars |= {chr(i) for i in range(0x20, 0x7F)}
	return "".join(sorted(chars))


def embed_eyes() -> None:
	with open(EYES, "rb") as f:
		png = f.read()
	try:
		from PIL import Image
		im = Image.open(io.BytesIO(png)).convert("RGBA").resize((256, 128), Image.LANCZOS)
		buf = io.BytesIO()
		im.save(buf, "PNG", optimize=True)
		png = buf.getvalue()
	except ImportError:
		print("沒有 Pillow：眼睛直接嵌原圖（pip install Pillow 可以縮小）")
	data = base64.b64encode(png).decode("ascii")
	with open(SHELL, encoding="utf-8") as f:
		html = f.read()
	html, n = EYES_SRC.subn(lambda m: m.group(1) + data + m.group(2), html, count=1)
	if n != 1:
		sys.exit('loading_shell.html 裡找不到 <image id="g-eyes" ... href="data:image/png;base64,">')
	with open(SHELL, "w", encoding="utf-8") as f:
		f.write(html)
	print("眼睛嵌好了：%.1f KB" % (len(png) / 1024))


def embed_font() -> None:
	try:
		from fontTools import subset
	except ImportError:
		print("沒有 fonttools：字型這一步跳過（pip install fonttools brotli）")
		return

	with open(SHELL, encoding="utf-8") as f:
		html = f.read()
	chars = used_chars(html)

	opts = subset.Options()
	opts.flavor = "woff2"
	opts.hinting = False
	opts.desubroutinize = True
	font = subset.load_font(FONT, opts)
	sub = subset.Subsetter(opts)
	sub.populate(text=chars)
	sub.subset(font)

	# 依 OFL 改名（不能沿用 open huninn／huninn）
	names = {1: NEW_NAME, 2: "Regular", 3: NEW_NAME + "-Regular-loading", 4: NEW_NAME + " Regular", 6: NEW_NAME + "-Regular"}
	table = font["name"]
	for rec in list(table.names):
		if rec.nameID in (16, 17, 18, 21, 22):
			table.removeNames(nameID=rec.nameID)
		elif rec.nameID in names:
			table.setName(names[rec.nameID], rec.nameID, rec.platformID, rec.platEncID, rec.langID)

	buf = io.BytesIO()
	subset.save_font(font, buf, opts)
	data = base64.b64encode(buf.getvalue()).decode("ascii")

	html, n = FONT_SRC.subn(lambda m: m.group(1) + data + m.group(2), html, count=1)
	if n != 1:
		sys.exit("loading_shell.html 裡找不到 @font-face 的 data:font/woff2 位置")
	with open(SHELL, "w", encoding="utf-8") as f:
		f.write(html)
	print("嵌好了：%d 個字、字型 %.1f KB（base64 後 %.1f KB）" % (len(chars), len(buf.getvalue()) / 1024, len(data) / 1024))


# 預覽用的假引擎：跟 Godot 的 Engine 有一樣的介面，進度用計時器假裝
FAKE_ENGINE = r"""
<script>
(function () {
	const q = new URLSearchParams(location.search);
	const TOTAL = 72.6 * 1048576;
	function Engine(cfg) { this.cfg = cfg; this._init = null; }
	Engine.getMissingFeatures = function () { return []; };
	Engine.prototype.init = function () {
		if (this._init) { return this._init; }
		const cb = this.cfg.onProgress || function () {};
		const stage = q.get('stage');
		const hold = q.get('p');
		this._init = new Promise(function (resolve, reject) {
			if (stage === 'error') {
				cb(TOTAL * 0.37, TOTAL);
				setTimeout(function () { reject(new Error('Failed to fetch index.pck (404)')); }, 600);
				return;
			}
			if (stage === 'start') { cb(TOTAL, TOTAL); resolve(); return; }
			if (hold !== null) { cb(TOTAL * Number(hold), TOTAL); return; }
			const dur = Number(q.get('dur') || 10) * 1000;
			const t0 = performance.now();
			const id = setInterval(function () {
				const f = Math.min(1, (performance.now() - t0) / dur);
				cb(Math.max(1, f * TOTAL), TOTAL);
				if (f >= 1) { clearInterval(id); resolve(); }
			}, 150);
		});
		return this._init;
	};
	Engine.prototype.preloadFile = function () { return Promise.resolve(); };
	Engine.prototype.start = function () {
		const forever = q.get('stage') === 'start';
		return new Promise(function (resolve) { if (!forever) { setTimeout(resolve, 3000); } });
	};
	Engine.prototype.installServiceWorker = function () { return Promise.resolve(); };
	window.Engine = Engine;
}());
</script>
"""


def make_preview(out: str) -> None:
	with open(SHELL, encoding="utf-8") as f:
		html = f.read()
	config = '{"args":[],"executable":"index","fileSizes":{"index.pck":33176096,"index.wasm":39514754}}'
	marker = "$" + "GODOT_"
	html = html.replace('<script src="' + marker + 'URL"></script>', FAKE_ENGINE)
	html = html.replace(marker + "CONFIG", config)
	html = html.replace(marker + "THREADS_ENABLED", "false")
	html = html.replace(marker + "HEAD_INCLUDE", "")
	html = html.replace("<body>", '<body style="background:#222">', 1)
	with open(out, "w", encoding="utf-8") as f:
		f.write(html)
	print("預覽：" + os.path.abspath(out))


if __name__ == "__main__":
	if len(sys.argv) >= 3 and sys.argv[1] == "--preview":
		make_preview(sys.argv[2])
	else:
		embed_eyes()
		embed_font()
