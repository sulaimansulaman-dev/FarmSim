extends Node

## Automated walk through Stages 1-5: loads each stage, checks the gate,
## tools, sowing, treatments, saplings and the market, then plays the bridge
## keeper's quiz with correct answers and follows the move to the next stage.
##
## Run this scene on its own. It backs up and restores the real progress file,
## writes PASS/FAIL lines to user://stage_flow_test.txt, and quits when done.

const REPORT_PATH := "user://stage_flow_test.txt"

var _failures := 0
var _backup := ""
var _report: FileAccess


func _ready() -> void:
	_report = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_log("TEST START")
	if FileAccess.file_exists(ProgressManager.SAVE_PATH):
		_backup = FileAccess.get_file_as_string(ProgressManager.SAVE_PATH)
	ProgressManager.reset()
	await _run()
	_restore()
	_log("TEST SUMMARY failures=%d" % _failures)
	_report.close()
	get_tree().quit()


func _log(message: String) -> void:
	print(message)
	if _report != null:
		_report.store_line(message)
		_report.flush()


func _check(condition: bool, label: String) -> void:
	if condition:
		_log("PASS " + label)
	else:
		_failures += 1
		_log("FAIL " + label)


func _restore() -> void:
	if _backup.is_empty():
		if FileAccess.file_exists(ProgressManager.SAVE_PATH):
			DirAccess.remove_absolute(ProgressManager.SAVE_PATH)
	else:
		var file := FileAccess.open(ProgressManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(_backup)
		file.close()
	ProgressManager.load_progress()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	await get_tree().process_frame
	SceneManager.load_main_scene_container()
	await SceneManager.load_level("Stage1")
	await _frames(3)
	StageSession.place_local_player()

	var player := StageSession.local_player()
	_check(player != null, "local player found")
	if player != null:
		var cam := player.get_node("Camera2D") as Camera2D
		_check(is_equal_approx(cam.zoom.x, 1.3), "camera zoom is 1.3 (%s)" % str(cam.zoom))

	for stage_id in StageSession.stage_order():
		await _test_stage(str(stage_id))
		if _failures > 25:
			return


func _level() -> Node:
	var root := get_node(SceneManager.main_scene_level_root_path)
	return root.get_child(root.get_child_count() - 1)


func _test_stage(stage_id: String) -> void:
	_log("=== " + stage_id)
	_check(SceneManager.current_level == stage_id, "%s loaded (current=%s)" % [stage_id, SceneManager.current_level])
	_check(StageSession.active and StageSession.stage_id == stage_id, "%s session active" % stage_id)

	var level := _level()
	var gate := level.get_node_or_null("StageGate") as StageGate
	_check(gate != null, "%s has gate" % stage_id)
	if gate == null:
		return
	_check(gate.floor_root.get_child_count() > 0, "%s bridge floor built (%d pieces)" % [stage_id, gate.floor_root.get_child_count()])
	_check(gate.boundary.get_child_count() > 20, "%s shoreline collision (%d shapes)" % [stage_id, gate.boundary.get_child_count()])
	_check(not gate.barrier_shape.disabled, "%s barrier closed at start" % stage_id)
	_log("   gate at %s keeper at %s" % [gate.global_position, gate.keeper.global_position])

	var tools_panel = get_tree().root.find_child("ToolsPanel", true, false)
	var visible_tools: Array = []
	for tool in tools_panel._buttons:
		if tools_panel._buttons[tool].visible:
			visible_tools.append(DataTypes.Tools.keys()[tool])
	_log("   tools: %s" % str(visible_tools))
	var extras: Array = StageSession.extra_tools()
	if "sapling" in extras:
		_check("PlantSapling" in visible_tools, "%s sapling tool granted" % stage_id)
	if "organic" in extras:
		_check("OrganicControl" in visible_tools, "%s organic tool granted" % stage_id)

	var cursor := level.get_node("CropsCursorComponent") as CropsCursorComponent
	var soil := cursor.tilled_soil_tilemap_layer
	var cells := soil.get_used_cells()
	_check(not cells.is_empty(), "%s has tilled soil" % stage_id)
	if not cells.is_empty():
		var cell: Vector2i = cells[0]
		cursor._send("plant", cell, {"crop_id": "cabbage", "fertilised": false})
		await _frames(1)
		var crop := cursor.crop_at(soil.map_to_local(cell)) as CropPlant
		_check(crop != null and crop.name == "crop_%d_%d" % [cell.x, cell.y], "%s sow via action gives named crop" % stage_id)
		if crop != null and stage_id == "Stage3":
			EconomyManager.balance = 500
			EconomyManager.buy_supply("spray")
			EconomyManager.buy_supply("organic")
			crop.crop_sim.crop.pest_active = true
			crop.crop_sim.crop.pest_type = "bird"
			var result := crop.prepare_treatment("spray")
			_check(result == CropPlant.TREAT_FAILED, "chemical spray fails on birds")
			var organic_result := crop.prepare_treatment("organic")
			_check(organic_result != CropPlant.TREAT_REFUSED, "organic control applied to birds (%d)" % organic_result)
			cursor._send("treat", cell, {"result": CropPlant.TREAT_CLEARED})
			await _frames(1)
			_check(not crop.crop_sim.crop.pest_active, "treatment clears pest")
		if crop != null:
			cursor._send("remove", cell, {})
			await _frames(2)

	if stage_id == "Stage4":
		var grass := level.get_node("GameTilemap/Grass") as TileMapLayer
		var tree_cell := grass.local_to_map(Vector2(400, 200))
		cursor._send("tree", tree_cell, {"index": 1})
		await _frames(1)
		_check(level.get_node_or_null("tree_%d_%d" % [tree_cell.x, tree_cell.y]) != null, "sapling planted as named tree")

	if stage_id != "Stage1":
		var market = load("res://scenes/ui/market_panel.tscn").instantiate()
		get_tree().root.add_child(market)
		await _frames(1)
		_check(market._pages.size() == 3, "%s market has 3 tabs" % stage_id)
		market.close_market()
		await _frames(1)

	# Complete the goals.
	for objective in StageSession.definition().get("objectives", []):
		if StageSession.bridge_open:
			break
		StageSession._bump(str(objective["type"]), int(objective["target"]))
	await _frames(2)
	_check(StageSession.objectives_complete(), "%s objectives complete" % stage_id)
	_check(StageSession.bridge_open, "%s bridge opened" % stage_id)
	_check(gate.barrier_shape.disabled, "%s barrier lifted" % stage_id)
	_check(StageSession.projected_stars() >= 1, "%s projected stars %d" % [stage_id, StageSession.projected_stars()])

	# Walk onto the keeper trigger.
	var player := StageSession.local_player()
	player.global_position = gate.keeper_trigger.global_position
	var quiz = null
	for i in 30:
		await get_tree().physics_frame
		quiz = get_tree().root.get_node_or_null("QuizBattle")
		if quiz != null:
			break
	_check(quiz != null, "%s quiz opened by walking to keeper" % stage_id)
	if quiz == null:
		return
	_check(get_tree().paused, "%s world paused during quiz" % stage_id)

	await _play_quiz(quiz, stage_id)

	var next := StageSession.next_stage_id(stage_id)
	for i in 90:
		await get_tree().process_frame
		if next.is_empty() or SceneManager.current_level == next:
			break
	await _frames(2)
	_check(not get_tree().paused, "%s world unpaused after quiz" % stage_id)
	_check(ProgressManager.stars_for(stage_id) >= 1, "%s evaluation saved (%d stars)" % [stage_id, ProgressManager.stars_for(stage_id)])
	if not next.is_empty():
		_check(ProgressManager.is_stage_unlocked(next), "%s unlocked" % next)
		_check(SceneManager.current_level == next, "moved to %s" % next)
	await _frames(3)


func _play_quiz(quiz, stage_id: String) -> void:
	var answered := 0
	for guard in 120:
		await _frames(3)
		if not is_instance_valid(quiz):
			return
		var go := _find_button(quiz, "ON TO")
		if go == null:
			go = _find_button(quiz, "FINISH")
		if go != null and go.is_visible_in_tree():
			_log("   quiz answered=%d" % answered)
			go.pressed.emit()
			return
		var buttons: Array = quiz._answer_buttons
		if buttons[0].visible and not buttons[0].disabled:
			var question: Dictionary = quiz._questions[quiz._asked]
			var right_text: String = question["options"][int(question["answer"])]
			for i in buttons.size():
				if buttons[i].visible and buttons[i].text.ends_with(right_text):
					quiz._on_answer(i)
					answered += 1
					break
		elif quiz._next_button.visible:
			quiz._picked.emit()
	_check(false, "%s quiz did not finish" % stage_id)


func _find_button(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if child.text.begins_with(prefix):
			return child
	return null
