class_name AIDriver
extends Node3D
## Drives a [MeridianVehicle] around a racing-line [Path3D].
##
## This is the AI half of the control-surface split (TECHNICAL §3): it writes the
## exact same input fields the player's controller writes, so player and AI run
## identical physics. Parent an AIDriver above a vehicle (see Race/ai_car.tscn)
## and it steers toward a look-ahead point on the racing line, easing off for
## corners it can see coming.
##
## Setup: nothing. By default the driver builds its own smooth racing line
## through the existing Checkpoint gates (a Catmull-Rom spline through the
## children of the "Checkpoints" node, in the order you placed them), so the
## track needs no extra authoring.
##
## Optional: assign [member racing_line] (or add a [Path3D] named "RacingLine")
## to hand-author a better line — it takes priority over the generated one.
##
## Exposes `input_enabled` so RaceManager can hold it on the grid during the
## countdown, exactly like the player's controller.

@export var vehicle : MeridianVehicle
## Optional hand-authored line. Defaults to a Path3D named "RacingLine" if one
## exists; otherwise the line is generated from the checkpoints.
@export var racing_line : Path3D
## When false the driver releases all controls (used during the countdown).
@export var input_enabled := true

@export_group("Racing Line")
## Generate the line from the Checkpoint gates when no Path3D is supplied.
@export var auto_line_from_checkpoints := true
## Corner rounding of the generated line. 0 = straight between gates (cuts
## corners), 1 = full Catmull-Rom curve. Raise it if the AI clips walls.
@export_range(0.0, 2.0) var line_smoothing := 1.0

@export_group("Pace")
## Flat-out target speed on straights.
@export var max_speed_kmh := 150.0
## Slowest the driver will slow to for the tightest corner.
@export var min_corner_speed_kmh := 45.0
## How strongly upcoming bends reduce target speed. Higher = more cautious.
@export var corner_sensitivity := 1.0
## 0 = sloppy backmarker, 1 = clean and quick. Scales pace and reactions.
@export_range(0.0, 1.0) var skill := 1.0

@export_group("Steering")
## Look-ahead distance at a standstill, in metres.
@export var look_ahead_min := 10.0
## Extra metres of look-ahead per m/s of speed. Higher = smoother, lazier lines.
@export var look_ahead_per_speed := 0.55
## Multiplies the computed steering correction.
@export var steering_gain := 1.4

@export_group("Avoidance")
@export var avoid_enabled := true
## Only cars closer than this (and roughly ahead) are avoided.
@export var avoid_distance := 18.0
## Sideways shift of the aim point when squeezing past someone.
@export var avoid_strength := 3.5

@export_group("Recovery")
## Below this speed (m/s) while trying to drive, the driver counts as stuck.
@export var stuck_speed := 1.5
## Seconds of being stuck before reversing out.
@export var stuck_time := 2.0
## Seconds spent reversing before trying again.
@export var reverse_time := 1.2

const KMH_TO_MPS := 1.0 / 3.6
## Metres ahead of the aim point used to measure how sharp the next bend is.
const BEND_PROBE := 14.0

var _curve : Curve3D
var _length := 0.0
## Curve-space -> world. Identity for a generated line (already world-space).
var _line_xform := Transform3D.IDENTITY
var _others : Array[MeridianVehicle] = []
var _stuck_timer := 0.0
var _reverse_timer := 0.0

func _ready() -> void:
	if vehicle == null:
		vehicle = _first_vehicle(self)
	if racing_line == null:
		racing_line = _find_by_name(get_tree().root, "RacingLine") as Path3D

	# A hand-authored Path3D wins; otherwise build a line through the gates.
	if racing_line and racing_line.curve and racing_line.curve.point_count > 1:
		_curve = racing_line.curve
		_line_xform = racing_line.global_transform
	elif auto_line_from_checkpoints:
		_curve = _build_line_from_checkpoints()
		_line_xform = Transform3D.IDENTITY
	if _curve:
		_length = _curve.get_baked_length()

	if vehicle == null:
		push_warning("AIDriver: no MeridianVehicle found under %s." % name)
	if _curve == null or _length <= 0.0:
		push_warning("AIDriver: no racing line — need 3+ gates under a 'Checkpoints' node, or a 'RacingLine' Path3D.")
	_gather_others()

## Builds a closed, smooth loop through the Checkpoint gates in placement order.
## Uses Catmull-Rom tangents converted to Bezier handles, so the AI arcs through
## corners instead of driving gate-to-gate in straight lines.
func _build_line_from_checkpoints() -> Curve3D:
	var holder := _find_by_name(get_tree().root, "Checkpoints")
	if holder == null:
		return null
	var points : Array[Vector3] = []
	for c in holder.get_children():
		if c is Checkpoint:
			points.append((c as Checkpoint).global_position)
	var n := points.size()
	if n < 3:
		return null

	var handles : Array[Vector3] = []
	for i in n:
		var prev : Vector3 = points[(i - 1 + n) % n]
		var next : Vector3 = points[(i + 1) % n]
		# Catmull-Rom tangent m = (next - prev) / 2; Bezier handle = m / 3.
		handles.append((next - prev) * (line_smoothing / 6.0))

	var curve := Curve3D.new()
	for i in n:
		curve.add_point(points[i], -handles[i], handles[i])
	# Close the loop so sampling wraps continuously back to the first gate.
	curve.add_point(points[0], -handles[0], handles[0])
	return curve

