# 仙境丹穴山（levels/heaven）的模型（本組自製）：
#   機關：畫門 picture_gate、陸吾 luwu、香爐 censer（爐蓋可以拿下來）、石柱 pillar、雲堆 cloud_pile_a／b、雲洞口 cloud_rim
#   終點：南天門 sky_gate、唱盤 turntable、圓門 ring_gate、金環 gold_ring、結局的鳳凰金光 phoenix_light
#   場景：水墨松 pine_a／b、花樹 blossom、銀杏 ginkgo_a／b、山石 scholar_rock、亭子 pavilion、迴廊 corridor、樓閣 tower、
#         宮燈 palace_lantern、石碑 stele、欄杆柱 rail_post
#   Blender --background --factory-startup --python build_heaven_props.py -- <輸出資料夾>
# 材質名稱是給 Godot 換著色器用的：cloud（雲）、water（雲洞裡面）、painting（畫門裡的畫）、lantern_glow*（會發光）；其他的走卡通材質。
# Blender 是 Z 向上；匯出時轉成 Y 向上（Blender 的 -Y = Godot 的 +Z = 模型的正面）。
# 最前面這一段小工具跟冰雪島的 build_isle_props.py 是同一套。
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



def frustum(r1, r2, depth, z0, m, name, verts=14):
    """圓台（底在 z0）"""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=(0, 0, z0 + depth / 2.0))
    o = bpy.context.object
    o.name = name
    setmat(o, m, True)
    return o




# ================================================================== 仙境自己的小工具

def cyl(r, depth, loc, m, name, verts=16, r2=None, rot=(0, 0, 0), parent=None, smooth=True):
    """圓柱／圓台（r＝底、r2＝頂）。原點在中心"""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    setmat(o, m, smooth)
    if parent:
        adopt(o, parent)
    return o


def torus(R, r, loc, m, name, rot=(0, 0, 0), seg=40, minor=10, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=seg, minor_segments=minor)
    o = bpy.context.object
    o.name = name
    setmat(o, m, True)
    if parent:
        adopt(o, parent)
    return o


def solidify(o, t):
    m = o.modifiers.new("so", 'SOLIDIFY')
    m.thickness = t
    m.offset = -1.0
    apply_mod(o, m)


