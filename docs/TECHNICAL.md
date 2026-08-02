# Enkore — Technical

> Status: **v0.2 — rewritten 2026-08-02** to describe what is actually built,
> not what was once planned. Companion to [VISION.md](VISION.md) and
> [BACKLOG.md](BACKLOG.md).

---

## 1. Stack

- **Engine:** Godot 4.6 · **Physics:** Jolt · **Render:** Forward+ / D3D12
- **Language:** GDScript. No C# solution exists — see [BACKLOG.md](BACKLOG.md) §7.
- **Addons present:** Terrain3D, Sky3D, gevp (the vehicle rig originates here).

---

## 2. What exists today

Everything below is built, in the repo, and working unless noted.

### Vehicle rig — `Game/VehicleRig/`
The salvaged simcade rig, the oldest and most valuable code in the project.
- `vehicle.gd` (`MeridianVehicle`, RigidBody3D) — brush tire model, raycast
  wheels, ABS, traction control, locking differentials, torque vectoring,
  aerodynamic drag, stability assists, automatic/manual gearbox. Fully
  data-driven through exported properties.
- `wheel.gd` (`MeridianWheel`) — per-wheel suspension, slip and grip; reads
  surface type from the collider's **node group** (`Road`, `Dirt`, `Grass`).
- `cam.gd` chase camera · `engine_sound.gd` · `wheel_smoke.gd` ·
  `gui.gd` (speed/RPM/gear) · `debug.gd` + `debug_ui.gd` (force/slip overlays).
- `vehicle_controllergd.gd` (`MeridianVehicleController`) — reads player input.
- `simcade_car.tscn` — the original hand-built car. `vehicle_sys_test.tscn` —
  the player car assembly (car + camera + HUD + tuning panel).

### Live tuning panel — `Game/VehicleRig/tuning_panel.gd`
Runtime, mouse-driven slider panel (**F1**) wired straight to the vehicle, so
handling is tuned while driving. 17 live parameters across steering, throttle/
brakes, grip, stability and aero. Six presets (Default/Muscle/Sedan/Formula
One/Truck/SUV). **Copy** prints and clipboards the current values so a good
setup can be baked in. Grip changes are pushed into each wheel's live cache.

### Modular vehicle assembler — `Game/Modular/`
Data-driven car construction: new vehicles are a resource setup, not a
hand-built scene.
- `vehicle_definition.gd` (`VehicleDefinition`) — body model, body transform,
  axle geometry (track, axle Z, ride height), chassis collider, name/tint.
- `wheel_definition.gd` (`WheelDefinition`) — wheel model, scale/rotation/
  offset, mirroring, tyre radius. Separate resource, so **any wheel fits any
  body**.
- `modular_vehicle.gd` (`ModularVehicle`, `@tool`) — builds body, collider and
  four raycast wheels from those resources, then runs the normal physics init.
  Rebuilds live in the editor while sliders are dragged, so wheel placement is
  done by eye. Generated nodes are never saved into the scene.

### Race systems — `Game/Racing/`
- `race_manager.gd` (`RaceManager`) — grid spawn → countdown → race → finish.
  Tracks per-racer checkpoint index and lap count; **live position** sorts by
  laps, then gates cleared, then distance to the next gate. Finish order and
  times recorded. Discovers everything by convention (see §3).
- `checkpoint.gd/.tscn` (`Checkpoint`) — ordered Area3D gates. Must be crossed
  in sequence, which is what prevents corner-cutting; the first gate doubles as
  start/finish and validates a lap.
- `race_hud.gd` (`RaceHUD`) — countdown, live lap/position/time, finish screen,
  **R** to restart. Identifies the player as the car driven by the input
  controller (not by scene order).

### AI — `Game/AI/`
- `ai_driver.gd` (`AIDriver`) — writes the **same input fields** the player's
  controller writes, so rivals run identical physics. Steers toward a
  speed-scaled look-ahead point, eases off for bends it can see coming, nudges
  around cars directly ahead, reverses out when stuck. Per-car `skill`,
  `max_speed_kmh`, `corner_sensitivity`.
- **Racing line is generated automatically** as a closed Catmull-Rom spline
  through the checkpoints in placement order — no Path3D authoring needed. A
  hand-made `RacingLine` Path3D still takes priority if one exists.
- `ai_car.tscn` (fixed rig) · `modular_ai_car.tscn` (uses `ModularVehicle`).

### Content & scenes
- `Scenes/Prototype_Race.tscn` — the working arena: PSX arena mesh, road
  blockout, jump pad, checkpoints, grid, race systems, player + AI rivals.
- `Scenes/test_track_figure8.tscn` — generated figure-8 test track.
  `Tools/gen_figure8.py` regenerates it parametrically.
- Input map: WASD/arrows, Space handbrake, Shift clutch, E/Q shift, T gearbox
  toggle. **Keyboard only** — no gamepad yet ([BACKLOG.md](BACKLOG.md) §5).

### Infrastructure
Private GitHub repo with Git LFS for binaries; GitHub Projects board with
milestones per iteration. No CI (removed deliberately — overhead outweighed
value for a solo dev; restorable from history).

---

## 3. Architecture principles

Three rules that the code already follows and should keep following.

**1. Input is decoupled from the vehicle.** The vehicle never reads `Input`; it
exposes `throttle_input` / `steering_input` / `brake_input` / `handbrake_input`
/ `clutch_input`, and a *driver* writes them each physics frame — either
`MeridianVehicleController` (player) or `AIDriver` (rival). One car, two brains,
identical physics. Any node exposing `input_enabled` can be gated by the
`RaceManager` during the countdown.

**2. Content is data, not scenes.** Vehicles are `VehicleDefinition` +
`WheelDefinition` resources assembled by `ModularVehicle`. New cars should never
require new hand-built scenes. Extend this pattern to other content.

**3. Systems discover their world by convention.** `RaceManager` finds gates
under a node named `Checkpoints`, spawns under `Grid`, and treats any
`MeridianVehicle` in the tree as a racer; `AIDriver` builds its line from those
same gates. Placing content requires no wiring.

---

## 4. Project layout

```
Art/     Models/{Arena,Vehicles}, Textures, Shaders    content
Game/    VehicleRig, Modular, Racing, AI               code
Data/    Vehicles/*.tres                               definitions
Scenes/  Prototype_Race, test_track_figure8            playable scenes
Tools/   gen_figure8.py                                dev scripts
addons/  docs/                                         third-party · docs
```

---

## 5. Iterations ahead

Named, not designed. Detail is added when the iteration starts.

- **2 — Weight & Carnage.** Damage and destruction. The one architectural note
  worth recording now: damage must be **two-way** (the player is breakable too),
  and it has to run on the existing shared-physics rig so player and AI take
  damage by the same rules.
- **3 — Progression.** Things that build up and carry forward. Whatever form it
  takes, it plugs into `VehicleDefinition`/`WheelDefinition` and the driver
  control surface rather than modifying the vehicle rig.
- **4 — Cast & Tournament.** Content: racer models, vehicles, the tournament
  holder. Blocked less by code than by the art pipeline
  ([BACKLOG.md](BACKLOG.md) §1).
