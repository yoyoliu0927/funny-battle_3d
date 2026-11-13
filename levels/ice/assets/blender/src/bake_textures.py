# 冰雪島的手繪風貼圖（本組自製）：用 Blender 內建的 numpy 算出來存成 PNG，全部可以無縫拼接。
#   Blender --background --factory-startup --python bake_textures.py -- <輸出資料夾>
# 產出：
#   ice_cracks.png   R=冰裂紋（粗細不一的白線）  G=冰刀刮痕、小氣泡  B=冰層深處的雲霧塊
#   cliff_strata.png 一層一層的岩壁（明暗＋一點冷暖色偏），著色器再依深度上色
#   snow_soft.png    R=雪地的大起伏  G=風吹的細紋  B=亮晶晶的雪粒位置
#   sea_waves.png    R=海面的波光線（卡通風，一格一格彎彎的亮線）  G=大片的明暗  B=浪花小點
import bpy, sys
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
outdir = argv[0]
N = 1024
rng = np.random.default_rng(20261113)


def save(name, rgb):
    h, w, _ = rgb.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    px = np.ones((h, w, 4), dtype=np.float32)
    px[..., :3] = np.clip(rgb, 0.0, 1.0)
    img.pixels = px[::-1].ravel()          # Blender 的影像原點在左下
    img.filepath_raw = outdir + "/" + name
    img.file_format = 'PNG'
    img.save()
    print("SAVED", img.filepath_raw)


def grid():
    v = (np.arange(N) + 0.5) / N
    return np.meshgrid(v, v)               # x, y ∈ [0,1)


def smooth(t):
    return t * t * (3.0 - 2.0 * t)


def vnoise(x, y, cells, seed):
    """可拼接的 value noise：cells × cells 的隨機格點，邊界繞回去"""
    r = np.random.default_rng(seed)
    g = r.random((cells, cells))
    fx = x * cells
    fy = y * cells
    ix = np.floor(fx).astype(int)
    iy = np.floor(fy).astype(int)
    tx = smooth(fx - ix)
    ty = smooth(fy - iy)
    a = g[iy % cells, ix % cells]
    b = g[iy % cells, (ix + 1) % cells]
    c = g[(iy + 1) % cells, ix % cells]
    d = g[(iy + 1) % cells, (ix + 1) % cells]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(x, y, cells, seed, octaves=4):
    s = 0.0
    amp = 0.5
    tot = 0.0
    for o in range(octaves):
        s = s + amp * vnoise(x, y, cells * (2 ** o), seed + o * 17)
        tot += amp
        amp *= 0.5
    return s / tot


def voronoi_edges(x, y, cells, seed, jitter=0.85):
    """可拼接的 Voronoi：回傳 (F2 - F1, 最近那格的亂數 id)"""
    r = np.random.default_rng(seed)
    px = r.random((cells, cells))
    py = r.random((cells, cells))
    ids = r.random((cells, cells))
    fx = x * cells
    fy = y * cells
    ix = np.floor(fx).astype(int)
    iy = np.floor(fy).astype(int)
    f1 = np.full(x.shape, 9.0)
    f2 = np.full(x.shape, 9.0)
    cid = np.zeros(x.shape)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx = ix + dx
            cy = iy + dy
            qx = cx + 0.5 + (px[cy % cells, cx % cells] - 0.5) * jitter
            qy = cy + 0.5 + (py[cy % cells, cx % cells] - 0.5) * jitter
            d = np.hypot(fx - qx, fy - qy)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, ids[cy % cells, cx % cells], cid)
            f1 = np.where(closer, d, f1)
    return f2 - f1, cid


def wrap_d(a):
    """座標差繞回 [-0.5, 0.5)"""
    return (a + 0.5) % 1.0 - 0.5


