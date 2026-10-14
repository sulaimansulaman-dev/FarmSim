extends Node

## Captures screenshots of the new stage features for a visual check:
## the HUD with goals, the bridge and keeper, the quiz battle and the results.
## Saves PNGs to user://captures/ and quits.

var _backup := ""


func _ready() -> void:
	if FileAccess.file_exists(ProgressManager.SAVE_PATH):
		_backup = FileAccess.get_file_as_string(ProgressManager.SAVE_PATH)
	DirAccess.make_dir_recursive_absolute("user://captures")
	await get_tree().process_frame
	await _run()
	if _backup.is_empty():
		DirAccess.remove_absolute(ProgressManager.SAVE_PATH)
	else:
		var file := FileAccess.open(ProgressManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(_backup)
		file.close()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("user://captures/" + file_name)


func _run() -> void:
	GameManager.start_level("Stage3")
	await _frames(20)
	var player := StageSession.local_player()
	var level := get_node(SceneManager.main_scene_level_root_path).get_child(0)
	var gate := level.get_node("StageGate") as StageGate

	player.global_position = Vector2(900, 200)
	await _frames(10)
	await _shot("01_hud_bridge_closed.png")

	for objective in StageSession.definition().get("objectives", []):
		StageSession._bump(str(objective["type"]), int(objective["target"]))
	player.global_position = Vector2(1040, 200)
	await _frames(10)
	await _shot("02_bridge_open.png")

	player.global_position = gate.keeper_trigger.global_position
	await _frames(30)
	var quiz = get_tree().root.get_node_or_null("QuizBattle")
	if quiz == null:
		return
	await get_tree().create_timer(1.0).timeout
	await _shot("03_quiz_intro.png")
	quiz._picked.emit()
	await _frames(5)
	quiz._picked.emit()
	await get_tree().create_timer(1.5).timeout
	await _shot("04_quiz_question.png")

	for guard in 60:
		await _frames(4)
		if not is_instance_valid(quiz):
			return
		var buttons: Array = quiz._answer_buttons
		if buttons[0].visible and not buttons[0].disabled:
			var question: Dictionary = quiz._questions[quiz._asked]
			var right_text: String = question["options"][int(question["answer"])]
			for i in buttons.size():
				if buttons[i].visible and buttons[i].text.ends_with(right_text):
					quiz._on_answer(i)
					break
			await get_tree().create_timer(0.8).timeout
			if guard < 8:
				await _shot("05_quiz_feedback.png")
		elif quiz._next_button.visible:
			quiz._picked.emit()
		else:
			for child in quiz.find_children("*", "Button", true, false):
				if child.text.begins_with("ON TO") and child.is_visible_in_tree():
					await get_tree().create_timer(0.5).timeout
					await _shot("06_results.png")
					return
