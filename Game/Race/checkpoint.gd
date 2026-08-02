class_name Checkpoint
extends Area3D
## A race gate. Place instances in driving order as children of a node named
## "Checkpoints". The FIRST child (index 0) doubles as the start/finish line.
## Cars must cross the gates in order; crossing the start/finish after the last
## gate validates a lap. This is a trigger only — it never blocks the car.
##
## Resize the child CollisionShape/Placeholder to span your road width.

signal racer_passed(racer: Node3D, checkpoint: Checkpoint)

## Hide the translucent placeholder box (leave on while blocking out).
@export var show_placeholder := true

func _ready() -> void:
	add_to_group("checkpoint")
	monitoring = true
	body_entered.connect(_on_body_entered)
	var ph := get_node_or_null("Placeholder") as Node3D
	if ph:
		ph.visible = show_placeholder

func _on_body_entered(body: Node3D) -> void:
	# Only react to cars, never the ground/walls.
	if body is MeridianVehicle:
		racer_passed.emit(body, self)
