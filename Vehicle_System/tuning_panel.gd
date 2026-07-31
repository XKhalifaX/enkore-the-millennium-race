extends Control
## Runtime vehicle tuning panel.
##
## Mouse-adjustable sliders wired live to the [MeridianVehicle] so handling can be
## dialed in *while driving*. Press [b]F1[/b] to show/hide.
##
## Runtime changes are not saved. When a setup feels right, hit
## [b]"Copy / print current values"[/b]: the current tuning is printed to the Output
## console and copied to the clipboard, ready to be baked into the vehicle/tuning
## resource permanently.
class_name VehicleTuningPanel
extends Control

@export var vehicle : MeridianVehicle

const PANEL_WIDTH := 370.0
const LABEL_WIDTH := 155.0
const VALUE_WIDTH := 62.0

var _content : VBoxContainer
var _status : Label
var _rows : Array = []   # each: { getter:Callable, snap:String }

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vehicle == null:
		push_warning("VehicleTuningPanel: no vehicle assigned.")
	_build()

func _unhandled_input(event : InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()

func _build() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	# Pin to the top-right so it clears the speed/RPM HUD on the left.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -(PANEL_WIDTH + 10.0)
	panel.offset_right = -10.0
	panel.offset_top = 10.0
	add_child(panel)

	var outer := VBoxContainer.new()
	panel.add_child(outer)

	var title := Label.new()
	title.text = "VEHICLE TUNING   —   F1 to toggle"
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(PANEL_WIDTH - 28, 0)
	scroll.add_child(_content)

	_section("Steering")
	_slider("Max steer angle", 20.0, 60.0, 1.0,
		func(): return rad_to_deg(vehicle.max_steering_angle),
		func(v): vehicle.max_steering_angle = deg_to_rad(v),
		"%d°", "max_steering_angle = deg_to_rad(%s)")
	_slider("Steer speed", 1.0, 12.0, 0.05,
		func(): return vehicle.steering_speed,
		func(v): vehicle.steering_speed = v,
		"%.2f", "steering_speed = %s")
	_slider("Countersteer speed", 2.0, 20.0, 0.1,
		func(): return vehicle.countersteer_speed,
		func(v): vehicle.countersteer_speed = v,
		"%.2f", "countersteer_speed = %s")
	_slider("Steer speed decay", 0.05, 1.0, 0.01,
		func(): return vehicle.steering_speed_decay,
		func(v): vehicle.steering_speed_decay = v,
		"%.2f", "steering_speed_decay = %s")
	_slider("Steer exponent", 1.0, 3.0, 0.05,
		func(): return vehicle.steering_exponent,
		func(v): vehicle.steering_exponent = v,
		"%.2f", "steering_exponent = %s")
	_slider("Countersteer assist", 0.0, 2.0, 0.05,
		func(): return vehicle.countersteer_assist,
		func(v): vehicle.countersteer_assist = v,
		"%.2f", "countersteer_assist = %s")

	_section("Throttle & Brakes")
	_slider("Throttle response", 2.0, 40.0, 0.5,
		func(): return vehicle.throttle_speed,
		func(v): vehicle.throttle_speed = v,
		"%.1f", "throttle_speed = %s")
	_slider("Brake response", 2.0, 30.0, 0.5,
		func(): return vehicle.braking_speed,
		func(v): vehicle.braking_speed = v,
		"%.1f", "braking_speed = %s")
	_slider("Max torque (Nm)", 100.0, 900.0, 5.0,
		func(): return vehicle.max_torque,
		func(v): vehicle.max_torque = v,
		"%d", "max_torque = %s")
	_slider("Traction ctrl slip", 0.5, 20.0, 0.5,
		func(): return vehicle.traction_control_max_slip,
		func(v): vehicle.traction_control_max_slip = v,
		"%.1f", "traction_control_max_slip = %s")

	_section("Grip")
	_slider("Road friction", 1.0, 5.0, 0.05,
		func(): return _grip("coefficient_of_friction", 3.0),
		func(v): _set_grip("coefficient_of_friction", "current_cof", v, false),
		"%.2f", "coefficient_of_friction[\"Road\"] = %s")
	_slider("Tire stiffness", 1.0, 20.0, 0.1,
		func(): return _grip("tire_stiffnesses", 10.0),
		func(v): _set_grip("tire_stiffnesses", "current_tire_stiffness", v, true),
		"%.1f", "tire_stiffnesses[\"Road\"] = %s")
	_slider("Lateral grip assist", 0.0, 0.5, 0.01,
		func(): return _grip("lateral_grip_assist", 0.05),
		func(v): _set_grip("lateral_grip_assist", "current_lateral_grip_assist", v, false),
		"%.2f", "lateral_grip_assist[\"Road\"] = %s")

	_section("Stability")
	_toggle("Enable stability",
		func(): return vehicle.enable_stability,
		func(on): vehicle.enable_stability = on,
		"enable_stability = %s")
	_slider("Yaw strength", 0.0, 20.0, 0.1,
		func(): return vehicle.stability_yaw_strength,
		func(v): vehicle.stability_yaw_strength = v,
		"%.1f", "stability_yaw_strength = %s")
	_slider("Yaw ground mult", 0.0, 6.0, 0.1,
		func(): return vehicle.stability_yaw_ground_multiplier,
		func(v): vehicle.stability_yaw_ground_multiplier = v,
		"%.1f", "stability_yaw_ground_multiplier = %s")

	_section("Aero")
	_slider("Drag coefficient", 0.05, 1.0, 0.01,
		func(): return vehicle.coefficient_of_drag,
		func(v): vehicle.coefficient_of_drag = v,
		"%.2f", "coefficient_of_drag = %s")

	var copy_btn := Button.new()
	copy_btn.text = "Copy / print current values"
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(_on_copy)
	outer.add_child(copy_btn)

	_status = Label.new()
	_status.text = "Tip: tune, then Copy to save your values."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 0)
	outer.add_child(_status)

