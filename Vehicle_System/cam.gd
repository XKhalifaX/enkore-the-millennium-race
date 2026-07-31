extends SpringArm3D

const PITCH: float = deg_to_rad(5.0)

## The Node3D (or PhysicsBody3D) that the camera will follow.
@export var target: Node3D

## Distance the camera stays from the target. Sets SpringArm3D.spring_length.
@export var follow_distance: float = 5.0
## Height offset above the target's origin.
@export var follow_height: float = 2.0
## Sensitivity of the mouse movement when right-clicking.
@export var mouse_sensitivity: float = 0.15
## How many meters the camera zooms in/out per scroll tick.
@export var zoom_step: float = 0.5
## Minimum distance the camera can get to the vehicle.
@export var min_zoom_distance: float = 2.0
## Maximum distance the camera can get from the vehicle.
@export var max_zoom_distance: float = 15.0

@onready var cam: Camera3D = $Node3D/Camera3D

var basic_mode: bool = false
var dead_mode: bool = false
var time_since_mouse_input: float = 0.0
var is_right_clicking: bool = false

var last_v: Vector3
var gforce_target: Vector3
var gforce: Vector3

var jolt: float = 0.0
var shake: float = 0.0

var jolt_target: float = 0.0
var height_target: float = 0.0
var distance_target: float = 0.0
var fov_change_speed: float = 10.0

var mouse_input: Vector2 = Vector2.ZERO
var look_accel: float = 0.0

func _ready() -> void:
	if target:
		setup_camera_targets()

func setup_camera_targets() -> void:
	add_excluded_object(target)
	cam.make_current()
	
	distance_target = follow_distance
	height_target = follow_height
	reset_camera()

func reset_camera() -> void:
	if not target: return
	rotation.y = target.rotation.y
	rotation.x = -PITCH

func apply_impact_shake(intensity: float) -> void:
	shake += intensity

func apply_jolt(intensity: float) -> void:
	jolt_target += clampf(intensity, 0.0, 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Track right-click hold/release states
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_clicking = event.pressed
			if is_right_clicking:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Scroll Wheel Zoom In
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance_target = clampf(distance_target - zoom_step, min_zoom_distance, max_zoom_distance)
		
		# Scroll Wheel Zoom Out
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance_target = clampf(distance_target + zoom_step, min_zoom_distance, max_zoom_distance)

	# Collect mouse movement data ONLY when right-click is active
	if event is InputEventMouseMotion and is_right_clicking:
		mouse_input += event.relative * mouse_sensitivity

func _physics_process(delta: float) -> void:
	if target == null:
		return

	time_since_mouse_input += delta

	var vel: Vector3 = Vector3.ZERO
	if target is RigidBody3D:
		vel = target.linear_velocity
	elif target.has_method("get_real_velocity"):
		vel = target.get_real_velocity()
	else:
		vel = (target.global_position - last_v) / delta

	var veldir: float = atan2(-vel.x, vel.z)
	var apply_scale: float = (clampf(vel.length() - 5.0, 0.0, 30.0) / 30.0)

	var is_wasted: bool = target.get("is_wasted") if "is_wasted" in target else false
	dead_mode = is_wasted

	# Camera Shake
	cam.position.x = lerp(cam.position.x, randf_range(-1.0, 1.0) * shake, delta * 30.0)
	cam.position.y = lerp(cam.position.y, randf_range(-1.0, 1.0) * shake, delta * 30.0)

	# Dynamic Pitch adjustments from movement physics
	var horizontal_vel: Vector2 = Vector2(vel.x, vel.z)
	var vertical_vel: float = vel.y
	var pitch_target: float = Vector2(horizontal_vel.length(), vertical_vel).angle()
	
	# Only auto-align pitch if user isn't actively looking around
	if time_since_mouse_input > 1.0:
		rotation.x = lerp(rotation.x, pitch_target - PITCH, delta * apply_scale * 5.0)

	var fov_target: float = 70.0 + (50.0 * min(vel.length() / 100.0, 1.0))

	if dead_mode:
		fov_target = 60.0
		fov_change_speed = 0.1
		height_target = lerp(height_target, 1.0, delta * fov_change_speed)
		spring_length = lerp(spring_length, 20.0, delta * fov_change_speed)
	else:
		fov_change_speed = 10.0
		height_target = lerp(height_target, follow_height, delta * fov_change_speed)
		spring_length = lerp(spring_length, distance_target, delta * fov_change_speed)

	cam.fov = lerp(cam.fov, fov_target, delta * fov_change_speed)

	gforce_target += vel - (last_v if target is RigidBody3D else vel)
	gforce_target = lerp(gforce_target, Vector3.ZERO, delta * 4.0)
	gforce = lerp(gforce, gforce_target, delta * 5.0)

	if dead_mode:
		_process_dead_cam(apply_scale, veldir, delta)
	else:
		# Use the static camera logic which accepts direct mouse_input data
		_process_static_cam(Vector2.ZERO, apply_scale, veldir, delta)

	last_v = target.linear_velocity if target is RigidBody3D else target.global_position
	mouse_input = Vector2.ZERO

	jolt_target = lerp(jolt_target, 0.0, delta * 3.0)
	jolt = lerp(jolt, jolt_target, delta * 20.0)
	shake = lerp(shake, 0.0, delta * 4.0)

	rotation.x = clampf(rotation.x, deg_to_rad(-60.0), deg_to_rad(30.0))

func _process_dead_cam(apply_scale: float, veldir: float, delta: float) -> void:
	# Changed 'position' to 'global_position'
	global_position = target.global_position + (Vector3.UP * height_target)
	rotation.x = lerp(rotation.x, deg_to_rad(-20.0), delta)
	rotation.z = lerp(rotation.z, deg_to_rad(10.0) * sin(Time.get_ticks_msec() / 1500.0), delta)
	var angle_delta: float = - rotation.y - veldir + PI
	rotation.y += sin(angle_delta) * apply_scale * delta * 5.0

func _process_static_cam(_look: Vector2, apply_scale: float, veldir: float, delta: float) -> void:
	# Changed 'position' to 'global_position'
	global_position = target.global_position + (Vector3.UP * height_target)
	
	if time_since_mouse_input > 1.0:
		var angle_delta: float = - rotation.y - veldir + PI
		rotation.y += sin(angle_delta) * apply_scale * delta * 5.0

	if mouse_input.length() > 0.0:
		rotation.y -= deg_to_rad(mouse_input.x)
		rotation.x -= deg_to_rad(mouse_input.y)
		time_since_mouse_input = 0.0

	cam.rotation.x = deg_to_rad(-jolt)
	cam.rotation.z = lerp(cam.rotation.z, deg_to_rad(-15.0) if dead_mode else 0.0, delta * fov_change_speed)
