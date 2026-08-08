class_name GearboxPresets
extends RefCounted
## Shared gearbox math: turns a target top speed + gear count into ratios that
## make the box span the speed range a track actually reaches (a gearbox geared
## for speeds never reached is the usual cause of gear hunting).
##
## One source of truth for both the F1 tuning panel (player, live) and
## VehicleDefinition (per AI car, applied at spawn).

enum Preset { SCENE_DEFAULT, THREE_LAZY, FOUR_ARCADE, FIVE_SPEED, SIX_QUICK, CUSTOM }

const GEAR_SPACING_EXPONENT := 0.75
const RPM_PER_RAD := 60.0 / TAU

## preset -> [gear_count, top_speed_kmh]
const SPECS := {
	Preset.THREE_LAZY: [3, 130.0],
	Preset.FOUR_ARCADE: [4, 140.0],
	Preset.FIVE_SPEED: [5, 160.0],
	Preset.SIX_QUICK: [6, 190.0],
}

## Ratios so gear N tops out at its share of [param top_speed_kmh]. Lower gears
## are spaced closer together than higher ones.
static func compute_ratios(top_speed_kmh: float, gear_count: int, max_rpm: float,
		tire_radius: float, final_drive: float) -> Array[float]:
	var ratios: Array[float] = []
	if gear_count < 1 or final_drive <= 0.0 or tire_radius <= 0.0:
		return ratios
	var k := (max_rpm / RPM_PER_RAD) * tire_radius * 3.6
	for i in gear_count:
		var fraction := pow(float(i + 1) / float(gear_count), GEAR_SPACING_EXPONENT)
		var speed := maxf(top_speed_kmh * fraction, 1.0)
		ratios.append(k / speed / final_drive)
	return ratios

## Ratios for a preset. Returns [] for SCENE_DEFAULT (meaning: keep whatever
## gearbox the vehicle already has).
static func ratios_for(preset: Preset, custom_gears: int, custom_top_kmh: float,
		max_rpm: float, tire_radius: float, final_drive: float) -> Array[float]:
	if preset == Preset.SCENE_DEFAULT:
		return []
	if preset == Preset.CUSTOM:
		return compute_ratios(custom_top_kmh, custom_gears, max_rpm, tire_radius, final_drive)
	var spec: Array = SPECS[preset]
	return compute_ratios(spec[1], spec[0], max_rpm, tire_radius, final_drive)
