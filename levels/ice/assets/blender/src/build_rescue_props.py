# 用 Blender 建救企鵝模式介面／主角用的小零件（低多邊形、平面著色），輸出到 rescue/ 子資料夾：
#   aim_ring.glb           瞄準時地上的落點圈（四個小三角往內指）
#   fx_ring.glb            細細的圓環（落水的水環、家豪腳下的圈、準星的小圈）
#   rooster_comb.glb       家豪的雞冠
#   rooster_beak.glb       家豪的嘴
#   banana_peel_icon.png   道具格的圖示：直接拿 banana_peel.glb 這個模型算一張透明底的圖（只讀取，不改它）
# 用法：Blender --background --factory-startup --python build_rescue_props.py -- <輸出資料夾> <banana_peel.glb 的路徑>
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
outdir = argv[0]
peel_glb = argv[1]

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

# ---------------------------------------------------------------- 瞄準圈
def aim_ring():
    clear()
    white = mat("AimWhite", (1.0, 1.0, 1.0), 0.6)
    bm = bmesh.new()
    n = 32
    prof = [(0.86, 0.0), (0.83, 0.05), (0.70, 0.05), (0.67, 0.0)]      # 截面：(半徑, 高)，上面比下面窄一點（倒角）
    rings = []
    for i in range(n):
        a = i * math.tau / n
        rings.append([bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for r, z in prof])
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(len(prof) - 1):
            bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
        bm.faces.new((a[-1], b[-1], b[0], a[0]))
    # 四個往內指的小三角（像準星）
    for i in range(4):
        rot = Matrix.Rotation(i * math.tau / 4, 4, 'Z')
        pts = [Vector((0.69, -0.11, 0.0)), Vector((0.69, 0.11, 0.0)), Vector((0.46, 0.0, 0.0))]
        low = [bm.verts.new(rot @ p) for p in pts]
        top = [bm.verts.new(rot @ (Vector((p.x * 0.985, p.y * 0.8, 0.05)))) for p in pts]
        bm.faces.new(top)
        for k in range(3):
            bm.faces.new((low[k], low[(k + 1) % 3], top[(k + 1) % 3], top[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bm(bm, "AimRing", [white])
    export("aim_ring")

# ---------------------------------------------------------------- 家豪的雞冠、嘴
def rooster_parts():
    clear()
    red = mat("CombRed", (0.90, 0.10, 0.10), 0.7)
    bm = bmesh.new()
    # 側面輪廓（y＝前後，負的是前面；z＝高）：三個圓弧的雞冠，中間厚、邊緣薄
    outline = [(-0.10, 0.0), (-0.115, 0.07), (-0.065, 0.115), (-0.03, 0.075), (0.0, 0.145), (0.035, 0.085),
               (0.07, 0.115), (0.115, 0.06), (0.10, 0.0)]
    rim = [bm.verts.new((0, y, z)) for y, z in outline]
    cy = sum(y for y, z in outline) / len(outline)
    left = bm.verts.new((-0.04, cy, 0.05))
    right = bm.verts.new((0.04, cy, 0.05))
    for i in range(len(rim)):
        a, b = rim[i], rim[(i + 1) % len(rim)]
        bm.faces.new((left, a, b))
        bm.faces.new((right, b, a))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bm(bm, "Comb", [red])
    export("rooster_comb")
    clear()
    yel = mat("BeakYellow", (1.0, 0.72, 0.10), 0.6)
    bm = bmesh.new()
    # 嘴：四角錐，尖端朝前（-y）微微往下勾
    base = [bm.verts.new(p) for p in [(-0.055, 0, 0.035), (0.055, 0, 0.035), (0.05, 0, -0.04), (-0.05, 0, -0.04)]]
    mid = [bm.verts.new(p) for p in [(-0.035, -0.08, 0.018), (0.035, -0.08, 0.018), (0.03, -0.075, -0.035), (-0.03, -0.075, -0.035)]]
    tip = bm.verts.new((0, -0.15, -0.03))
    for k in range(4):
        bm.faces.new((base[k], base[(k + 1) % 4], mid[(k + 1) % 4], mid[k]))
        bm.faces.new((mid[k], mid[(k + 1) % 4], tip))
    bm.faces.new(base)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bm(bm, "Beak", [yel])
    export("rooster_beak")

# ---------------------------------------------------------------- 道具格圖示：香蕉皮模型算一張透明底的圖
def banana_icon():
    clear()
    bpy.ops.import_scene.gltf(filepath=peel_glb)
    # Workbench 用的是材質的「檢視顏色」：設成跟模型一樣的顏色（再鮮豔一點，小圖才清楚）
    for m in bpy.data.materials:
        if m.use_nodes and "Principled BSDF" in m.node_tree.nodes:
            c = m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
            m.diffuse_color = (c[0], c[1], c[2], 1.0)
    sc = bpy.context.scene
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = 'ORTHO'
    cam_d.ortho_scale = 1.02
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    cam.location = (0.0, -1.6, 1.9)
    target = Vector((0, 0.0, 0.14))
    d = (target - cam.location).normalized()
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'FLAT'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.show_object_outline = True
    sc.display.shading.object_outline_color = (0.23, 0.16, 0.12)
    sc.display.shading.show_shadows = False
    sc.display.shading.show_cavity = True
    sc.view_settings.view_transform = 'Standard'
    sc.render.film_transparent = True
    sc.render.resolution_x = 160
    sc.render.resolution_y = 160
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.filepath = outdir + "/banana_peel_icon.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", sc.render.filepath)

# ---------------------------------------------------------------- 細圓環（水環、腳下的圈）
def fx_ring():
    clear()
    white = mat("RingWhite", (1.0, 1.0, 1.0), 0.6)
    bm = bmesh.new()
    n = 40
    prof = [(1.0, 0.0), (0.985, 0.035), (0.925, 0.035), (0.91, 0.0)]
    rings = []
    for i in range(n):
        a = i * math.tau / n
        rings.append([bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for r, z in prof])
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(len(prof) - 1):
            bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
        bm.faces.new((a[-1], b[-1], b[0], a[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj_from_bm(bm, "Ring", [white])
    export("fx_ring")

aim_ring()
fx_ring()
rooster_parts()
banana_icon()
