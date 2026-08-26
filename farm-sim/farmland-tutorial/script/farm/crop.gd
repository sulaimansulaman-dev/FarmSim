class_name Crop
extends RefCounted

## One planted crop on one tile, simulated day by day.
##
## Design note - why this class records a decision log
## ---------------------------------------------------
## FR-005 requires the end-of-cycle summary to explain HOW the player's
## decisions affected the result. A model that only tracks a health number
## cannot do that: at harvest you have a figure and no story behind it.
##
## So this class keeps two separate things:
##
##   health           the visible indicator the HUD shows      (FR-003)
##   yield_penalties  an itemised list of what cost the player yield, and why
##                    (FR-005, and the source material for quiz questions tied
##                     to the player's own actions, FR-012)
##
## Final yield is computed from the penalty list, not from health, so every
## kilogram lost can be traced to a named cause on a named day. Build it any
## other way and FR-005 becomes guesswork.

signal stage_changed(new_stage_id: String, display_name: String)
signal health_changed(new_health: float)
signal pest_appeared()
signal died()

enum State { EMPTY, GROWING, MATURE, DEAD, HARVESTED }

const MAX_HEALTH := 100.0

# --- identity ---------------------------------------------------------------
var crop_id: String = ""
var display_name: String = ""

# --- live state -------------------------------------------------------------
var state: int = State.EMPTY
var health: float = MAX_HEALTH
var moisture: float = 0.5
var day: int = 0
var stage_index: int = 0
var days_in_stage: int = 0
var pest_active: bool = false
var pest_days_untreated: int = 0

# --- explanation of the result ----------------------------------------------
var yield_penalties: Array = []
var action_log: Array = []

var _library: CropLibrary
var _definition: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(library: CropLibrary, rng_seed: int = 0) -> void:
	_library = library
	# A fixed seed makes a cycle reproducible, which DEL-02 requires: yield must
	# respond to player actions "correctly and repeatably". Same seed plus same
	# actions must always give the same harvest, or QA cannot test this at all.
	_rng.seed = rng_seed


# --- player actions ---------------------------------------------------------

## Plants a crop on this tile. Returns false if the id is unknown or the tile
## is already occupied.
func plant(new_crop_id: String, starting_moisture: float = 0.5) -> bool:
	if state != State.EMPTY and state != State.HARVESTED:
		return false
	if not _library.has_crop(new_crop_id):
		push_warning("Crop.plant: unknown crop id '%s'" % new_crop_id)
		return false

	_definition = _library.get_definition(new_crop_id)
	crop_id = new_crop_id
	display_name = _definition["display_name"]

	state = State.GROWING
	health = MAX_HEALTH
	moisture = clampf(starting_moisture, 0.0, 1.0)
	day = 0
	stage_index = 0
	days_in_stage = 0
	pest_active = false
	pest_days_untreated = 0
	yield_penalties.clear()
	action_log.clear()

	_record_action("plant", "Planted %s." % display_name)
	stage_changed.emit(current_stage_id(), current_stage_name())
	return true


## Adds water to the soil. Amount is a fraction of field capacity (0..1).
func water(amount: float = 0.35) -> bool:
	if state != State.GROWING and state != State.MATURE:
		return false
	var before := moisture
	moisture = clampf(moisture + amount, 0.0, 1.0)
	_record_action("water", "Watered. Soil moisture %d%% to %d%%." % [
		int(round(before * 100.0)), int(round(moisture * 100.0))
	])
	return true


## Treats an active pest outbreak. Returns false if there was nothing to treat,
## which the UI should surface - wasting a treatment is itself a lesson.
func treat_pest() -> bool:
	if not pest_active:
		_record_action("treat_pest_wasted", "Applied treatment, but there was no pest outbreak.")
		return false
	pest_active = false
	pest_days_untreated = 0
	_record_action("treat_pest", "Treated the pest outbreak.")
	return true


## Harvests a mature crop and returns the end-of-cycle summary.
func harvest() -> Dictionary:
	var summary := build_summary()
	if state == State.MATURE:
		state = State.HARVESTED
		_record_action("harvest", "Harvested %.1f kg of %s." % [summary["yield_kg"], display_name])
	return summary