# ------------------------------------------------------------------ 冰面
def bake_ice():
    x, y = grid()
    # 先把座標扭一下：裂紋才不會是直直的多邊形
    wx = x + (fbm(x, y, 4, 11) - 0.5) * 0.10
    wy = y + (fbm(x, y, 4, 23) - 0.5) * 0.10
    big, _ = voronoi_edges(wx, wy, 5, 101)
    mid, mid_id = voronoi_edges(wx + 0.37, wy + 0.11, 11, 202)
    thick = 0.030 + 0.045 * fbm(x, y, 6, 31)         # 粗細不一
    crack = 1.0 - np.clip(big / thick, 0.0, 1.0)
    crack = smooth(crack)
    # 小裂紋只出現在一部分格子裡（像是從大裂紋岔出去的）
    m = (mid_id > 0.45).astype(np.float64) * smooth(np.clip((fbm(x, y, 5, 47) - 0.42) * 6.0, 0.0, 1.0))
    small = smooth(1.0 - np.clip(mid / 0.035, 0.0, 1.0)) * m * 0.75
    r = np.maximum(crack, small)
    # 刮痕：一條條細長、微彎的線
    g = np.zeros_like(x)
    sr = np.random.default_rng(303)
    for _ in range(70):
        cx, cy = sr.random(2)
        ang = sr.random() * np.pi
        ln = 0.06 + sr.random() * 0.22
        wd = 0.0012 + sr.random() * 0.0016
        bend = (sr.random() - 0.5) * 0.8
        dx = wrap_d(x - cx)
        dy = wrap_d(y - cy)
        u = dx * np.cos(ang) + dy * np.sin(ang)
        v = -dx * np.sin(ang) + dy * np.cos(ang) - bend * u * u / max(ln, 0.01)
        along = np.clip(1.0 - np.abs(u) / ln, 0.0, 1.0)
        line = np.clip(1.0 - np.abs(v) / wd, 0.0, 1.0) * smooth(along)
        g = np.maximum(g, line * (0.45 + 0.55 * sr.random()))
    # 小氣泡：一小群一小群的圓點
    for _ in range(26):
        cx, cy = sr.random(2)
        for _k in range(sr.integers(4, 11)):
            bx = cx + sr.normal() * 0.02
            by = cy + sr.normal() * 0.02
            rad = 0.0025 + sr.random() * 0.004
            d = np.hypot(wrap_d(x - bx), wrap_d(y - by))
            ring = np.clip(1.0 - np.abs(d - rad * 0.7) / (rad * 0.35), 0.0, 1.0)   # 空心小圈
            g = np.maximum(g, ring * 0.8)
    # 深處的雲霧塊
    b = fbm(x, y, 3, 404, 5)
    b = smooth(np.clip((b - 0.30) / 0.42, 0.0, 1.0))
    save("ice_cracks.png", np.stack([r, g, b], axis=-1))


# ------------------------------------------------------------------ 岩壁
def bake_cliff():
    x, y = grid()
    bands = 9
    # 層的邊界上下起伏（左右可拼接）
    # 起伏要小：島的網格每 1/9 張貼圖凹一道縫，貼圖的縫要跟它對得上
    wob = (fbm(x, y * 0.0 + 0.3, 3, 501) - 0.5) * 0.028 + (fbm(x, y, 5, 502) - 0.5) * 0.012
    yy = (y + wob) % 1.0
    # 每層一樣厚（跟島的網格一致）
    br = np.random.default_rng(606)
    th = np.ones(bands)
    edges = np.concatenate([[0.0], np.cumsum(th) / th.sum()])
    idx = np.clip(np.searchsorted(edges, yy, side="right") - 1, 0, bands - 1)
    y0 = edges[idx]
    y1 = edges[idx + 1]
    v = (yy - y0) / (y1 - y0)                          # 0 = 這一層的上緣，1 = 下緣
    # 每層切成幾塊（直的裂縫），每塊明暗、冷暖不一樣
    lum = np.zeros_like(x)
    warm = np.zeros_like(x)
    crack = np.zeros_like(x)
    for bi in range(bands):
        sel = idx == bi
        nb = br.integers(2, 5)
        cuts = np.sort(br.random(nb))
        shift = (fbm(x, y, 5, 700 + bi) - 0.5) * 0.09 + (v - 0.5) * (br.random() - 0.5) * 0.06   # 裂縫歪歪斜斜的
        xx = (x + shift) % 1.0
        ci = np.searchsorted(cuts, xx, side="right") % nb
        tones = 0.80 + br.random(nb) * 0.2
        warms = br.random(nb)
        lum = np.where(sel, tones[ci], lum)
        warm = np.where(sel, warms[ci], warm)
        dmin = np.full(x.shape, 1.0)
        for c in cuts:
            dmin = np.minimum(dmin, np.abs(wrap_d(xx - c)))
        crack = np.where(sel, np.clip(1.0 - dmin / 0.006, 0.0, 1.0), crack)
    # 每層上緣亮、往下漸暗，層和層之間一條深色的縫；塊的四角磨圓
    hi = np.exp(-v * 6.0) * 0.26
    lo = smooth(np.clip((v - 0.55) / 0.45, 0.0, 1.0)) * 0.22
    crease = np.clip(1.0 - np.minimum(v, 1.0 - v) * (y1 - y0) / 0.008, 0.0, 1.0)
    stroke = (vnoise(x, y, 64, 811) - 0.5) * 0.05 + (fbm(x * 1.0, y, 8, 812) - 0.5) * 0.14   # 筆觸
    # 橫向的細紋（沉積岩的紋理）
    ystripe = (vnoise(x * 0.0 + 0.5, yy, 90, 813) - 0.5) * 0.07
    L = lum + hi - lo + stroke + ystripe
    L = L * (1.0 - 0.55 * smooth(crease)) * (1.0 - 0.45 * smooth(crack))
    L = np.clip(L, 0.0, 1.2) / 1.2
    w = (warm - 0.5) * 0.10
    rgb = np.stack([L + w, L, L - w * 1.2], axis=-1)
    save("cliff_strata.png", rgb)


