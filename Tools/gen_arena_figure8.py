"""Rebuild the figure-8 checkpoint layout inside the arena pillars."""
import math, re

SCENE = r"C:/Users/khali/OneDrive/المستندات/enkore--the-milennium-race/Scenes/Prototype_Race.tscn"

# Arena bounds from the corner pillars (position +/- half of their 4.95 x 4.89 box)
PX_MIN, PX_MAX = -96.34793, 63.993423
PZ_MIN, PZ_MAX = -120.899376, 100.58082
PILLAR_HALF_X, PILLAR_HALF_Z = 4.9460115 / 2, 4.89465 / 2

CX = (PX_MIN + PX_MAX) / 2.0
CZ = (PZ_MIN + PZ_MAX) / 2.0

# Two lobes stacked along Z (the arena's long axis), crossing at the centre.
#   x(t) = CX + WX * sin(2t)      z(t) = CZ + LZ * sin(t)
WX = 58.0
LZ = 90.0

N_GATES = 10
T0 = math.pi / 2.0          # start/finish at the top lobe apex
GATE_BASE_W = 10.0          # width of the box inside checkpoint.tscn
GATE_W = 26.0               # generous: the whole floor is drivable
GATE_Y = 1.33               # keep the existing gate height
JUMP_Y = -0.19624346
GRID_Y = 1.10


def pos(t):
    return (CX + WX * math.sin(2 * t), CZ + LZ * math.sin(t))


def tangent(t):
    dx = 2 * WX * math.cos(2 * t)
    dz = LZ * math.cos(t)
    n = math.hypot(dx, dz)
    return (dx / n, dz / n)


def f(v):
    return ("%.5f" % v).rstrip("0").rstrip(".") or "0"


def basis(dx, dz, sx=1.0):
    """+Z along (dx,dz), +Y up, right-handed. X scaled by sx."""
    return (dz * sx, 0.0, -dx * sx, 0.0, 1.0, 0.0, dx, 0.0, dz)


def xform(b, ox, oy, oz):
    return "Transform3D(%s)" % ", ".join(
        f(v) for v in (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], ox, oy, oz))


# --- build the node blocks -------------------------------------------------
out = []
out.append('[node name="Grid" type="Node3D" parent="."]\n')

# Grid sits just after the start/finish gate, along the direction of travel.
for j, (ahead_t, lateral) in enumerate(
        [(0.045, -4.5), (0.045, 4.5), (0.085, -4.5), (0.085, 4.5)]):
    t = T0 + ahead_t
    x, z = pos(t)
    dx, dz = tangent(t)
    nx, nz = dz, -dx                      # left normal
    px, pz = x + nx * lateral, z + nz * lateral
    # Car forward is -Z, so the basis Z axis points backwards along travel.
    b = basis(-dx, -dz)
    out.append('\n[node name="Spawn%d" type="Marker3D" parent="Grid"]\n' % (j + 1))
    out.append("transform = %s\n" % xform(b, px, GRID_Y, pz))

out.append('\n[node name="Checkpoints" type="Node3D" parent="."]\n')
out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)\n" % f(GATE_Y))

sx = GATE_W / GATE_BASE_W
gates = []
for k in range(N_GATES):
    t = T0 + 2 * math.pi * k / N_GATES
    x, z = pos(t)
    dx, dz = tangent(t)
    gates.append((x, z))
    nm = "CP01_StartFinish" if k == 0 else "CP%02d" % (k + 1)
    out.append('\n[node name="%s" parent="Checkpoints" instance=ExtResource("8_2b27c")]\n' % nm)
    out.append("transform = %s\n" % xform(basis(dx, dz, sx), x, 0.0, z))

new_block = "".join(out) + "\n"

# --- splice into the scene -------------------------------------------------
src = open(SCENE, encoding="utf-8").read()

start = src.index('[node name="Grid" type="Node3D"')
end = src.index('[node name="ModularAICar2"')
src = src[:start] + new_block + src[end:]

# Jump pad -> the crossing point, keeping its existing scale of 2.
src = re.sub(
    r'(\[node name="Jump_pad"[^\]]*\]\n)transform = Transform3D\([^)]*\)',
    lambda m: m.group(1) + "transform = Transform3D(2, 0, 0, 0, 1, 0, 0, 0, 2, %s, %s, %s)"
              % (f(CX), f(JUMP_Y), f(CZ)),
    src, count=1)

open(SCENE, "w", encoding="utf-8", newline="\n").write(src)

# --- report ----------------------------------------------------------------
print("arena centre      : (%.2f, %.2f)" % (CX, CZ))
print("figure-8 extent   : X %.1f..%.1f   Z %.1f..%.1f"
      % (CX - WX, CX + WX, CZ - LZ, CZ + LZ))
print("pillar inner face : X %.1f..%.1f   Z %.1f..%.1f"
      % (PX_MIN + PILLAR_HALF_X, PX_MAX - PILLAR_HALF_X,
         PZ_MIN + PILLAR_HALF_Z, PZ_MAX - PILLAR_HALF_Z))
print("clearance         : X %.1f m   Z %.1f m"
      % ((PX_MAX - PILLAR_HALF_X) - (CX + WX), (PZ_MAX - PILLAR_HALF_Z) - (CZ + LZ)))
print("jump pad          : (%.2f, %.2f)  = crossing point" % (CX, CZ))

worst = min(math.dist(g, (CX, CZ)) for g in gates)
print("\nnearest gate to crossing: %.1f m  (%s)"
      % (worst, "OK" if worst > 25 else "TOO CLOSE"))

lap = sum(math.dist(gates[i], gates[(i + 1) % N_GATES]) for i in range(N_GATES))
print("lap length (gate-to-gate): %.0f m  (~%.0f m through corners)" % (lap, lap * 1.08))
for kmh in (60, 80, 100, 120):
    print("   at avg %3d km/h -> %.1f s lap" % (kmh, lap * 1.08 / (kmh / 3.6)))
