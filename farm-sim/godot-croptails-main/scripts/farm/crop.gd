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
## Emitted when the crop finishes its last stage and can be harvested.
signal matured()
signal died()

enum State { EMPTY, GROWING, MATURE, DEAD, HARVESTED }

const MAX_HEALTH := 100.0

## Passed as the temperature when the caller is not modelling it at all, in
## which case the crop grows at full rate. Keeps the older callers working.
const NO_TEMPERATURE := -999.0

# --- identity ---------------------------------------------------------------
var crop_id: String = ""
var display_name: String = ""

# --- live state -------------------------------------------------------------
var state: int = State.EMPTY
var health: float = MAX_HEALTH
var moisture: float = 0.5
var day: int = 0
var stage_index: int = 0
## Fractional, because a cold day advances the crop by less than a full day of
## development. This is what makes planting out of season cost you.
var days_in_stage: float = 0.0
var pest_active: bool = false
var pest_days_untreated: int = 0
var waterlogged_days: int = 0

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
	days_in_stage = 0.0
	pest_active = false
	pest_days_untreated = 0
	waterlogged_days = 0
	yield_penalties.clear()
	action_log.clear()

	_record_action("plant", "Planted %s." % display_name)
	stage_changed.emit(current_stage_id(), current_stage_name())
	return true


## Adds water to the soil. Amount is a fraction of field capacity (0..1).
##
## Watering stops short of drowning the crop. A farmer with a watering can sees
## the soil is wet and stops; the player has only one watering action and no way
## to pour a smaller amount, so letting that single action drown the crop
## punishes them for the only move available to them.
##
## Waterlogging is still in the model, and still teaches - it now comes from
## rain and storms, which the forecast warns about a day ahead. The lesson
## becomes "look at the forecast before you irrigate", which is a decision the
## player can actually act on.
func water(amount: float = 0.35) -> bool:
	if state != State.GROWING and state != State.MATURE:
		return false

	var ceiling: float = float(_definition.get("waterlogged_point", 1.0)) - 0.02
	if moisture >= ceiling:
		_record_action("water_skipped", "Soil was already wet enough; more would have drowned the roots.")
		return false

	var before := moisture
	moisture = clampf(moisture + amount, 0.0, ceiling)
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


## Jumps straight to maturity, skipping whatever growth is left.
##
## DEMO AND TESTING ONLY. This bypasses the simulation entirely: the yield you
## get reflects only the damage accumulated up to the moment it was called, so
## a crop ripened the instant it was planted harvests at full weight. Do not
## call it from gameplay - it is here so a crop cycle can be shown in a meeting
## without sitting through twenty-six days of it.
func force_mature() -> bool:
	if state != State.GROWING:
		return false
	stage_index = _definition["stages"].size() - 1
	days_in_stage = 0.0
	state = State.MATURE
	matured.emit()
	_record_action("force_mature", "[demo] Skipped ahead to harvest.")
	stage_changed.emit(current_stage_id(), current_stage_name())
	return true


## Harvests a mature crop and returns the end-of-cycle summary.
##
## The state change happens BEFORE the summary is built, so the record says
## what the crop actually is rather than what it was a moment earlier. This is
## safe: projected_yield_kg() treats HARVESTED and MATURE identically, so the
## yield figure does not move.
func harvest() -> Dictionary:
	var was_mature := state == State.MATURE
	if was_mature:
		state = State.HARVESTED

	var summary := build_summary()
	if was_mature:
		_record_action("harvest", "Harvested %.1f kg of %s." % [summary["yield_kg"], display_name])
	return summary


# --- daily simulation -------------------------------------------------------

## Advances the simulation by one day.
##
## evaporation_multiplier scales water loss: 1.0 normal, higher in a heatwave
## or drought. temperature_c drives how much the crop actually develops today.
## Both are owned by the weather system.
##
## growth_multiplier compresses the calendar without touching the agronomy - a
## tutorial crop can ripen in a day while crops.json still holds the real
## number of days the crop takes in the field.
func advance_day(
	evaporation_multiplier: float = 1.0,
	pest_chance: float = 0.0,
	temperature_c: float = NO_TEMPERATURE,
	growth_multiplier: float = 1.0
) -> void:
	if state != State.GROWING and state != State.MATURE:
		return

	day += 1

	var health_before := health

	_apply_water_loss(evaporation_multiplier)
	_apply_water_stress()
	_apply_waterlogging()
	_apply_cold_damage(temperature_c)
	_maybe_start_pest(pest_chance)
	_apply_pest_damage()

	# A plant that took no harm today puts condition back on. Without this,
	# health is a ratchet: one bad spell below growth_stall_health and the crop
	# can never grow again, yet never dies either - it just stands there for the
	# rest of the game looking alive.
	#
	# Recovering health does NOT undo the loss. yield_penalties is the ledger and
	# it is append-only, so every kilogram already forfeited stays forfeited.
	# Health is the plant's condition today; the ledger is what the season cost.
	if health == health_before and health > 0.0:
		health = minf(health + _library.tuning("recovery_per_day", 2.0), MAX_HEALTH)

	if health <= 0.0:
		health = 0.0
		state = State.DEAD
		health_changed.emit(health)
		died.emit()
		return

	_advance_growth(growth_rate_at(temperature_c) * maxf(growth_multiplier, 0.0))
	health_changed.emit(health)


