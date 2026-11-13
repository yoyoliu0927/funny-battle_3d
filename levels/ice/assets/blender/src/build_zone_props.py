# 冰雪島周邊區域的道具：冰釣小屋、木棧道、冰晶簇（低多邊形、平面著色）
import bpy, sys, math, random
argv = sys.argv[sys.argv.index("--") + 1:]
outdir = argv[0]

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    for c in (bpy.data.meshes, bpy.data.materials):
        for x in list(c): c.remove(x)

def mat(name, rgb, rough=0.85, metal=0.0, emit=None, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 2.0
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = 'BLEND'
    return m

def keep(o, parent):
    if parent:
        bpy.context.view_layer.update()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()

def finish(o, m, name, parent):
    o.name = name; o.data.materials.clear(); o.data.materials.append(m)
    for p in o.data.polygons: p.use_smooth = False
    keep(o, parent); return o

def box(size, loc, m, name, parent, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = size
    return finish(o, m, name, parent)

def cyl(r, depth, loc, rot, m, name, parent, verts=8, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.object, m, name, parent)

def empty(name):
    bpy.ops.object.empty_add(location=(0, 0, 0)); o = bpy.context.object; o.name = name; return o

def export(path):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True)
    print("EXPORTED", path)

# Blender：Z 向上；-Y 是「正面」（匯出後是 Godot 的 +Z）
# ---------------- 冰釣小屋
clear()
wood = mat("plank", (0.60, 0.38, 0.22)); wood_d = mat("plank_dark", (0.40, 0.24, 0.13))
roof = mat("roof", (0.55, 0.16, 0.13)); snow = mat("snow", (0.95, 0.97, 1.0), 0.95)
glow = mat("window", (1.0, 0.82, 0.45), 0.4, emit=(1.0, 0.7, 0.3)); iron = mat("iron", (0.25, 0.27, 0.3), 0.5, 0.5)
door = mat("door", (0.33, 0.19, 0.1))
W, D, H = 2.2, 1.7, 1.45
root = empty("FishingHut")
for sx in (-1, 1):   # 底下的雪橇板（冰釣小屋可以拖著走）
    box((0.12, D + 0.6, 0.08), (sx * (W / 2 - 0.25), 0, 0.12), wood_d, "Runner", root)
    box((0.12, 0.25, 0.08), (sx * (W / 2 - 0.25), -(D + 0.6) / 2 + 0.05, 0.2), wood_d, "RunnerTip", root, rot=(0.6, 0, 0))
box((W + 0.1, D + 0.1, 0.12), (0, 0, 0.24), wood_d, "Floor", root)
for i in range(6):     # 牆：一條一條木板
    z = 0.38 + i * (H / 6)
    box((W, D, H / 6 - 0.03), (0, 0, z + H / 12), wood if i % 2 == 0 else wood_d, "Plank%d" % i, root)
box((0.55, 0.06, 0.95), (-0.45, -D / 2 - 0.03, 0.3 + 0.48), door, "Door", root)
box((0.06, 0.07, 0.06), (-0.25, -D / 2 - 0.08, 0.78), iron, "Knob", root)
box((0.5, 0.06, 0.42), (0.5, -D / 2 - 0.03, 1.1), glow, "Window", root)
box((0.6, 0.08, 0.06), (0.5, -D / 2 - 0.05, 0.86), wood_d, "Sill", root)
top = 0.38 + H
rise = (W / 2) * math.tan(math.radians(32))
for sx in (-1, 1):     # 兩片斜屋頂＋積雪（Λ 形：外側低、中間高）
    a = math.radians(32) * sx
    half = (W / 2 + 0.25) / math.cos(math.radians(32))
    box((half, D + 0.5, 0.1), (sx * W / 4, 0, top + rise / 2 + 0.06), roof, "Roof", root, rot=(0, a, 0))
    box((half - 0.1, D + 0.45, 0.08), (sx * W / 4, 0, top + rise / 2 + 0.14), snow, "RoofSnow", root, rot=(0, a, 0))
for sy in (-1, 1):     # 山牆：前後各一片三角形
    me = bpy.data.meshes.new("gable")
    yy = sy * D / 2
    me.from_pydata([(-W / 2, yy, top), (W / 2, yy, top), (0, yy, top + rise)], [], [(0, 1, 2)])
    me.update()
    g = bpy.data.objects.new("Gable", me)
    bpy.context.collection.objects.link(g)
    finish(g, wood, "Gable", root)
cyl(0.11, 0.7, (0.6, 0.35, top + rise * 0.7 + 0.2), (0, 0, 0), iron, "Chimney", root)
cyl(0.15, 0.08, (0.6, 0.35, top + rise * 0.7 + 0.56), (0, 0, 0), snow, "ChimneySnow", root)
box((0.9, 0.5, 0.12), (W / 2 + 0.25, -0.3, 0.06), snow, "SnowDrift", root, rot=(0, 0, 0.3))
export(outdir + "/fishing_hut.glb")

# ---------------- 木棧道（長 6 公尺，從 -Y 端開始往 +Y 伸）
clear()
wood = mat("plank", (0.58, 0.37, 0.21)); wood_d = mat("plank_dark", (0.38, 0.23, 0.12)); snow = mat("snow", (0.95, 0.97, 1.0), 0.95)
root = empty("Pier")
random.seed(3)
L = 6.0
n = 20
for i in range(n):
    y = -L / 2 + (i + 0.5) * (L / n)
    box((1.4 + random.uniform(-0.06, 0.06), L / n - 0.05, 0.08), (random.uniform(-0.04, 0.04), y, 0.42), wood if i % 3 else wood_d, "Board%d" % i, root, rot=(0, 0, random.uniform(-0.03, 0.03)))
    if random.random() < 0.35:
        box((random.uniform(0.3, 0.7), L / n - 0.1, 0.05), (random.uniform(-0.4, 0.4), y, 0.48), snow, "SnowPatch", root)
for k in range(5):
    y = -L / 2 + 0.2 + k * (L - 0.4) / 4
    for sx in (-1, 1):
        cyl(0.09, 0.7, (sx * 0.62, y, 0.22), (0, 0, 0), wood_d, "Post", root)
        cyl(0.12, 0.06, (sx * 0.62, y, 0.58), (0, 0, 0), snow, "PostSnow", root)
box((0.08, L, 0.08), (0.66, 0, 0.5), wood_d, "RailL", root)
box((0.08, L, 0.08), (-0.66, 0, 0.5), wood_d, "RailR", root)
export(outdir + "/pier.glb")

# ---------------- 冰晶簇
clear()
ice = mat("ice_crystal", (0.62, 0.86, 1.0), 0.08, 0.0, emit=(0.25, 0.55, 0.85), alpha=0.82)
ice_d = mat("ice_crystal_dark", (0.42, 0.7, 0.95), 0.1, 0.0, emit=(0.15, 0.4, 0.7), alpha=0.85)
root = empty("IceCrystals")
random.seed(7)
for k in range(7):
    a = random.uniform(0, math.tau); d = random.uniform(0.0, 0.45)
    h = random.uniform(0.6, 1.6)
    tilt = (random.uniform(-0.35, 0.35), random.uniform(-0.35, 0.35), 0)
    x, y = math.cos(a) * d, math.sin(a) * d
    cyl(0.14 + h * 0.06, h, (x, y, h / 2), tilt, ice if k % 2 else ice_d, "Prism%d" % k, root, verts=6)
    cyl(0.14 + h * 0.06, 0.3, (x + math.sin(tilt[1]) * h / 2, y - math.sin(tilt[0]) * h / 2, h + 0.1), tilt, ice, "Tip%d" % k, root, verts=6, r2=0.0)
export(outdir + "/ice_crystals.glb")
