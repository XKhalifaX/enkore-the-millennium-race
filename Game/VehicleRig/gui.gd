extends Control
## Vehicle HUD: speed, RPM, gear, and a traction readout.

@export var vehicle : MeridianVehicle
## Longitudinal slip on a driven wheel above this counts as wheelspin. Watch the
## number in the readout while driving to calibrate it for a given car.
@export var wheelspin_threshold := 1.0

@onready var speed_label = $VBoxContainer/Speed
@onready var rpm_label = $VBoxContainer/RPM
@onready var gear_label = $VBoxContainer/Gear

## Added in code so the existing scene needs no new nodes.
var traction_label : Label

func _ready() -> void:
	traction_label = Label.new()
	traction_label.name = "Traction"
	$VBoxContainer.add_child(traction_label)

func _process(_delta):
	if vehicle == null:
		return
	speed_label.text = str(round(vehicle.speed * 3.6)) + " km/h"
	rpm_label.text = str(round(vehicle.motor_rpm)) + " rpm"
	gear_label.text = "Gear: " + str(vehicle.current_gear)
	_update_traction()

## Worst longitudinal slip across the driven wheels. Driven wheels only, so a
## locked front wheel while braking doesn't read as wheelspin.
func _drive_wheel_slip() -> float:
	var worst := 0.0
	for wheel in vehicle.drive_wheels:
		worst = maxf(worst, absf(wheel.slip_vector.y))
	return worst

func _update_traction() -> void:
	var slip := _drive_wheel_slip()
	var text := "Grip"
	var colour := Color(0.55, 0.9, 0.55)
	if vehicle.tcs_active:
		# Traction control is actively cutting power to stop the spin.
		text = "TCS  %.1f" % slip
		colour = Color(1.0, 0.85, 0.2)
	elif slip > wheelspin_threshold:
		text = "WHEELSPIN  %.1f" % slip
		colour = Color(1.0, 0.35, 0.3)
	traction_label.text = text
	traction_label.add_theme_color_override("font_color", colour)
