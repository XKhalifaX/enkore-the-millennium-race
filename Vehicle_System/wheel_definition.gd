class_name WheelDefinition
extends Resource
## One wheel type: the model plus how it must be oriented and sized.
##
## Kept separate from [VehicleDefinition] so any wheel can be fitted to any car —
## pick a body and a wheel independently on a [ModularVehicle].
##
## Imported wheels arrive at arbitrary scale and axis, so adjust these live in
## the inspector; the vehicle rebuilds as you drag.

## The wheel model. An imported .fbx/.glb works directly.
@export var wheel_scene : PackedScene
@export_range(0.001, 10.0, 0.001, "or_greater") var wheel_scale := 1.0
## Spin the model onto the right axis (a wheel must roll around its local X).
@export var wheel_rotation_degrees := Vector3.ZERO
## Nudge the mesh inside the hub, e.g. to centre a model whose origin is off.
@export var wheel_offset := Vector3.ZERO
## Rotate the right-hand wheels 180° so an asymmetric wheel faces outward.
@export var mirror_right_wheels := true

## Physical tyre radius in metres, applied to the vehicle so the suspension and
## rolling behaviour match the model. Set 0 to leave the vehicle's own values.
@export_range(0.0, 2.0, 0.005, "or_greater") var tire_radius := 0.355