# ------------------------------------------------------------------ 雪地
def bake_snow():
    x, y = grid()
    dunes = fbm(x, y, 3, 901, 4)
    wxx = x + (fbm(x, y, 3, 905) - 0.5) * 0.25
    ripple = 0.5 + 0.5 * np.sin((wxx * 0.6 + y) * np.pi * 2.0 * 14.0 + fbm(x, y, 6, 906) * 6.0)
    ripple = ripple * smooth(np.clip((fbm(x, y, 4, 907) - 0.35) * 3.0, 0.0, 1.0))
    sp = np.zeros_like(x)
    sr = np.random.default_rng(909)
    pts = sr.random((900, 2))
    for p in pts:
        d = np.hypot(wrap_d(x - p[0]), wrap_d(y - p[1]))
        sp = np.maximum(sp, np.clip(1.0 - d / 0.0022, 0.0, 1.0) * (0.4 + 0.6 * sr.random()))
    save("snow_soft.png", np.stack([dunes, ripple, sp], axis=-1))


# ------------------------------------------------------------------ 海面
def bake_sea():
    x, y = grid()
    # 波光：一小段一小段橫向的弧線（像「～」），疏疏的；不要連成網（會跟冰面的裂紋搞混）
    lines = np.zeros_like(x)
    sr = np.random.default_rng(1203)
    for _ in range(150):
        cx, cy = sr.random(2)
        ln = 0.035 + sr.random() * 0.075
        wd = 0.0028 + sr.random() * 0.0035
        amp = (sr.random() - 0.5) * 0.02
        dx = wrap_d(x - cx)
        dy = wrap_d(y - cy)
        v = dy - amp * np.cos(dx / ln * np.pi)                     # 中間微微拱起或下凹
        along = np.clip(1.0 - np.abs(dx) / ln, 0.0, 1.0)
        line = np.clip(1.0 - np.abs(v) / (wd * (0.3 + 0.7 * along)), 0.0, 1.0) * smooth(along)
        lines = np.maximum(lines, line * (0.5 + 0.5 * sr.random()))
    big = fbm(x, y, 3, 1206, 4)
    sp = np.zeros_like(x)
    for p in sr.random((220, 2)):
        dd = np.hypot(wrap_d(x - p[0]) * 0.45, wrap_d(y - p[1]))      # 橫向拉長的小浪花
        sp = np.maximum(sp, np.clip(1.0 - dd / 0.004, 0.0, 1.0) * (0.4 + 0.6 * sr.random()))
    save("sea_waves.png", np.stack([lines, big, sp], axis=-1))


bake_ice()
bake_cliff()
bake_snow()
bake_sea()