# --- daily simulation -------------------------------------------------------

## Advances the simulation by one day.
## evaporation_multiplier lets weather scale water loss: 1.0 normal, higher in
## a heatwave or drought. Owned by the weather system.
func advance_day(evaporation_multiplier: float = 1.0, pest_chance: float = 0.0) -> void:
	if state != State.GROWING and state != State.MATURE:
		return

	day += 1

	_apply_water_loss(evaporation_multiplier)
	_apply_water_stress()
	_apply_waterlogging()
	_maybe_start_pest(pest_chance)
	_apply_pest_damage()

	if health <= 0.0:
		health = 0.0
		state = State.DEAD
		health_changed.emit(health)
		died.emit()
		return

	_advance_growth()
	health_changed.emit(health)


func _apply_water_loss(evaporation_multiplier: float) -> void:
	var use: float = float(_definition["daily_water_use"]) * maxf(evaporation_multiplier, 0.0)
	moisture = clampf(moisture - use, 0.0, 1.0)


func _apply_water_stress() -> void:
	var wilting: float = float(_definition["wilting_point"])
	if moisture >= wilting:
		return

	# How far below the wilting point are we, as a 0..1 severity.
	var severity: float = (wilting - moisture) / maxf(wilting, 0.001)
	var stage := current_stage()
	var sensitivity: float = float(stage["water_sensitivity"])
	var damage: float = severity * sensitivity * _library.tuning("stress_damage_per_day", 9.0)

	_damage_health(damage)
	_record_penalty(
		"water_stress",
		damage,
		"Day %d, %s: soil was too dry (%d%%). %s" % [
			day, stage["display_name"], int(round(moisture * 100.0)),
			stage.get("teaching_note", "")
		]
	)


func _apply_waterlogging() -> void:
	if not _definition.has("waterlogged_point"):
		return
	var soaked: float = float(_definition["waterlogged_point"])
	if moisture <= soaked:
		return

	# Over-watering is a real and common mistake, so the model punishes it.
	# A game where more water is always better teaches the wrong lesson.
	var severity: float = (moisture - soaked) / maxf(1.0 - soaked, 0.001)
	var damage: float = severity * _library.tuning("waterlog_damage_per_day", 5.0)

	_damage_health(damage)
	_record_penalty(
		"waterlogged",
		damage,
		"Day %d, %s: soil was waterlogged (%d%%). Roots need air as well as water; over-watering drowns them." % [
			day, current_stage()["display_name"], int(round(moisture * 100.0))
		]
	)


func _maybe_start_pest(pest_chance: float) -> void:
	if pest_active or pest_chance <= 0.0:
		return
	var susceptibility: float = float(_definition.get("pest_susceptibility", 1.0))
	if _rng.randf() < pest_chance * susceptibility:
		pest_active = true
		pest_days_untreated = 0
		pest_appeared.emit()
		_record_action("pest_outbreak", "Day %d: a pest outbreak appeared." % day)


func _apply_pest_damage() -> void:
	if not pest_active:
		return
	pest_days_untreated += 1
	var damage: float = _library.tuning("pest_damage_per_day", 7.0)

	_damage_health(damage)
	_record_penalty(
		"pest",
		damage,
		"Day %d, %s: pests fed on the crop for a %s day untreated." % [
			day, current_stage()["display_name"], _ordinal(pest_days_untreated)
		]
	)


func _advance_growth() -> void:
	# A badly stressed plant stops developing rather than growing on schedule.
	if health < _library.tuning("growth_stall_health", 25.0):
		return
	if state == State.MATURE:
		return

	days_in_stage += 1
	var stage := current_stage()

	if days_in_stage >= int(stage["days"]):
		if stage_index < _definition["stages"].size() - 1:
			stage_index += 1
			days_in_stage = 0
			stage_changed.emit(current_stage_id(), current_stage_name())
		else:
			state = State.MATURE


# --- queries ----------------------------------------------------------------

func current_stage() -> Dictionary:
	if _definition.is_empty():
		return {}
	return _definition["stages"][stage_index]


func current_stage_id() -> String:
	var stage := current_stage()
	return stage.get("id", "")


func current_stage_name() -> String:
	var stage := current_stage()
	return stage.get("display_name", "")


