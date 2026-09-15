extends Node

## One run through one stage: goals, the clock, stars, and moving on.
##
## Every stage has a short checklist in data/stages.json. This autoload counts
## progress against it from FarmEvents, keeps the stage timer, and works out the
## 3-star rating with the spec's weighted formula (FR-EVA-002):
##
##   score = time x w_time + crops x w_crops + quiz x w_quiz
##
## The first star is the checklist itself. Until every objective is done the
## rating is zero stars and the bridge off the island stays shut. Once it opens,
## the rating shown on the HUD assumes a perfect quiz - the bridge keeper's quiz
## is what settles the final number.
##
## Moving to the next stage is host-authoritative. In a LAN game whoever passes
## the quiz asks the host, and the host loads the next stage on every device.

signal session_started(stage_id: String)
signal objectives_changed()
signal bridge_opened()
signal stage_finished(stage_id: String, evaluation: Dictionary)

const DATA_PATH := "res://data/stages.json"
const FRUIT_NAMES := ["apple", "orange", "peach", "pear"]
## Where a player is placed when a stage loads, if the level has no PlayerSpawn
## marker. The same spot the main scene's static player starts on.
const DEFAULT_SPAWN := Vector2(512, 156)

var stage_id: String = ""
var active: bool = false
var elapsed_sec: float = 0.0
var bridge_open: bool = false
## Set once the quiz is passed, so walking back onto the bridge does nothing.
var quiz_passed: bool = false

var _config: Dictionary = {}
var _counts: Dictionary = {}
var _seasons_harvested: Dictionary = {}


func _ready() -> void:
	_load()
	SceneManager.level_loaded.connect(_on_level_loaded)
	SceneManager.returned_to_title.connect(_on_returned_to_title)

	FarmEvents.crop_planted.connect(_on_crop_planted)
	FarmEvents.crop_watered.connect(func(_p): _bump("water"))
	FarmEvents.crop_harvested.connect(func(_id, _kg): _bump("harvest"))
	FarmEvents.crop_graded.connect(_on_crop_graded)
	FarmEvents.soil_tilled.connect(func(_pos): _bump("till"))
	FarmEvents.pest_treated.connect(func(_p): _bump("treat_pest"))
	FarmEvents.item_collected.connect(_on_item_collected)
	FarmEvents.produce_sold.connect(func(amount): _bump("sell_earned", int(round(amount))))
	FarmEvents.supply_bought.connect(func(_id): _bump("buy_supply"))
	FarmEvents.tree_planted.connect(func(_t): _bump("plant_tree"))
	FarmEvents.tree_chopped.connect(func(): _bump("chop_tree"))


func _process(delta: float) -> void:
	if active and not quiz_passed:
		elapsed_sec += delta


# --- data -------------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_error("StageSession: %s is missing." % DATA_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("StageSession: %s is not valid JSON." % DATA_PATH)
		return
	_config = parsed


func stage_order() -> Array:
	return _config.get("order", [])


func definition(id: String = "") -> Dictionary:
	if id.is_empty():
		id = stage_id
	return _config.get("stages", {}).get(id, {})


func is_stage(id: String) -> bool:
	return not definition(id).is_empty()


func area_id(id: String) -> String:
	return str(definition(id).get("area_id", ""))


func next_stage_id(id: String) -> String:
	return str(definition(id).get("next", ""))


func extra_tools() -> Array:
	return definition().get("extra_tools", [])


# --- lifecycle --------------------------------------------------------------

func _on_level_loaded(_display_name: String) -> void:
	var id := SceneManager.current_level
	if not is_stage(id):
		active = false
		stage_id = ""
		objectives_changed.emit()
		return
	begin(id)


func begin(id: String) -> void:
	stage_id = id
	active = true
	elapsed_sec = 0.0
	bridge_open = false
	quiz_passed = false
	_counts.clear()
	_seasons_harvested.clear()
	session_started.emit(id)
	objectives_changed.emit()


func _on_returned_to_title() -> void:
	active = false
	stage_id = ""


# --- counting ---------------------------------------------------------------

func _bump(kind: String, amount: int = 1) -> void:
	if not active:
		return
	_counts[kind] = int(_counts.get(kind, 0)) + amount
	objectives_changed.emit()
	_check_bridge()


func _on_crop_planted(plant: CropPlant) -> void:
	_bump("plant")
	if SeasonManager.enabled and SeasonManager.season_suits_crop(plant.crop_id):
		_bump("sow_in_season")


func _on_crop_graded(_crop_id: String, grade: String, _kg: float) -> void:
	if grade == "A":
		_bump("grade_a")
	if SeasonManager.enabled:
		_seasons_harvested[SeasonManager.season_id()] = true
		_counts["harvest_seasons"] = _seasons_harvested.size()
		_bump("harvest_seasons", 0)


func _on_item_collected(item_name: String, _amount: int) -> void:
	var base_name: String = EconomyManager.split_grade(item_name)[0]
	if CropManager.library.has_crop(base_name):
		_bump("collect_crop")
	elif base_name in FRUIT_NAMES:
		_bump("collect_fruit")


func count(kind: String) -> int:
	return int(_counts.get(kind, 0))


## The checklist as the HUD shows it.
func objective_progress() -> Array:
	var rows: Array = []
	for objective in definition().get("objectives", []):
		var target := int(objective.get("target", 1))
		var have := mini(count(str(objective.get("type", ""))), target)
		rows.append({
			"label": str(objective.get("label", "")),
			"have": have,
			"target": target,
			"done": have >= target,
		})
	return rows


func objectives_complete() -> bool:
	if not active:
		return false
	for row in objective_progress():
		if not row["done"]:
			return false
	return true


