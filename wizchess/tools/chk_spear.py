import bpy
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/wizchess/models/knight_b.glb')
sc=bpy.context.scene; sc.render.fps=30
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
sp=[o for o in bpy.data.objects if o.name.startswith('spear')][0]
import numpy as np
cam=bpy.data.objects.new("c",bpy.data.cameras.new("c")); sc.collection.objects.link(cam); sc.camera=cam
for loc in ((3,-4,4),(-3,4,4),(0,-5,1),(4,0,2)):
    l=bpy.data.objects.new("l",bpy.data.lights.new("l","POINT")); l.data.energy=1500; l.location=loc; sc.collection.objects.link(l)
mk=bpy.data.materials.new("r"); mk.use_nodes=True; mk.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value=(1,0,0,1); mk.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value=20
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06); ball=bpy.context.object; ball.data.materials.append(mk)
sc.render.engine="CYCLES"; sc.cycles.samples=8; sc.render.resolution_x=400; sc.render.resolution_y=420
for i,(an,fr) in enumerate((("idle",0),("walk",10),("throw",58),("throw",66),("throw",71))):
    act=[a for a in bpy.data.actions if a.name.startswith(an)][0]
    arm.animation_data.action=act; sc.frame_set(fr); bpy.context.view_layer.update()
    ws=[sp.matrix_world@v.co for v in sp.data.vertices]
    # остриё: самая дальняя точка от кисти
    pb=arm.pose.bones[[b.name for b in arm.pose.bones if b.name.endswith('RightHand')][0]]
    h=arm.matrix_world@pb.head
    ball.location=max(ws,key=lambda p:(p-h).length) if False else None or ball.location
    # дальний конец в направлении меньшей толщины не знаем — отмечаем ОБА конца: ближний к острию по ширине
    pts=np.array([list(p) for p in ws]); c=pts.mean(0); w,v=np.linalg.eigh((pts-c).T@(pts-c)); A=v[:,-1]; pr=(pts-c)@A
    def wid(m):
        q=pts[m]-c; r=q-np.outer(q@A,A); return np.linalg.norm(r,axis=1).max()
    L=pr.max()-pr.min()
    a_end=wid(pr>pr.max()-0.06*L); b_end=wid(pr<pr.min()+0.06*L)
    # остриё — конец, у которого первые 6% самые тонкие? проверяем оба и печатаем
    tip=pts[pr.argmax()] if a_end<b_end else pts[pr.argmin()]
    ball.location=Vector(tip)
    fwd=Vector((0,-1,0)); d=(Vector(tip)-h).normalized()
    print(an,fr,"tip-from-hand dir",tuple(round(x,2) for x in d),"endwidths",round(a_end,3),round(b_end,3))
    cam.location=(3.4,-1.8,1.2); dd=Vector((0,-0.4,0.95))-cam.location; cam.rotation_euler=dd.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f'/tmp/claude-0/sk_{i}.png'; bpy.ops.render.render(write_still=True)