def grid_mesh(rows, name, wrap=False):
    """rows：一排一排的頂點（每排一樣多）→ 一張網格。wrap＝每一排頭尾相接"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in row] for row in rows]
    n = len(rows[0])
    for j in range(len(rows) - 1):
        for i in range(n if wrap else n - 1):
            i2 = (i + 1) % n
            a, b, c, d = vs[j][i], vs[j][i2], vs[j + 1][i2], vs[j + 1][i]
            if len({a, b, c, d}) == 4:
                bm.faces.new([a, b, c, d])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    return o


def poly_roof(n, R, h, lift, z0, m, name, r0=0.0, rings=7, per=6, rot=0.0, power=1.9, thick=0.07, parent=None):
    """攢尖頂／一圈屋簷：n 邊形，往下凹的曲線，角上翹起來。R＝屋簷角到中心的距離，r0＝中間留空的半徑（給多層的樓用）"""
    rows = []
    for j in range(rings + 1):
        v = j / rings
        row = []
        for s in range(n):
            a0 = rot + s * math.tau / n
            a1 = rot + (s + 1) * math.tau / n
            for k in range(per):
                t = k / per
                px = math.cos(a0) * (1 - t) + math.cos(a1) * t
                py = math.sin(a0) * (1 - t) + math.sin(a1) * t
                rr = r0 + (R - r0) * v
                corner = abs(2 * t - 1)
                z = z0 + h * (1 - v) ** power + lift * (corner ** 2.6) * (v ** 2.2)
                row.append((px * rr, py * rr, z))
        rows.append(row)
    o = grid_mesh(rows, name, wrap=True)
    solidify(o, thick)
    setmat(o, m, True)
    if parent:
        adopt(o, parent)
    return o


def gable_roof(L, W, h, lift, z0, m, name, y0=0.0, nu=10, nv=6, thick=0.07, parent=None, along='x'):
    """兩面坡的屋頂（往下凹，兩頭翹起來）。L＝屋脊多長，W＝兩邊屋簷之間多寬"""
    rows = []
    for i in range(nu + 1):
        u = -1 + 2 * i / nu
        row = []
        for j in range(2 * nv + 1):
            s = -1 + j / nv
            v = abs(s)
            z = z0 + h * (1 - v) ** 1.7 + lift * (abs(u) ** 3) * (0.35 + 0.65 * v)
            if along == 'x':
                row.append((u * L / 2, y0 + s * W / 2, z))
            else:
                row.append((s * W / 2, y0 + u * L / 2, z))
        rows.append(row)
    o = grid_mesh(rows, name)
    solidify(o, thick)
    setmat(o, m, True)
    if parent:
        adopt(o, parent)
    return o


def box(size, loc, m, name, bev=0.02, parent=None, rot=(0, 0, 0)):
    return beam(size, loc, m, name, parent, rot=rot, bev=bev)


def palette():
    return {
        "red": mat("wood_red", (0.70, 0.13, 0.09), 0.65),
        "red_dark": mat("wood_red_dark", (0.42, 0.08, 0.07), 0.7),
        "wood": mat("wood_brown", (0.42, 0.25, 0.14), 0.8),
        "tile": mat("roof_tile", (0.16, 0.30, 0.33), 0.55),
        "tile_light": mat("roof_tile_light", (0.26, 0.44, 0.45), 0.55),
        "plaster": mat("plaster", (0.93, 0.88, 0.76), 0.9),
        "gold": mat("gold", (0.96, 0.74, 0.22), 0.35),
        "jade": mat("jade_white", (0.90, 0.95, 0.92), 0.4),
        "stone": mat("stone", (0.66, 0.70, 0.70), 0.9),
        "stone_dark": mat("stone_dark", (0.40, 0.45, 0.47), 0.9),
        "bronze": mat("bronze", (0.36, 0.40, 0.30), 0.5),
        "glow": mat("lantern_glow", (1.0, 0.60, 0.22), 0.6, emit=(1.0, 0.55, 0.18)),
        "glow_gold": mat("lantern_glow_gold", (1.0, 0.82, 0.36), 0.4, emit=(1.0, 0.78, 0.30)),
        "paper": mat("paper", (0.96, 0.92, 0.80), 0.9),
    }


# ------------------------------------------------------------------ 畫門：掛在木架上的一幅立軸（山海畫卷）。兩根柱子會擋路（±1.42）；正面是畫，背面是裱紙和一方朱印
def build_picture_gate():
    clear()
    P = palette()
    painting = mat("painting", (0.9, 0.86, 0.74), 0.9)
    silk = mat("silk_teal", (0.14, 0.40, 0.44), 0.7)
    silk2 = mat("silk_gold", (0.90, 0.68, 0.24), 0.55)
    dark = mat("wood_dark", (0.24, 0.13, 0.10), 0.7)
    for sx in (-1.42, 1.42):
        box((0.20, 0.20, 3.5), (sx, 0, 1.75), dark, "Post", 0.03)
        box((0.46, 0.80, 0.18), (sx, 0, 0.09), P["stone"], "Foot", 0.04)
        ball(0.13, (sx, 0, 3.58), 1.0, P["gold"], "Knob", None, amp=0.0, sub=2)
    path = [Vector((-2.05, 0, 3.52)), Vector((-1.6, 0, 3.30)), Vector((0, 0, 3.25)), Vector((1.6, 0, 3.30)), Vector((2.05, 0, 3.52))]
    setmat(tube(path, [0.05, 0.08, 0.09, 0.08, 0.05], 8, "Bar"), dark, True)
    for sx in (-0.9, 0.9):
        cyl(0.016, 0.22, (sx, 0, 3.13), P["gold"], "Cord", 6)
    # 立軸：天杆、綾邊（青綠）、上下兩條金色的錦眉、畫心、地杆（兩頭金色的軸頭）
    cyl(0.055, 2.66, (0, 0, 3.02), dark, "TopRod", 10, rot=(0, math.radians(90), 0))
    box((2.60, 0.05, 2.86), (0, 0, 1.59), silk, "Mount", 0.008)
    box((2.60, 0.06, 0.15), (0, 0, 2.86), silk2, "BandTop", 0.004)
    box((2.60, 0.06, 0.11), (0, 0, 0.36), silk2, "BandBot", 0.004)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -0.034, 1.60), rotation=(math.radians(90), 0, 0))
    pl = bpy.context.object
    pl.scale = (2.26, 2.24, 1)
    apply_scale(pl)
    pl.name = "Painting"
    setmat(pl, painting, False)
    cyl(0.09, 2.50, (0, 0, 0.14), dark, "BotRod", 12, rot=(0, math.radians(90), 0))
    for sx in (-1.27, 1.27):
        cyl(0.115, 0.10, (sx, 0, 0.14), P["gold"], "RodCap", 12, rot=(0, math.radians(90), 0))
    # 背面：裱紙＋一方朱印＋兩條驚燕（垂下來的細帶）
    box((2.40, 0.02, 2.40), (0, 0.035, 1.60), P["paper"], "BackPaper", 0.004)
    box((0.46, 0.02, 0.46), (0.78, 0.05, 0.78), P["red"], "Seal", 0.01)
    for sx in (-0.5, 0.5):
        box((0.10, 0.02, 0.9), (sx, -0.04, 2.56), P["paper"], "Swallow", 0.004)
    export("picture_gate")


# ------------------------------------------------------------------ 南天門：三間的牌樓，白玉柱、朱紅的樑、三個屋頂（中間最高）
def build_sky_gate():
    clear()
    P = palette()
    xs = (-3.3, -1.5, 1.5, 3.3)
    hs = (3.6, 4.7, 4.7, 3.6)
    for x, h in zip(xs, hs):
        cyl(0.24, h, (x, 0, h / 2), P["jade"], "Pillar", 14)
        box((0.74, 0.74, 0.36), (x, 0, 0.18), P["stone"], "Base", 0.05)
        torus(0.26, 0.06, (x, 0, h - 0.5), P["gold"], "Band", seg=16, minor=6)
    # 中間
    box((3.5, 0.30, 0.34), (0, 0, 4.25), P["red"], "BeamC1", 0.03)
    box((3.5, 0.26, 0.26), (0, 0, 3.72), P["red_dark"], "BeamC2", 0.03)
    box((1.5, 0.10, 0.62), (0, -0.16, 3.98), P["gold"], "Plaque", 0.03)
    box((1.3, 0.05, 0.44), (0, -0.215, 3.98), P["red_dark"], "PlaqueIn", 0.01)
    gable_roof(4.6, 1.7, 0.62, 0.34, 4.86, P["tile"], "RoofC")
    box((4.5, 0.14, 0.16), (0, 0, 5.52), P["tile_light"], "RidgeC", 0.03)
    for sx in (-2.3, 2.3):
        ball(0.13, (sx, 0, 5.62), 1.0, P["gold"], "FinialC", None, amp=0.0, sub=2)
    # 兩邊
    for sg in (-1, 1):
        xm = sg * 2.4
        box((2.0, 0.26, 0.28), (xm, 0, 3.28), P["red"], "BeamS1", 0.03)
        box((2.0, 0.22, 0.22), (xm, 0, 2.86), P["red_dark"], "BeamS2", 0.03)
        gable_roof(2.7, 1.4, 0.48, 0.28, 3.76, P["tile"], "RoofS").location.x = xm
        box((2.6, 0.12, 0.14), (xm, 0, 4.27), P["tile_light"], "RidgeS", 0.03)
    # 燈
    for sx in (-1.5, 1.5):
        ball(0.20, (sx, -0.36, 3.2), 1.25, P["glow"], "Lamp", None, amp=0.0, sub=3)
        cyl(0.012, 0.3, (sx, -0.36, 3.56), P["gold"], "LampCord", 6)
    export("sky_gate")


# ------------------------------------------------------------------ 香爐：三足的銅爐。爐蓋 Head 是獨立的節點（被撞到會掉下來扣在工人頭上）
def build_censer():
    clear()
    P = palette()
    root = empty("Censer")
    body = empty("Body", parent=root)
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        tube([Vector((math.cos(a) * 0.36, math.sin(a) * 0.36, 0.0)), Vector((math.cos(a) * 0.40, math.sin(a) * 0.40, 0.22)),
              Vector((math.cos(a) * 0.30, math.sin(a) * 0.30, 0.46))], [0.07, 0.085, 0.10], 8, "Leg%d" % k)
        setmat(bpy.context.collection.objects["Leg%d" % k], P["bronze"], True)
        adopt(bpy.context.collection.objects["Leg%d" % k], body)
    ball(0.52, (0, 0, 0.78), 0.78, P["bronze"], "Bowl", body, amp=0.0, sub=3)
    torus(0.50, 0.06, (0, 0, 1.05), P["gold"], "Rim", seg=24, minor=8, parent=body)
    torus(0.47, 0.035, (0, 0, 0.70), P["gold"], "Belt", seg=24, minor=6, parent=body)
    for sx in (-1, 1):
        torus(0.15, 0.04, (sx * 0.56, 0, 0.98), P["gold"], "Handle", rot=(math.radians(90), 0, 0), seg=14, minor=6, parent=body)
    # 爐蓋：圓頂＋頂上一顆珠子，蓋緣一圈金邊（原點在蓋子的中心）
    head = empty("Head", (0, 0, 1.25), root)
    ball(0.44, (0, 0, 1.18), 0.62, P["bronze"], "Lid", head, amp=0.0, sub=3)
    torus(0.42, 0.045, (0, 0, 1.12), P["gold"], "LidRim", seg=24, minor=6, parent=head)
    ball(0.11, (0, 0, 1.52), 1.0, P["gold"], "Knob", head, amp=0.0, sub=2)
    for k in range(5):
        a = k * math.tau / 5
        ball(0.05, (math.cos(a) * 0.27, math.sin(a) * 0.27, 1.34), 1.0, P["glow"], "Vent%d" % k, head, amp=0.0, sub=1)
    export("censer")


# ------------------------------------------------------------------ 石柱（華表）：八角的白石柱，柱頭一片雲板、一顆珠
def build_pillar():
    clear()
    P = palette()
    box((1.0, 1.0, 0.24), (0, 0, 0.12), P["stone"], "Plinth", 0.05)
    cyl(0.42, 0.26, (0, 0, 0.37), P["stone"], "Lotus", 12, r2=0.33)
    cyl(0.29, 2.5, (0, 0, 1.75), P["jade"], "Shaft", 8, r2=0.25, smooth=False)
    torus(0.28, 0.05, (0, 0, 1.0), P["gold"], "Band1", seg=16, minor=6)
    torus(0.26, 0.05, (0, 0, 2.6), P["gold"], "Band2", seg=16, minor=6)
    # 雲板：橫穿過柱子的一片（兩頭捲起來）
    o = local_blob([((-0.55, 0, 2.86), (0.34, 0.07, 0.16)), ((0.0, 0, 2.86), (0.40, 0.08, 0.13)), ((0.6, 0, 2.92), (0.30, 0.07, 0.18)), ((0.82, 0, 3.0), (0.14, 0.06, 0.12))], 0.035, 5, 5.0, 0.0, P["jade"], "CloudPlate", ratio=0.5)
    cyl(0.34, 0.14, (0, 0, 3.07), P["stone"], "Cap", 12, r2=0.26)
    ball(0.17, (0, 0, 3.30), 1.0, P["gold"], "Pearl", None, amp=0.0, sub=2)
    export("pillar")


# ------------------------------------------------------------------ 落葉堆（金黃的一堆）、洞口（石頭砌的一圈／金邊）
def build_piles_and_rims():
    clear()
    leaf = mat("leaf_gold", (0.96, 0.70, 0.16), 0.9)
    leaf2 = mat("leaf_orange", (0.92, 0.50, 0.12), 0.9)
    blob([((0, 0, 0.30), (1.15, 1.0, 0.62)), ((0.6, 0.3, 0.26), (0.7, 0.7, 0.5)), ((-0.7, -0.2, 0.22), (0.7, 0.6, 0.42))], 0.07, 6, 3.0, 0.07, leaf, "Pile", cut=0.0, ratio=0.4)
    rnd = random.Random(4)
    for k in range(14):
        a = rnd.uniform(0, math.tau)
        d = rnd.uniform(0.2, 1.3)
        bpy.ops.mesh.primitive_plane_add(size=0.26, location=(math.cos(a) * d, math.sin(a) * d, max(0.05, 0.75 - d * 0.5) + rnd.uniform(0, 0.1)),
                                         rotation=(rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(0, 6.28)))
        setmat(bpy.context.object, leaf2 if k % 2 else leaf, False)
    export("leaf_pile")
    # 石頭砌的洞口（半徑 1：會被放大成洞的半徑）＋裡面的水面（材質 water）
    for name, kind in (("hole_rim_stone", "stone"), ("hole_rim_gold", "gold")):
        clear()
        P = palette()
        water = mat("water", (0.1, 0.3, 0.35), 0.3)
        bpy.ops.mesh.primitive_circle_add(vertices=40, radius=1.14, fill_type='NGON', location=(0, 0, -0.22))
        setmat(bpy.context.object, water, False)
        bpy.context.object.name = "Water"
        cyl(1.16, 0.5, (0, 0, -0.22), P["stone_dark"], "Wall", 40)
        w = bpy.context.object
        bm = bmesh.new()
        bm.from_mesh(w.data)
        caps = [f for f in bm.faces if len(f.verts) > 4]
        bmesh.ops.delete(bm, geom=caps, context='FACES')
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(w.data)
        bm.free()
        if kind == "stone":
            rnd = random.Random(9)
            n = 13
            for k in range(n):
                a = k * math.tau / n + rnd.uniform(-0.05, 0.05)
                s = rnd.uniform(0.85, 1.1)
                b = beam((0.50 * s, 0.30, 0.20 * rnd.uniform(0.8, 1.2)), (math.cos(a) * 1.20, math.sin(a) * 1.20, 0.06), P["stone"] if k % 3 else P["stone_dark"], "Curb%d" % k,
                         rot=(0, 0, a + math.pi / 2 + rnd.uniform(-0.08, 0.08)), bev=0.06)
            # 兩片荷葉
            lily = mat("lily", (0.22, 0.52, 0.34), 0.8)
            for (x, y, r) in ((0.35, 0.3, 0.26), (-0.4, -0.2, 0.2), (0.1, -0.55, 0.16)):
                cyl(r, 0.02, (x, y, -0.20), lily, "Lily", 12)
        else:
            torus(1.19, 0.07, (0, 0, 0.03), P["glow_gold"], "Ring", seg=48, minor=8)
            torus(1.34, 0.025, (0, 0, 0.02), P["gold"], "Ring2", seg=48, minor=6)
        export(name)


# ------------------------------------------------------------------ 陸吾：趴著的大貓（虎身、九條尾巴）。青色的毛、深色的條紋、白肚子。
# Head（頭）、EyesOpen／EyesShut（睜眼／閉眼）、Tails（九條尾巴）是獨立的節點，場地那邊會動它們。正面朝 Blender 的 -Y。
def build_luwu():
    clear()
    fur = mat("luwu_fur", (0.16, 0.56, 0.58), 0.8)
    fur_dark = mat("luwu_stripe", (0.05, 0.22, 0.28), 0.8)
    white = mat("luwu_white", (0.94, 0.97, 0.95), 0.85)
    nose = mat("luwu_nose", (0.90, 0.42, 0.40), 0.6)
    eye = mat("lantern_glow_eye", (1.0, 0.82, 0.25), 0.4, emit=(1.0, 0.78, 0.2))
    gold = mat("gold", (0.96, 0.74, 0.22), 0.35)
    root = empty("Luwu")
    body = empty("Body", parent=root)
    # 身體（趴著：一顆拉長的球）＋胸口＋四隻腳
    b = ball(1.0, (0, 0.35, 0.62), 1.0, fur, "Torso", None, amp=0.0, sub=3)
    b.scale = (0.78, 1.25, 0.62)
    apply_scale(b)
    adopt(b, body)
    c = ball(0.62, (0, -0.55, 0.60), 0.95, white, "Chest", body, amp=0.0, sub=3)
    c.scale = (0.9, 0.8, 0.9)
    for sx in (-1, 1):
        fp = tube([Vector((sx * 0.42, -0.55, 0.30)), Vector((sx * 0.46, -1.05, 0.20)), Vector((sx * 0.46, -1.45, 0.16))], [0.24, 0.20, 0.19], 10, "FrontLeg")
        setmat(fp, fur, True)
        adopt(fp, body)
        ball(0.21, (sx * 0.46, -1.52, 0.17), 0.8, white, "FrontPaw", body, amp=0.0, sub=2)
        hp = ball(0.42, (sx * 0.62, 0.95, 0.36), 0.8, fur, "Haunch", body, amp=0.0, sub=3)
        ball(0.19, (sx * 0.78, 0.50, 0.15), 0.75, white, "BackPaw", body, amp=0.0, sub=2)
    # 條紋：幾道套在身上的深色環（上半圈）
    for k, y in enumerate((-0.15, 0.25, 0.65, 1.05)):
        w = 0.80 - abs(y - 0.4) * 0.22
        path = [Vector((math.cos(a) * w, y + math.sin(a * 2) * 0.04, 0.62 + math.sin(a) * 0.64)) for a in [math.radians(d) for d in range(15, 166, 15)]]
        st = tube(path, [0.02] + [0.075] * (len(path) - 2) + [0.02], 6, "Stripe%d" % k)
        setmat(st, fur_dark, True)
        adopt(st, body)
    # 頭
    head = empty("Head", (0, -0.85, 1.0), root)
    ball(0.56, (0, -1.0, 1.22), 0.9, fur, "Skull", head, amp=0.0, sub=3)
    for sx in (-1, 1):
        ck = ball(0.26, (sx * 0.30, -1.36, 1.06), 0.85, white, "Cheek", head, amp=0.0, sub=2)
        ear = hull([(sx * 0.26, -0.98, 1.62), (sx * 0.52, -0.92, 1.58), (sx * 0.42, -0.94, 1.98), (sx * 0.38, -0.80, 1.62)], "Ear")
        setmat(ear, fur, False)
        adopt(ear, head)
        ei = hull([(sx * 0.31, -1.02, 1.64), (sx * 0.47, -0.98, 1.62), (sx * 0.41, -0.99, 1.86), (sx * 0.39, -0.95, 1.64)], "EarIn")
        setmat(ei, nose, False)
        adopt(ei, head)
        # 臉頰的鬚毛條紋
        for j in range(2):
            wh = tube([Vector((sx * 0.50, -1.18, 1.16 - j * 0.14)), Vector((sx * 0.66, -1.06, 1.20 - j * 0.16))], [0.035, 0.012], 5, "Cheekmark")
            setmat(wh, fur_dark, True)
            adopt(wh, head)
    ball(0.075, (0, -1.60, 1.14), 0.8, nose, "Nose", head, amp=0.0, sub=2)
    # 額頭的「王」字（三橫一豎）
    for j, z in enumerate((1.60, 1.50, 1.40)):
        bar = beam((0.26 - j * 0.03, 0.05, 0.045), (0, -1.43 - j * 0.045, z), fur_dark, "King%d" % j, None, rot=(0.55, 0, 0), bev=0.012)
        adopt(bar, head)
    kv = beam((0.045, 0.05, 0.26), (0, -1.475, 1.50), fur_dark, "KingV", None, rot=(0.55, 0, 0), bev=0.012)
    adopt(kv, head)
    eo = empty("EyesOpen", (0, -1.45, 1.28), root)
    es = empty("EyesShut", (0, -1.45, 1.28), root)
    adopt(eo, head)
    adopt(es, head)
    for sx in (-1, 1):
        e = ball(0.105, (sx * 0.24, -1.47, 1.30), 1.0, eye, "Eye", eo, amp=0.0, sub=2)
        p = ball(0.05, (sx * 0.24, -1.565, 1.30), 1.25, fur_dark, "Pupil", eo, amp=0.0, sub=2)
        p.scale = (0.5, 1.0, 1.0)
        sh = tube([Vector((sx * 0.14, -1.53, 1.31)), Vector((sx * 0.24, -1.55, 1.27)), Vector((sx * 0.34, -1.50, 1.31))], [0.02, 0.03, 0.02], 6, "Lid")
        setmat(sh, fur_dark, True)
        adopt(sh, es)
    # 九條尾巴：從屁股往上、往兩邊散開，尾端捲一下、是白的
    tails = empty("Tails", (0, 1.35, 0.55), root)
    for k in range(9):
        t = (k - 4) / 4.0
        ax = t * 1.05
        length = 1.9 - abs(t) * 0.35
        path = []
        for i in range(7):
            s = i / 6.0
            x = math.sin(ax) * length * s * 0.95
            y = 1.35 + 0.55 * s + 0.25 * math.sin(s * 3.0)
            z = 0.55 + math.cos(ax) * length * s - 0.35 * s * s + 0.18 * math.sin(s * math.pi) * (1 if k % 2 else -1) * 0.0
            # 尾端往外捲
            x += math.sin(ax) * 0.25 * max(0.0, s - 0.7) * 3.0
            z -= 0.5 * max(0.0, s - 0.75) * 2.0
            path.append(Vector((x, y, z)))
        tb = tube(path[:5], [0.11, 0.15, 0.16, 0.15, 0.13], 8, "Tail%d" % k)
        setmat(tb, fur, True)
        adopt(tb, tails)
        tp = tube(path[4:], [0.13, 0.11, 0.04], 8, "TailTip%d" % k)
        setmat(tp, white, True)
        adopt(tp, tails)
    # 脖子上一圈金鈴
    torus(0.50, 0.05, (0, -0.72, 0.95), gold, "Collar", rot=(math.radians(62), 0, 0), seg=20, minor=6, parent=root)
    ball(0.10, (0, -1.12, 0.66), 1.0, gold, "Bell", root, amp=0.0, sub=2)
    export("luwu")


# ------------------------------------------------------------------ 樹：水墨松（彎的樹幹、一層一層扁平的松針）、花樹、銀杏；山石
def build_trees():
    rnd = random.Random(31)
    for variant in ("a", "b"):
        clear()
        bark = mat("bark_ink", (0.20, 0.17, 0.16), 0.9)
        needle = mat("pine_leaf", (0.10, 0.36, 0.34), 0.85)
        needle2 = mat("pine_leaf_light", (0.20, 0.50, 0.44), 0.85)
        lean = 0.5 if variant == "a" else -0.35
        path = [Vector((0, 0, 0)), Vector((lean * 0.3, 0.05, 1.3)), Vector((lean * 0.9, -0.1, 2.5)), Vector((lean * 0.6, 0.1, 3.6)), Vector((lean * 1.2, 0, 4.6))]
        tr = tube(path, [0.26, 0.21, 0.16, 0.12, 0.06], 8, "Trunk")
        setmat(tr, bark, True)
        pads = [((lean * 1.2, 0.0, 4.75), 1.25), ((lean * 0.3 - 0.9, 0.2, 3.7), 0.95), ((lean * 0.9 + 1.0, -0.2, 3.1), 1.05), ((lean * 0.2 - 0.6, -0.4, 2.5), 0.75)]
        if variant == "b":
            pads.append(((lean * 0.6 + 0.9, 0.5, 4.0), 0.8))
        for i, (c, r) in enumerate(pads):
            br = tube([path[2] if c[2] < 3.9 else path[3], Vector((c[0], c[1], c[2] - 0.12))], [0.07, 0.03], 6, "Branch%d" % i)
            setmat(br, bark, True)
            parts = []
            for j in range(4):
                parts.append(((c[0] + rnd.uniform(-0.5, 0.5) * r, c[1] + rnd.uniform(-0.4, 0.4) * r, c[2] + rnd.uniform(-0.03, 0.08)), (r * rnd.uniform(0.5, 0.75), r * rnd.uniform(0.45, 0.65), r * 0.16)))
            local_blob(parts, 0.07, 4, 3.0 + i, 0.03, needle if i % 2 == 0 else needle2, "Pad%d" % i, ratio=0.45)
        export("pine_" + variant)
    # 花樹：矮矮的、歪的枝幹，一團一團粉紅的花
    clear()
    bark = mat("bark_ink", (0.20, 0.17, 0.16), 0.9)
    pink = mat("blossom_pink", (0.98, 0.40, 0.58), 0.9)
    pink2 = mat("blossom_light", (1.0, 0.62, 0.74), 0.9)
    path = [Vector((0, 0, 0)), Vector((0.15, 0, 0.8)), Vector((-0.2, 0.1, 1.5)), Vector((0.1, 0, 2.2))]
    setmat(tube(path, [0.16, 0.13, 0.09, 0.05], 8, "Trunk"), bark, True)
    tips = [(0.1, 0.0, 2.5, 0.75), (-0.9, 0.2, 2.0, 0.6), (0.9, -0.2, 1.9, 0.62), (-0.2, 0.7, 1.7, 0.5), (0.3, -0.7, 2.2, 0.5)]
    for i, (x, y, z, r) in enumerate(tips):
        setmat(tube([path[2], Vector((x, y, z - 0.1))], [0.06, 0.025], 6, "Branch%d" % i), bark, True)
        parts = [((x + rnd.uniform(-0.3, 0.3) * r, y + rnd.uniform(-0.3, 0.3) * r, z + rnd.uniform(-0.1, 0.15)), (r * rnd.uniform(0.5, 0.8),) * 2 + (r * 0.5,)) for j in range(3)]
        local_blob(parts, 0.07, 4, 7.0 + i, 0.05, pink if i % 2 == 0 else pink2, "Bloom%d" % i, ratio=0.4)
    export("blossom")
    # 銀杏：粗樹幹、金黃的大樹冠（兩個色階）
    for variant in ("a", "b"):
        clear()
        bark = mat("bark_warm", (0.34, 0.22, 0.14), 0.9)
        g1 = mat("ginkgo_gold", (0.99, 0.74, 0.14), 0.9)
        g2 = mat("ginkgo_orange", (0.95, 0.52, 0.10), 0.9)
        g3 = mat("ginkgo_pale", (1.0, 0.88, 0.40), 0.9)
        h = 5.2 if variant == "a" else 4.4
        path = [Vector((0, 0, 0)), Vector((0.1, 0, 1.2)), Vector((-0.1, 0.05, 2.4)), Vector((0.05, 0, h * 0.72))]
        setmat(tube(path, [0.34, 0.26, 0.20, 0.10], 9, "Trunk"), bark, True)
        crowns = [((0.0, 0.0, h * 0.86), 1.7, g1), ((-1.2, 0.3, h * 0.66), 1.2, g2), ((1.25, -0.2, h * 0.70), 1.25, g1), ((0.2, 1.0, h * 0.62), 1.0, g3), ((0.1, -1.1, h * 0.74), 1.05, g2), ((0.5, 0.2, h * 1.0), 1.0, g3)]
        for i, (c, r, m) in enumerate(crowns):
            setmat(tube([path[2], Vector((c[0] * 0.7, c[1] * 0.7, c[2] - 0.5))], [0.10, 0.04], 6, "Branch%d" % i), bark, True)
            parts = [((c[0] + rnd.uniform(-0.35, 0.35) * r, c[1] + rnd.uniform(-0.35, 0.35) * r, c[2] + rnd.uniform(-0.2, 0.2) * r), (r * rnd.uniform(0.55, 0.8),) * 2 + (r * rnd.uniform(0.45, 0.6),)) for j in range(4)]
            local_blob(parts, 0.11, 4, 13.0 + i, 0.09, m, "Crown%d" % i, ratio=0.35)
        export("ginkgo_" + variant)
    # 山石（太湖石那種瘦高、有稜角的石頭）
    clear()
    rock = mat("ink_rock", (0.30, 0.38, 0.40), 0.95)
    rock2 = mat("ink_rock_light", (0.50, 0.58, 0.58), 0.95)
    r2 = random.Random(5)
    for i, (cx, cy, s, hh) in enumerate(((0, 0, 0.7, 1.9), (0.55, 0.2, 0.45, 1.1), (-0.5, -0.15, 0.4, 0.8))):
        pts = []
        for k in range(26):
            a = r2.uniform(0, math.tau)
            z = r2.uniform(0, hh)
            rr = s * (1.0 - 0.45 * z / hh) * r2.uniform(0.55, 1.0)
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, z - 0.1))
        o = hull(pts, "Rock%d" % i)
        setmat(o, rock if i != 1 else rock2, False)
    export("scholar_rock")


# ------------------------------------------------------------------ 建築：亭子、迴廊、木樓、三層的樓閣
def build_pavilion():
    clear()
    P = palette()
    cyl(2.5, 0.36, (0, 0, 0.18), P["stone"], "Base", 6, smooth=False)
    cyl(2.25, 0.16, (0, 0, 0.44), P["jade"], "Floor", 6, smooth=False)
    for k in range(6):
        a = k * math.tau / 6
        x, y = math.cos(a) * 1.85, math.sin(a) * 1.85
        cyl(0.13, 2.7, (x, y, 1.85), P["red"], "Col%d" % k, 10)
        a2 = (k + 1) * math.tau / 6
        x2, y2 = math.cos(a2) * 1.85, math.sin(a2) * 1.85
        mx, my = (x + x2) / 2, (y + y2) / 2
        ang = math.atan2(y2 - y, x2 - x)
        ln = math.hypot(x2 - x, y2 - y)
        box((ln, 0.14, 0.20), (mx, my, 3.08), P["red_dark"], "Beam%d" % k, 0.02, rot=(0, 0, ang))
        box((ln, 0.08, 0.10), (mx, my, 2.80), P["gold"], "Trim%d" % k, 0.01, rot=(0, 0, ang))
        if k not in (4,):         # 正面那一邊（朝 -Y）留開口
            box((ln - 0.3, 0.07, 0.07), (mx, my, 1.02), P["red"], "Rail%d" % k, 0.01, rot=(0, 0, ang))
            box((ln - 0.3, 0.07, 0.07), (mx, my, 0.70), P["red"], "RailB%d" % k, 0.01, rot=(0, 0, ang))
    poly_roof(6, 3.1, 1.5, 0.55, 3.18, P["tile"], "Roof", rings=8, per=6)
    cyl(0.16, 0.5, (0, 0, 4.85), P["gold"], "FinialStem", 8, r2=0.05)
    ball(0.2, (0, 0, 4.74), 1.0, P["gold"], "Finial", None, amp=0.0, sub=2)
    for k in range(6):
        a = k * math.tau / 6
        ball(0.09, (math.cos(a) * 3.05, math.sin(a) * 3.05, 3.74), 1.0, P["gold"], "Tip%d" % k, None, amp=0.0, sub=2)
    export("pavilion")


def build_corridor():
    clear()
    P = palette()
    L = 4.8
    box((2.6, L, 0.28), (0, 0, 0.14), P["stone"], "Base", 0.04)
    for y in (-L / 2 + 0.3, 0, L / 2 - 0.3):
        for sx in (-1.05, 1.05):
            cyl(0.12, 2.5, (sx, y, 1.53), P["red"], "Col", 10)
        box((2.4, 0.14, 0.18), (0, y, 2.72), P["red_dark"], "Tie", 0.02)
    for sx in (-1.05, 1.05):
        box((0.14, L, 0.20), (sx, 0, 2.84), P["red_dark"], "Beam", 0.02)
        box((0.07, L - 0.4, 0.07), (sx, 0, 0.95), P["red"], "Rail", 0.01)
        box((0.07, L - 0.4, 0.07), (sx, 0, 0.62), P["red"], "RailB", 0.01)
        box((0.09, L, 0.12), (sx, 0, 2.60), P["gold"], "Trim", 0.01)
    gable_roof(L + 0.5, 3.4, 0.78, 0.25, 2.94, P["tile"], "Roof", along='y')
    box((0.14, L + 0.4, 0.14), (0, 0, 3.74), P["tile_light"], "Ridge", 0.03)
    for y in (-1.2, 1.2):
        ball(0.17, (0, y, 2.36), 1.2, P["glow"], "Lamp", None, amp=0.0, sub=2)
    export("corridor")


def tier(P, half, z0, wall_h, eave, roof_h, lift, name, windows=True):
    """樓的一層：牆（白灰＋木框）＋外面一圈屋簷"""
    box((half * 2, half * 2, wall_h), (0, 0, z0 + wall_h / 2), P["plaster"], name + "Wall", 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.16, 0.16, wall_h), (sx * half, sy * half, z0 + wall_h / 2), P["red"], name + "Post", 0.02)
    for a in range(4):
        ang = a * math.pi / 2
        dx, dy = math.cos(ang), math.sin(ang)
        box((half * 2, 0.10, 0.16), (-dy * half * 0 + dx * 0, 0, 0), P["red_dark"], name + "tmp", 0.01).location = (dx * half * 0, 0, 0)
        bpy.data.objects.remove(bpy.context.object)
        cx, cy = -dy * half, dx * half
        box((half * 2, 0.10, 0.16), (cx, cy, z0 + wall_h - 0.10), P["red_dark"], name + "Top", 0.01, rot=(0, 0, ang))
        box((half * 2, 0.10, 0.12), (cx, cy, z0 + 0.08), P["red_dark"], name + "Bot", 0.01, rot=(0, 0, ang))
        if windows:
            for off in (-0.45, 0.45):
                wx, wy = cx + dx * half * off, cy + dy * half * off
                box((half * 0.5, 0.08, wall_h * 0.48), (wx * 1.0 + (-dy) * 0.03, wy + dx * 0.03, z0 + wall_h * 0.52), P["glow"], name + "Win", 0.01, rot=(0, 0, ang))
                box((half * 0.56, 0.10, 0.07), (wx + (-dy) * 0.035, wy + dx * 0.035, z0 + wall_h * 0.52), P["red_dark"], name + "WinBar", 0.01, rot=(0, 0, ang))
    R = (half + eave) * math.sqrt(2)
    poly_roof(4, R, roof_h, lift, z0 + wall_h, P["tile"], name + "Eave", r0=half * 0.7 * math.sqrt(2), rings=6, per=7, rot=math.pi / 4, power=1.6)
    for a in range(4):
        ang = math.pi / 4 + a * math.pi / 2
        ball(0.10, (math.cos(ang) * R * 0.99, math.sin(ang) * R * 0.99, z0 + wall_h + lift + 0.02), 1.0, P["gold"], name + "Tip", None, amp=0.0, sub=2)


def build_house_tower():
    # 木樓：兩層，下層寬、上層窄，正面（-Y）一扇門
    clear()
    P = palette()
    box((5.6, 4.6, 0.34), (0, 0, 0.17), P["stone"], "Base", 0.04)
    tier(P, 2.3, 0.34, 2.6, 0.9, 0.9, 0.45, "L1")
    tier(P, 1.7, 3.5, 2.1, 0.8, 1.0, 0.45, "L2")
    poly_roof(4, 1.7 * 0.72 * math.sqrt(2), 0.9, 0.0, 5.6 + 0.5, P["tile"], "Cap", rings=5, per=6, rot=math.pi / 4, power=1.5)
    ball(0.16, (0, 0, 7.05), 1.0, P["gold"], "Finial", None, amp=0.0, sub=2)
    box((1.1, 0.12, 1.9), (0, -2.33, 1.30), P["red_dark"], "Door", 0.02)
    box((1.3, 0.10, 0.16), (0, -2.34, 2.34), P["gold"], "DoorTrim", 0.02)
    for sx in (-1.0, 1.0):
        ball(0.2, (sx * 1.0, -2.75, 2.25), 1.25, P["glow"], "Lamp", None, amp=0.0, sub=2)
        cyl(0.012, 0.5, (sx * 1.0, -2.75, 2.7), P["gold"], "Cord", 6)
    # 二樓的欄杆
    for a in range(4):
        ang = a * math.pi / 2
        cx, cy = -math.sin(ang) * 2.15, math.cos(ang) * 2.15
        box((4.3, 0.06, 0.06), (cx, cy, 4.05), P["red"], "Rail", 0.01, rot=(0, 0, ang))
    export("house")
    # 樓閣：三層，越上面越小
    clear()
    P = palette()
    box((7.0, 7.0, 0.5), (0, 0, 0.25), P["stone"], "Base", 0.05)
    box((2.0, 1.0, 0.25), (0, -3.9, 0.125), P["stone"], "Step1", 0.03)
    tier(P, 2.7, 0.5, 2.8, 1.0, 1.0, 0.5, "L1")
    tier(P, 2.1, 3.9, 2.3, 0.9, 0.95, 0.5, "L2")
    tier(P, 1.5, 6.75, 2.0, 0.8, 0.9, 0.5, "L3")
    poly_roof(4, 1.5 * 0.74 * math.sqrt(2), 1.25, 0.0, 8.75 + 0.45, P["tile"], "Cap", rings=6, per=6, rot=math.pi / 4, power=1.4)
    cyl(0.12, 0.9, (0, 0, 10.75), P["gold"], "Spire", 8, r2=0.03)
    ball(0.2, (0, 0, 10.45), 1.0, P["gold"], "SpireBall", None, amp=0.0, sub=2)
    box((1.3, 0.12, 2.1), (0, -2.73, 1.55), P["red_dark"], "Door", 0.02)
    box((1.6, 0.10, 0.2), (0, -2.75, 2.75), P["gold"], "DoorTrim", 0.02)
    export("tower")


# ------------------------------------------------------------------ 小東西：宮燈、石碑、欄杆柱、小拱橋
def build_small():
    clear()
    P = palette()
    box((0.46, 0.46, 0.2), (0, 0, 0.1), P["stone"], "Base", 0.04)
    cyl(0.07, 2.6, (0, 0, 1.5), P["red_dark"], "Post", 8)
    tube([Vector((0, 0, 2.7)), Vector((0, -0.25, 2.95)), Vector((0, -0.55, 2.9))], [0.05, 0.04, 0.03], 6, "Arm")
    setmat(bpy.context.collection.objects["Arm"], P["red_dark"], True)
    cyl(0.01, 0.3, (0, -0.55, 2.75), P["gold"], "Cord", 6)
    ball(0.26, (0, -0.55, 2.38), 1.2, P["glow"], "Lantern", None, amp=0.0, sub=3)
    cyl(0.14, 0.07, (0, -0.55, 2.68), P["gold"], "CapTop", 10)
    cyl(0.14, 0.07, (0, -0.55, 2.08), P["gold"], "CapBot", 10)
    cyl(0.03, 0.36, (0, -0.55, 1.88), P["red"], "Tassel", 6, r2=0.06)
    export("palace_lantern")
    # 石碑：龜座上一塊大石板，正面刻滿金色的字（一行一行的小點）
    clear()
    P = palette()
    b = ball(0.7, (0, 0, 0.26), 0.5, P["stone_dark"], "Turtle", None, amp=0.0, sub=3)
    b.scale = (1.2, 0.9, 1.0)
    ball(0.2, (0, -0.72, 0.30), 0.8, P["stone_dark"], "TurtleHead", None, amp=0.0, sub=2)
    box((1.2, 0.24, 2.3), (0, 0, 1.6), P["stone"], "Slab", 0.04)
    box((1.36, 0.30, 0.34), (0, 0, 2.86), P["stone_dark"], "Cap", 0.06)
    rnd = random.Random(12)
    for col in range(5):
        x = -0.42 + col * 0.21
        z = 2.5
        while z > 0.8:
            ln = rnd.choice((0.06, 0.09, 0.12))
            box((0.07, 0.03, ln), (x, -0.125, z - ln / 2), P["glow_gold"], "Glyph", 0.005)
            z -= ln + 0.045
    export("stele")
    # 欄杆柱
    clear()
    P = palette()
    box((0.3, 0.3, 0.95), (0, 0, 0.475), P["jade"], "Post", 0.03)
    cyl(0.2, 0.12, (0, 0, 1.0), P["jade"], "Neck", 10, r2=0.14)
    ball(0.17, (0, 0, 1.16), 1.1, P["jade"], "Bud", None, amp=0.0, sub=2)
    export("rail_post")
    # 小拱橋（沿 Blender 的 Y 方向過河，長 7 公尺、寬 2.6）
    clear()
    P = palette()
    rows = []
    for i in range(15):
        u = -1 + 2 * i / 14
        z = 0.95 * (1 - u * u) + 0.05
        rows.append([(-1.3, u * 3.5, z), (1.3, u * 3.5, z)])
    deck = grid_mesh(rows, "Deck")
    solidify(deck, 0.22)
    setmat(deck, P["stone"], True)
    for sx in (-1.3, 1.3):
        pts = [Vector((sx, -3.5 + 7.0 * i / 14, 0.95 * (1 - (-1 + 2 * i / 14) ** 2) + 0.62)) for i in range(15)]
        setmat(tube(pts, [0.06] * 15, 6, "Rail"), P["red"], True)
        for i in range(0, 15, 2):
            u = -1 + 2 * i / 14
            z = 0.95 * (1 - u * u) + 0.05
            box((0.14, 0.14, 0.62), (sx, u * 3.5, z + 0.30), P["red_dark"], "Post", 0.02)
    export("bridge")


# ------------------------------------------------------------------ 第 3 關：唱盤、圓門、金環；結局的鳳凰金光
def bird_emblem(P, loc, rot, s, name, parent=None):
    """一個小小的鳥形紋章（展翅的剪影：身體一個菱形、兩片翅膀）"""
    e = empty(name, loc, parent)
    e.rotation_euler = rot
    bpy.context.view_layer.update()
    for sx in (-1, 1):
        w = hull([(0, 0, 0.02 * s), (sx * 0.55 * s, 0, 0.30 * s), (sx * 0.62 * s, 0, 0.02 * s), (sx * 0.30 * s, 0, -0.10 * s), (0, 0.03 * s, 0.0), (sx * 0.4 * s, 0.03 * s, 0.1 * s)], name + "Wing")
        setmat(w, P["glow_gold"], False)
        w.parent = e
    b = hull([(0, 0, 0.34 * s), (0.10 * s, 0, 0.0), (-0.10 * s, 0, 0.0), (0, 0, -0.34 * s), (0, 0.04 * s, 0.0)], name + "Body")
    setmat(b, P["glow_gold"], False)
    b.parent = e
    return e


def build_disc_and_rings():
    # 唱盤：一張大圓盤（深色的盤面、一圈一圈的紋路、金色的圓標），邊上一圈十二個鳥的紋章
    clear()
    P = palette()
    vinyl = mat("vinyl", (0.10, 0.11, 0.20), 0.25)
    cyl(1.55, 0.14, (0, 0, 0.07), P["jade"], "Platter", 48)
    cyl(1.38, 0.05, (0, 0, 0.165), vinyl, "Record", 48)
    for k, r in enumerate((0.55, 0.75, 0.95, 1.15, 1.30)):
        torus(r, 0.012, (0, 0, 0.192), P["gold"] if k % 2 else P["stone_dark"], "Groove%d" % k, seg=48, minor=4)
    cyl(0.40, 0.03, (0, 0, 0.205), P["glow_gold"], "Label", 32)
    cyl(0.05, 0.10, (0, 0, 0.25), P["gold"], "Spindle", 10)
    torus(1.50, 0.05, (0, 0, 0.14), P["glow_gold"], "Rim", seg=48, minor=6)
    export("turntable")
    # 圓門：立著的一個大圓環（石座上），環上一圈十二個鳥的紋章，正中間是空的
    clear()
    P = palette()
    box((3.4, 1.0, 0.5), (0, 0, 0.25), P["stone"], "Plinth", 0.06)
    box((2.2, 0.8, 0.4), (0, 0, 0.70), P["jade"], "Plinth2", 0.05)
    R = 3.4
    cz = R + 0.85
    torus(R, 0.26, (0, 0, cz), P["jade"], "Ring", rot=(math.radians(90), 0, 0), seg=64, minor=12)
    torus(R - 0.36, 0.05, (0, -0.02, cz), P["glow_gold"], "RingIn", rot=(math.radians(90), 0, 0), seg=64, minor=6)
    torus(R + 0.36, 0.05, (0, -0.02, cz), P["glow_gold"], "RingOut", rot=(math.radians(90), 0, 0), seg=64, minor=6)
    for k in range(12):
        a = k * math.tau / 12 + math.pi / 12
        x, z = math.cos(a) * R, cz + math.sin(a) * R
        cyl(0.32, 0.08, (x, -0.26, z), P["stone_dark"], "Plate%d" % k, 20, rot=(math.radians(90), 0, 0))
        bird_emblem(P, (x, -0.32, z), (0, a - math.pi / 2, 0), 0.42, "Bird%d" % k)
    export("ring_gate")
    # 金環：一圈很細的發光的環（半徑 3），立著
    clear()
    P = palette()
    torus(3.0, 0.05, (0, 0, 0), P["glow_gold"], "Ring", rot=(math.radians(90), 0, 0), seg=72, minor=6)
    torus(2.82, 0.018, (0, 0, 0), P["glow_gold"], "RingThin", rot=(math.radians(90), 0, 0), seg=72, minor=4)
    for k in range(8):
        a = k * math.tau / 8
        ball(0.09, (math.cos(a) * 3.0, 0, math.sin(a) * 3.0), 1.0, P["glow_gold"], "Bead%d" % k, None, amp=0.0, sub=1)
    export("gold_ring")
    # 鳳凰金光：一片展翅的剪影（朝 -Y 的平面），結局時從家豪身上展開
    clear()
    glow = mat("phoenix", (1.0, 0.8, 0.3), 0.5, emit=(1.0, 0.8, 0.3))
    half = [(0.0, 0.25), (0.10, 0.55), (0.06, 0.80), (0.0, 0.95), (0.14, 0.86), (0.30, 0.74), (0.62, 0.90), (1.05, 1.22), (1.55, 1.38), (2.05, 1.34),
            (1.72, 1.12), (2.0, 1.02), (1.60, 0.88), (1.85, 0.72), (1.42, 0.62), (1.58, 0.42), (1.12, 0.40), (0.80, 0.22), (0.42, 0.14),
            (0.36, -0.20), (0.60, -0.90), (0.50, -1.50), (0.30, -1.0), (0.22, -1.75), (0.08, -1.1), (0.0, -1.95)]
    pts = half + [(-x, z) for (x, z) in reversed(half[1:-1])]
    me = bpy.data.meshes.new("Phoenix")
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, z)) for (x, z) in pts]
    f = bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=[f])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Phoenix", me)
    bpy.context.collection.objects.link(o)
    setmat(o, glow, False)
    export("phoenix_light")


# ------------------------------------------------------------------ 第二批（山海畫卷）：紅梅、攤子、幌子、小燈籠、星碑、紋章盤
def build_plum():
    rnd = random.Random(77)
    for variant in ("a", "b"):
        clear()
        bark = mat("bark_ink", (0.16, 0.12, 0.12), 0.9)
        red = mat("plum_red", (0.88, 0.10, 0.18), 0.85)
        red2 = mat("plum_pink", (0.99, 0.36, 0.42), 0.85)
        snow = mat("snow_cap", (0.96, 0.98, 1.0), 0.9)
        lean = 0.4 if variant == "a" else -0.32
        path = [Vector((0, 0, 0)), Vector((lean * 0.5, 0.05, 0.7)), Vector((-lean * 0.35, -0.05, 1.35)), Vector((lean * 0.5, 0.05, 1.95)), Vector((lean * 0.2, 0, 2.5))]
        setmat(tube(path, [0.18, 0.15, 0.11, 0.07, 0.03], 8, "Trunk"), bark, True)
        nb = 7 if variant == "a" else 6
        for i in range(nb):
            a = i * math.tau / nb + rnd.uniform(-0.3, 0.3)
            base = path[1 + i % 3]
            d = Vector((math.cos(a), math.sin(a), 0))
            p1 = base + d * rnd.uniform(0.5, 0.8) + Vector((0, 0, rnd.uniform(0.2, 0.45)))
            a2 = a + rnd.choice((-1, 1)) * rnd.uniform(0.5, 0.9)
            p2 = p1 + Vector((math.cos(a2), math.sin(a2), 0)) * rnd.uniform(0.45, 0.75) + Vector((0, 0, rnd.uniform(0.1, 0.4)))
            p3 = p2 + d * rnd.uniform(0.25, 0.45) + Vector((0, 0, rnd.uniform(0.15, 0.3)))
            setmat(tube([base, p1, p2, p3], [0.06, 0.045, 0.03, 0.012], 5, "Branch%d" % i), bark, True)
            # 花：沿著枝一朵一朵（小球），枝頭多幾朵
            for seg, (q0, q1) in enumerate(((p1, p2), (p2, p3), (base, p1))):
                for k in range(4 if seg < 2 else 2):
                    t = rnd.uniform(0.2, 1.0)
                    q = q0.lerp(q1, t) + Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), rnd.uniform(0.0, 0.12)))
                    ball(rnd.uniform(0.09, 0.15), tuple(q), 0.8, red if rnd.random() < 0.65 else red2, "Bloom", None, amp=0.0, sub=1)
            # 枝上的積雪
            mid = p1.lerp(p2, 0.5) + Vector((0, 0, 0.07))
            sn = ball(0.2, tuple(mid), 0.38, snow, "Snow%d" % i, None, amp=0.0, sub=2)
            sn.scale = (1.5, 1.0, 1.0)
            sn.rotation_euler = (0, 0, a2)
        export("plum_" + variant)


def build_stall():
    clear()
    P = palette()
    cloth_r = mat("awning_red", (0.82, 0.17, 0.12), 0.8)
    cloth_w = mat("awning_cream", (0.98, 0.93, 0.78), 0.8)
    bamboo = mat("bamboo", (0.86, 0.70, 0.40), 0.8)
    bun = mat("bun", (0.99, 0.97, 0.90), 0.9)
    box((2.3, 1.0, 0.10), (0, 0, 0.90), P["wood"], "Top", 0.03)
    for sx in (-1.05, 1.05):
        for sy in (-0.42, 0.42):
            box((0.10, 0.10, 2.35 if sy > 0 else 2.0), (sx, sy, 1.175 if sy > 0 else 1.0), P["wood"], "Post", 0.02)
    box((2.3, 0.05, 0.55), (0, -0.50, 0.58), cloth_r, "Skirt", 0.01)
    box((2.3, 0.055, 0.10), (0, -0.50, 0.36), cloth_w, "SkirtHem", 0.005)
    # 條紋的遮陽棚（前低後高）
    for k in range(7):
        x = -1.2 + (k + 0.5) * 2.4 / 7
        box((2.4 / 7, 1.55, 0.05), (x, -0.12, 2.24), cloth_r if k % 2 == 0 else cloth_w, "Awning%d" % k, 0.008, rot=(math.radians(15), 0, 0))
        box((2.4 / 7, 0.04, 0.20), (x, -0.87, 1.96), cloth_r if k % 2 == 0 else cloth_w, "Flap%d" % k, 0.008)
    # 貨：兩疊蒸籠、一盤包子、一把茶壺
    for sx, n in ((-0.65, 3), (-0.05, 2)):
        for k in range(n):
            cyl(0.27, 0.13, (sx, 0.05, 1.02 + k * 0.14), bamboo, "Steamer", 16)
        cyl(0.28, 0.05, (sx, 0.05, 1.0 + n * 0.14), P["wood"], "Lid", 16, r2=0.12)
    cyl(0.30, 0.03, (0.62, -0.05, 0.965), P["plaster"], "Plate", 16)
    for k in range(6):
        a = k * math.tau / 5
        rr = 0.17 if k < 5 else 0.0
        ball(0.095, (0.62 + math.cos(a) * rr, -0.05 + math.sin(a) * rr, 1.04 if k < 5 else 1.13), 0.8, bun, "Bun", None, amp=0.0, sub=2)
    ball(0.15, (0.2, -0.3, 1.07), 0.85, P["bronze"], "Pot", None, amp=0.0, sub=2)
    cyl(0.015, 0.5, (1.08, -0.72, 1.72), P["gold"], "Cord", 6)
    ball(0.17, (1.08, -0.72, 1.40), 1.15, P["glow"], "Lantern", None, amp=0.0, sub=2)
    export("stall")
    # 幌子：一根竿子、橫出去一根桿，掛一塊布（字由 Godot 貼）；布的中心在 x=0.55、z=2.05
    clear()
    P = palette()
    cloth_r = mat("awning_red", (0.82, 0.17, 0.12), 0.8)
    box((0.36, 0.36, 0.16), (0, 0, 0.08), P["stone"], "Base", 0.03)
    cyl(0.05, 3.3, (0, 0, 1.65), P["wood"], "Pole", 8)
    cyl(0.03, 0.95, (0.45, 0, 3.0), P["wood"], "Arm", 6, rot=(0, math.radians(90), 0))
    ball(0.08, (0, 0, 3.34), 1.0, P["gold"], "Knob", None, amp=0.0, sub=2)
    box((0.74, 0.03, 1.86), (0.55, 0, 2.05), P["paper"], "Cloth", 0.006)
    box((0.80, 0.035, 0.14), (0.55, 0, 2.93), cloth_r, "ClothTop", 0.006)
    for k in range(3):
        box((0.20, 0.03, 0.26), (0.55 - 0.26 + k * 0.26, 0, 1.02), cloth_r, "Tail%d" % k, 0.006)
    export("banner")
    # 小燈籠（掛在一串上的）：原點在頂端
    clear()
    P = palette()
    cyl(0.008, 0.16, (0, 0, -0.08), P["gold"], "Cord", 5)
    ball(0.2, (0, 0, -0.36), 1.1, P["glow"], "Lantern", None, amp=0.0, sub=2)
    cyl(0.10, 0.05, (0, 0, -0.15), P["gold"], "CapTop", 8)
    cyl(0.10, 0.05, (0, 0, -0.57), P["gold"], "CapBot", 8)
    cyl(0.02, 0.22, (0, 0, -0.70), P["red"], "Tassel", 5, r2=0.045)
    export("mini_lantern")


def build_astral():
    # 星碑：一塊立著的深色琉璃板，金框，兩面刻滿發光的金字
    clear()
    P = palette()
    glass = mat("star_glass", (0.08, 0.10, 0.24), 0.25)
    box((1.9, 0.9, 0.22), (0, 0, 0.11), P["stone_dark"], "Plinth", 0.04)
    box((1.6, 0.6, 0.16), (0, 0, 0.30), P["gold"], "Plinth2", 0.03)
    box((1.36, 0.14, 3.3), (0, 0, 2.03), glass, "Slab", 0.02)
    for sx in (-0.70, 0.70):
        box((0.07, 0.18, 3.36), (sx, 0, 2.03), P["glow_gold"], "Frame", 0.01)
    for z in (0.38, 3.70):
        box((1.47, 0.18, 0.07), (0, 0, z), P["glow_gold"], "Frame", 0.01)
    rnd = random.Random(21)
    for side in (-1, 1):
        for col in range(6):
            x = -0.5 + col * 0.2
            z = 3.5
            while z > 0.62:
                ln = rnd.choice((0.07, 0.10, 0.14, 0.14))
                if rnd.random() < 0.9:
                    box((0.085, 0.02, ln), (x, side * 0.078, z - ln / 2), P["glow_gold"], "Glyph", 0.004)
                z -= ln + 0.05
    export("star_stele")
    # 紋章盤：平放的一塊圓牌（半徑 1），深色的底、金色的邊；中間的字或紋由 Godot 貼
    clear()
    P = palette()
    base = mat("medal_base", (0.10, 0.10, 0.22), 0.35)
    cyl(1.0, 0.06, (0, 0, 0.03), base, "Disc", 40)
    torus(0.96, 0.045, (0, 0, 0.06), P["glow_gold"], "Rim", seg=48, minor=6)
    torus(0.80, 0.015, (0, 0, 0.065), P["glow_gold"], "RimIn", seg=48, minor=4)
    for k in range(8):
        a = k * math.tau / 8
        ball(0.035, (math.cos(a) * 0.88, math.sin(a) * 0.88, 0.07), 1.0, P["glow_gold"], "Dot%d" % k, None, amp=0.0, sub=1)
    export("medallion")


BUILDERS = [("picture_gate", build_picture_gate), ("sky_gate", build_sky_gate), ("censer", build_censer), ("pillar", build_pillar),
            ("piles", build_piles_and_rims), ("luwu", build_luwu), ("trees", build_trees), ("pavilion", build_pavilion),
            ("corridor", build_corridor), ("house", build_house_tower), ("small", build_small), ("disc", build_disc_and_rings),
            ("plum", build_plum), ("stall", build_stall), ("astral", build_astral)]
# 後面可以接要重做的名字（不接＝全部重做）：... -- <輸出資料夾> plum stall
want = argv[1:]
for name, fn in BUILDERS:
    if not want or name in want:
        fn()
