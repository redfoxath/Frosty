"""Перепривязка меша к скелету Mixamo по «геодезическому» расстоянию по поверхности.
Оружие, сросшееся с ладонью, уходит к руке, а не к ноге рядом.
Отдельные куски (щит) целиком привязываются к ближайшей кисти/предплечью.
Запуск: python reweight.py in.glb out.glb"""
import bpy, bmesh, sys, heapq
from math import exp
from mathutils import Vector
from mathutils.kdtree import KDTree

src, dst = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
me = [o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm][0]
for o in list(bpy.data.objects):
    if o.type == "MESH" and o != me:
        bpy.data.objects.remove(o)

# кости, которые получают вес; пальцы сливаем в кисть
def canon(n):
    for side in ("Left", "Right"):
        if n.startswith("mixamorig:" + side + "Hand") and n != "mixamorig:" + side + "Hand":
            return "mixamorig:" + side + "Hand"
    if n.endswith("Toe_End"):
        return n.replace("Toe_End", "ToeBase")
    return n

segs = {}
for b in arm.data.bones:
    c = canon(b.name)
    if c != b.name:
        continue
    h = arm.matrix_world @ b.head_local
    t = arm.matrix_world @ b.tail_local
    segs[b.name] = (h, t)
names = list(segs)

def seg_dist(p, h, t):
    d = t - h
    L = d.length_squared
    k = 0.0 if L < 1e-12 else max(0.0, min(1.0, (p - h).dot(d) / L))
    return (h + d * k - p).length

# граф связности на слитой копии
bm = bmesh.new()
bm.from_mesh(me.data)
bm.transform(me.matrix_world)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
bm.verts.ensure_lookup_table()
N = len(bm.verts)
pos = [v.co.copy() for v in bm.verts]
adj = [[] for _ in range(N)]
for e in bm.edges:
    a, b = e.verts[0].index, e.verts[1].index
    w = (pos[a] - pos[b]).length
    adj[a].append((b, w))
    adj[b].append((a, w))
# острова
comp = [-1] * N
islands = []
for i in range(N):
    if comp[i] >= 0:
        continue
    cid = len(islands)
    st = [i]
    comp[i] = cid
    members = []
    while st:
        x = st.pop()
        members.append(x)
        for y, _ in adj[x]:
            if comp[y] < 0:
                comp[y] = cid
                st.append(y)
    islands.append(members)
main = max(range(len(islands)), key=lambda k: len(islands[k]))
print("islands", [len(x) for x in islands])

# евклидовы расстояния до костей
ed = [[seg_dist(pos[i], *segs[n]) for n in names] for i in range(N)]
# семена: вершины, близкие к своей кости
INF = 1e9
geo = {n: [INF] * N for n in names}
for bi, n in enumerate(names):
    pq = []
    for i in islands[main]:
        dmin = min(ed[i])
        if ed[i][bi] <= dmin + 1e-6 and ed[i][bi] < 0.12:
            geo[n][i] = ed[i][bi]
            pq.append((ed[i][bi], i))
    if not pq:
        near = sorted(islands[main], key=lambda i: ed[i][bi])[:25]
        for i in near:
            geo[n][i] = ed[i][bi]
            pq.append((ed[i][bi], i))
    print("seeds", n, len(pq))
    heapq.heapify(pq)
    G = geo[n]
    while pq:
        d, x = heapq.heappop(pq)
        if d > G[x]:
            continue
        for y, w in adj[x]:
            nd = d + w
            if nd < G[y]:
                G[y] = nd
                heapq.heappush(pq, (nd, y))

weights = [None] * N
for i in range(N):
    if comp[i] == main:
        ds = sorted(((geo[n][i], n) for n in names if geo[n][i] < INF))
        if not ds:
            ds = sorted((ed[i][k], names[k]) for k in range(len(names)))
    else:
        ds = None
    if ds:
        d0 = ds[0][0]
        top = [(n, exp(-(d - d0) / 0.012)) for d, n in ds[:3]]
        s = sum(w for _, w in top)
        weights[i] = [(n, w / s) for n, w in top if w / s > 0.02]
# отдельные куски — целиком к ближайшей кисти/предплечью
hand_bones = [n for n in names if any(k in n for k in ("Hand", "ForeArm"))]
for k, isl in enumerate(islands):
    if k == main:
        continue
    c = sum((pos[i] for i in isl), Vector()) / len(isl)
    best = min(hand_bones, key=lambda n: seg_dist(c, *segs[n]))
    print("island", len(isl), "->", best)
    for i in isl:
        weights[i] = [(best, 1.0)]

# перенос на исходные вершины
kd = KDTree(N)
for i, p in enumerate(pos):
    kd.insert(p, i)
kd.balance()
for vg in list(me.vertex_groups):
    me.vertex_groups.remove(vg)
groups = {n: me.vertex_groups.new(name=n) for n in names}
mw = me.matrix_world
for v in me.data.vertices:
    _, idx, _ = kd.find(mw @ v.co)
    for n, w in weights[idx]:
        groups[n].add([v.index], w, "REPLACE")
stats = {}
for i in range(N):
    n = weights[i][0][0] if weights[i] else None
    stats[n] = stats.get(n, 0) + 1
print("dominant", sorted(stats.items(), key=lambda x: -x[1]))
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_skins=True)
print("WROTE", dst)
