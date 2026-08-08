class_name HandlingPresets
extends RefCounted
## Shared handling archetypes (Muscle / Sedan / Formula One / Truck / SUV).
##
## One source of truth for both the F1 tuning panel (player, live) and
## VehicleDefinition (per AI car, applied at spawn). Only live-tunable values are
## included — mass and suspension are baked when the vehicle initializes, so a
## Truck here is sluggish and low-grip rather than physically heavier.

enum Preset { SCENE_DEFAULT, MUSCLE, SEDAN, FORMULA_ONE, TRUCK, SUV }

## Display order + labels for menus.
const ORDER := [Preset.MUSCLE, Preset.SEDAN, Preset.FORMULA_ONE, Preset.TRUCK, Preset.SUV]
const NAMES := {
	Preset.MUSCLE: "Muscle Car",
	Preset.SEDAN: "Sedan",
	Preset.FORMULA_ONE: "Formula One",
	Preset.TRUCK: "Truck",
	Preset.SUV: "SUV",
}

const DATA := {
	Preset.MUSCLE: {
		"steer_deg": 38.0, "steer_speed": 3.6, "countersteer_speed": 10.0,
		"steer_decay": 0.22, "steer_exponent": 1.6, "countersteer_assist": 0.70,
		"throttle_speed": 16.0, "brake_speed": 9.0, "max_torque": 650.0, "tcs_slip": 14.0,
		"friction": 2.00, "stiffness": 4.5, "lateral_assist": 0.03,
		"stability": true, "yaw_strength": 1.6, "yaw_ground": 3.2,
		"drag": 0.36,
	},
	Preset.SEDAN: {
		"steer_deg": 40.0, "steer_speed": 4.5, "countersteer_speed": 12.0,
		"steer_decay": 0.20, "steer_exponent": 1.4, "countersteer_assist": 0.90,
		"throttle_speed": 20.0, "brake_speed": 12.0, "max_torque": 300.0, "tcs_slip": 6.0,
		"friction": 2.40, "stiffness": 6.5, "lateral_assist": 0.08,
		"stability": true, "yaw_strength": 3.0, "yaw_ground": 4.0,
		"drag": 0.31,
	},
	Preset.FORMULA_ONE: {
		"steer_deg": 26.0, "steer_speed": 7.0, "countersteer_speed": 16.0,
		"steer_decay": 0.14, "steer_exponent": 1.2, "countersteer_assist": 0.60,
		"throttle_speed": 34.0, "brake_speed": 26.0, "max_torque": 780.0, "tcs_slip": 4.0,
		"friction": 4.60, "stiffness": 16.0, "lateral_assist": 0.14,
		"stability": true, "yaw_strength": 4.5, "yaw_ground": 5.0,
		"drag": 0.85,
	},
	Preset.TRUCK: {
		"steer_deg": 34.0, "steer_speed": 2.4, "countersteer_speed": 7.0,
		"steer_decay": 0.35, "steer_exponent": 1.8, "countersteer_assist": 0.80,
		"throttle_speed": 8.0, "brake_speed": 6.0, "max_torque": 820.0, "tcs_slip": 16.0,
		"friction": 1.80, "stiffness": 3.5, "lateral_assist": 0.02,
		"stability": true, "yaw_strength": 1.2, "yaw_ground": 2.5,
		"drag": 0.75,
	},
	Preset.SUV: {
		"steer_deg": 37.0, "steer_speed": 3.3, "countersteer_speed": 9.0,
		"steer_decay": 0.26, "steer_exponent": 1.6, "countersteer_assist": 0.80,
		"throttle_speed": 13.0, "brake_speed": 8.0, "max_torque": 430.0, "tcs_slip": 10.0,
		"friction": 2.10, "stiffness": 4.8, "lateral_assist": 0.04,
		"stability": true, "yaw_strength": 2.0, "yaw_ground": 3.4,
		"drag": 0.52,
	},
}

## The value table for a preset ({} for SCENE_DEFAULT).
static func values(preset: Preset) -> Dictionary:
	return DATA.get(preset, {})

## Applies a preset's live-tunable handling to a vehicle. Grip is written to the
## vehicle's dictionaries and to any already-initialised wheels, so this works
## both before initialize() (AI, at spawn) and after it (live tuning).
static func apply(vehicle: MeridianVehicle, preset: Preset) -> void:
	var p: Dictionary = DATA.get(preset, {})
	if p.is_empty():
		return
	vehicle.max_steering_angle = deg_to_rad(p["steer_deg"])
	vehicle.steering_speed = p["steer_speed"]
	vehicle.countersteer_speed = p["countersteer_speed"]
	vehicle.steering_speed_decay = p["steer_decay"]
	vehicle.steering_exponent = p["steer_exponent"]
	vehicle.countersteer_assist = p["countersteer_assist"]
	vehicle.throttle_speed = p["throttle_speed"]
	vehicle.braking_speed = p["brake_speed"]
	vehicle.max_torque = p["max_torque"]
	vehicle.traction_control_max_slip = p["tcs_slip"]
	vehicle.coefficient_of_friction["Road"] = p["friction"]
	vehicle.tire_stiffnesses["Road"] = p["stiffness"]
	vehicle.lateral_grip_assist["Road"] = p["lateral_assist"]
	vehicle.enable_stability = p["stability"]
	vehicle.stability_yaw_strength = p["yaw_strength"]
	vehicle.stability_yaw_ground_multiplier = p["yaw_ground"]
	vehicle.coefficient_of_drag = p["drag"]
	for w in vehicle.wheel_array:
		w.coefficient_of_friction["Road"] = p["friction"]
		w.tire_stiffnesses["Road"] = p["stiffness"]
		w.lateral_grip_assist["Road"] = p["lateral_assist"]
		if w.surface_type == "Road":
			w.current_cof = p["friction"]
			w.current_tire_stiffness = 1000000.0 + 8000000.0 * p["stiffness"]
			w.current_lateral_grip_assist = p["lateral_assist"]
