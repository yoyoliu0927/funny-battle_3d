# 用 Blender 建救企鵝模式的小道具和特效零件（低多邊形、平面著色），輸出成 GLB：
#   banana_peel.glb  香蕉皮（四瓣攤開、裡面是淡黃色）
#   fx_star.glb      暈倒時頭上轉圈的星星
#   fx_shard.glb     滑行時腳邊噴的碎冰
#   fx_drop.glb      掉進冰洞濺起來的水滴
# 用法：Blender --background --factory-startup --python build_fx_props.py -- <輸出資料夾>
import bpy, bmesh, sys, math, random
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
outdir = argv[0]
random.seed(7)

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for c in (bpy.data.meshes, bpy.data.materials):
        for x in list(c):
            c.remove(x)

def mat(name, rgb, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Roughness"].default_value = rough
    return m

def obj_from_bm(bm, name, mats):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o

def export(name):
    bpy.ops.object.select_all(action='SELECT')
    path = "%s/%s.glb" % (outdir, name)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True)
    print("EXPORTED", path)

# ---------------------------------------------------------------- 香蕉皮
def banana_peel():
    clear()
    yellow = mat("PeelYellow", (1.0, 0.80, 0.10))
    inside = mat("PeelInside", (1.0, 0.94, 0.66))
    brown = mat("PeelStem", (0.40, 0.25, 0.10))
    bm = bmesh.new()
    # 四瓣：從中間的蒂頭往外垂到地上，尾端微微翹起來
    path = [(0.035, 0.215), (0.10, 0.205), (0.17, 0.135), (0.235, 0.05), (0.33, 0.028), (0.41, 0.05), (0.455, 0.095)]
    width = [0.085, 0.125, 0.14, 0.135, 0.115, 0.075, 0.02]
    thick = 0.03
    for k in range(4):
        ang = k * math.tau / 4 + 0.35 + random.uniform(-0.12, 0.12)
        reach = random.uniform(0.9, 1.08)
        rot = Matrix.Rotation(ang, 4, 'Z')
        top = []
        bot = []
        for i, (r, z) in enumerate(path):
            # 這一段的切線，用來算「往下」的厚度方向
            r0, z0 = path[max(i - 1, 0)]
            r1, z1 = path[min(i + 1, len(path) - 1)]
            t = Vector((r1 - r0, 0, z1 - z0)).normalized()
            n = Vector((-t.z, 0, t.x))          # 朝上（外側）的法線
            c = Vector((r * reach, 0, z))
            w = width[i] * 0.5
            row_t = [bm.verts.new(rot @ (c + Vector((0, -w, 0)))), bm.verts.new(rot @ (c + Vector((0, w, 0))))]
            cb = c - n * thick
            row_b = [bm.verts.new(rot @ (cb + Vector((0, -w * 0.8, 0)))), bm.verts.new(rot @ (cb + Vector((0, w * 0.8, 0))))]
            top.append(row_t)
            bot.append(row_b)
        for i in range(len(path) - 1):
            f = bm.faces.new((top[i][0], top[i + 1][0], top[i + 1][1], top[i][1]))     # 朝上：果皮裡面（淡黃）
            f.material_index = 1
            f = bm.faces.new((bot[i][1], bot[i + 1][1], bot[i + 1][0], bot[i][0]))     # 朝下：果皮外面
            f.material_index = 0
            f = bm.faces.new((top[i][0], bot[i][0], bot[i + 1][0], top[i + 1][0]))
            f.material_index = 0
            f = bm.faces.new((top[i][1], top[i + 1][1], bot[i + 1][1], bot[i][1]))
            f.material_index = 0
        f = bm.faces.new((top[-1][0], top[-1][1], bot[-1][1], bot[-1][0]))
        f.material_index = 0
    # 中間的蒂頭：六角錐台＋咖啡色的頭
    def ring(r, z, n=6):
        return [bm.verts.new((math.cos(i * math.tau / n) * r, math.sin(i * math.tau / n) * r, z)) for i in range(n)]
    rings = [(0.075, 0.14, 0), (0.07, 0.225, 0), (0.045, 0.30, 0), (0.036, 0.315, 2), (0.03, 0.365, 2)]
    prev = None
    for r, z, mi in rings:
        cur = ring(r, z)
        if prev:
            for i in range(6):
                f = bm.faces.new((prev[i], prev[(i + 1) % 6], cur[(i + 1) % 6], cur[i]))
                f.material_index = mi
        prev = cur
    f = bm.faces.new(prev)
    f.material_index = 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bm(bm, "BananaPeel", [yellow, inside, brown])
    export("banana_peel")

# ---------------------------------------------------------------- 星星
def star():
    clear()
    gold = mat("StarGold", (1.0, 0.80, 0.12), 0.5)
    bm = bmesh.new()
    pts = []
    for i in range(10):
        r = 0.2 if i % 2 == 0 else 0.092
        a = math.pi / 2 + i * math.tau / 10
        pts.append(Vector((math.cos(a) * r, 0, math.sin(a) * r)))
    front = bm.verts.new((0, -0.06, 0))
    back = bm.verts.new((0, 0.06, 0))
    rim = [bm.verts.new(p) for p in pts]
    for i in range(10):
        a, b = rim[i], rim[(i + 1) % 10]
        bm.faces.new((front, a, b))
        bm.faces.new((back, b, a))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bm(bm, "Star", [gold])
    export("fx_star")

# ---------------------------------------------------------------- 碎冰、水滴
def shard():
    clear()
    ice = mat("Ice", (0.82, 0.94, 1.0), 0.3)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.11, v.co.y * 0.07, v.co.z * 0.16)) * random.uniform(0.75, 1.25)
    obj_from_bm(bm, "Shard", [ice])
    export("fx_shard")

def drop():
    clear()
    water = mat("Water", (0.80, 0.93, 1.0), 0.25)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=0.2)
    for v in bm.verts:
        if v.co.z > 0.05:
            k = v.co.z / 0.2
            v.co.x *= 1.0 - 0.55 * k
            v.co.y *= 1.0 - 0.55 * k
            v.co.z *= 1.0 + 0.9 * k
    obj_from_bm(bm, "Drop", [water])
    export("fx_drop")

banana_peel()
star()
shard()
drop()
