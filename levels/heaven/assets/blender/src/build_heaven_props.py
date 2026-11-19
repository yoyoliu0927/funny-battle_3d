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


