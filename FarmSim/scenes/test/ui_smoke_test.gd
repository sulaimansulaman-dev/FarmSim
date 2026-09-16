extends Node

## Smoke test for the menus around the stages: title screen level select
## (locks and stars), stats, the pause menu freezing the world, and the goals
## panel on the HUD. Writes to user://ui_smoke_test.txt and quits.

var _report: FileAccess
var _failures := 0
var _backup := ""


func _ready() -> void:
	_report = FileAccess.open("user://ui_smoke_test.txt", FileAccess.WRITE)
	if FileAccess.file_exists(ProgressManager.SAVE_PATH):
		_backup = FileAccess.get_file_as_string(ProgressManager.SAVE_PATH)
	await get_tree().process_frame
	await _run()
	_restore()
	_log("TEST SUMMARY failures=%d" % _failures)
	_report.close()
	get_tree().quit()


func _log(message: String) -> void:
	print(message)
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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	ProgressManager.reset()
	ProgressManager.record_evaluation("Stage1", {"stars_earned": 2, "quiz_score": 75, "completion_time_sec": 300, "crops_harvested": 1, "quiz_attempts": []})

	var title = load("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(5)
	title._refresh_stage_buttons()
	var buttons: Dictionary = title._stage_buttons
	_check(buttons.size() == 5, "level select lists 5 stages (%d)" % buttons.size())
	if buttons.size() == 5:
		_check(not buttons["Stage1"].disabled and buttons["Stage1"].text.contains("2/3"), "Stage 1 shows 2 stars: %s" % buttons["Stage1"].text)
		_check(not buttons["Stage2"].disabled, "Stage 2 unlocked after Stage 1")
		_check(buttons["Stage3"].disabled, "Stage 3 still locked: %s" % buttons["Stage3"].text)
	title._load_stats_from_progress()
	_check(int(title.player_stats["farmer_level"]) >= 1, "stats read farmer level from progress")
	_check(ProgressManager.furthest_unlocked_stage() == "Stage2", "continue goes to Stage 2")

	var saved = JSON.parse_string(FileAccess.get_file_as_string(ProgressManager.SAVE_PATH))
	_check(saved is Dictionary and saved.has("player_profile") and saved.has("farm_world_state") and saved.has("stage_evaluations"), "save file follows spec schema")
	if saved is Dictionary:
		_check("area_2" in saved["farm_world_state"]["unlocked_areas"], "save unlocks area_2")
	title.queue_free()
	await _frames(2)

	await GameManager.start_level("Stage2")
	await _frames(5)
	var objectives = get_tree().root.find_child("ObjectivesPanel", true, false)
	_check(objectives != null and objectives.visible, "goals panel visible on Stage 2")
	GameManager.show_game_menu_screen()
	await _frames(2)
	_check(get_tree().paused, "pause menu freezes the world")
	var menu = get_tree().root.get_node_or_null("GameMenuScreen")
	_check(menu != null, "pause menu open")
	if menu != null:
		menu._on_resume_button_pressed()
	await _frames(3)
	_check(not get_tree().paused, "resume unfreezes the world")

	var market = load("res://scenes/ui/market_panel.tscn").instantiate()
	get_tree().root.add_child(market)
	await _frames(2)
	var supplies: Node = market._pages["SUPPLIES"]
	var text := ""
	for label in supplies.find_children("*", "Label", true, false):
		text += label.text + " | "
	_check(not text.contains("Organic") and not text.contains("sapling"), "Stage 2 market hides pest control and saplings")
	market.close_market()
	await _frames(2)