func _check_bridge() -> void:
	if bridge_open or not objectives_complete():
		return
	bridge_open = true
	bridge_opened.emit()
	FarmEvents.advisory.emit("Every goal is done - the bridge to the east is open! Cross it and face the bridge keeper.")


# --- scoring ----------------------------------------------------------------

## Crops (and, on the orchard stage, fruit) brought in this run.
func harvested_count() -> int:
	return count("harvest") + count("collect_fruit")


func time_score() -> float:
	var par := float(definition().get("par_time_sec", 600))
	if elapsed_sec <= par:
		return 1.0
	return clampf(par / maxf(elapsed_sec, 1.0), 0.0, 1.0)


func crop_score() -> float:
	var target := float(definition().get("harvest_target", 1))
	return clampf(float(harvested_count()) / maxf(target, 1.0), 0.0, 1.0)


func score(quiz_score: float) -> float:
	var weights: Dictionary = _config.get("evaluation", {})
	return (
		time_score() * float(weights.get("weight_time", 0.3))
		+ crop_score() * float(weights.get("weight_crops", 0.3))
		+ clampf(quiz_score, 0.0, 1.0) * float(weights.get("weight_quiz", 0.4))
	)


func stars_for_score(value: float) -> int:
	var weights: Dictionary = _config.get("evaluation", {})
	if value >= float(weights.get("three_stars_at", 0.85)):
		return 3
	if value >= float(weights.get("two_stars_at", 0.6)):
		return 2
	return 1


## Stars as they stand right now, assuming the quiz goes perfectly.
func projected_stars() -> int:
	if not objectives_complete():
		return 0
	return stars_for_score(score(1.0))


## The record written to the save file for this run (Tech Spec 4.1).
func build_evaluation(quiz_correct: int, quiz_asked: int, attempts: Array) -> Dictionary:
	var quiz_score := float(quiz_correct) / maxf(float(quiz_asked), 1.0)
	var final_score := score(quiz_score)
	return {
		"stars_earned": stars_for_score(final_score),
		"score": snappedf(final_score, 0.01),
		"quiz_score": int(round(quiz_score * 100.0)),
		"completion_time_sec": int(round(elapsed_sec)),
		"crops_harvested": harvested_count(),
		"grade_a_crops": count("grade_a"),
		"grade_b_crops": maxi(count("harvest") - count("grade_a"), 0),
		"time_score": snappedf(time_score(), 0.01),
		"crop_score": snappedf(crop_score(), 0.01),
		"completed_at": Time.get_datetime_string_from_system(true),
		"quiz_attempts": attempts,
	}


# --- finishing and moving on ------------------------------------------------

## Called by the quiz once the player has seen their stars and pressed on.
func finish_stage(evaluation: Dictionary) -> void:
	quiz_passed = true
	var finished := stage_id
	stage_finished.emit(finished, evaluation)

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_advance.rpc_id(1, finished, evaluation)
		return

	_host_advance(finished, evaluation)


@rpc("any_peer", "call_remote", "reliable")
func _request_advance(finished: String, evaluation: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Only the stage everyone is actually on may be finished. A stale request
	# from a client that lagged behind a stage change is ignored.
	if finished != stage_id:
		return
	_host_advance(finished, evaluation)


func _host_advance(finished: String, evaluation: Dictionary) -> void:
	ProgressManager.record_evaluation(finished, evaluation)

	var next := next_stage_id(finished)
	if next.is_empty():
		if multiplayer.has_multiplayer_peer():
			_show_finale.rpc()
		else:
			_show_finale()
		return

	if multiplayer.has_multiplayer_peer():
		_load_stage.rpc(next)
	else:
		_load_stage(next)


@rpc("authority", "call_local", "reliable")
func _load_stage(next: String) -> void:
	await SceneManager.load_level(next)
	SaveGameManager.allow_save_game = true
	place_local_player()


@rpc("authority", "call_local", "reliable")
func _show_finale() -> void:
	FarmEvents.advisory.emit("You have completed all five stages. The open farm is coming in a later build!")
	get_tree().paused = false
	await get_tree().create_timer(3.0).timeout
	if MultiplayerManager.is_hosting or MultiplayerManager.is_client:
		MultiplayerManager.leave_game()
	GameManager.return_to_title()


## Tells a joining client which stage the host is on, so both are on one map.
func sync_stage_to_peer(peer_id: int) -> void:
	if stage_id.is_empty():
		return
	_load_stage_for_joiner.rpc_id(peer_id, SceneManager.current_level)


@rpc("authority", "call_remote", "reliable")
func _load_stage_for_joiner(level_id: String) -> void:
	if SceneManager.current_level == level_id:
		return
	await SceneManager.load_level(level_id)
	place_local_player()


# --- players ----------------------------------------------------------------

## The player this device controls: the static singleplayer Player, or the
## networked one this peer has authority over.
func local_player() -> Player:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or not player.is_inside_tree():
			continue
		var parent_name := str(player.get_parent().name)
		if parent_name != "GameRoot" and parent_name != "Players":
			continue
		if multiplayer.has_multiplayer_peer() and not player.is_multiplayer_authority():
			continue
		return player
	return null


func place_local_player() -> void:
	var player := local_player()
	if player == null:
		return
	var spawn := DEFAULT_SPAWN
	var level_root := get_node_or_null(SceneManager.main_scene_level_root_path)
	if level_root != null:
		var marker := level_root.find_child("PlayerSpawn", true, false) as Node2D
		if marker != null:
			spawn = marker.global_position
	player.global_position = spawn
	player.velocity = Vector2.ZERO
