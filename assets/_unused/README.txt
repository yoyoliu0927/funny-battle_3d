這個資料夾裡的檔案目前沒有被任何腳本、場景或著色器用到。

資料夾裡有 .gdignore，所以 Godot 不會匯入它們，也不會打包進遊戲（網頁版可以少下載約 10 MB）。
檔案本身還留在 repo 裡：哪一天要用，把檔案搬回 assets/ 對應的資料夾就可以了。

- ChatGPT Image *.png：概念圖
- *_nor_gl_1k.jpg / *_rough_1k.jpg：地面與岩石的法線、粗糙度貼圖（目前的卡通著色器只用到顏色貼圖）
  來源與授權見 assets/textures/CREDITS.txt