## How much development one day buys at this temperature, as a 0..1 fraction.
##
## Below the crop's minimum growth temperature it is zero: the plant simply
## stops developing. This is the mechanism behind the whole season lesson.
## Without it, weather only changes how often you water, and a diligent player
## cancels the season out entirely - which is exactly backwards.
func growth_rate_at(temperature_c: float) -> float:
	if temperature_c == NO_TEMPERATURE or _definition.is_empty():
		return 1.0

	var minimum: float = float(_definition.get("min_growth_temp_c", -999.0))
	var optimal: float = float(_definition.get("optimal_temp_c", 25.0))
	if temperature_c <= minimum:
		return 0.0

	var floor_rate: float = _library.tuning("min_growth_rate", 0.3)
	var ramp: float = clampf((temperature_c - minimum) / maxf(optimal - minimum, 0.001), 0.0, 1.0)
	return floor_rate + (1.0 - floor_rate) * ramp


func _apply_cold_damage(temperature_c: float) -> void:
	if temperature_c == NO_TEMPERATURE:
		return
	var minimum: float = float(_definition.get("min_growth_temp_c", -999.0))
	if temperature_c > minimum:
		return

	var damage: float = float(_definition.get("cold_damage_per_day", 0.0))
	if damage <= 0.0:
		return

	_damage_health(damage)
	_record_penalty(
		"cold",
		damage,
		"Day %d, %s: %.0f degrees is below the %.0f degrees %s needs to grow. The crop is not developing at all." % [
			day, current_stage()["display_name"], temperature_c, minimum, display_name
		]
	)


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


## Waterlogging needs the soil to STAY saturated, not merely to get a soaking.
##
## Soil drains. A single downpour runs off and away within a day, which is why
## the first saturated day costs nothing - it only drains. Damage starts on the
## second consecutive day, because that is when roots are actually starved of
## air. Without this, every storm damaged every crop and waterlogging was more
## than half of all damage in the game: noise rather than a lesson.
func _apply_waterlogging() -> void:
	if not _definition.has("waterlogged_point"):
		return
	var soaked: float = float(_definition["waterlogged_point"])

	if moisture <= soaked:
		waterlogged_days = 0
		return

	waterlogged_days += 1

	# Drainage. Excess water leaves the soil quickly whether or not the crop
	# was harmed by it.
	var drain: float = _library.tuning("daily_drainage", 0.25)
	moisture = maxf(moisture - drain, soaked)

	if waterlogged_days < 2:
		return

	var severity: float = (moisture - soaked) / maxf(1.0 - soaked, 0.001)
	var damage: float = maxf(severity, 0.35) * _library.tuning("waterlog_damage_per_day", 5.0)

	_damage_health(damage)
	_record_penalty(
		"waterlogged",
		damage,
		"Day %d, %s: soil has been waterlogged for %d days. Roots need air as well as water; standing water drowns them." % [
			day, current_stage()["display_name"], waterlogged_days
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


func _advance_growth(growth_rate: float = 1.0) -> void:
	# A badly stressed plant stops developing rather than growing on schedule.
	if health < _library.tuning("growth_stall_health", 25.0):
		return
	if state == State.MATURE:
		return
	if growth_rate <= 0.0:
		return

	days_in_stage += growth_rate

	# A loop rather than a single check, and subtraction rather than zeroing.
	# A tutorial crop running at ten times the calendar clears several stages in
	# one day, and carrying the remainder forward means no development is thrown
	# away when a stage is passed part way through a day.
	while days_in_stage >= float(current_stage()["days"]):
		if stage_index >= _definition["stages"].size() - 1:
			state = State.MATURE
			matured.emit()
			return

		days_in_stage -= float(current_stage()["days"])
		stage_index += 1
		stage_changed.emit(current_stage_id(), current_stage_name())


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


## True when the soil has dropped below the point where this crop starts
## taking damage. "Looks a bit dry" and "is losing yield right now" are
## different things and the player needs to be able to tell them apart.
func is_thirsty() -> bool:
	if _definition.is_empty():
		return false
	if state != State.GROWING and state != State.MATURE:
		return false
	return moisture < float(_definition.get("wilting_point", 0.0))


func is_ready_to_harvest() -> bool:
	return state == State.MATURE


## 0.0 to 1.0 progress through the whole cycle, for a HUD progress bar.
func growth_progress() -> float:
	if _definition.is_empty():
		return 0.0
	var total := _library.days_to_maturity(crop_id)
	if total <= 0:
		return 0.0
	var elapsed := 0.0
	for i in range(stage_index):
		elapsed += float(_definition["stages"][i]["days"])
	elapsed += days_in_stage
	return clampf(elapsed / float(total), 0.0, 1.0)


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
		"cold": return "cold - the wrong season for this crop"
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
