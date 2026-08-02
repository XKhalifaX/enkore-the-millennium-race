# Structural Backlog — things to solve *before* they become expensive

> Status: living parking lot. Nothing here is scheduled; it's the list of
> structural/pipeline problems that will bite as the project scales, so they get
> decided deliberately instead of by accident.
> Companion to [VISION.md](VISION.md) and [TECHNICAL.md](TECHNICAL.md).
> Last updated: 2026-08-02

Rule of thumb: iteration work ships the game, this list keeps it *shippable*.
Pull an item into a milestone when its pain becomes real — not before.

---

## 1. Art pipeline: textures should travel with the model

**The pain (live, today):** exporting a model means hunting down every texture
and reassigning it by hand in Godot. That cost is paid *per model, per reimport*,
and it scales linearly with the cast.

**Research directions:**
- **glTF 2.0 (`.glb`) instead of FBX.** A `.glb` embeds meshes, PBR materials and
  textures in one file; Godot imports the materials directly. This is the single
  biggest lever and Blender exports it natively.
- **Direct `.blend` import.** Godot 4 can import `.blend` files if Blender is
  installed (Project Settings → Import → Blender → path). Saves the export step
  entirely; re-saving the .blend reimports in-engine.
- **Import presets.** Set the PSX/stylized look *once* (point filtering, no
  mipmaps, low-res) as a default import preset instead of per-texture.
- **"Extract Materials" / Keep-on-Reimport.** Godot re-generates materials on
  reimport and blows away manual edits unless materials are extracted to disk
  first. Decide the convention before the cast grows.
- **Naming + folder convention** so textures auto-resolve next to the model.

**Definition of done:** dropping a new vehicle into the game is *one* import with
materials intact, not a manual reassembly.

---

## 2. Procedural / modular track generation

**Why:** the arena is one hero environment (VISION §4b), but iterating its layout
by hand-placing road slabs is slow, and later rounds/variants will need more.

**Research directions:**
- **Modular track kit:** straight / 45° / 90° / chicane / banked pieces that snap
  on a grid. Cheap to author, instantly recombinable.
- **Spline-driven mesh:** author a `Path3D`, extrude road mesh + collision along
  it. Biggest win: **checkpoints and the AI racing line can be auto-placed from
  the same spline** (the AI already derives its line from checkpoint order).
- **Full procgen:** seeded layout generation — fits the roguelike framing (a new
  track per run) but is a large commitment; evaluate only after the kit works.
- **Prior art in-repo:** `Race/tools_gen_figure8.py` already generates a full
  track (road, walls, ordered gates, grid) from math — a working seed for this.

**Watch:** VISION commandment 8 — scope the spectacle so it runs flawless.

---

## 3. Asset budget for a demo

**Why:** "how much art does a demo actually need" is unanswered, and it's the
main driver of how long the demo takes. Vision says MVP = 1 arena, 1–2
characters, so the honest floor is small.

**First-pass inventory** (✅ = exists):

| Asset | Need | Status |
|---|---|---|
| Player/rival vehicle models | 3–5 (rivals double as playables, VISION §5) | ✅ 1 |
| Arena environment | 1 (hero, or modular kit) | 🟡 blockout + PSX arena |
| Checkpoint / gate model | 1 + start-finish gantry | ❌ placeholder box |
| Track surface + barrier kit | small set | ❌ prototype boxes |
| Driver / character representation | 1–2 (if visible in-car) | 🟡 Magician model unused |
| Host / overlord figure | 1 | ❌ **[PINNED]** needs original design |
| VFX | smoke ✅, sparks, impact, explosion | 🟡 |
| Audio | engine ✅, impacts, UI, music | 🟡 |
| UI / HUD kit | 1 | 🟡 code-drawn placeholder |

**Open question:** does the demo show 1 arena + 3 rivals, or fewer? That number
sets the art budget — decide before modelling starts.

---

## 4. Data model: per-vehicle/character tuning

**Why:** handling presets (Muscle/Sedan/F1/Truck/SUV) currently exist only at
runtime in the tuning panel. Nothing persists them, and each character needs its
own feel (TECHNICAL §5: `VehicleTuning`, `CharacterDefinition`).

**Known blocker:** `MeridianVehicle.initialize()` appends to `wheel_array`/`axles`
without clearing, so it **cannot be safely called twice**. Mass, suspension and
brake force are baked there — which is why runtime presets can only change
steering/power/grip, and a "Truck" is sluggish rather than genuinely heavy. Fixing
re-init (or applying tuning *before* first init) unlocks real per-vehicle weight.

---

## 5. Input: gamepad / analog steering

Only keyboard keys are mapped. The vehicle rig reads
`Input.get_action_strength()` and fully supports analog, so a controller would
give proportional throttle and steering "for free" — but no joypad events are
bound to the actions yet. Cheap win, big feel improvement, and racers are
controller-first for most players.

---

## 6. Repo & code structure

- TECHNICAL §6 proposes `Game/ Arena/ Vehicles/ Characters/`; the repo currently
  uses `Race/`, `Vehicle_System/` at root. Reorganize once the shape settles —
  moving scenes later breaks paths, so do it deliberately, not twice.
- `godot-realistic-water-master/` is an entire nested Godot project sitting in the
  repo (Godot warns and ignores it). Extract what's needed, delete the rest.
- `Models/Magician/` is quarantined by a `.gdignore` because it references two
  missing textures. Restore or drop it.

---

## 7. Language decision: C# vs GDScript

TECHNICAL §1 specifies C# for game systems, but the race systems (RaceManager,
Checkpoint, RaceHUD, AIDriver) were written in **GDScript** — it matched the
existing rig, needed no C# solution/build step, and kept iteration fast. There is
no `.csproj` in the project today.

**Decide and record:** stay GDScript-only (and update TECHNICAL), or introduce C#
for the heavier roguelike systems later. Mixing without a rule is the bad outcome.

---

## 8. Later-iteration structural work

Flagged so they aren't a surprise when their iteration lands:

- **Damage / destruction model** (Iter 2) — two-way damage, wreck states. The
  single biggest new system; destruction is the *objective*, not garnish.
- **Run/meta state** (Iter 3) — `RunState`, `UpgradeDefinition`, save/persistence.
- **Weighted rival AI** (Iter 4) — per-character threat behavior on top of the
  current uniform `AIDriver`; also rubber-banding policy.
- **Performance budget** — many racers + destruction VFX. Measure before it hurts.
