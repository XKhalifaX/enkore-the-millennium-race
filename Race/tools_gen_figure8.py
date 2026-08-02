"""Generate a figure-8 test track scene for Enkore.

Centerline is a Gerono lemniscate:  x = A*sin(t),  z = (B/2)*sin(2t)
which crosses itself once at the origin -> a true figure-8.
"""
import math, io, os

OUT = r"C:/Users/khali/OneDrive/المستندات/enkore--the-milennium-race/Race/test_track_figure8.tscn"

# --- Track parameters ------------------------------------------------------
A          = 130.0   # half-extent along X  (total length 260 m)
B          = 150.0   # total extent along Z (z spans -75..75)
ROAD_W     = 16.0
ROAD_THICK = 0.6
ROAD_TOP   = 0.02    # sit just above the ground plane (top at y=0)
NSEG       = 72

WALL_H     = 2.5
WALL_T     = 1.0
WALL_SKIP_R = 30.0   # no walls this close to the crossing (keep intersection open)

N_CP       = 10      # checkpoint gates
CP_T0      = math.pi / 2.0   # start/finish at the right-hand loop apex (clear of crossing)
GATE_BASE_W = 10.0   # width of the box in checkpoint.tscn
GATE_W     = ROAD_W + 6.0

ROAD_CY  = ROAD_TOP - ROAD_THICK / 2.0
WALL_CY  = ROAD_TOP + WALL_H / 2.0
WALL_OFF = ROAD_W / 2.0 + WALL_T / 2.0


def C(t):
    return (A * math.sin(t), (B / 2.0) * math.sin(2.0 * t))


def tangent(t):
    dx = A * math.cos(t)
    dz = B * math.cos(2.0 * t)
    n = math.hypot(dx, dz)
    return (dx / n, dz / n)


def basis_from_dir(dx, dz, sx, sy, sz):
    """Right-handed basis with +Z along (dx,dz), +Y up, scaled per axis.
    Returns the 9 numbers in .tscn order (x-axis, y-axis, z-axis)."""
    zx, zz = dx, dz
    # X = Y cross Z  with Y = (0,1,0)
    xx, xz = zz, -zx
    return (xx * sx, 0.0, xz * sx,
            0.0, sy, 0.0,
            zx * sz, 0.0, zz * sz)


def f(v):
    return ("%.5f" % v).rstrip("0").rstrip(".") or "0"


def xform(b, ox, oy, oz):
    return "Transform3D(%s)" % ", ".join(f(v) for v in (b[0], b[1], b[2], b[3], b[4],
                                                        b[5], b[6], b[7], b[8], ox, oy, oz))


ext = []          # (type, uid, path, id)
sub = []          # raw text blocks
nodes = io.StringIO()

ext.append(('PackedScene', 'uid://dt2ybpq5gbr2e', 'res://Vehicle_System/vehicle_sys_test.tscn', '1_car'))
ext.append(('Script', 'uid://cv1ix08r15fwd', 'res://Race/race_manager.gd', '2_rm'))
ext.append(('Script', 'uid://d3e7x50s66e7q', 'res://Race/race_hud.gd', '3_hud'))
ext.append(('PackedScene', None, 'res://Race/checkpoint.tscn', '4_cp'))
ext.append(('Texture2D', 'uid://dpfg6gl8qcmco', 'res://Textures/prototype_512x512_grey3.png', '5_tex_road'))
ext.append(('Texture2D', 'uid://5pe2qqi0t4db', 'res://Textures/prototype_512x512_grey1.png', '6_tex_wall'))

# --- shared sub-resources --------------------------------------------------
sub.append('''[sub_resource type="StandardMaterial3D" id="Mat_road"]
albedo_color = Color(0.32, 0.33, 0.36, 1)
albedo_texture = ExtResource("5_tex_road")
roughness = 0.9
uv1_triplanar = true
uv1_world_triplanar = true''')

sub.append('''[sub_resource type="StandardMaterial3D" id="Mat_wall"]
albedo_color = Color(0.85, 0.25, 0.35, 1)
albedo_texture = ExtResource("6_tex_wall")
roughness = 0.8
uv1_triplanar = true
uv1_world_triplanar = true''')

sub.append('''[sub_resource type="StandardMaterial3D" id="Mat_ground"]
albedo_color = Color(0.16, 0.17, 0.2, 1)
roughness = 1.0''')