func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	if not input_enabled or _curve == null or _length <= 0.0:
		_release_controls()
		return

	var speed := vehicle.speed
	var car_xform := vehicle.global_transform

	# Where are we on the line, and where should we aim?
	var here : float = _offset_at(car_xform.origin)
	var look : float = look_ahead_min + speed * look_ahead_per_speed
	var target : Vector3 = _point_at(here + look)
	if avoid_enabled:
		target += car_xform.basis.x * _avoid_shift(car_xform)

	# --- Stuck detection / reverse recovery ---
	if _reverse_timer > 0.0:
		_reverse_timer -= delta
		_drive_backwards(target, car_xform)
		return
	if speed < stuck_speed:
		_stuck_timer += delta
		if _stuck_timer > stuck_time:
			_stuck_timer = 0.0
			_reverse_timer = reverse_time
	else:
		_stuck_timer = 0.0

	# --- Steering: aim at the look-ahead point ---
	vehicle.steering_input = _steer_toward(target, car_xform)

	# --- Pace: ease off for the bend we can see coming ---
	var target_speed := _target_speed(here, look)
	var error := target_speed - speed
	if error > 1.0:
		vehicle.throttle_input = clampf(error / 5.0, 0.25, 1.0)
		vehicle.brake_input = 0.0
	elif error < -2.0:
		vehicle.throttle_input = 0.0
		vehicle.brake_input = clampf(-error / 8.0, 0.0, 1.0)
	else:
		vehicle.throttle_input = 0.3
		vehicle.brake_input = 0.0

	vehicle.handbrake_input = 0.0
	vehicle.clutch_input = 0.0

# --- Driving helpers -------------------------------------------------------

## Steering input for the vehicle: +1 is full left, -1 full right.
func _steer_toward(target: Vector3, car_xform: Transform3D) -> float:
	var local : Vector3 = car_xform.affine_inverse() * target
	# Vehicle forward is -Z, so a target with +X sits to the right.
	var angle := atan2(-local.x, -local.z)
	var lock := maxf(vehicle.max_steering_angle, 0.01)
	return clampf(angle / lock * steering_gain, -1.0, 1.0)

## Desired speed (m/s), reduced for how sharply the line bends just ahead.
func _target_speed(here: float, look: float) -> float:
	var a : Vector3 = _point_at(here + look)
	var b : Vector3 = _point_at(here + look + BEND_PROBE)
	var c : Vector3 = _point_at(here + look + BEND_PROBE * 2.0)
	var d1 := Vector2(b.x - a.x, b.z - a.z)
	var d2 := Vector2(c.x - b.x, c.z - b.z)
	var bend := 0.0
	if d1.length() > 0.01 and d2.length() > 0.01:
		bend = absf(d1.normalized().angle_to(d2.normalized()))
	var tightness := clampf(bend / (PI * 0.5) * corner_sensitivity, 0.0, 1.0)
	var fast := max_speed_kmh * KMH_TO_MPS
	var slow := min_corner_speed_kmh * KMH_TO_MPS
	return lerpf(fast, slow, tightness) * lerpf(0.75, 1.0, skill)

## Sideways nudge (metres, +right) to squeeze past a car sitting just ahead.
func _avoid_shift(car_xform: Transform3D) -> float:
	var shift := 0.0
	var inv := car_xform.affine_inverse()
	for other in _others:
		if other == null or not is_instance_valid(other):
			continue
		var local : Vector3 = inv * other.global_position
		var ahead := -local.z
		if ahead > 0.0 and ahead < avoid_distance and absf(local.x) < 3.5:
			# Pull the aim point to whichever side they are not on.
			shift += (-avoid_strength if local.x >= 0.0 else avoid_strength)
	return clampf(shift, -avoid_strength, avoid_strength)

## Back out of a wall: brake to force reverse gear, then power out while
## steering away from the line we failed to follow.
func _drive_backwards(target: Vector3, car_xform: Transform3D) -> void:
	if vehicle.current_gear != -1:
		vehicle.throttle_input = 0.0
		vehicle.brake_input = 1.0
	else:
		vehicle.throttle_input = 0.6
		vehicle.brake_input = 0.0
	vehicle.steering_input = -_steer_toward(target, car_xform)
	vehicle.handbrake_input = 0.0
	vehicle.clutch_input = 0.0

func _release_controls() -> void:
	vehicle.throttle_input = 0.0
	vehicle.brake_input = 0.0
	vehicle.steering_input = 0.0
	vehicle.handbrake_input = 0.0
	vehicle.clutch_input = 0.0

# --- Racing-line sampling --------------------------------------------------

## Distance along the line closest to a world position.
func _offset_at(world_pos: Vector3) -> float:
	var local : Vector3 = _line_xform.affine_inverse() * world_pos
	return _curve.get_closest_offset(local)

## World-space point at a distance along the line, wrapping around the loop.
func _point_at(offset: float) -> Vector3:
	var o := fposmod(offset, _length)
	return _line_xform * _curve.sample_baked(o)

# --- Discovery -------------------------------------------------------------

func _gather_others() -> void:
	_others.clear()
	for v in _all_vehicles(get_tree().root):
		if v != vehicle:
			_others.append(v)

func _all_vehicles(node: Node) -> Array[MeridianVehicle]:
	var found : Array[MeridianVehicle] = []
	if node is MeridianVehicle:
		found.append(node as MeridianVehicle)
	for child in node.get_children():
		found.append_array(_all_vehicles(child))
	return found

func _first_vehicle(node: Node) -> MeridianVehicle:
	if node is MeridianVehicle:
		return node as MeridianVehicle
	for child in node.get_children():
		var r := _first_vehicle(child)
		if r:
			return r
	return null

func _find_by_name(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var r := _find_by_name(child, target)
		if r:
			return r
	return null
