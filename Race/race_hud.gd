extends CanvasLayer
## Race HUD: countdown, live lap/position/time, and the finish screen.
##
## Auto-connects to the RaceManager (found via the "race_manager" group) and
## reads the player (group "player", else the first MeridianVehicle). Add this
## as a node in the race scene — no wiring needed. Press R to restart.
class_name RaceHUD

var _rm: RaceManager
var _player: Node3D
var _info: Label
var _center: Label
var _finished := false

func _ready() -> void:
	_build_ui()
	_rm = get_tree().get_first_node_in_group("race_manager") as RaceManager
	_player = _find_player()
	if _rm:
		_rm.countdown_tick.connect(_on_countdown)
		_rm.race_started.connect(_on_go)
		_rm.race_finished.connect(_on_finished)
	else:
		push_warning("RaceHUD: no RaceManager found in the scene.")

func _process(_delta: float) -> void:
	if _rm == null or _player == null or _finished:
		return
	if _rm.state == RaceManager.State.RACING:
		var lap: int = mini(_rm.get_lap(_player) + 1, _rm.total_laps)
		var pos := _rm.get_position(_player)
		_info.text = "LAP %d/%d    POS %d/%d    %s" % [
			lap, _rm.total_laps, pos, _rm.get_racer_count(), _format_time(_rm.race_time)]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()

# --- Signal handlers -------------------------------------------------------

func _on_countdown(n: int) -> void:
	_center.text = str(n)
	_center.visible = true

func _on_go() -> void:
	_center.text = "GO!"
	await get_tree().create_timer(1.0).timeout
	if not _finished:
		_center.visible = false

func _on_finished(results: Array) -> void:
	_finished = true
	var line := "FINISHED"
	for r in results:
		if r["racer"] == _player:
			line = "FINISHED\nTime  %s" % _format_time(r["time"])
			break
	_center.text = line + "\n\nPress R to restart"
	_center.visible = true

# --- UI --------------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 22)
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_info.offset_top = 12
	root.add_child(_info)

	_center = Label.new()
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.add_theme_font_size_override("font_size", 64)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.visible = false
	root.add_child(_center)

## Finds the car the HUD reports on. Tree order is NOT reliable once AI cars
## exist, so prefer the vehicle that is actually driven by input: the player's
## car sits under a MeridianVehicleController, rivals under an AIDriver.
func _find_player() -> Node3D:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		return p
	var driven := _input_driven_vehicle(get_tree().root)
	if driven:
		return driven
	return _first_vehicle(get_tree().root)

func _input_driven_vehicle(node: Node) -> Node3D:
	if node is MeridianVehicle and node.get_parent() is MeridianVehicleController:
		return node as Node3D
	for child in node.get_children():
		var r := _input_driven_vehicle(child)
		if r:
			return r
	return null

func _first_vehicle(node: Node) -> Node3D:
	if node is MeridianVehicle:
		return node as Node3D
	for child in node.get_children():
		var r := _first_vehicle(child)
		if r:
			return r
	return null

func _format_time(t: float) -> String:
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	var hundredths := int(round((t - int(t)) * 100.0))
	return "%d:%02d.%02d" % [minutes, seconds, hundredths]
