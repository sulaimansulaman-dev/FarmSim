extends Node

## The player's progress across the stages, saved as JSON (Tech Spec 4.1).
##
## The file follows the spec's save-state schema:
##
##   player_profile     farmer_level, currency_balance
##   farm_world_state   unlocked_areas, continuous_tiles
##   stage_evaluations  one record per completed stage
##
## continuous_tiles is written but left empty. It belongs to the open-world
## Final Stage, which is outside the Stage 1-5 build.
##
## Storage authority (Tech Spec 4.2): only the host - or a singleplayer game -
## writes to disk. A client keeps its copy in memory so its own menus still
## work, but never touches the file, which is what stops two devices fighting
## over one save.

signal progress_changed()

const SAVE_PATH := "user://farmsim_save.json"
const SCHEMA_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_progress()


# --- file -------------------------------------------------------------------

func load_progress() -> void:
	data = _blank()
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ProgressManager: save file is not valid JSON, starting fresh.")
		return

	# Merged over a blank record, so a save from an older build that lacks a
	# section still loads instead of crashing on a missing key.
	for key in parsed:
		data[key] = parsed[key]
	_ensure_shape()


func save_progress() -> void:
	if not _may_write():
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("ProgressManager: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))


func has_progress() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and not stage_evaluations().is_empty()


## Wipes progress back to a brand-new farm. Stage 1 stays unlocked.
func reset() -> void:
	data = _blank()
	save_progress()
	progress_changed.emit()


# --- queries ----------------------------------------------------------------

func stage_evaluations() -> Dictionary:
	return data["stage_evaluations"]


func unlocked_areas() -> Array:
	return data["farm_world_state"]["unlocked_areas"]


func is_stage_unlocked(stage_id: String) -> bool:
	var area := StageSession.area_id(stage_id)
	if area.is_empty():
		# Anything that is not one of the five stages (old sandbox levels) is
		# never locked.
		return true
	return unlocked_areas().has(area)


func stars_for(stage_id: String) -> int:
	var record: Dictionary = stage_evaluations().get(_eval_key(stage_id), {})
	return int(record.get("stars_earned", 0))


func total_stars() -> int:
	var total := 0
	for record in stage_evaluations().values():
		total += int(record.get("stars_earned", 0))
	return total


## The furthest stage the player can play, which is where Continue goes.
func furthest_unlocked_stage() -> String:
	var furthest := "Stage1"
	for stage_id in StageSession.stage_order():
		if is_stage_unlocked(stage_id):
			furthest = stage_id
	return furthest


# --- recording --------------------------------------------------------------

## Stores a finished stage and unlocks the one after it.
##
## A replay only replaces the record if it earned more stars, so going back to
## practise a stage can never cost the player what they already achieved. The
## quiz attempt log is kept either way, because it is evidence of learning.
func record_evaluation(stage_id: String, evaluation: Dictionary) -> void:
	var key := _eval_key(stage_id)
	var previous: Dictionary = stage_evaluations().get(key, {})
	var attempts: Array = previous.get("quiz_attempts", [])
	attempts.append_array(evaluation.get("quiz_attempts", []))

	var record := evaluation.duplicate(true)
	if int(previous.get("stars_earned", 0)) > int(record.get("stars_earned", 0)):
		record = previous.duplicate(true)
	record["quiz_attempts"] = attempts
	stage_evaluations()[key] = record

	var next_stage := StageSession.next_stage_id(stage_id)
	if not next_stage.is_empty():
		var area := StageSession.area_id(next_stage)
		if not unlocked_areas().has(area):
			unlocked_areas().append(area)

	var profile: Dictionary = data["player_profile"]
	profile["currency_balance"] = int(round(EconomyManager.balance))
	profile["farmer_level"] = 1 + int(total_stars() / 3.0)

	save_progress()
	progress_changed.emit()


# --- internals --------------------------------------------------------------

func _eval_key(stage_id: String) -> String:
	# "Stage3" -> "stage_3", matching the spec's example keys.
	return "stage_" + stage_id.trim_prefix("Stage")


func _may_write() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _blank() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"player_profile": {"farmer_level": 1, "currency_balance": 0},
		"farm_world_state": {"unlocked_areas": ["area_1"], "continuous_tiles": []},
		"stage_evaluations": {},
	}


func _ensure_shape() -> void:
	var blank := _blank()
	for key in blank:
		if typeof(data.get(key)) != typeof(blank[key]):
			data[key] = blank[key]
	if not data["farm_world_state"].has("unlocked_areas"):
		data["farm_world_state"]["unlocked_areas"] = ["area_1"]
	if not unlocked_areas().has("area_1"):
		unlocked_areas().append("area_1")