sub.append('''[sub_resource type="BoxShape3D" id="Shape_ground"]
size = Vector3(600, 1, 600)''')
sub.append('''[sub_resource type="BoxMesh" id="Mesh_ground"]
size = Vector3(600, 1, 600)''')

sub.append('''[sub_resource type="ProceduralSkyMaterial" id="Sky_mat"]''')
sub.append('''[sub_resource type="Sky" id="Sky"]
sky_material = SubResource("Sky_mat")''')
sub.append('''[sub_resource type="Environment" id="Env"]
background_mode = 2
sky = SubResource("Sky")
ambient_light_source = 3
tonemap_mode = 2''')

# Deduped box shapes/meshes keyed by rounded (w,h,l)
box_cache = {}


def box_ids(w, h, l):
    key = (round(w, 2), round(h, 2), round(l, 2))
    if key not in box_cache:
        n = len(box_cache)
        sid, mid = "Shape_b%d" % n, "Mesh_b%d" % n
        sub.append('[sub_resource type="BoxShape3D" id="%s"]\nsize = Vector3(%s, %s, %s)'
                   % (sid, f(key[0]), f(key[1]), f(key[2])))
        sub.append('[sub_resource type="BoxMesh" id="%s"]\nsize = Vector3(%s, %s, %s)'
                   % (mid, f(key[0]), f(key[1]), f(key[2])))
        box_cache[key] = (sid, mid)
    return box_cache[key]


def emit_box(parent, name, w, h, l, b, ox, oy, oz, mat, groups=None):
    sid, mid = box_ids(w, h, l)
    g = ' groups=["%s"]' % groups if groups else ""
    nodes.write('\n[node name="%s" type="StaticBody3D" parent="%s"%s]\n' % (name, parent, g))
    nodes.write("transform = %s\n" % xform(b, ox, oy, oz))
    nodes.write('\n[node name="CollisionShape3D" type="CollisionShape3D" parent="%s/%s"]\n'
                % (parent, name))
    nodes.write('shape = SubResource("%s")\n' % sid)
    nodes.write('\n[node name="MeshInstance3D" type="MeshInstance3D" parent="%s/%s"]\n'
                % (parent, name))
    nodes.write('mesh = SubResource("%s")\n' % mid)
    nodes.write('surface_material_override/0 = SubResource("%s")\n' % mat)


# --- root ------------------------------------------------------------------
nodes.write('[node name="TestTrackFigure8" type="Node3D"]\n')

nodes.write('\n[node name="Ground" type="StaticBody3D" parent="." groups=["Road"]]\n')
nodes.write("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)\n")
nodes.write('\n[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]\n')
nodes.write('shape = SubResource("Shape_ground")\n')
nodes.write('\n[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]\n')
nodes.write('mesh = SubResource("Mesh_ground")\n')
nodes.write('surface_material_override/0 = SubResource("Mat_ground")\n')

nodes.write('\n[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]\n')
nodes.write("transform = Transform3D(1, 0, 0, 0, 0.642788, 0.766044, 0, -0.766044, 0.642788, 0, 60, 0)\n")
nodes.write("shadow_enabled = true\n")

nodes.write('\n[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n')
nodes.write('environment = SubResource("Env")\n')

# --- road ------------------------------------------------------------------
nodes.write('\n[node name="Track" type="Node3D" parent="."]\n')

for i in range(NSEG):
    t0 = 2 * math.pi * i / NSEG
    t1 = 2 * math.pi * (i + 1) / NSEG
    x0, z0 = C(t0)
    x1, z1 = C(t1)
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    dx, dz = x1 - x0, z1 - z0
    seg_len = math.hypot(dx, dz)
    if seg_len < 1e-6:
        continue
    dx, dz = dx / seg_len, dz / seg_len
    b = basis_from_dir(dx, dz, 1.0, 1.0, 1.0)
    emit_box("Track", "Road%02d" % i, ROAD_W, ROAD_THICK, seg_len * 1.12,
             b, cx, ROAD_CY, cz, "Mat_road", groups="Road")

# --- walls -----------------------------------------------------------------
nodes.write('\n[node name="Walls" type="Node3D" parent="."]\n')

