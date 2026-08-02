# Structural Backlog

> Living parking lot for pipeline/architecture problems — the things that decide
> whether the project scales or stalls. Nothing here is scheduled; pull an item
> onto the board when its pain becomes real.
> Revised 2026-08-02. See [VISION.md](VISION.md) · [TECHNICAL.md](TECHNICAL.md).

**Iteration work ships the game; this list keeps it shippable.**

For what already exists and works, see [TECHNICAL.md §2](TECHNICAL.md) — that is
the authoritative inventory (vehicle rig, tuning panel, modular vehicle
assembler, lap/checkpoint/position tracking, race HUD, AI driver).

---

## 1. Art pipeline — the top priority

**The pain, today:** exporting a model means hunting down every texture and
reassigning it by hand in Godot. Paid per model, per reimport. It scales with
the cast, and iteration 4 *is* the cast.

**Directions to try, best first:**
- **Export `.glb` (glTF 2.0) instead of FBX** — embeds meshes, materials and
  textures in one file; Godot imports the materials directly.
- **Import `.blend` directly** — Godot 4 can, if pointed at a Blender install.
  Removes the export step entirely.
- **Substance Painter → Godot:** settle one export preset (which maps, packed or
  separate, naming) and the matching Godot material setup.
- **Import presets** so the look is set once, not per texture.
- **"Extract materials"** so reimports stop wiping manual edits.
- **Texture sourcing:** a shortlist of good libraries and a convention for where
  they live in the repo.

**Done when:** dropping in a new vehicle is one import with materials intact.

**Already solved for vehicles:** `ModularVehicle` + `VehicleDefinition` /
`WheelDefinition` — models go into resources and the car assembles itself. That
same "definition resource" pattern is the template for track pieces and props.

---

## 2. Track building

Hand-placing road blocks is slow, and it's the current bottleneck on making the
arena interesting.

- **Modular track kit:** straight / 45° / 90° / chicane / banked pieces that snap
  together. Cheap to author, instantly recombinable.
- **Spline-driven road:** author one curve; extrude road mesh + collision along
  it. Biggest win — **checkpoints and the AI racing line already derive from
  gate order**, so one spline could generate road, gates and line together.
- Prior art in-repo: `Tools/gen_figure8.py` generates road, walls, ordered gates
  and a grid from math.

---

## 3. Asset budget

Unanswered, and it drives the whole schedule for iteration 4.

| Asset | Status |
|---|---|
| Racer vehicles | 2 models (assembler makes more cheap to add) |
| Arena | blockout + PSX arena mesh |
| Checkpoint / start-finish gate | placeholder box |
| Track surface + barrier kit | prototype boxes |
| Tournament holder | none — needs an identity |
| VFX | smoke only |
| Audio | engine only |
| UI / HUD | code-drawn placeholder |

**Decision needed:** how many racers and vehicles does the target build ship
with? That number sets the art budget.

---

## 4. Per-vehicle tuning data

Handling presets live only in the runtime tuning panel; nothing persists them,
and each vehicle should feel different.

**Known blocker:** `MeridianVehicle.initialize()` appends to `wheel_array` /
`axles` without clearing, so it **cannot safely run twice**. Mass, suspension and
brake force are baked there — which is why runtime presets can only change
steering/power/grip, and a "Truck" is sluggish rather than genuinely heavy.
Fixing re-init (or applying tuning *before* first init) unlocks real per-vehicle
weight, and is a prerequisite for vehicles that feel meaningfully distinct.

---

## 5. Gamepad input

Keyboard only. The rig already reads `Input.get_action_strength()` and supports
analog, so a controller would give proportional throttle and steering almost for
free — nothing is bound yet. Cheap, and a large feel improvement.

---

## 6. Language: GDScript vs C#

Everything is GDScript; there is no C# solution. That's a fine outcome — but it
should be a decision, not a drift. Either commit to GDScript-only, or define the
rule for when C# is introduced. Mixing without a rule is the bad ending.

---

## 7. Known rough edges

- Third-party `addons/gevp` demo scenes reference `res://Systems/...` paths that
  don't exist. Harmless (unused vendor samples), left untouched.
- `terrain.gdextension` lists Linux arm64/rv64 binaries that aren't shipped.
  Harmless on Windows.
- CI was removed deliberately; restorable from git history if ever wanted.
