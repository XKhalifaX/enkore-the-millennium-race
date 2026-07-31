# [Working Title] — Technical Document

> Status: **Draft v0.1** — living document. Scoped to **Iteration 1** (feel + race), with a forward-looking data model so later iterations don't require rewrites.
> Companion to [VISION.md](VISION.md). Last updated: 2026-07-31

---

## 1. Engine & stack

- **Engine:** Godot 4.6
- **Languages:** C# (game logic/systems) + GDScript (vehicle physics — the existing rig is GDScript, keep it)
- **Physics:** Jolt Physics (already the project default)
- **Render:** Forward+ / D3D12
- **Addons in use:** Terrain3D, Sky3D (available for the arena; may or may not be needed if the arena is more built/enclosed than open terrain)

---

## 2. What we reuse vs. cut

### Reuse (the salvage)
- **`Systems/Vehicle_System/` — the whole simcade rig is the crown jewel.**
  - `vehicle.gd` (`MeridianVehicle`, RigidBody3D), `wheel.gd` (`MeridianWheel`), `cam.gd` (chase camera), `engine_sound.gd`, `wheel_smoke.gd`, `gui.gd`, `debug*.gd`.
  - **Re-tune toward arcade feel** (more grip forgiveness, snappier response, less punishing slip) rather than rewrite. Keep the raycast-wheel model.
- **Sky3D / Terrain3D / water shaders** — available for arena dressing.

### Cut (belongs to the dead sandbox direction)
- `Systems/Player_Sys/` (on-foot movement, stats, equip, interactor) — the player *is* the car now.
- `Systems/Item_System/` (inventory, items, weapon defs) — not needed for the racer.
- `Systems/NPC_System/` (Ped_Manager, NPC_Controller) — replaced by AI *drivers*.
- `Systems/World_Sys/IInteractable.cs`, `Gas_Station/`, on-foot `player.tscn`.
- **`vehicle_Interactable.cs` (enter/exit vehicle)** — in a pure racer the player controls the car directly; no walk-up-and-enter. Cut for iteration 1.

### Repurpose
- **`PlayerState.cs` → a lightweight race state** (`Countdown`, `Racing`, `Finished`, `Wrecked`, `Spectating`). Much of the old machine collapses; keep the pattern, drop the on-foot modes.

---

## 3. Core architectural decision: decouple input from the vehicle

The single most important refactor. Right now the vehicle reads input directly. To let **player and AI share the exact same car**, the vehicle must not know *who* is driving.

- **`MeridianVehicle`** exposes a control surface, e.g.:
  `set_control_input(throttle: float, brake: float, steer: float, handbrake: bool)`
  and stops reading `Input` itself.
- **Controllers** feed it each physics frame:
  - **`PlayerDriver`** — reads keyboard/gamepad → calls `set_control_input`.
  - **`AIDriver`** — computes desired throttle/steer from the racing line → calls `set_control_input`.
- Payoff: one vehicle, two brains, identical physics. Rivals feel fair because they *are* running your car model. This also makes "rivals double as playable characters" (Vision §5) almost free.

---

## 4. Iteration 1 — system breakdown

**Goal:** prove the driving + racing is fun. One arena, one player car, N AI rivals, one race. No roguelike, no upgrades, no destruction.

### 4.1 Arena (`The Millennium Tournament`)
- One environment scene containing: the drivable circuit geometry, a **start/finish line**, an ordered set of **checkpoint gates**, and a **starting grid** of spawn points.
- Collision + (if AI uses navigation) a racing-line path. Recommend a hand-placed **racing-line Path3D** for AI in iter 1 — simplest, most controllable.

### 4.2 Arcade vehicle
- Reused rig, arcade-tuned. Expose the control surface (§3).
- Handling profile stored as data (see §5) so different cars/characters can feel different later without code changes.

### 4.3 Race manager (`RaceManager`, C#)
- Owns race lifecycle: **grid spawn → countdown → GO → racing → finish → standings**.
- Tracks each racer's progress: `currentCheckpointIndex`, `lapCount`, and distance-to-next-checkpoint.
- **Live position** = sort racers by `(lapCount desc, checkpointIndex desc, distanceToNextCheckpoint asc)`.
- Detects race completion (target lap count) → emits finish → win/lose result.

### 4.4 Checkpoints (`Checkpoint`, Area3D)
- Ordered gates. A racer must pass them in sequence; the last one before start/finish validates a lap. Prevents corner-cutting and drives the position sort.

