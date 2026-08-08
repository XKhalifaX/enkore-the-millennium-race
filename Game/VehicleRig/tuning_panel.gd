extends Control
## Runtime vehicle tuning panel.
##
## Mouse-adjustable sliders wired live to the [MeridianVehicle] so handling can be
## dialed in *while driving*. Press [b]F1[/b] to show/hide.
##
## Pick a [b]Preset[/b] from the dropdown to jump between handling archetypes
## (Default / Muscle Car / Sedan / Formula One / Truck / SUV), then fine-tune from
## there. "Default" is captured from the vehicle scene at startup, so it always
## restores the car's real baseline.
##
## Runtime changes are not saved. When a setup feels right, hit
## [b]"Copy / print current values"[/b]: the current tuning is printed to the Output
## console and copied to the clipboard, ready to be baked into the vehicle/tuning
## resource permanently.
class_name VehicleTuningPanel

@export var vehicle : MeridianVehicle

const PANEL_WIDTH := 370.0
const LABEL_WIDTH := 155.0
const VALUE_WIDTH := 62.0

const DEFAULT_PRESET := "Default (scene)"

## Handling archetypes. Only live-tunable parameters are included — mass and
## suspension are baked when the vehicle initializes, so a Truck here is
## sluggish and low-grip rather than physically heavier.
const PRESETS := {
	"Muscle Car": {
		"steer_deg": 38.0, "steer_speed": 3.6, "countersteer_speed": 10.0,
		"steer_decay": 0.22, "steer_exponent": 1.6, "countersteer_assist": 0.70,
		"throttle_speed": 16.0, "brake_speed": 9.0, "max_torque": 650.0, "tcs_slip": 14.0,
		"friction": 2.00, "stiffness": 4.5, "lateral_assist": 0.03,
		"stability": true, "yaw_strength": 1.6, "yaw_ground": 3.2,
		"drag": 0.36,
	},
	"Sedan": {
		"steer_deg": 40.0, "steer_speed": 4.5, "countersteer_speed": 12.0,
		"steer_decay": 0.20, "steer_exponent": 1.4, "countersteer_assist": 0.90,
		"throttle_speed": 20.0, "brake_speed": 12.0, "max_torque": 300.0, "tcs_slip": 6.0,
		"friction": 2.40, "stiffness": 6.5, "lateral_assist": 0.08,
		"stability": true, "yaw_strength": 3.0, "yaw_ground": 4.0,
		"drag": 0.31,
	},
	"Formula One": {
		"steer_deg": 26.0, "steer_speed": 7.0, "countersteer_speed": 16.0,
		"steer_decay": 0.14, "steer_exponent": 1.2, "countersteer_assist": 0.60,
		"throttle_speed": 34.0, "brake_speed": 26.0, "max_torque": 780.0, "tcs_slip": 4.0,
		"friction": 4.60, "stiffness": 16.0, "lateral_assist": 0.14,
		"stability": true, "yaw_strength": 4.5, "yaw_ground": 5.0,
		"drag": 0.85,
	},
	"Truck": {
		"steer_deg": 34.0, "steer_speed": 2.4, "countersteer_speed": 7.0,
		"steer_decay": 0.35, "steer_exponent": 1.8, "countersteer_assist": 0.80,
		"throttle_speed": 8.0, "brake_speed": 6.0, "max_torque": 820.0, "tcs_slip": 16.0,
		"friction": 1.80, "stiffness": 3.5, "lateral_assist": 0.02,
		"stability": true, "yaw_strength": 1.2, "yaw_ground": 2.5,
		"drag": 0.75,
	},
	"SUV": {
		"steer_deg": 37.0, "steer_speed": 3.3, "countersteer_speed": 9.0,
		"steer_decay": 0.26, "steer_exponent": 1.6, "countersteer_assist": 0.80,
		"throttle_speed": 13.0, "brake_speed": 8.0, "max_torque": 430.0, "tcs_slip": 10.0,
		"friction": 2.10, "stiffness": 4.8, "lateral_assist": 0.04,
		"stability": true, "yaw_strength": 2.0, "yaw_ground": 3.4,
		"drag": 0.52,
	},
}

## Gearbox archetypes. Ratios are computed from the target top speed and gear
## count, so the box always spans the speed range the track actually produces —
## the usual cause of hunting is a gearbox geared for speeds never reached.
const GEARBOX_PRESETS := {
	"3-speed lazy": { "gears": 3, "top": 130.0 },
	"4-speed arcade": { "gears": 4, "top": 140.0 },
	"5-speed": { "gears": 5, "top": 160.0 },
	"6-speed quick": { "gears": 6, "top": 190.0 },
}
const DEFAULT_GEARBOX := "Default (scene)"
## Lower gears are spaced closer together than higher ones.
const GEAR_SPACING_EXPONENT := 0.75
const RPM_PER_RAD := 60.0 / TAU

