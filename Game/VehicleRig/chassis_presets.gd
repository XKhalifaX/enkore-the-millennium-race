class_name ChassisPresets
extends RefCounted
## Baked-physics archetypes: mass, centre-of-gravity height, weight distribution,
## drive split, and suspension travel. These are the values you can't tune live
## and are easy to get wrong, so pick an archetype instead of guessing numbers.
##
## Suspension is stored as a RATIO of tyre radius (spring_length / tyre_radius),
## so travel always suits the wheel size — a monster truck's big wheels get long
## travel automatically.

enum Preset { CUSTOM, LIGHT_CAR, SEDAN, SPORTS, SUV, PICKUP, MONSTER_TRUCK }

const ORDER := [Preset.LIGHT_CAR, Preset.SEDAN, Preset.SPORTS, Preset.SUV,
	Preset.PICKUP, Preset.MONSTER_TRUCK]
const NAMES := {
	Preset.LIGHT_CAR: "Light Car",
	Preset.SEDAN: "Sedan",
	Preset.SPORTS: "Sports",
	Preset.SUV: "SUV",
	Preset.PICKUP: "Pickup",
	Preset.MONSTER_TRUCK: "Monster Truck",
}

## mass(kg) · cog(height offset) · weight(front distribution) · split(0=RWD,1=FWD,
## 0.5=AWD) · spring_ratio(spring length / tyre radius)
const DATA := {
	Preset.LIGHT_CAR:     {"mass": 950.0,  "cog": -0.15, "weight": 0.58, "split": 1.0, "spring_ratio": 0.45},
	Preset.SEDAN:         {"mass": 1500.0, "cog": -0.20, "weight": 0.52, "split": 0.0, "spring_ratio": 0.50},
	Preset.SPORTS:        {"mass": 1300.0, "cog": -0.28, "weight": 0.47, "split": 0.0, "spring_ratio": 0.40},
	Preset.SUV:           {"mass": 2200.0, "cog": -0.10, "weight": 0.55, "split": 0.4, "spring_ratio": 0.60},
	Preset.PICKUP:        {"mass": 2500.0, "cog": -0.08, "weight": 0.57, "split": 0.2, "spring_ratio": 0.60},
	Preset.MONSTER_TRUCK: {"mass": 4800.0, "cog": -0.60, "weight": 0.50, "split": 0.5, "spring_ratio": 0.78},
}

static func values(preset: Preset) -> Dictionary:
	return DATA.get(preset, {})
