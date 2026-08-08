@tool
class_name ModularVehicle
extends MeridianVehicle
## A [MeridianVehicle] that assembles itself from a [VehicleDefinition].
##
## Drop this node in, assign a definition, and it builds the body mesh, the four
## raycast wheels with their hubs and meshes, and the chassis collider — no
## hand-wiring. Swapping [member definition] swaps the whole car.
##
## It is a [code]@tool[/code] script: the car rebuilds in the editor as you drag
## the definition's sliders, so wheel placement can be eyeballed in the viewport.
## Generated nodes are deliberately NOT saved into the scene (no owner) — they
## are rebuilt every time, so never hand-edit them.
##
## All the normal MeridianVehicle tuning (torque, grip, suspension...) still
## lives on this node; the definition only covers assembly and geometry.

## Which car to build. Changing it (or any value inside it) rebuilds instantly.
@export var definition : VehicleDefinition:
	set(value):
		if definition and definition.changed.is_connected(_on_definition_changed):
			definition.changed.disconnect(_on_definition_changed)
		definition = value
		if definition and not definition.changed.is_connected(_on_definition_changed):
			definition.changed.connect(_on_definition_changed)
		_rebuild()

## Which wheels to fit. Any wheel type works on any body.
@export var wheels : WheelDefinition:
	set(value):
		if wheels and wheels.changed.is_connected(_on_definition_changed):
			wheels.changed.disconnect(_on_definition_changed)
		wheels = value
		if wheels and not wheels.changed.is_connected(_on_definition_changed):
			wheels.changed.connect(_on_definition_changed)
		_rebuild()

## Draw a translucent box in the editor matching the collision shape, so
## collision_size / collision_offset can be tuned by eye. Editor-only — never
## shown in the running game.
@export var show_collision_preview := true:
	set(value):
		show_collision_preview = value
		_rebuild()

## Inspector button to force a rebuild if the preview gets out of sync.
@export_tool_button("Rebuild car") var rebuild_action := _rebuild

## Nodes this script generated, cleared on every rebuild.
var _generated : Array[Node] = []
## Fingerprint of the definition values, polled in-editor so dragging a slider
## on the resource rebuilds the car even though custom Resources do not reliably
## announce their own edits.
var _spec_fingerprint := 0

func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		_spec_fingerprint = _compute_fingerprint()
		return
	# Physics setup needs the wheels to exist first, hence rebuild above.
	if torque_curve == null:
		torque_curve = _default_torque_curve()
	# Let the fitted wheel drive the physical tyre size.
	var spec := _wheels()
	if spec and spec.tire_radius > 0.0:
		front_tire_radius = spec.tire_radius
		rear_tire_radius = spec.tire_radius
	super()
	_apply_gearbox_from_definition()

func _on_definition_changed() -> void:
	_rebuild()

## Applies the definition's gearbox choice once the physics rig is initialised
## (average_drive_wheel_radius is only valid after super()).
func _apply_gearbox_from_definition() -> void:
	if definition == null:
		return
	var radius := average_drive_wheel_radius
	if radius <= 0.0:
		radius = front_tire_radius
	var ratios := GearboxPresets.ratios_for(definition.gearbox_preset,
		definition.custom_gear_count, definition.custom_top_speed_kmh,
		max_rpm, radius, final_drive)
	if not ratios.is_empty():
		set_gear_ratios(ratios)
	if definition.override_shift_feel:
		automatic_time_between_shifts = definition.shift_cooldown
		automatic_downshift_ratio = definition.downshift_point

## Editor-only: watch the assigned resources for edits and rebuild on change.
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var current := _compute_fingerprint()
	if current != _spec_fingerprint:
		_spec_fingerprint = current
		_rebuild()

func _compute_fingerprint() -> int:
	var values : Array = []
	if definition:
		values.append_array([definition.body_scene, definition.body_offset,
			definition.body_rotation_degrees, definition.body_scale,
			definition.front_track, definition.rear_track,
			definition.front_axle_z, definition.rear_axle_z, definition.axle_height,
			definition.collision_size, definition.collision_offset,
			definition.apply_tint, definition.body_tint])
	var spec := _wheels()
	if spec:
		values.append_array([spec.wheel_scene, spec.wheel_scale,
			spec.wheel_rotation_degrees, spec.wheel_offset,
			spec.mirror_right_wheels, spec.tire_radius])
	return values.hash()