var _content : VBoxContainer
var _status : Label
var _gearbox_button : OptionButton
var _gearbox_readout : Label
var _gear_count := 6
var _top_speed := 190.0
var _default_gear_ratios : Array[float] = []
var _preset_button : OptionButton
var _rows : Array = []          # { key, getter, setter, snap, refresh }
var _default_preset := {}       # captured from the scene at startup
var _current_preset := DEFAULT_PRESET

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vehicle == null:
		push_warning("VehicleTuningPanel: no vehicle assigned.")
	else:
		# Captured before the UI is built so the gearbox controls start truthful.
		_default_gear_ratios = vehicle.gear_ratios.duplicate()
		_gear_count = clampi(vehicle.gear_ratios.size(), 3, 6)
		if not vehicle.gear_ratios.is_empty():
			_top_speed = _speed_at_limiter(
				vehicle.gear_ratios[vehicle.gear_ratios.size() - 1] * vehicle.final_drive)
	_build()
	_default_preset = _capture_current()
	_update_gearbox_readout()

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

	# --- Preset picker ---
	var preset_row := HBoxContainer.new()
	outer.add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "Preset"
	preset_label.custom_minimum_size = Vector2(60, 0)
	preset_row.add_child(preset_label)
	_preset_button = OptionButton.new()
	_preset_button.focus_mode = Control.FOCUS_NONE
	_preset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_button.add_item(DEFAULT_PRESET)
	for preset_name in PRESETS.keys():
		_preset_button.add_item(preset_name)
	_preset_button.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(PANEL_WIDTH - 28, 0)
	scroll.add_child(_content)

	_section("Steering")
	_slider("steer_deg", "Max steer angle", 20.0, 60.0, 1.0,
		func(): return rad_to_deg(vehicle.max_steering_angle),
		func(v): vehicle.max_steering_angle = deg_to_rad(v),
		"%d°", "max_steering_angle = deg_to_rad(%s)")
	_slider("steer_speed", "Steer speed", 1.0, 12.0, 0.05,
		func(): return vehicle.steering_speed,
		func(v): vehicle.steering_speed = v,
		"%.2f", "steering_speed = %s")
	_slider("countersteer_speed", "Countersteer speed", 2.0, 20.0, 0.1,
		func(): return vehicle.countersteer_speed,
		func(v): vehicle.countersteer_speed = v,
		"%.2f", "countersteer_speed = %s")
	_slider("steer_decay", "Steer speed decay", 0.05, 1.0, 0.01,
		func(): return vehicle.steering_speed_decay,
		func(v): vehicle.steering_speed_decay = v,
		"%.2f", "steering_speed_decay = %s")
	_slider("steer_exponent", "Steer exponent", 1.0, 3.0, 0.05,
		func(): return vehicle.steering_exponent,
		func(v): vehicle.steering_exponent = v,
		"%.2f", "steering_exponent = %s")
	_slider("countersteer_assist", "Countersteer assist", 0.0, 2.0, 0.05,
		func(): return vehicle.countersteer_assist,
		func(v): vehicle.countersteer_assist = v,
		"%.2f", "countersteer_assist = %s")

	_section("Throttle & Brakes")
	_slider("throttle_speed", "Throttle response", 2.0, 40.0, 0.5,
		func(): return vehicle.throttle_speed,
		func(v): vehicle.throttle_speed = v,
		"%.1f", "throttle_speed = %s")
	_slider("brake_speed", "Brake response", 2.0, 30.0, 0.5,
		func(): return vehicle.braking_speed,
		func(v): vehicle.braking_speed = v,
		"%.1f", "braking_speed = %s")
	_slider("max_torque", "Max torque (Nm)", 100.0, 900.0, 5.0,
		func(): return vehicle.max_torque,
		func(v): vehicle.max_torque = v,
		"%d", "max_torque = %s")
	_slider("tcs_slip", "Traction ctrl slip", 0.5, 20.0, 0.5,
		func(): return vehicle.traction_control_max_slip,
		func(v): vehicle.traction_control_max_slip = v,
		"%.1f", "traction_control_max_slip = %s")

	_section("Grip")
	_slider("friction", "Road friction", 1.0, 5.0, 0.05,
		func(): return _grip("coefficient_of_friction", 3.0),
		func(v): _set_grip("coefficient_of_friction", "current_cof", v, false),
		"%.2f", "coefficient_of_friction[\"Road\"] = %s")
	_slider("stiffness", "Tire stiffness", 1.0, 20.0, 0.1,
		func(): return _grip("tire_stiffnesses", 10.0),
		func(v): _set_grip("tire_stiffnesses", "current_tire_stiffness", v, true),
		"%.1f", "tire_stiffnesses[\"Road\"] = %s")
	_slider("lateral_assist", "Lateral grip assist", 0.0, 0.5, 0.01,
		func(): return _grip("lateral_grip_assist", 0.05),
		func(v): _set_grip("lateral_grip_assist", "current_lateral_grip_assist", v, false),
		"%.2f", "lateral_grip_assist[\"Road\"] = %s")

	_section("Stability")
	_toggle("stability", "Enable stability",
		func(): return vehicle.enable_stability,
		func(on): vehicle.enable_stability = on,
		"enable_stability = %s")
	_slider("yaw_strength", "Yaw strength", 0.0, 20.0, 0.1,
		func(): return vehicle.stability_yaw_strength,
		func(v): vehicle.stability_yaw_strength = v,
		"%.1f", "stability_yaw_strength = %s")
	_slider("yaw_ground", "Yaw ground mult", 0.0, 6.0, 0.1,
		func(): return vehicle.stability_yaw_ground_multiplier,
		func(v): vehicle.stability_yaw_ground_multiplier = v,
		"%.1f", "stability_yaw_ground_multiplier = %s")

	_section("Aero")
	_slider("drag", "Drag coefficient", 0.05, 1.0, 0.01,
		func(): return vehicle.coefficient_of_drag,
		func(v): vehicle.coefficient_of_drag = v,
		"%.2f", "coefficient_of_drag = %s")

	_section("Gearbox")
	_build_gearbox_controls()
	_slider("shift_cooldown", "Shift cooldown (s)", 0.0, 2.0, 0.05,
		func(): return vehicle.automatic_time_between_shifts,
		func(v): vehicle.automatic_time_between_shifts = v,
		"%.2f", "automatic_time_between_shifts = %s")
	_slider("downshift_point", "Downshift point", 0.3, 0.95, 0.01,
		func(): return vehicle.automatic_downshift_ratio,
		func(v): vehicle.automatic_downshift_ratio = v,
		"%.2f", "automatic_downshift_ratio = %s")

	var copy_btn := Button.new()
	copy_btn.text = "Copy / print current values"
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.pressed.connect(_on_copy)
	outer.add_child(copy_btn)

	_status = Label.new()
	_status.text = "Pick a preset, fine-tune, then Copy to save your values."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_WIDTH - 20, 0)
	outer.add_child(_status)

