import bpy
import math
import os

OUT = '/home/sanketh/dreamFocus/assets/models/family_house.glb'

# Clean scene.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    pass

def mat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    return m

wall = mat('Warm plaster', (0.78, 0.58, 0.38))
trim = mat('Cream trim', (0.93, 0.82, 0.61))
roof = mat('Terracotta roof', (0.48, 0.16, 0.10))
door = mat('Blue door', (0.08, 0.25, 0.38))
glass = mat('Window glass', (0.20, 0.58, 0.72))
ground = mat('Ground', (0.28, 0.50, 0.22))

def cube(name, loc, scale, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if bevel:
        mod = o.modifiers.new('Soft edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

# House footprint: 6 x 5, bottom at z=0.
cube('Walls', (0, 0, 1.5), (6, 5, 3), wall, .08)

# Gable roof prism, ridge along Y.
verts = [(-3, -2.7, 3), (3, -2.7, 3), (0, -2.7, 5),
         (-3, 2.7, 3), (3, 2.7, 3), (0, 2.7, 5)]
faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
mesh = bpy.data.meshes.new('GableRoofMesh')
mesh.from_pydata(verts, [], faces)
mesh.update()
roof_obj = bpy.data.objects.new('Roof', mesh)
bpy.context.collection.objects.link(roof_obj)
roof_obj.data.materials.append(roof)

# Front facade is -Y.
cube('FrontDoor', (0, -2.54, 1.1), (1.15, .12, 2.2), door, .04)
for x in (-1.8, 1.8):
    cube('FrontWindow', (x, -2.56, 1.8), (1.15, .12, 1.0), trim, .04)
    cube('FrontGlass', (x, -2.63, 1.8), (.82, .04, .68), glass, .01)
    cube('WindowMullionV', (x, -2.67, 1.8), (.06, .04, .72), trim)
    cube('WindowMullionH', (x, -2.67, 1.8), (.86, .04, .06), trim)

# Side and rear windows establish a readable 3D silhouette.
for y in (-1.35, 1.35):
    cube('SideWindow', (-3.04, y, 1.8), (.12, 1.0, 1.0), trim, .04)
    cube('SideGlass', (-3.11, y, 1.8), (.04, .72, .68), glass, .01)
cube('BackWindow', (0, 2.54, 1.8), (1.3, .12, 1.0), trim, .04)
cube('BackGlass', (0, 2.62, 1.8), (.95, .04, .68), glass, .01)

# Small step and chimney.
cube('FrontStep', (0, -2.85, .12), (1.6, .7, .24), trim, .04)
cube('Chimney', (1.6, .8, 4.0), (.65, .65, 2.0), trim, .03)

# Ground is separate for the standalone GLB preview.
cube('Ground', (0, 0, -.12), (14, 14, .2), ground)

# Parent all house parts to an empty at the ground-centered origin.
bpy.ops.object.empty_add(type='PLAIN_AXES', location=(0, 0, 0))
root = bpy.context.object
root.name = 'FamilyHouse'
for o in list(bpy.context.scene.objects):
    if o != root and o.parent is None:
        o.parent = root

# Export with applied geometry and embedded materials.
bpy.ops.object.select_all(action='SELECT')
for o in bpy.context.selected_objects:
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True, export_materials=True)
print('EXPORTED', OUT)