### 4.5 Rival AI (`AIDriver`)
- Iteration-1 simplicity: follow the **racing-line Path3D**, steer toward a look-ahead point, throttle based on upcoming curvature (slow for corners), basic collision nudging.
- Keep AI **uniform** for iter 1 (the weighted "character rivals" with unique threat behavior are Iteration 4). A field of competent-but-plain AI is enough to answer "is racing fun?"
- Light rubber-banding optional, off by default until we playtest.

### 4.6 Camera
- Reuse `cam.gd` chase cam; tune follow distance/damping for arcade readability.

### 4.7 HUD (`RaceHUD`, CanvasLayer)
- Position (e.g. 3/8), current lap (2/3), lap time, speed. Built in code like the old status UIs, or a `.tscn` — either is fine.

### 4.8 Flow
- Simple: race scene loads → countdown → race → results overlay → **restart**. No menus needed for iter 1 (menu/car-select is a later iteration).

### Definition of Done (Iteration 1)
- [ ] Player drives an arcade-tuned car in the arena with satisfying feel.
- [ ] N AI rivals complete the circuit and compete for position.
- [ ] Countdown start, lap + checkpoint tracking, live positions, finish + final standings.
- [ ] HUD shows position / lap / time / speed.
- [ ] Results screen → restart.
- [ ] **The honest gut-check: is it fun to replay this one race?** If no, iterate the *feel* before adding anything.

---

## 5. Forward-looking data model (build once, don't repaint)

Use **Godot Resources** (the old `ItemDefinition` pattern was clean — reuse the approach) so everything is data-driven and inspector-editable. Define the shells now even if later iterations fill them in.

- **`VehicleTuning` (Resource)** — handling profile (grip, throttle response, brake force, steering, mass feel). Lets each car/character drive differently without code. *Used in iter 1.*
- **`CharacterDefinition` (Resource)** — id, display name, visuals/model ref, `VehicleTuning` ref, and (later) a `SignatureAbility` ref. *Iter 1 can use one minimal instance.*
- **`SignatureAbility` (Resource, base class)** — the "cursed technique" hook. *Stub only in iter 1.* (Iteration 3.)
- **`UpgradeDefinition` (Resource)** — a drafted run upgrade; must define an *effect*, not just a stat number (Vision Commandment 1). *Stub only.* (Iteration 3.)
- **`RunState` (runtime object)** — current character, drafted upgrades, tournament round, power scaling. *Not built in iter 1.* (Iteration 3.)

Designing `CharacterDefinition` + `VehicleTuning` now means the roguelike/character layers later plug in without touching the vehicle or race code.

---

## 6. Suggested folder structure (you own final organization)

A clean split of *new game code* from *reused rig* and *content*:

```
res://
  Game/
    Vehicle/      # arcade vehicle wrapper + control surface (wraps the reused rig)
    Racing/       # RaceManager, Checkpoint, standings/position logic
    AI/           # AIDriver
    Player/       # PlayerDriver (input -> vehicle)
    Camera/       # chase cam
    UI/           # RaceHUD, results screen
    State/        # race state machine (repurposed PlayerState)
    Data/         # VehicleTuning, CharacterDefinition, (stubs) SignatureAbility, UpgradeDefinition
  Arena/          # The Millennium Tournament scene, geometry, racing-line Path3D, checkpoints, grid
  Vehicles/       # your ready-made vehicle models + scenes
  Characters/     # character definitions + visuals
  docs/           # VISION.md, TECHNICAL.md
  _legacy/        # (optional) park the cut sandbox systems here instead of deleting, until sure
```

> Tip: move the cut sandbox systems into `_legacy/` rather than deleting outright — cheap insurance while the pivot settles. Delete once iteration 1 proves out.

---

## 7. Iteration roadmap (from VISION §9, technical framing)

1. **Iter 1 — Feel + race** *(this doc's focus)*: drive, rivals, one race, standings.
2. **Iter 2 — Weight & carnage**: two-way damage, wreck states, destruction feedback, weighted-rival presence.
3. **Iter 3 — The run**: `SignatureAbility` + `UpgradeDefinition` draft + `RunState` power curve.
4. **Iter 4+ — Tournament & cast**: phase-based round objectives, meta-progression, multiple characters, the overlord/host.

Each iteration ends with a playtest and the same question: *is it more fun than before?*
```