wall_n = 0
for i in range(NSEG):
    t0 = 2 * math.pi * i / NSEG
    t1 = 2 * math.pi * (i + 1) / NSEG
    x0, z0 = C(t0)
    x1, z1 = C(t1)
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    dx, dz = x1 - x0, z1 - z0
    seg_len = math.hypot(dx, dz)
    if seg_len < 1e-6:
        continue
    dx, dz = dx / seg_len, dz / seg_len
    nx, nz = dz, -dx           # left normal
    for side in (1.0, -1.0):
        wx = cx + nx * WALL_OFF * side
        wz = cz + nz * WALL_OFF * side
        if math.hypot(wx, wz) < WALL_SKIP_R:      # keep the crossing open
            continue
        b = basis_from_dir(dx, dz, 1.0, 1.0, 1.0)
        emit_box("Walls", "Wall%03d" % wall_n, WALL_T, WALL_H, seg_len * 1.12,
                 b, wx, WALL_CY, wz, "Mat_wall")
        wall_n += 1

# --- checkpoints -----------------------------------------------------------
nodes.write('\n[node name="Checkpoints" type="Node3D" parent="."]\n')

sx = GATE_W / GATE_BASE_W
for k in range(N_CP):
    t = CP_T0 + 2 * math.pi * k / N_CP
    x, z = C(t)
    dx, dz = tangent(t)
    b = basis_from_dir(dx, dz, sx, 1.0, 1.0)
    nm = "CP%02d_StartFinish" % k if k == 0 else "CP%02d" % k
    nodes.write('\n[node name="%s" parent="Checkpoints" instance=ExtResource("4_cp")]\n' % nm)
    nodes.write("transform = %s\n" % xform(b, x, ROAD_TOP + 2.5, z))

# --- grid ------------------------------------------------------------------
nodes.write('\n[node name="Grid" type="Node3D" parent="."]\n')

# Just AFTER the start/finish gate, so the first gate reached is CP01.
for j, (ahead, lateral) in enumerate([(10.0, -4.0), (10.0, 4.0), (20.0, -4.0), (20.0, 4.0)]):
    t = CP_T0 + ahead / 200.0     # small step along the curve
    x, z = C(t)
    dx, dz = tangent(t)
    nx, nz = dz, -dx
    px, pz = x + nx * lateral, z + nz * lateral
    # Car forward is -Z, so the basis Z axis points backwards along travel.
    b = basis_from_dir(-dx, -dz, 1.0, 1.0, 1.0)
    nodes.write('\n[node name="Spawn%d" type="Marker3D" parent="Grid"]\n' % j)
    nodes.write("transform = %s\n" % xform(b, px, 0.8, pz))

# --- car + race systems ----------------------------------------------------
nodes.write('\n[node name="Vehicle_Sys_Test" parent="." instance=ExtResource("1_car")]\n')

nodes.write('\n[node name="RaceManager" type="Node" parent="."]\n')
nodes.write('script = ExtResource("2_rm")\n')
nodes.write("total_laps = 2\n")

nodes.write('\n[node name="RaceHUD" type="CanvasLayer" parent="."]\n')
nodes.write('script = ExtResource("3_hud")\n')

# --- assemble --------------------------------------------------------------
head = io.StringIO()
head.write("[gd_scene load_steps=%d format=3]\n\n" % (len(ext) + len(sub) + 1))
for typ, uid, path, rid in ext:
    if uid:
        head.write('[ext_resource type="%s" uid="%s" path="%s" id="%s"]\n' % (typ, uid, path, rid))
    else:
        head.write('[ext_resource type="%s" path="%s" id="%s"]\n' % (typ, path, rid))
head.write("\n")
for s in sub:
    head.write(s + "\n\n")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
    fh.write(head.getvalue() + nodes.getvalue())

print("wrote", OUT)
print("road segments : %d" % NSEG)
print("wall segments : %d" % wall_n)
print("checkpoints   : %d" % N_CP)
print("unique boxes  : %d" % len(box_cache))
print("track extent  : X +/-%.0f  Z +/-%.0f" % (A, B / 2))
# crossing angle sanity
d0 = tangent(0.0)
d1 = tangent(math.pi)
ang = math.degrees(math.acos(max(-1, min(1, d0[0] * d1[0] + d0[1] * d1[1]))))
print("crossing angle: %.1f deg" % ang)
