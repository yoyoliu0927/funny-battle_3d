# 用 Blender 建冰雪島的雪人和企鵝籠（低多邊形、平面著色），輸出成 GLB
import bpy, sys, math
argv = sys.argv[sys.argv.index("--") + 1:]
outdir = argv[0]

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for c in (bpy.data.meshes, bpy.data.materials):
        for x in list(c):
            c.remove(x)

def mat(name, rgb, rough=0.8, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    return m

def finish(o, m, name, parent=None, smooth=False):
    o.name = name
    o.data.materials.clear()
    o.data.materials.append(m)
    if not smooth:
        for poly in o.data.polygons:
            poly.use_smooth = False
    if parent:
        bpy.context.view_layer.update()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()   # 保留原本的世界座標
    return o

def ico(r, loc, m, name, parent=None, sub=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    return finish(o, m, name, parent)

def cyl(r, depth, loc, rot, m, name, parent=None, verts=8, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot)
    return finish(bpy.context.object, m, name, parent)

def box(size, loc, m, name, parent=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    return finish(o, m, name, parent)

def empty(name, loc=(0, 0, 0), parent=None):
    bpy.ops.object.empty_add(location=loc)
    o = bpy.context.object
    o.name = name
    if parent:
        bpy.context.view_layer.update()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return o

def export(path):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True)
    print("EXPORTED", path)

# Blender 是 Z 向上；匯出時轉成 Y 向上。下面座標 (x, y, z)＝(右, 前→後, 上)
# ---------------- 雪人：Body（兩顆雪球＋圍巾＋手＋扣子）與 Head（頭＋鼻子＋眼睛＋嘴）分開
clear()
snow = mat("snow", (0.95, 0.97, 1.0), 0.9)
coal = mat("coal", (0.06, 0.06, 0.07), 0.6)
carrot = mat("carrot", (0.98, 0.45, 0.1), 0.7)
scarf = mat("scarf", (0.85, 0.12, 0.15), 0.8)
wood = mat("stick", (0.38, 0.24, 0.13), 0.9)
root = empty("Snowman")
body = empty("Body", parent=root)
ico(0.56, (0, 0, 0.46), snow, "BallLow", body, scale=(1, 1, 0.9))
ico(0.41, (0, 0, 1.13), snow, "BallMid", body, scale=(1, 1, 0.92))
for i, z in enumerate([0.98, 1.16, 1.34 - 0.04]):
    ico(0.045, (0, -0.39 + (z - 1.13) * -0.05, z), coal, "Button%d" % i, body, sub=1)
bpy.ops.mesh.primitive_torus_add(major_radius=0.27, minor_radius=0.075, location=(0, 0, 1.43), major_segments=12, minor_segments=6)
finish(bpy.context.object, scarf, "Scarf", body)
box((0.12, 0.05, 0.38), (0.16, -0.3, 1.25), scarf, "ScarfTail", body, rot=(0.25, 0, 0.2))
cyl(0.025, 0.7, (0.6, 0, 1.25), (0, math.radians(60), 0), wood, "ArmR", body, verts=6)
cyl(0.025, 0.7, (-0.6, 0, 1.25), (0, math.radians(-60), 0), wood, "ArmL", body, verts=6)
head = empty("Head", (0, 0, 1.68), root)
ico(0.29, (0, 0, 1.68), snow, "HeadBall", head)
cyl(0.065, 0.36, (0, -0.42, 1.66), (math.radians(90), 0, 0), carrot, "Nose", head, verts=8, r2=0.0)
for x in (-0.1, 0.1):
    ico(0.04, (x, -0.255, 1.76), coal, "Eye", head, sub=1)
for k in range(5):
    a = math.radians(-50 + k * 25)
    ico(0.025, (math.sin(a) * 0.14, -0.25, 1.58 - math.cos(a) * 0.03), coal, "Mouth", head, sub=1)
export(outdir + "/snowman.glb")

# ---------------- 企鵝籠：木底＋木頂＋柱子＋三面鐵欄杆；Door（正面整片欄杆＋大鎖）轉軸在左邊
clear()
wood = mat("wood", (0.55, 0.36, 0.2), 0.85)
wood_dark = mat("wood_dark", (0.36, 0.22, 0.12), 0.9)
iron = mat("iron", (0.32, 0.35, 0.4), 0.45, 0.6)
gold = mat("gold", (0.95, 0.75, 0.2), 0.35, 0.8)
straw = mat("straw", (0.93, 0.78, 0.32), 0.95)
W, D, H = 2.6, 2.0, 1.45
root = empty("Cage")
box((W + 0.1, D + 0.1, 0.16), (0, 0, 0.08), wood, "Floor", root)
box((W + 0.3, D + 0.3, 0.14), (0, 0, H + 0.07), wood, "Roof", root)
box((W + 0.1, 0.12, 0.12), (0, -D / 2, H - 0.03), wood_dark, "BeamFront", root)
for sx in (-1, 1):
    for sy in (-1, 1):
        box((0.14, 0.14, H), (sx * W / 2, sy * D / 2, H / 2), wood_dark, "Post", root)
for i in range(9):
    x = -1.2 + i * 0.3
    cyl(0.03, H - 0.16, (x, D / 2, H / 2), (0, 0, 0), iron, "BarBack", root, verts=6)
for i in range(6):
    y = -0.9 + i * 0.36
    for sx in (-1, 1):
        cyl(0.03, H - 0.16, (sx * W / 2, y, H / 2), (0, 0, 0), iron, "BarSide", root, verts=6)
# 稻草
for k in range(7):
    box((0.5, 0.35, 0.06), (-0.9 + k * 0.3, 0.3 * ((k % 3) - 1), 0.19), straw, "Straw", root, rot=(0, 0, k * 0.7))
door = empty("Door", (-W / 2, -D / 2, 0), root)
for i in range(9):
    x = -1.2 + i * 0.3
    cyl(0.03, H - 0.16, (x, -D / 2, H / 2), (0, 0, 0), iron, "DoorBar", door, verts=6)
box((W - 0.1, 0.06, 0.07), (0, -D / 2, 0.35), iron, "DoorRailLow", door)
box((W - 0.1, 0.06, 0.07), (0, -D / 2, H - 0.25), iron, "DoorRailHigh", door)
box((0.22, 0.12, 0.2), (W / 2 - 0.25, -D / 2 - 0.08, 0.75), gold, "Lock", door)
bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.02, location=(W / 2 - 0.25, -D / 2 - 0.08, 0.9), rotation=(math.radians(90), 0, 0), major_segments=10, minor_segments=4)
finish(bpy.context.object, gold, "Shackle", door)
export(outdir + "/cage.glb")