# --- Gearbox ---------------------------------------------------------------

func _build_gearbox_controls() -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var label := Label.new()
	label.text = "Gearbox"
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(label)
	_gearbox_button = OptionButton.new()
	_gearbox_button.focus_mode = Control.FOCUS_NONE
	_gearbox_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gearbox_button.add_item(DEFAULT_GEARBOX)
	for preset_name in GEARBOX_PRESETS.keys():
		_gearbox_button.add_item(preset_name)
	_gearbox_button.item_selected.connect(_on_gearbox_selected)
	row.add_child(_gearbox_button)

	_plain_slider("Top speed (km/h)", 80.0, 280.0, 5.0, _top_speed,
		func(v):
			_top_speed = v
			_apply_gearbox())
	_plain_slider("Gears", 3.0, 6.0, 1.0, float(_gear_count),
		func(v):
			_gear_count = int(v)
			_apply_gearbox())

	_gearbox_readout = Label.new()
	_gearbox_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gearbox_readout.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 0)
	_gearbox_readout.add_theme_font_size_override("font_size", 11)
	_content.add_child(_gearbox_readout)

## A slider that drives panel state rather than a vehicle property directly.
func _plain_slider(nm : String, minv : float, maxv : float, step : float,
		start : float, on_change : Callable) -> void:
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
	sld.value = clampf(start, minv, maxv)
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sld.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sld.focus_mode = Control.FOCUS_NONE
	row.add_child(sld)
	var val := Label.new()
	val.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = "%d" % sld.value
	row.add_child(val)
	sld.value_changed.connect(func(v : float):
		val.text = "%d" % v
		on_change.call(v))

func _on_gearbox_selected(index : int) -> void:
	var preset_name := _gearbox_button.get_item_text(index)
	if preset_name == DEFAULT_GEARBOX:
		if vehicle and not _default_gear_ratios.is_empty():
			vehicle.set_gear_ratios(_default_gear_ratios.duplicate())
		_update_gearbox_readout()
		return
	var preset : Dictionary = GEARBOX_PRESETS.get(preset_name, {})
	if preset.is_empty():
		return
	_gear_count = int(preset["gears"])
	_top_speed = float(preset["top"])
	_apply_gearbox()
	if _status:
		_status.text = "Gearbox: %s" % preset_name

## Road speed (km/h) at which a given total ratio reaches the rev limiter.
func _speed_at_limiter(total_ratio : float) -> float:
	if total_ratio <= 0.0:
		return 0.0
	return (vehicle.max_rpm / RPM_PER_RAD) / total_ratio * _tire_radius() * 3.6

