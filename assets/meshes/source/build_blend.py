import json, sys, bpy
S, MODEL = sys.argv[-2], sys.argv[-1]
import importlib
sys.path.insert(0, S)
g = importlib.import_module(MODEL.lower() + '_geo')

bpy.ops.wm.read_factory_settings(use_empty=True)
COLORS = {'Body': (0.93, 0.92, 0.88), 'Trim': (0.028, 0.03, 0.035), 'Glass': (0.02, 0.03, 0.07),
          'Head': (1, 0.96, 0.82), 'Tail': (1, 0.02, 0.04), 'Lamp': (1, 0.82, 0.32), 'Chrome': (0.58, 0.61, 0.67)}
mats = {}
for k, c in COLORS.items():
    m = bpy.data.materials.new(k); m.diffuse_color = (*c, 1); m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']; bsdf.inputs['Base Color'].default_value = (*c, 1)
    bsdf.inputs['Roughness'].default_value = 0.6
    if k in ('Head', 'Tail', 'Lamp'):
        bsdf.inputs['Emission Color'].default_value = (*c, 1); bsdf.inputs['Emission Strength'].default_value = 1.5
    mats[k] = m

OPTIONS = {'HoodScoop': 'Hood_Scoop', 'HoodScoopMouth': 'Hood_Scoop', 'HoodVents': 'Hood_Scoop', 'GrilleBar': None,
           'Wing': 'Wing_Rally', 'WingBlade': 'Wing_Rally', 'LampPod': 'Bumper_Lamps', 'RallyLamp': 'Bumper_Lamps'}
root = bpy.data.collections.new(MODEL); bpy.context.scene.collection.children.link(root)
cols = {}
def col(name):
    if name not in cols:
        c = bpy.data.collections.new(name); root.children.link(c); cols[name] = c
    return cols[name]

for p in g.build('full'):
    name = p['name']
    opt = OPTIONS.get(name)
    objname = ('Opt_' + opt + '_' + name) if opt else name
    me = bpy.data.meshes.new(objname)
    # repère du jeu (X droite, Y haut, avant -Z) -> Blender (X droite, Z haut, avant +Y)
    verts = [(x, -z, y) for x, y, z in p['verts']]
    me.from_pydata(verts, [], p['faces']); me.update()
    me.materials.append(mats[p['paint']])
    for poly in me.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(objname, me)
    ob['Paint'] = p['paint']
    col('Option_' + opt if opt else ('Glass' if p['paint'] == 'Glass' else 'Body')).objects.link(ob)

bpy.ops.wm.save_as_mainfile(filepath=S + '/export/' + MODEL + '.blend')
bpy.ops.export_scene.gltf(filepath=S + '/export/' + MODEL + '.glb', export_format='GLB', export_yup=True, export_apply=True)
bpy.ops.export_scene.fbx(filepath=S + '/export/' + MODEL + '.fbx', axis_forward='Z', axis_up='Y', apply_unit_scale=True, global_scale=1.0, mesh_smooth_type='FACE')
print('objets', len(bpy.data.objects), 'triangles', sum(sum(len(pl.vertices) - 2 for pl in o.data.polygons) for o in bpy.data.objects))