# --- Assembly --------------------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_generated()
	if definition == null:
		return

	_add_body()
	_add_collision()
	var fl := _add_wheel("WheelFrontLeft", -definition.front_track * 0.5,
		definition.front_axle_z, false)
	var fr := _add_wheel("WheelFrontRight", definition.front_track * 0.5,
		definition.front_axle_z, true)
	var rl := _add_wheel("WheelRearLeft", -definition.rear_track * 0.5,
		definition.rear_axle_z, false)
	var rr := _add_wheel("WheelRearRight", definition.rear_track * 0.5,
		definition.rear_axle_z, true)

	# Only wire the exported wheel slots at runtime. In the editor they would be
	# serialized into the .tscn as paths to generated nodes that do not exist on
	# load, producing "node not found" errors on every open.
	if not Engine.is_editor_hint():
		front_left_wheel = fl
		front_right_wheel = fr
		rear_left_wheel = rl
		rear_right_wheel = rr

func _clear_generated() -> void:
	for node in _generated:
		if is_instance_valid(node):
			# Detach immediately so a fast slider drag can't leave duplicate
			# wheels visible (or clash names) before queue_free lands.
			var parent := node.get_parent()
			if parent:
				parent.remove_child(node)
			node.queue_free()
	_generated.clear()
	front_left_wheel = null
	front_right_wheel = null
	rear_left_wheel = null
	rear_right_wheel = null

## Adds a child that will be wiped on the next rebuild and never saved to disk.
func _track(node: Node, parent: Node) -> void:
	parent.add_child(node)
	_generated.append(node)

func _add_body() -> void:
	if definition.body_scene == null:
		return
	var holder := Node3D.new()
	holder.name = "Body"
	_track(holder, self)
	var model := definition.body_scene.instantiate()
	holder.add_child(model)
	holder.position = definition.body_offset
	holder.rotation_degrees = definition.body_rotation_degrees
	holder.scale = Vector3.ONE * definition.body_scale
	if definition.apply_tint:
		_tint(model, definition.body_tint)

func _add_collision() -> void:
	var shape := BoxShape3D.new()
	shape.size = definition.collision_size
	var col := CollisionShape3D.new()
	col.name = "Chassis"
	col.shape = shape
	col.position = definition.collision_offset
	_track(col, self)
	if show_collision_preview and Engine.is_editor_hint():
		_add_collision_preview()

## Editor-only translucent box mirroring the chassis collider.
func _add_collision_preview() -> void:
	var mesh := BoxMesh.new()
	mesh.size = definition.collision_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var preview := MeshInstance3D.new()
	preview.name = "CollisionPreview"
	preview.mesh = mesh
	preview.material_override = mat
	preview.position = definition.collision_offset
	_track(preview, self)

## The wheel type fitted to this car.
func _wheels() -> WheelDefinition:
	return wheels

## Builds one raycast wheel: the MeridianWheel, its hub, and the wheel mesh.
func _add_wheel(wheel_name: String, x: float, z: float, is_right: bool) -> MeridianWheel:
	var wheel := MeridianWheel.new()
	wheel.name = wheel_name
	wheel.position = Vector3(x, definition.axle_height, z)
	_track(wheel, self)

	# wheel.gd drives this node: it slides with the suspension and spins.
	var hub := Node3D.new()
	hub.name = "Hub"
	wheel.add_child(hub)
	wheel.wheel_node = hub

	var spec := _wheels()
	if spec and spec.wheel_scene:
		var model := spec.wheel_scene.instantiate()
		hub.add_child(model)
		if model is Node3D:
			var m := model as Node3D
			m.position = spec.wheel_offset
			m.rotation_degrees = spec.wheel_rotation_degrees
			if is_right and spec.mirror_right_wheels:
				m.rotation_degrees.y += 180.0
			m.scale = Vector3.ONE * spec.wheel_scale
	return wheel

# --- Helpers ---------------------------------------------------------------

## Recursively tints every mesh so one body model can field a varied grid.
func _tint(node: Node, colour: Color) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mesh_node.material_override = mat
	for child in node.get_children():
		_tint(child, colour)

## A usable torque curve so a fresh vehicle runs without one being authored.
func _default_torque_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(0.45, 1.0))
	curve.add_point(Vector2(1.0, 0.72))
	return curve
