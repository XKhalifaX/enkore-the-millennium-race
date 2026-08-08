class_name VehicleDefinition
extends Resource
## Describes one car body: which model, and where its wheels sit.
##
## Wheels are chosen separately — see [WheelDefinition], assigned on the
## [ModularVehicle] node — so any wheel type fits any body.
##
## Create one per vehicle type (right-click in the FileSystem →
## New Resource → VehicleDefinition), point it at your model file, then assign
## it to a [ModularVehicle]. Every racer using this definition gets the same car.
##
## Imported models arrive at arbitrary scale and axis, so body and wheels each
## expose scale + rotation. Adjust them live in the inspector — [ModularVehicle]
## rebuilds as you drag, so wheel placement is done by eye.
##
## Defaults match the existing simcade car (track 1.56 m, wheelbase 2.81 m).

@export_group("Body")
## The car body model. An imported .fbx/.glb works directly.
@export var body_scene : PackedScene
@export var body_offset := Vector3.ZERO
@export var body_rotation_degrees := Vector3.ZERO
## Imported models are often 100x or 0.01x. Adjust until the body reads as
## roughly 4-5 m long against the wheels.
@export_range(0.001, 10.0, 0.001, "or_greater") var body_scale := 1.0

@export_group("Axle Geometry")
## Distance between the left and right wheel centres, in metres.
@export_range(0.5, 4.0, 0.01, "or_greater") var front_track := 1.56
@export_range(0.5, 4.0, 0.01, "or_greater") var rear_track := 1.56
## Z position of each axle. Godot's forward is -Z, so the front axle is negative.
@export_range(-6.0, 0.0, 0.005, "or_less") var front_axle_z := -1.395
@export_range(0.0, 6.0, 0.005, "or_greater") var rear_axle_z := 1.410
## Height of the wheel raycast origins. Raise it if the car sits too low.
@export_range(-2.0, 2.0, 0.005, "or_greater", "or_less") var axle_height := 0.088

@export_group("Collision")
## Box collider for the chassis (width, height, length).
@export var collision_size := Vector3(1.8, 1.0, 4.4)
@export var collision_offset := Vector3(0.0, 0.575, 0.152)

@export_group("Handling")
## Handling archetype applied to this car at spawn (steering, grip, stability,
## power, aero — the same presets as the F1 tuning panel). "Scene default"
## leaves the vehicle's own values untouched.
@export var handling_preset: HandlingPresets.Preset = HandlingPresets.Preset.SCENE_DEFAULT

@export_group("Gearbox")
## How this car's automatic gearbox is geared. "Scene default" keeps whatever
## ratios the vehicle already has; the presets and Custom recompute the ratios
## to suit a top speed and gear count (same options as the F1 tuning panel).
@export var gearbox_preset: GearboxPresets.Preset = GearboxPresets.Preset.SCENE_DEFAULT
## Number of gears, used when Gearbox Preset is Custom.
@export_range(3, 8, 1, "or_greater") var custom_gear_count := 5
## Top speed the gearbox is spread across, used when Gearbox Preset is Custom.
@export_range(60.0, 300.0, 5.0) var custom_top_speed_kmh := 160.0
## Override the shift feel too (else the vehicle's own values are kept).
@export var override_shift_feel := false
## Minimum seconds between automatic shifts (anti-hunting). Applied if overriding.
@export_range(0.0, 2.0, 0.05) var shift_cooldown := 0.5
## Downshift when the lower gear would sit under this fraction of redline.
@export_range(0.3, 0.95, 0.01) var downshift_point := 0.75

@export_group("Identity")
## Shown in menus/standings later. Also handy for telling rivals apart.
@export var display_name := "Racer"
## Optional tint applied to the body's materials, so one model can field a
## whole grid of visually distinct cars.
@export var body_tint := Color.WHITE
@export var apply_tint := false