func _section(title : String) -> void:
	if _content.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		_content.add_child(spacer)
	var lbl := Label.new()
	lbl.text = "▶ " + title
	lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_content.add_child(lbl)

func _slider(nm : String, minv : float, maxv : float, step : float,
		getter : Callable, setter : Callable, fmt : String, snap : String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var lbl := Label.new()
	lbl.text = nm
	lbl.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(lbl)

	var sld := HSlider.new()
	sld.min_value = minv
	sld.max_value = maxv
	sld.step = step
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sld.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sld.focus_mode = Control.FOCUS_NONE
	var cur : float = clampf(float(getter.call()), minv, maxv)
	sld.value = cur
	row.add_child(sld)

	var val := Label.new()
	val.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = fmt % cur
	row.add_child(val)

	sld.value_changed.connect(func(v : float):
		setter.call(v)
		val.text = fmt % v)
	_rows.append({ "getter": getter, "snap": snap })

func _toggle(nm : String, getter : Callable, setter : Callable, snap : String) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var lbl := Label.new()
	lbl.text = nm
	lbl.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(getter.call())
	cb.toggled.connect(func(on : bool): setter.call(on))
	row.add_child(cb)
	_rows.append({ "getter": getter, "snap": snap })

func _grip(dict_name : String, def : float) -> float:
	if vehicle == null:
		return def
	var d : Dictionary = vehicle.get(dict_name)
	return d.get("Road", def)

## Pushes a grip value into the vehicle's dictionary and each wheel's live cache so
## it takes effect immediately (surface stays "Road" on the prototype arena).
## [param stiffness] applies the tire-stiffness curve used by the wheel model.
func _set_grip(dict_name : String, cache_field : String, v : float, stiffness : bool) -> void:
	if vehicle == null:
		return
	var d : Dictionary = vehicle.get(dict_name)
	d["Road"] = v
	var cache_value : float = (1000000.0 + 8000000.0 * v) if stiffness else v
	for w in vehicle.wheel_array:
		var wd : Dictionary = w.get(dict_name)
		wd["Road"] = v
		if w.surface_type == "Road":
			w.set(cache_field, cache_value)

func _on_copy() -> void:
	var lines : Array[String] = []
	lines.append("# --- Vehicle tuning snapshot (%s) ---" % Time.get_datetime_string_from_system(false, true))
	for r in _rows:
		var v = r["getter"].call()
		var sval : String
		if typeof(v) == TYPE_BOOL:
			sval = str(v)
		else:
			sval = String.num(float(v), 3)
		lines.append(r["snap"] % sval)
	var text := "\n".join(lines)
	print("\n" + text + "\n")
	DisplayServer.clipboard_set(text)
	if _status:
		_status.text = "Copied %d values to clipboard + printed to Output." % _rows.size()
