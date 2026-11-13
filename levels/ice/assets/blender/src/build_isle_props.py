# 冰雪島的模型（本組自製）：
#   地圖：雪堆、碎冰塊、冰洞口（有厚度的破冰邊緣＋水面）、薄冰片、浮冰、冰柱、石頭、雲朵
#   道具：雪人（頭可以拿下來）、企鵝籠（門會開、鎖會掉）、釣竿、火焰、冰台座
#   地標：小木船（漁村）、夜市攤位和一串燈籠（燈籠夜市）
#   Blender --background --factory-startup --python build_isle_props.py -- <輸出資料夾>
# 材質名稱是給 Godot 換著色器用的：snow / ice / ice_wall / water / thin_ice / crack / flame_outer / flame_inner / cloud / lantern_glow*
# Blender 是 Z 向上；匯出時轉成 Y 向上（Blender 的 -Y = Godot 的 +Z）。
import bpy, bmesh, sys, math, random
from mathutils import Vector, noise

argv = sys.argv[sys.argv.index("--") + 1:]
outdir = argv[0]


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for c in (bpy.data.meshes, bpy.data.materials):
        for x in list(c):
            c.remove(x)


def mat(name, rgb, rough=0.8, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 1.0
    return m


def active(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def apply_scale(o):
    active(o)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def apply_mod(o, m):
    active(o)
    bpy.ops.object.modifier_apply(modifier=m.name)


def setmat(o, m, smooth=True):
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def ico(r, loc, scale=(1, 1, 1), sub=3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    apply_scale(o)
    return o


def join(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def displace(o, amp, freq, seed):
    off = Vector((seed * 1.31, seed * 2.17, seed * 0.73))
    for v in o.data.vertices:
        n = noise.noise(v.co * freq + off)
        v.co += v.normal * n * amp


def remesh(o, voxel):
    m = o.modifiers.new("rm", 'REMESH')
    m.mode = 'VOXEL'
    m.voxel_size = voxel
    apply_mod(o, m)


def smooth_mod(o, it, f=0.6):
    m = o.modifiers.new("sm", 'SMOOTH')
    m.iterations = it
    m.factor = f
    apply_mod(o, m)


def decimate(o, ratio):
    m = o.modifiers.new("dc", 'DECIMATE')
    m.ratio = ratio
    apply_mod(o, m)


def bevel(o, width, segments=1):
    m = o.modifiers.new("bv", 'BEVEL')
    m.width = width
    m.segments = segments
    m.limit_method = 'ANGLE'
    apply_mod(o, m)


def cut_below(o, z):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(o.data)
    bm.free()


def hull(points, name):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    ret = bmesh.ops.convex_hull(bm, input=bm.verts)
    junk = list({g for g in ret["geom_interior"] + ret["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def tube(path, radii, sides, name, twist=0.0, cap=True):
    """沿著一串點掃出一條管子（path: [Vector]，radii: 每個點的半徑）"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    n = len(path)
    for i, p in enumerate(path):
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        ref = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 1, 0))
        a = t.cross(ref).normalized()
        b = t.cross(a).normalized()
        ring = []
        for k in range(sides):
            ang = k * math.tau / sides + twist * i
            ring.append(bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * radii[i]))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]])
    if cap:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def export(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=outdir + "/" + name + ".glb", export_format='GLB', export_yup=True, export_apply=True)
    print("EXPORTED", name)


def blob(parts, voxel, smooth_it, seed, amp, m, name, cut=None, ratio=0.35, freq=1.3):
    """幾顆壓扁的球黏在一起 → 重新包成一顆 → 抹平：圓滾滾、不規則的一坨（雪堆、雲）"""
    objs = [ico(1.0, loc, sc) for loc, sc in parts]
    o = join(objs)
    remesh(o, voxel)
    displace(o, amp, freq, seed)
    smooth_mod(o, smooth_it)
    if cut is not None:
        cut_below(o, cut)
    decimate(o, ratio)
    o.name = name
    return setmat(o, m, True)


# ------------------------------------------------------------------ 雪堆（4 種，底部埋進地裡）
def build_drifts():
    specs = {
        "a": [((0, 0, 0.05), (1.25, 0.8, 0.42)), ((0.8, 0.25, 0.0), (0.7, 0.55, 0.30)), ((-0.75, -0.2, 0.0), (0.6, 0.5, 0.26))],
        "b": [((0, 0, 0.0), (0.85, 0.75, 0.50)), ((0.55, -0.35, -0.02), (0.5, 0.45, 0.30))],
        "c": [((-0.9, 0, 0.0), (0.8, 0.55, 0.30)), ((0.0, 0.15, 0.04), (0.9, 0.6, 0.40)), ((0.95, -0.05, 0.0), (0.75, 0.5, 0.27)), ((1.75, 0.1, -0.03), (0.5, 0.4, 0.2))],
        "d": [((0, 0, 0.0), (0.6, 0.55, 0.33)), ((0.3, 0.4, -0.02), (0.4, 0.35, 0.22)), ((-0.35, 0.3, -0.03), (0.35, 0.33, 0.2))],
    }
    for i, (k, parts) in enumerate(specs.items()):
        clear()
        snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
        blob(parts, 0.07, 10, 3.0 + i * 5.1, 0.07, snow, "Drift", cut=-0.12, ratio=0.22)
        export("snow_drift_" + k)


# ------------------------------------------------------------------ 碎冰塊（切面的、有倒角）
def build_ice_chunks():
    rnd = random.Random(77)
    specs = {
        "a": (0.55, 0.40, 0.30, 9),     # 塊
        "b": (0.75, 0.50, 0.16, 8),     # 板
        "c": (0.42, 0.34, 0.26, 9),     # 厚一點的
        "d": (0.95, 0.60, 0.20, 10),    # 大板
        "e": (0.35, 0.30, 0.22, 7),     # 小碎塊
    }
    for k, (sx, sy, sz, n) in specs.items():
        clear()
        ice = mat("ice", (0.62, 0.88, 0.98), 0.15)
        pts = []
        for _ in range(n):
            pts.append((rnd.uniform(-sx, sx), rnd.uniform(-sy, sy), rnd.uniform(0.0, sz * 2.0)))
        # 底面多放幾個點：站得穩
        for _ in range(4):
            pts.append((rnd.uniform(-sx, sx) * 0.9, rnd.uniform(-sy, sy) * 0.9, -0.06))
        o = hull(pts, "IceChunk")
        bevel(o, 0.035)
        setmat(o, ice, False)
        export("ice_chunk_" + k)


# ------------------------------------------------------------------ 冰柱（從上往下掛，原點在頂端）
def build_icicles():
    rnd = random.Random(5)
    for k, count in (("a", 4), ("b", 6), ("c", 2)):
        clear()
        ice = mat("ice", (0.70, 0.92, 1.0), 0.12)
        objs = []
        for i in range(count):
            L = rnd.uniform(0.5, 1.5) * (1.3 if i == 0 else 1.0)
            r0 = 0.07 + L * 0.07
            cx = rnd.uniform(-0.55, 0.55) * (count / 4.0)
            cy = rnd.uniform(-0.12, 0.12)
            bend = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 0))
            path = []
            radii = []
            for s in range(6):
                t = s / 5.0
                path.append(Vector((cx, cy, -L * t)) + bend * t * t)
                radii.append(max(r0 * (1.0 - t) ** 0.85 * (1.0 + 0.12 * math.sin(t * 9.0 + i)), 0.004))
            objs.append(tube(path, radii, 7, "Icicle", cap=True))
        # 頂端一坨冰把幾根連在一起
        top = ico(1.0, (0, 0, 0.02), (0.5 * count / 4.0 + 0.2, 0.2, 0.09), 2)
        objs.append(top)
        o = join(objs)
        o.name = "Icicles"
        setmat(o, ice, True)
        export("icicles_" + k)


# ------------------------------------------------------------------ 火焰（外焰＋內焰，水滴形、扭一下）
def build_flame():
    clear()
    outer = mat("flame_outer", (1.0, 0.45, 0.08), 0.5, emit=(1.0, 0.45, 0.08))
    inner = mat("flame_inner", (1.0, 0.85, 0.3), 0.5, emit=(1.0, 0.85, 0.3))
    prof = [(0.0, 0.0), (0.20, 0.06), (0.30, 0.22), (0.27, 0.42), (0.17, 0.66), (0.08, 0.86), (0.0, 1.08)]
    for nm, sc, m, lean in (("FlameOuter", 1.0, outer, 0.10), ("FlameInner", 0.58, inner, -0.06)):
        path = [Vector((lean * (z ** 2), 0.04 * math.sin(z * 5.0), z * sc)) for r, z in prof]
        radii = [max(r * sc, 0.003) for r, z in prof]
        o = tube(path, radii, 9, nm, twist=0.35, cap=False)
        setmat(o, m, True)
    export("flame")


# ------------------------------------------------------------------ 雲朵（3 種，底部比較平）
def build_clouds():
    rnd = random.Random(8)
    for i, k in enumerate(("a", "b", "c")):
        clear()
        cloud = mat("cloud", (1.0, 1.0, 1.0), 1.0)
        parts = []
        n = 5 + i * 2
        for j in range(n):
            x = (j - (n - 1) / 2.0) * 1.25 + rnd.uniform(-0.3, 0.3)
            r = rnd.uniform(0.9, 1.7) * (1.0 - 0.35 * abs(j - (n - 1) / 2.0) / n * 2.0)
            parts.append(((x, rnd.uniform(-0.5, 0.5), r * 0.55), (r * 1.15, r, r * 0.85)))
        o = blob(parts, 0.22, 8, 11.0 + i * 3.0, 0.10, cloud, "Cloud", ratio=0.30, freq=0.6)
        for v in o.data.vertices:
            if v.co.z < 0.35:
                v.co.z = 0.35 - (0.35 - v.co.z) * 0.35     # 底部壓平一點
        export("cloud_puff_" + k)


# ------------------------------------------------------------------ 釣竿（插在冰洞邊，竿尖朝 Godot 的 +Z，垂一條線到水面的浮標）
def build_rod():
    clear()
    wood = mat("wood", (0.55, 0.36, 0.20), 0.8)
    line = mat("line", (0.95, 0.95, 0.95), 0.6)
    red = mat("red", (0.92, 0.16, 0.14), 0.5)
    white = mat("white", (0.97, 0.97, 0.97), 0.5)
    path = []
    radii = []
    for s in range(9):
        t = s / 8.0
        # 從地面斜斜往前上方，尾段被魚線拉彎
        path.append(Vector((0, -1.25 * t, 0.05 + 1.25 * t - 0.42 * t * t * t)))
        radii.append(0.034 - 0.024 * t)
    rod = tube(path, radii, 6, "Rod")
    setmat(rod, wood, True)
    tip = path[-1]
    ln = tube([tip, Vector((tip.x, tip.y, -0.30))], [0.006, 0.006], 4, "Line")
    setmat(ln, line, True)
    # Y 形支架
    a = tube([Vector((0, -0.42, -0.1)), Vector((0, -0.42, 0.40))], [0.03, 0.024], 6, "Stand")
    b = tube([Vector((0, -0.42, 0.38)), Vector((0.10, -0.42, 0.56))], [0.022, 0.016], 6, "StandL")
    c = tube([Vector((0, -0.42, 0.38)), Vector((-0.10, -0.42, 0.56))], [0.022, 0.016], 6, "StandR")
    for o in (a, b, c):
        setmat(o, wood, True)
    # 捲線器
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.06, depth=0.05, location=(0.05, -0.22, 0.27), rotation=(0, math.pi / 2, 0))
    reel = bpy.context.object
    reel.name = "Reel"
    setmat(reel, red, True)
    # 浮標：上紅下白
    for nm, z, m in (("BobTop", -0.20, red), ("BobLow", -0.26, white)):
        f = ico(0.07, (tip.x, tip.y, z), (1, 1, 0.8), 2)
        f.name = nm
        setmat(f, m, True)
    export("fishing_rod")


# ------------------------------------------------------------------ 冰台座（冰雕底下的冰塊，上面一層雪）
def build_pedestal():
    clear()
    rnd = random.Random(3)
    ice = mat("ice", (0.62, 0.88, 0.98), 0.15)
    snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.25))
    o = bpy.context.object
    o.scale = (1.05, 1.05, 0.6)
    apply_scale(o)
    for v in o.data.vertices:
        v.co.x += rnd.uniform(-0.05, 0.05)
        v.co.y += rnd.uniform(-0.05, 0.05)
        if v.co.z > 0.3:
            v.co.x *= 0.9
            v.co.y *= 0.9
    bevel(o, 0.07, 1)
    o.name = "IceBlock"
    setmat(o, ice, False)
    blob([((0, 0, 0.55), (0.52, 0.52, 0.10)), ((0.25, 0.3, 0.53), (0.3, 0.26, 0.09)), ((-0.35, -0.3, 0.52), (0.25, 0.25, 0.08))], 0.045, 8, 9.0, 0.02, snow, "BlockSnow", ratio=0.3)
    export("ice_pedestal")



# ------------------------------------------------------------------ 冰洞口（半徑 1 = 冰洞的半徑；Godot 裡 x、z 放大成實際半徑）
# 一圈被敲破的冰：內緣參差不齊、稍微翹起來，往下是一圈看得到厚度的冰壁；上面黏著幾塊碎冰；洞裡一片水面。
def build_hole_rims():
    for vi, k in enumerate(("a", "b")):
        clear()
        rnd = random.Random(40 + vi * 7)
        ice = mat("ice", (0.80, 0.95, 1.0), 0.2)
        wall = mat("ice_wall", (0.20, 0.70, 0.90), 0.15)
        water = mat("water", (0.03, 0.2, 0.3), 0.1)
        n = 44
        r_in, r_out, lift = [], [], []
        for i in range(n):
            a = i * math.tau / n
            jag = rnd.uniform(-0.035, 0.05) + (0.05 if i % 5 == 0 else 0.0) * rnd.uniform(-1.0, 1.0)
            r_in.append(1.0 + 0.035 * math.sin(3 * a + vi) + 0.025 * math.sin(7 * a + vi * 2.0) + jag)
            r_out.append(1.33 + 0.05 * math.sin(4 * a + vi * 1.3) + rnd.uniform(-0.035, 0.035))
            lift.append(rnd.uniform(0.035, 0.085))
        me = bpy.data.meshes.new("HoleRim")
        bm = bmesh.new()
        ring_wall_low, ring_in, ring_mid, ring_out = [], [], [], []
        for i in range(n):
            a = i * math.tau / n
            cx, sy = math.cos(a), math.sin(a)
            ring_wall_low.append(bm.verts.new(((r_in[i] + 0.10) * cx, (r_in[i] + 0.10) * sy, -0.34)))
            ring_in.append(bm.verts.new((r_in[i] * cx, r_in[i] * sy, lift[i])))
            rm = (r_in[i] + r_out[i]) * 0.5 + rnd.uniform(-0.03, 0.03)
            ring_mid.append(bm.verts.new((rm * cx, rm * sy, 0.03 + rnd.uniform(-0.008, 0.012))))
            ring_out.append(bm.verts.new((r_out[i] * cx, r_out[i] * sy, -0.012)))
        wall_faces, top_faces = [], []
        for i in range(n):
            j = (i + 1) % n
            wall_faces.append(bm.faces.new([ring_wall_low[i], ring_in[i], ring_in[j], ring_wall_low[j]]))
            top_faces.append(bm.faces.new([ring_in[i], ring_mid[i], ring_mid[j], ring_in[j]]))
            top_faces.append(bm.faces.new([ring_mid[i], ring_out[i], ring_out[j], ring_mid[j]]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("HoleRim", me)
        bpy.context.collection.objects.link(o)
        o.data.materials.append(ice)
        o.data.materials.append(wall)
        # 面的順序：每段 [壁, 頂, 頂]
        for pi, poly in enumerate(o.data.polygons):
            poly.material_index = 1 if pi % 3 == 0 else 0
            poly.use_smooth = False
        # 法線朝外（壁朝洞心、頂朝上）：用中心點檢查一下，反了就整個翻面
        up = sum(1 for poly in o.data.polygons if poly.material_index == 0 and poly.normal.z > 0)
        if up < n:
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
            bm.to_mesh(o.data)
            bm.free()
        # 黏在洞口上的碎冰（矮矮的，不擋洞裡的人）
        for _ in range(7):
            a = rnd.uniform(0, math.tau)
            rr = rnd.uniform(1.10, 1.30)
            sx, sy2, sz = rnd.uniform(0.09, 0.2), rnd.uniform(0.07, 0.14), rnd.uniform(0.05, 0.16)
            pts = [(rnd.uniform(-sx, sx), rnd.uniform(-sy2, sy2), rnd.uniform(0.0, sz * 2.0)) for _p in range(8)]
            pts += [(rnd.uniform(-sx, sx), rnd.uniform(-sy2, sy2), -0.02) for _p in range(3)]
            ch = hull(pts, "Shard")
            bevel(ch, 0.012)
            ch.location = (rr * math.cos(a), rr * math.sin(a), 0.02)
            ch.rotation_euler = (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, math.tau))
            setmat(ch, ice, False)
        # 水面
        bpy.ops.mesh.primitive_circle_add(vertices=40, radius=1.22, fill_type='TRIFAN', location=(0, 0, -0.26))
        w = bpy.context.object
        w.name = "Water"
        setmat(w, water, True)
        export("ice_hole_rim_" + k)


# ------------------------------------------------------------------ 薄冰片（半徑 1；比較白、有放射狀的裂痕）
def build_thin_ice():
    clear()
    rnd = random.Random(12)
    thin = mat("thin_ice", (0.90, 0.97, 1.0), 0.3, emit=(0.10, 0.17, 0.22))
    crack = mat("crack", (0.22, 0.45, 0.65), 0.6, emit=(0.10, 0.22, 0.32))
    n = 20
    me = bpy.data.meshes.new("ThinIce")
    bm = bmesh.new()
    top = [bm.verts.new((math.cos(i * math.tau / n) * (1.0 + rnd.uniform(-0.05, 0.05)), math.sin(i * math.tau / n) * (1.0 + rnd.uniform(-0.05, 0.05)), 0.035)) for i in range(n)]
    low = [bm.verts.new((v.co.x * 1.03, v.co.y * 1.03, 0.0)) for v in top]
    bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([low[i], low[j], top[j], top[i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    plate = bpy.data.objects.new("ThinIce", me)
    bpy.context.collection.objects.link(plate)
    setmat(plate, thin, False)

    def strip(points, width, name):
        """沿著折線鋪一條細帶（裂痕），貼在冰片上面一點點"""
        m2 = bpy.data.meshes.new(name)
        b2 = bmesh.new()
        prev = None
        for i, p in enumerate(points):
            d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
            side = Vector((-d.y, d.x, 0)) * width * (1.0 - 0.6 * i / (len(points) - 1))
            a = b2.verts.new(p + side)
            b = b2.verts.new(p - side)
            if prev:
                b2.faces.new([prev[0], prev[1], b, a])
            prev = (a, b)
        bmesh.ops.recalc_face_normals(b2, faces=b2.faces)
        b2.to_mesh(m2)
        b2.free()
        ob = bpy.data.objects.new(name, m2)
        bpy.context.collection.objects.link(ob)
        setmat(ob, crack, False)
        for poly in ob.data.polygons:
            if poly.normal.z < 0:
                poly.flip()
        return ob

    for k in range(7):
        a = k * math.tau / 7 + rnd.uniform(-0.25, 0.25)
        ln = rnd.uniform(0.55, 0.92)
        pts = []
        for s2 in range(5):
            t = s2 / 4.0
            off = rnd.uniform(-0.06, 0.06) if 0 < s2 < 4 else 0.0
            pts.append(Vector((math.cos(a) * ln * t - math.sin(a) * off, math.sin(a) * ln * t + math.cos(a) * off, 0.04)))
        strip(pts, 0.022, "Crack%d" % k)
        if k % 2 == 0:
            # 岔出去的小裂痕
            base = pts[2]
            a2 = a + rnd.choice((-1, 1)) * rnd.uniform(0.6, 1.0)
            strip([base, base + Vector((math.cos(a2), math.sin(a2), 0)) * 0.18, base + Vector((math.cos(a2 + 0.3), math.sin(a2 + 0.3), 0)) * 0.34], 0.014, "Branch%d" % k)
    export("thin_ice")


# ------------------------------------------------------------------ 浮冰（海上漂的：不規則的厚冰板，上面一層雪；原點在水面）
def build_floes():
    for vi, (k, size, count) in enumerate((("a", 2.6, 1), ("b", 1.8, 1), ("c", 1.0, 3))):
        clear()
        rnd = random.Random(60 + vi * 3)
        ice = mat("ice", (0.62, 0.88, 0.98), 0.15)
        snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
        for c in range(count):
            ox, oy = (0.0, 0.0) if count == 1 else (rnd.uniform(-1.6, 1.6), rnd.uniform(-1.4, 1.4))
            sz = size * (1.0 if count == 1 else rnd.uniform(0.7, 1.1))
            n = rnd.randint(7, 9)
            pts = []
            for i in range(n):
                a = i * math.tau / n + rnd.uniform(-0.2, 0.2)
                r = sz * rnd.uniform(0.72, 1.0)
                pts.append((ox + math.cos(a) * r, oy + math.sin(a) * r * 0.82, 0.30 + rnd.uniform(-0.04, 0.06)))
                pts.append((ox + math.cos(a) * r * 0.86, oy + math.sin(a) * r * 0.70, -0.55))
            o = hull(pts, "Floe%d" % c)
            bevel(o, 0.07)
            setmat(o, ice, False)
            cap = blob([((ox, oy, 0.30), (sz * 0.72, sz * 0.58, 0.16)), ((ox + sz * 0.2, oy - sz * 0.1, 0.33), (sz * 0.4, sz * 0.36, 0.14))], 0.06 if sz > 1.5 else 0.045, 8, 20.0 + vi + c, 0.03, snow, "FloeSnow%d" % c, cut=0.0, ratio=0.3)     # cut 是相對第一顆球的中心（z = 0.30）
        export("ice_floe_" + k)



# ================================================================== 第四輪：主要道具（雪人、企鵝籠）、石頭、地標
def empty(name, loc=(0, 0, 0), parent=None):
    bpy.ops.object.empty_add(location=loc)
    o = bpy.context.object
    o.name = name
    if parent:
        adopt(o, parent)
    return o


def adopt(o, parent):
    """掛到 parent 底下，保留原本的世界座標"""
    bpy.context.view_layer.update()
    o.parent = parent
    o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o


def ball(r, loc, squash, m, name, parent=None, seed=1.0, amp=0.012, sub=3):
    """圓滾滾、稍微壓扁、表面有一點手捏感的球（平滑著色）。原點在球心"""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.object
    for v in o.data.vertices:
        v.co.z *= squash
    if amp > 0.0:
        displace(o, amp, 2.2 / r * 0.3, seed)
    o.name = name
    setmat(o, m, True)
    if parent:
        adopt(o, parent)
    return o


def beam(size, loc, m, name, parent=None, rot=(0, 0, 0), bev=0.03, rnd=None, jit=0.012):
    """粗粗的木條：邊角倒圓、稍微歪一點。原點在中心"""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    active(o)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rnd:
        for v in o.data.vertices:
            v.co.x += rnd.uniform(-jit, jit)
            v.co.y += rnd.uniform(-jit, jit)
            v.co.z += rnd.uniform(-jit, jit)
    bevel(o, bev, 2)
    o.name = name
    setmat(o, m, True)
    for poly in o.data.polygons:
        poly.use_smooth = True
    if parent:
        adopt(o, parent)
    return o


def local_blob(parts, voxel, smooth_it, seed, amp, m, name, ratio=0.35, freq=1.3):
    """跟 blob() 一樣，但座標留在世界座標（原點在 0,0,0），好跟別的零件對位置"""
    o = blob(parts, voxel, smooth_it, seed, amp, m, name, ratio=ratio, freq=freq)
    active(o)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o


# ------------------------------------------------------------------ 雪人：Body（兩顆雪球＋圍巾＋樹枝手＋扣子）和 Head（頭＋紅蘿蔔＋煤炭眼＋水桶帽）分開
# Head 的原點在頭的球心（戰局會把 Head 整個拿起來、放大、扣到工人頭上）。水桶帽跟著頭走，戴在誰頭上都認得出是雪人。
def build_snowman():
    clear()
    rnd = random.Random(21)
    snow = mat("snowman", (0.96, 0.98, 1.0), 0.95)
    coal = mat("coal", (0.07, 0.07, 0.09), 0.6)
    carrot = mat("carrot", (1.0, 0.42, 0.06), 0.7)
    scarf = mat("scarf", (0.88, 0.14, 0.16), 0.85)
    stripe = mat("scarf_stripe", (0.98, 0.93, 0.85), 0.85)
    stick = mat("stick", (0.40, 0.25, 0.14), 0.9)
    tin = mat("bucket", (0.86, 0.20, 0.18), 0.5)             # 紅色的搪瓷水桶（跟圍巾同色；夜裡也跟雪分得開）
    tin_dark = mat("bucket_dark", (0.60, 0.12, 0.12), 0.5)
    root = empty("Snowman")
    body = empty("Body", parent=root)
    ball(0.60, (0, 0, 0.47), 0.84, snow, "BallLow", body, 3.0)
    ball(0.44, (0, 0, 1.12), 0.88, snow, "BallMid", body, 7.0)
    for i, z in enumerate((0.98, 1.14, 1.28)):
        ball(0.05, (0, -0.42 + abs(z - 1.12) * 0.22, z), 1.0, coal, "Button%d" % i, body, amp=0.0, sub=2)
    # 圍巾：脖子上一圈＋垂下來的兩條尾巴（尾端有白條紋）
    bpy.ops.mesh.primitive_torus_add(major_radius=0.30, minor_radius=0.085, location=(0, 0, 1.43), major_segments=20, minor_segments=8)
    ring = bpy.context.object
    ring.scale = (1.0, 1.0, 0.8)
    apply_scale(ring)
    ring.name = "Scarf"
    setmat(ring, scarf, True)
    adopt(ring, body)
    tails = []
    for k, (x0, lean, ln) in enumerate(((0.20, 0.10, 0.50), (0.07, -0.05, 0.38))):
        t = beam((0.15, 0.06, ln), (x0 + lean * 0.5, -0.36 - k * 0.03, 1.40 - ln * 0.5), scarf, "T%d" % k, None, rot=(0.22, lean * 0.6, 0.0), bev=0.02)
        e = beam((0.155, 0.065, 0.07), (x0 + lean * 0.93, -0.36 - k * 0.03 - ln * 0.105, 1.40 - ln * 0.93), stripe, "E%d" % k, None, rot=(0.22, lean * 0.6, 0.0), bev=0.02)
        tails += [t, e]
    tail = join(tails)
    tail.name = "ScarfTail"
    adopt(tail, body)
    # 樹枝手（末端分岔）
    for sgn, nm in ((1, "ArmR"), (-1, "ArmL")):
        a = tube([Vector((sgn * 0.34, 0, 1.18)), Vector((sgn * 0.70, -0.02, 1.38)), Vector((sgn * 0.98, 0.0, 1.62))], [0.035, 0.028, 0.018], 6, nm)
        b = tube([Vector((sgn * 0.78, -0.02, 1.44)), Vector((sgn * 0.96, -0.08, 1.40))], [0.022, 0.012], 5, nm + "b")
        c = tube([Vector((sgn * 0.86, -0.01, 1.51)), Vector((sgn * 0.90, 0.10, 1.66))], [0.02, 0.011], 5, nm + "c")
        arm = join([a, b, c])
        arm.name = nm
        setmat(arm, stick, True)
        adopt(arm, body)
    # 頭
    head = empty("Head", (0, 0, 1.68), root)
    ball(0.31, (0, 0, 1.68), 0.94, snow, "HeadBall", head, 11.0)
    nose = tube([Vector((0, -0.24, 1.665)), Vector((0, -0.42, 1.66)), Vector((0, -0.62, 1.645)), Vector((0.01, -0.80, 1.63))], [0.082, 0.070, 0.045, 0.006], 10, "Nose")
    setmat(nose, carrot, True)
    adopt(nose, head)
    for x in (-0.115, 0.115):
        ball(0.052, (x, -0.262, 1.775), 1.0, coal, "Eye", head, amp=0.0, sub=2)
    for k in range(5):
        a = math.radians(-52 + k * 26)
        ball(0.028, (math.sin(a) * 0.15, -0.262 - 0.02 * math.cos(a), 1.565 - math.cos(a) * 0.035), 1.0, coal, "Mouth", head, amp=0.0, sub=1)
    # 水桶帽：倒扣在頭上、歪一邊
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.255, radius2=0.19, depth=0.30, location=(0.03, 0.03, 2.03), rotation=(math.radians(-10), math.radians(12), 0))
    bucket = bpy.context.object
    bevel(bucket, 0.025, 2)
    bucket.name = "Bucket"
    setmat(bucket, tin, True)
    adopt(bucket, head)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.258, minor_radius=0.03, location=(0.0, 0.055, 1.885), rotation=(math.radians(-10), math.radians(12), 0), major_segments=18, minor_segments=6)
    rim = bpy.context.object
    rim.name = "BucketRim"
    setmat(rim, tin_dark, True)
    adopt(rim, head)
    export("snowman")


# ------------------------------------------------------------------ 企鵝籠：粗木條釘的籠子，屋頂一坨軟雪，門上掛一個大鎖
# Door（正面整片門：門框＋三根木條＋鎖）的轉軸在左前角；Lock、Shackle 是 Door 底下各自獨立的節點（原點在自己中心），開籠時會掉到地上。
def build_cage():
    clear()
    rnd = random.Random(33)
    wood = mat("wood", (0.74, 0.50, 0.29), 0.85)
    wood_dark = mat("wood_dark", (0.52, 0.33, 0.19), 0.9)
    snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
    gold = mat("gold", (1.0, 0.76, 0.16), 0.4)
    gold_dark = mat("gold_dark", (0.70, 0.46, 0.08), 0.5)
    steel = mat("steel", (0.62, 0.68, 0.76), 0.35)
    hay = mat("hay", (0.96, 0.80, 0.36), 0.95)
    W, D, H = 2.6, 2.0, 1.62
    root = empty("Cage")
    # 地板：五片厚木板
    for i in range(5):
        x = -W / 2 + (i + 0.5) * (W + 0.2) / 5 - 0.1
        beam(((W + 0.2) / 5 - 0.03, D + 0.24, 0.17), (x, 0, 0.085 + rnd.uniform(-0.01, 0.01)), wood if i % 2 == 0 else wood_dark, "Floor%d" % i, root, rnd=rnd)
    # 四根角柱
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam((0.24, 0.24, H + 0.06), (sx * W / 2, sy * D / 2, (H + 0.06) / 2), wood_dark, "Post", root, rot=(rnd.uniform(-0.02, 0.02), rnd.uniform(-0.02, 0.02), 0), bev=0.045, rnd=rnd)
    # 上面一圈橫樑
    beam((W + 0.36, 0.2, 0.2), (0, -D / 2, H), wood_dark, "BeamFront", root, bev=0.04, rnd=rnd)
    beam((W + 0.36, 0.2, 0.2), (0, D / 2, H), wood_dark, "BeamBack", root, bev=0.04, rnd=rnd)
    for sx in (-1, 1):
        beam((0.2, D + 0.1, 0.2), (sx * W / 2, 0, H), wood_dark, "BeamSide", root, bev=0.04, rnd=rnd)
    # 屋頂：四片木板＋厚厚一坨雪（前緣垂下幾坨）
    for i in range(4):
        y = -D / 2 - 0.12 + (i + 0.5) * (D + 0.30) / 4
        beam((W + 0.5, (D + 0.30) / 4 - 0.02, 0.12), (rnd.uniform(-0.03, 0.03), y, H + 0.16), wood if i % 2 else wood_dark, "Roof%d" % i, root, rnd=rnd)
    parts = [((0, 0.05, H + 0.30), (1.42, 1.05, 0.17)), ((0.45, -0.25, H + 0.38), (0.85, 0.70, 0.20)), ((-0.55, 0.30, H + 0.36), (0.75, 0.62, 0.18))]
    for x in (-1.15, -0.55, 0.1, 0.62, 1.2):
        parts.append(((x, -D / 2 - 0.20, H + 0.16 - rnd.uniform(0.0, 0.07)), (0.26, 0.15, rnd.uniform(0.12, 0.2))))
    cap = local_blob(parts, 0.055, 9, 5.0, 0.03, snow, "RoofSnow", ratio=0.3)
    adopt(cap, root)
    # 後面和兩側：粗木條
    for i in range(6):
        x = -W / 2 + 0.30 + i * (W - 0.6) / 5
        beam((0.12, 0.12, H - 0.16), (x, D / 2, H / 2 + 0.02), wood, "BarBack", root, rot=(0, rnd.uniform(-0.03, 0.03), 0), rnd=rnd)
    for sx in (-1, 1):
        for i in range(4):
            y = -D / 2 + 0.36 + i * (D - 0.72) / 3
            beam((0.12, 0.12, H - 0.16), (sx * W / 2, y, H / 2 + 0.02), wood, "BarSide", root, rot=(rnd.uniform(-0.03, 0.03), 0, 0), rnd=rnd)
    # 地上一坨乾草
    h = local_blob([((0.1, 0.2, 0.22), (0.95, 0.6, 0.10)), ((-0.5, -0.1, 0.22), (0.55, 0.45, 0.09))], 0.05, 6, 9.0, 0.03, hay, "Hay", ratio=0.3)
    adopt(h, root)
    # 門：門框＋三根木條（間隔寬，看得到裡面的企鵝）
    door = empty("Door", (-W / 2, -D / 2, 0), root)
    x0, x1 = -W / 2 + 0.20, W / 2 - 0.20
    for x in (x0, x1):
        beam((0.15, 0.13, H - 0.34), (x, -D / 2, H / 2 - 0.02), wood_dark, "DoorStile", door, bev=0.035, rnd=rnd)
    beam((x1 - x0 + 0.15, 0.13, 0.15), (0, -D / 2, 0.30), wood_dark, "DoorRailLow", door, bev=0.035, rnd=rnd)
    beam((x1 - x0 + 0.15, 0.13, 0.15), (0, -D / 2, H - 0.26), wood_dark, "DoorRailHigh", door, bev=0.035, rnd=rnd)
    for i in range(3):
        x = x0 + (i + 1) * (x1 - x0) / 4
        beam((0.11, 0.10, H - 0.60), (x, -D / 2, H / 2 + 0.02), wood, "DoorBar", door, rot=(0, rnd.uniform(-0.03, 0.03), 0), rnd=rnd)
    # 大鎖：金色鎖頭（有鑰匙孔）＋粗粗的 U 形鎖環
    lx, ly, lz = x1 - 0.02, -D / 2 - 0.14, 0.78
    lock = beam((0.36, 0.15, 0.32), (0, 0, 0), gold, "LockBody", None, bev=0.05)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.05, depth=0.03, location=(0, -0.078, 0.03), rotation=(math.radians(90), 0, 0))
    k1 = bpy.context.object
    setmat(k1, gold_dark, True)
    k2 = beam((0.04, 0.03, 0.10), (0, -0.078, -0.05), gold_dark, "Key2", None, bev=0.008)
    lock = join([lock, k1, k2])
    lock.name = "Lock"
    lock.location = (lx, ly, lz)
    adopt(lock, door)
    path = []
    for k in range(9):
        a = math.pi * k / 8.0
        path.append(Vector((-math.cos(a) * 0.105, 0, math.sin(a) * 0.12)))
    path = [Vector((-0.105, 0, -0.14))] + path + [Vector((0.105, 0, -0.14))]
    sh = tube(path, [0.036] * len(path), 8, "Shackle")
    setmat(sh, steel, True)
    sh.location = (lx, ly, lz + 0.27)
    adopt(sh, door)
    export("cage")


# ------------------------------------------------------------------ 石頭（深色、圓鈍的大石，頭上一坨雪）
def build_boulders():
    for vi, (k, n, sx, sy, sz) in enumerate((("a", 1, 0.95, 0.8, 0.75), ("b", 3, 0.6, 0.55, 0.5))):
        clear()
        rnd = random.Random(70 + vi)
        rock = mat("boulder", (0.34, 0.40, 0.56), 0.9)
        snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
        for c in range(n):
            ox, oy = (0.0, 0.0) if n == 1 else (math.cos(c * 2.1) * 0.75, math.sin(c * 2.1) * 0.62)
            sc = 1.0 if c == 0 else rnd.uniform(0.55, 0.85)
            pts = []
            for _ in range(22):
                v = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized() * rnd.uniform(0.82, 1.0)
                pts.append((ox + v.x * sx * sc, oy + v.y * sy * sc, max(v.z, -0.25) * sz * sc + sz * sc * 0.45))
            o = hull(pts, "Boulder%d" % c)
            bevel(o, 0.09 * sc, 2)
            setmat(o, rock, True)
            for poly in o.data.polygons:
                poly.use_smooth = True
            top = sz * sc * 1.32
            local_blob([((ox, oy, top), (sx * sc * 0.78, sy * sc * 0.74, 0.20 * sc)), ((ox + 0.2 * sc, oy - 0.2 * sc, top - 0.08), (sx * sc * 0.5, sy * sc * 0.5, 0.2 * sc))], 0.05, 8, 30.0 + c, 0.02, snow, "BoulderSnow%d" % c, ratio=0.3)
        export("snow_rock_" + k)


# ------------------------------------------------------------------ 小木船（第 9 關漁村的地標：拖上岸的漁船）
def build_boat():
    clear()
    red = mat("boat_red", (0.86, 0.22, 0.18), 0.7)
    white = mat("boat_white", (0.97, 0.95, 0.90), 0.7)
    wood = mat("wood", (0.74, 0.50, 0.29), 0.85)
    wood_dark = mat("wood_dark", (0.52, 0.33, 0.19), 0.9)

    def stations(scale_w, z_top, z_low):
        pts = []
        for j in range(11):
            y = -1.7 + 3.4 * j / 10.0
            w = (0.68 * max(1.0 - abs(y / 1.72) ** 2.4, 0.0) ** 0.55 + 0.02) * scale_w
            lift = 0.22 * abs(y / 1.7) ** 2.0                    # 船頭船尾翹起來
            for px, pz in ((-1.0, z_top), (-0.9, 0.28), (-0.55, z_low), (0.55, z_low), (0.9, 0.28), (1.0, z_top)):
                pts.append((px * w, y * (0.985 if scale_w < 1.0 else 1.0), pz + lift * (1.0 if pz > 0.2 else 0.5)))
        return pts

    # 船身：一整塊圓鈍的實心船殼（下半白、上面一圈紅），上面嵌一片木頭甲板和兩塊座板
    hull_o = hull(stations(1.0, 0.58, 0.0), "Hull")
    bevel(hull_o, 0.03, 2)
    hull_o.data.materials.append(white)
    hull_o.data.materials.append(red)
    for poly in hull_o.data.polygons:
        poly.material_index = 1 if poly.center.z > 0.34 else 0
        poly.use_smooth = True
    deck = hull([(x * 0.84, y * 0.9, 0.56 + 0.22 * abs(y / 1.7) ** 2.0 + dz) for (x, y, z) in stations(1.0, 0.58, 0.0) if z > 0.5 for dz in (0.0, 0.035)], "Deck")
    setmat(deck, wood, False)
    for y in (-0.55, 0.6):
        beam((1.0, 0.26, 0.09), (0, y, 0.66), wood_dark, "Seat", None, bev=0.02)
    # 兩支槳，橫放在船上
    for sgn in (-1, 1):
        o = tube([Vector((sgn * 0.32, -1.05, 0.74)), Vector((sgn * 0.42, 1.0, 0.76))], [0.03, 0.03], 6, "Oar")
        setmat(o, wood_dark, True)
        beam((0.16, 0.42, 0.05), (sgn * 0.44, 1.2, 0.765), wood_dark, "Blade", None, rot=(0, 0, sgn * -0.05), bev=0.02)
    export("rowboat")


# ------------------------------------------------------------------ 夜市攤位、一串燈籠（第 11 關燈籠夜市的地標）
def build_market():
    clear()
    rnd = random.Random(90)
    wood = mat("wood", (0.74, 0.50, 0.29), 0.85)
    wood_dark = mat("wood_dark", (0.52, 0.33, 0.19), 0.9)
    red = mat("cloth_red", (0.90, 0.22, 0.20), 0.8)
    cream = mat("cloth_cream", (0.99, 0.93, 0.80), 0.8)
    snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
    glow = mat("lantern_glow", (1.0, 0.62, 0.22), 0.6, emit=(1.0, 0.55, 0.18))
    glow2 = mat("lantern_glow_red", (1.0, 0.36, 0.22), 0.6, emit=(1.0, 0.30, 0.16))
    for sx in (-1, 1):
        beam((0.13, 0.13, 2.0), (sx * 1.0, -0.45, 1.0), wood_dark, "PostF", None, bev=0.03, rnd=rnd)
        beam((0.13, 0.13, 2.35), (sx * 1.0, 0.45, 1.175), wood_dark, "PostB", None, bev=0.03, rnd=rnd)
    beam((2.3, 0.85, 0.12), (0, -0.25, 0.92), wood, "Counter", None, bev=0.03, rnd=rnd)
    for i in range(4):
        beam((0.52, 0.07, 0.78), (-0.83 + i * 0.553, -0.62, 0.46), wood if i % 2 else wood_dark, "Front", None, bev=0.02, rnd=rnd)
    # 斜斜的條紋棚子（紅白相間），前緣一排小布條
    ang = math.atan2(0.38, 1.25)
    for i in range(6):
        x = -1.2 + (i + 0.5) * 0.4
        beam((0.40, 1.45, 0.05), (x, -0.08, 2.22), red if i % 2 == 0 else cream, "Awning", None, rot=(ang, 0, 0), bev=0.015)
        beam((0.40, 0.04, 0.22), (x, -0.78, 1.92), cream if i % 2 == 0 else red, "Valance", None, bev=0.015)
    local_blob([((0, 0.15, 2.36), (1.1, 0.5, 0.10)), ((0.5, -0.1, 2.30), (0.5, 0.4, 0.09))], 0.05, 8, 13.0, 0.02, snow, "AwningSnow", ratio=0.3)
    # 攤子上的貨：兩個木箱、一顆圓燈籠
    beam((0.42, 0.42, 0.32), (-0.65, -0.2, 1.14), wood_dark, "Box", None, rot=(0, 0, 0.3), bev=0.03)
    beam((0.34, 0.34, 0.26), (0.55, -0.25, 1.11), wood, "Box", None, rot=(0, 0, -0.2), bev=0.03)
    for x, m in ((-0.72, glow), (0.72, glow2)):
        ball(0.17, (x, -0.80, 1.60), 1.1, m, "Lamp", None, amp=0.0, sub=2)
        o = tube([Vector((x, -0.80, 1.80)), Vector((x, -0.78, 1.98))], [0.012, 0.012], 4, "Cord")
        setmat(o, wood_dark, True)
    export("market_stall")

    clear()
    wood_dark = mat("wood_dark", (0.52, 0.33, 0.19), 0.9)
    snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
    cols = [mat("lantern_glow", (1.0, 0.62, 0.22), 0.6, emit=(1.0, 0.55, 0.18)), mat("lantern_glow_red", (1.0, 0.36, 0.22), 0.6, emit=(1.0, 0.30, 0.16)),
            mat("lantern_glow_yellow", (1.0, 0.85, 0.36), 0.6, emit=(1.0, 0.78, 0.30))]
    half = 2.4
    for sx in (-1, 1):
        beam((0.14, 0.14, 2.9), (sx * half, 0, 1.45), wood_dark, "Pole", None, bev=0.035, rnd=rnd)
        local_blob([((sx * half, 0, 2.95), (0.16, 0.16, 0.08))], 0.035, 5, 3.0, 0.005, snow, "PoleSnow", ratio=0.4)
    path = []
    for k in range(13):
        t = k / 12.0
        path.append(Vector((-half + 2 * half * t, 0, 2.75 - 0.55 * 4.0 * t * (1.0 - t))))
    rope = tube(path, [0.02] * len(path), 5, "Rope")
    setmat(rope, wood_dark, True)
    for k in range(1, 12, 2):
        p = path[k]
        ball(0.20, (p.x, 0, p.z - 0.27), 1.12, cols[(k // 2) % 3], "Lantern", None, amp=0.0, sub=2)
        c = beam((0.12, 0.12, 0.05), (p.x, 0, p.z - 0.04), wood_dark, "Cap", None, bev=0.015)
        c2 = beam((0.10, 0.10, 0.04), (p.x, 0, p.z - 0.50), wood_dark, "Cap", None, bev=0.012)
    export("lantern_string")


build_drifts()
build_ice_chunks()
build_icicles()
build_flame()
build_clouds()
build_rod()
build_pedestal()
build_hole_rims()
build_thin_ice()
build_floes()
build_snowman()
build_cage()
build_boulders()
build_boat()
build_market()