func _tire_radius() -> float:
	if vehicle.average_drive_wheel_radius > 0.0:
		return vehicle.average_drive_wheel_radius
	return vehicle.front_tire_radius

## Ratios that make gear N top out at its share of the target top speed.
func _apply_gearbox() -> void:
	if vehicle == null or _gear_count < 1 or vehicle.final_drive <= 0.0:
		return
	var k : float = (vehicle.max_rpm / RPM_PER_RAD) * _tire_radius() * 3.6
	var ratios : Array[float] = []
	for i in _gear_count:
		var fraction : float = pow(float(i + 1) / float(_gear_count), GEAR_SPACING_EXPONENT)
		var speed : float = maxf(_top_speed * fraction, 1.0)
		ratios.append(k / speed / vehicle.final_drive)
	vehicle.set_gear_ratios(ratios)
	_update_gearbox_readout()

func _update_gearbox_readout() -> void:
	if _gearbox_readout == null or vehicle == null:
		return
	var parts : Array[String] = []
	for i in vehicle.gear_ratios.size():
		var speed := _speed_at_limiter(vehicle.gear_ratios[i] * vehicle.final_drive)
		parts.append("%d:%.0f" % [i + 1, speed])
	_gearbox_readout.text = "upshift km/h  " + "  ".join(parts)

func _section(title : String) -> void:
	if _content.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		_content.add_child(spacer)
	var lbl := Label.new()
	lbl.text = "▶ " + title
	lbl.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_content.add_child(lbl)

func _slider(key : String, nm : String, minv : float, maxv : float, step : float,
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

	# Dragging a slider means the user has departed from the named preset.
	sld.value_changed.connect(func(v : float):
		setter.call(v)
		val.text = fmt % v
		_mark_custom())

	var refresh := func():
		var now : float = clampf(float(getter.call()), minv, maxv)
		sld.set_value_no_signal(now)
		val.text = fmt % now

	_rows.append({ "key": key, "getter": getter, "setter": setter,
		"snap": snap, "refresh": refresh })

func _toggle(key : String, nm : String, getter : Callable, setter : Callable, snap : String) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var lbl := Label.new()
	lbl.text = nm
	lbl.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.button_pressed = bool(getter.call())
	cb.toggled.connect(func(on : bool):
		setter.call(on)
		_mark_custom())
	row.add_child(cb)

	var refresh := func():
		cb.set_pressed_no_signal(bool(getter.call()))

	_rows.append({ "key": key, "getter": getter, "setter": setter,
		"snap": snap, "refresh": refresh })

# --- Presets ---------------------------------------------------------------

func _capture_current() -> Dictionary:
	var d := {}
	for r in _rows:
		d[r["key"]] = r["getter"].call()
	return d

func _on_preset_selected(index : int) -> void:
	var preset_name := _preset_button.get_item_text(index)
	var values : Dictionary = _default_preset
	if preset_name != DEFAULT_PRESET:
		values = PRESETS.get(preset_name, {})
	_apply_preset(values)
	_current_preset = preset_name
	if _status:
		_status.text = "Applied preset: %s. Fine-tune, then Copy to save." % preset_name

func _apply_preset(values : Dictionary) -> void:
	if vehicle == null or values.is_empty():
		return
	for r in _rows:
		var key : String = r["key"]
		if values.has(key):
			r["setter"].call(values[key])
	for r in _rows:
		r["refresh"].call()

## A manual slider edit means the setup no longer matches the selected preset.
func _mark_custom() -> void:
	if _current_preset.begins_with("Custom"):
		return
	_current_preset = "Custom (from %s)" % _current_preset

# --- Grip helpers ----------------------------------------------------------

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

# --- Export ----------------------------------------------------------------

func _on_copy() -> void:
	var lines : Array[String] = []
	lines.append("# --- Vehicle tuning snapshot: %s (%s) ---" % [
		_current_preset, Time.get_datetime_string_from_system(false, true)])
	for r in _rows:
		var v = r["getter"].call()
		var sval : String
		if typeof(v) == TYPE_BOOL:
			sval = str(v)
		else:
			sval = String.num(float(v), 3)
		lines.append(r["snap"] % sval)
	if vehicle and not vehicle.gear_ratios.is_empty():
		var ratios : Array[String] = []
		for r in vehicle.gear_ratios:
			ratios.append(String.num(r, 3))
		lines.append("gear_ratios = Array[float]([%s])" % ", ".join(ratios))
		lines.append("final_drive = %s" % String.num(vehicle.final_drive, 3))
	var text := "\n".join(lines)
	print("\n" + text + "\n")
	DisplayServer.clipboard_set(text)
	if _status:
		_status.text = "Copied %d values (%s) to clipboard + Output." % [_rows.size(), _current_preset]
