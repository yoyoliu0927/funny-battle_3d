import bpy, sys, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src, outdir = argv[0], argv[1]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
info = []
for o in meshes:
    bb = [o.matrix_world @ mathutils.Vector(c) for c in o.bound_box]
    mn = mathutils.Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = mathutils.Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    d = mx - mn
    info.append((o, mn, mx, d))
stand = [i for i in info if i[3].z / max(i[3].x, i[3].y) > 1.4]
lie = [i for i in info if i[3].z / max(i[3].x, i[3].y) < 0.7]
print("standing", len(stand), "lying", len(lie))
stand.sort(key=lambda i: -i[3].z)
picks = {"penguin_stand": stand[len(stand) // 2][0] if stand else None, "penguin_lie": lie[0][0] if lie else None}
for name, o in picks.items():
    if o is None:
        continue
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    # 拿掉父物件，套用世界座標，移到原點、腳底在 0、高度統一
    mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bb = [mathutils.Vector(c) for c in o.bound_box]
    mn = mathutils.Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = mathutils.Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    ctr = (mn + mx) / 2
    o.data.transform(mathutils.Matrix.Translation((-ctr.x, -ctr.y, -mn.z)))
    # 原本臉朝 +Y（Blender 的後方）；轉 180 度讓臉朝前（Godot 的 +Z）
    import math
    o.data.transform(mathutils.Matrix.Rotation(math.pi, 4, 'Z'))
    h = (mx.z - mn.z) if name == "penguin_stand" else (mx.y - mn.y)
    s = 1.0 / max(h, 1e-6)
    o.data.transform(mathutils.Matrix.Scale(s, 4))
    o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    d2 = o.dimensions
    s2 = 1.0 / max(d2.z if name == "penguin_stand" else d2.y, 1e-6)
    o.data.transform(mathutils.Matrix.Scale(s2, 4))
    bpy.context.view_layer.update()
    print(name, "dims", tuple(round(v, 3) for v in o.dimensions))
    bpy.ops.export_scene.gltf(filepath=f"{outdir}/{name}.glb", export_format='GLB', use_selection=True)
    print("EXPORTED", name)
