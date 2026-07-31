class_name RaceManager
extends Node
## Owns the race lifecycle: grid spawn -> countdown -> GO -> laps -> finish.
##
## Zero-wiring by convention. Add this node to the race scene and:
##   - Put Checkpoint gates (in driving order) under a node named "Checkpoints".
##     The first gate is the start/finish line.
##   - Put spawn Marker3Ds under a node named "Grid" (cars face local -Z / forward).
##   - Any MeridianVehicle in the scene is treated as a racer (player now, AI later).
## Override the node names with the exported paths if you prefer.

signal countdown_tick(n: int)                    # 3, 2, 1
signal race_started
signal lap_completed(racer: Node3D, lap: int, total: int)
signal race_finished(results: Array)             # Array of { "racer": Node3D, "time": float }

@export var total_laps := 2
@export var countdown_seconds := 3
@export var checkpoints_path: NodePath           # optional; defaults to a node named "Checkpoints"
@export var grid_path: NodePath                  # optional; defaults to a node named "Grid"

enum State { COUNTDOWN, RACING, FINISHED }
var state: State = State.COUNTDOWN
var race_time := 0.0

var _checkpoints: Array[Checkpoint] = []
var _racers: Array = []                           # Array[RacerProgress]
var _results: Array = []

class RacerProgress:
	var racer: Node3D
	var controller: Node                          # MeridianVehicleController (input gate)
	var next_index := 0                            # which checkpoint index is expected next
	var lap := 0
	var finished := false
	var finish_time := 0.0

func _ready() -> void:
	add_to_group("race_manager")
	_gather_checkpoints()
	_gather_racers()
	if _checkpoints.is_empty():
		push_warning("RaceManager: no Checkpoint gates found. Add them under a 'Checkpoints' node.")
	if _racers.is_empty():
		push_warning("RaceManager: no MeridianVehicle racers found in the scene.")
	for cp in _checkpoints:
		cp.racer_passed.connect(_on_checkpoint_passed)
	_place_on_grid()
	_run_countdown()

func _process(delta: float) -> void:
	if state == State.RACING:
		race_time += delta

# --- Discovery -------------------------------------------------------------

func _gather_checkpoints() -> void:
	_checkpoints.clear()
	var parent := _resolve(checkpoints_path, "Checkpoints")
	if parent:
		for c in parent.get_children():
			if c is Checkpoint:
				_checkpoints.append(c)

func _gather_racers() -> void:
	_racers.clear()
	var cp_count := _checkpoints.size()
	for v in _find_vehicles(get_tree().root):
		var rp := RacerProgress.new()
		rp.racer = v
		var p := v.get_parent()
		if p is MeridianVehicleController:
			rp.controller = p
		# With a full checkpoint ring the first gate to hit is index 1 (0 is the
		# start/finish behind the grid). With a single gate, expect index 0.
		rp.next_index = 1 % maxi(cp_count, 1)
		_racers.append(rp)

func _find_vehicles(node: Node) -> Array:
	var found: Array = []
	if node is MeridianVehicle:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_vehicles(child))
	return found

func _resolve(path: NodePath, fallback_name: String) -> Node:
	if not path.is_empty() and has_node(path):
		return get_node(path)
	return _find_by_name(get_tree().root, fallback_name)

func _find_by_name(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var r := _find_by_name(child, target)
		if r:
			return r
	return null

func _get_grid_spawns() -> Array:
	var grid := _resolve(grid_path, "Grid")
	var spawns: Array = []
	if grid:
		for c in grid.get_children():
			if c is Node3D:
				spawns.append(c)
	return spawns

# --- Lifecycle -------------------------------------------------------------

func _place_on_grid() -> void:
	var spawns := _get_grid_spawns()
	for i in _racers.size():
		var rp: RacerProgress = _racers[i]
		if rp.racer is RigidBody3D:
			rp.racer.freeze = true
			rp.racer.linear_velocity = Vector3.ZERO
			rp.racer.angular_velocity = Vector3.ZERO
		if i < spawns.size():
			rp.racer.global_transform = spawns[i].global_transform

func _run_countdown() -> void:
	state = State.COUNTDOWN
	_set_controls(false)
	for n in range(countdown_seconds, 0, -1):
		countdown_tick.emit(n)
		await get_tree().create_timer(1.0).timeout
	_begin_race()

func _begin_race() -> void:
	state = State.RACING
	for rp in _racers:
		if rp.racer is RigidBody3D:
			rp.racer.freeze = false
	_set_controls(true)
	race_started.emit()

func _set_controls(enabled: bool) -> void:
	for rp in _racers:
		if rp.controller:
			rp.controller.input_enabled = enabled

# --- Progress --------------------------------------------------------------

func _on_checkpoint_passed(racer: Node3D, cp: Checkpoint) -> void:
	if state != State.RACING:
		return
	var rp := _find_racer(racer)
	if rp == null or rp.finished:
		return
	var idx := _checkpoints.find(cp)
	if idx != rp.next_index:
		return  # wrong order — ignore (prevents corner-cutting)

	# Crossing the start/finish line (index 0) completes a lap.
	if idx == 0:
		rp.lap += 1
		lap_completed.emit(racer, rp.lap, total_laps)
		if rp.lap >= total_laps:
			rp.finished = true
			rp.finish_time = race_time
			_results.append({ "racer": racer, "time": race_time })
			_check_finished()

	rp.next_index = (idx + 1) % _checkpoints.size()

func _find_racer(racer: Node3D) -> RacerProgress:
	for rp in _racers:
		if rp.racer == racer:
			return rp
	return null

func _check_finished() -> void:
	for rp in _racers:
		if not rp.finished:
			return
	state = State.FINISHED
	_set_controls(false)
	race_finished.emit(_results)

# --- Queries for the HUD ---------------------------------------------------

func get_racer_count() -> int:
	return _racers.size()

## 1-based live position of a racer (1 = leading). Progress = laps then gates passed.
func get_position(racer: Node3D) -> int:
	var me := _find_racer(racer)
	if me == null:
		return 0
	var ahead := 1
	for rp in _racers:
		if rp != me and _progress(rp) > _progress(me):
			ahead += 1
	return ahead

func get_lap(racer: Node3D) -> int:
	var rp := _find_racer(racer)
	return (rp.lap if rp else 0)

func _progress(rp: RacerProgress) -> float:
	var c := _checkpoints.size()
	if c == 0:
		return rp.lap
	# next_index runs 1..c-1,0; gates cleared this lap = (next_index - 1) mod c.
	var cleared := posmod(rp.next_index - 1, c)
	return float(rp.lap * c + cleared)