func is_ready_to_harvest() -> bool:
	return state == State.MATURE


## 0.0 to 1.0 progress through the whole cycle, for a HUD progress bar.
func growth_progress() -> float:
	if _definition.is_empty():
		return 0.0
	var total := _library.days_to_maturity(crop_id)
	if total <= 0:
		return 0.0
	var elapsed := 0
	for i in range(stage_index):
		elapsed += int(_definition["stages"][i]["days"])
	elapsed += days_in_stage
	return clampf(float(elapsed) / float(total), 0.0, 1.0)


## Total percentage of potential yield lost, 0..100.
func total_penalty_percent() -> float:
	var total := 0.0
	for penalty in yield_penalties:
		total += float(penalty["percent"])
	return minf(total, 100.0)


## The yield this crop would produce if harvested now, in kilograms (FR-004).
func projected_yield_kg() -> float:
	if _definition.is_empty() or state == State.DEAD:
		return 0.0
	var base: float = float(_definition["base_yield_kg"])
	var kept: float = (100.0 - total_penalty_percent()) / 100.0
	# Harvesting before maturity gives only what has developed so far.
	var maturity := 1.0
	if state != State.MATURE and state != State.HARVESTED:
		maturity = growth_progress()
	return maxf(base * kept * maturity, 0.0)


## The end-of-cycle summary (FR-004, FR-005).
##
## Returned as plain Dictionaries and Arrays so it serialises straight to JSON
## for the anonymised session log (FR-015, NFR-004) with no conversion step.
func build_summary() -> Dictionary:
	var causes := {}
	for penalty in yield_penalties:
		var cause: String = penalty["cause"]
		causes[cause] = float(causes.get(cause, 0.0)) + float(penalty["percent"])

	var headline := ""
	var worst_cause := ""
	var worst_amount := 0.0
	for cause in causes:
		if causes[cause] > worst_amount:
			worst_amount = causes[cause]
			worst_cause = cause

	if state == State.DEAD:
		headline = "The crop died before harvest."
	elif yield_penalties.is_empty():
		headline = "A clean cycle. The crop reached harvest with no losses."
	else:
		headline = "Biggest loss: %s, costing %d%% of the potential harvest." % [
			_cause_label(worst_cause), int(round(worst_amount))
		]

	return {
		"crop_id": crop_id,
		"display_name": display_name,
		"days_taken": day,
		"final_health": snappedf(health, 0.1),
		"state": _state_name(state),
		"potential_yield_kg": float(_definition.get("base_yield_kg", 0.0)),
		"yield_kg": snappedf(projected_yield_kg(), 0.1),
		"yield_lost_percent": snappedf(total_penalty_percent(), 0.1),
		"headline": headline,
		"losses_by_cause": causes,
		"penalties": yield_penalties.duplicate(true),
		"actions": action_log.duplicate(true),
	}


# --- internals --------------------------------------------------------------

func _damage_health(amount: float) -> void:
	health = clampf(health - amount, 0.0, MAX_HEALTH)


## Health damage and yield loss are deliberately the same magnitude here, but
## kept as separate concepts: health is what the player sees during the cycle,
## the penalty list is what explains the result afterwards.
func _record_penalty(cause: String, damage: float, explanation: String) -> void:
	yield_penalties.append({
		"day": day,
		"stage": current_stage_id(),
		"cause": cause,
		"percent": snappedf(damage, 0.1),
		"explanation": explanation,
	})


func _record_action(action: String, description: String) -> void:
	action_log.append({
		"day": day,
		"action": action,
		"description": description,
	})


func _cause_label(cause: String) -> String:
	match cause:
		"water_stress": return "water stress"
		"waterlogged": return "over-watering"
		"pest": return "pest damage"
		_: return cause


func _state_name(value: int) -> String:
	match value:
		State.EMPTY: return "empty"
		State.GROWING: return "growing"
		State.MATURE: return "mature"
		State.DEAD: return "dead"
		State.HARVESTED: return "harvested"
		_: return "unknown"


func _ordinal(n: int) -> String:
	match n:
		1: return "first"
		2: return "second"
		3: return "third"
		_: return "%dth" % n
