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

## Optional wheel type for this car only. Leave empty to use the wheels named by
## the definition — set it to fit different wheels without a new definition.
@export var wheels_override : WheelDefinition:
	set(value):
		if wheels_override and wheels_override.changed.is_connected(_on_definition_changed):
			wheels_override.changed.disconnect(_on_definition_changed)
		wheels_override = value
		if wheels_override and not wheels_override.changed.is_connected(_on_definition_changed):
			wheels_override.changed.connect(_on_definition_changed)
		_rebuild()

## Tick to force a rebuild if the preview ever gets out of sync.
@export var rebuild_now := false:
	set(_value):
		rebuild_now = false
		_rebuild()

## Nodes this script generated, cleared on every rebuild.
var _generated : Array[Node] = []

func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
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

func _on_definition_changed() -> void:
	_rebuild()

# --- Assembly --------------------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_generated()
	if definition == null:
		return

	_add_body()
	_add_collision()
	front_left_wheel = _add_wheel("WheelFrontLeft", -definition.front_track * 0.5,
		definition.front_axle_z, false)
	front_right_wheel = _add_wheel("WheelFrontRight", definition.front_track * 0.5,
		definition.front_axle_z, true)
	rear_left_wheel = _add_wheel("WheelRearLeft", -definition.rear_track * 0.5,
		definition.rear_axle_z, false)
	rear_right_wheel = _add_wheel("WheelRearRight", definition.rear_track * 0.5,
		definition.rear_axle_z, true)

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

## The wheel type in use: the per-car override wins over the definition's.
func _wheels() -> WheelDefinition:
	if wheels_override:
		return wheels_override
	return definition.wheels if definition else null

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
