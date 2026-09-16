extends CanvasLayer

## The bridge keeper's quiz, played as a battle (FR-EVA-001, FR-EVA-002).
##
## Laid out like a classic monster-battle screen: the keeper on a platform top
## right with a knowledge bar, the player's back bottom left with hearts, and a
## text box along the bottom. Every right answer knocks the keeper's bar down;
## every wrong one costs a heart. Empty the bar to pass, lose every heart and
## the keeper sends you back to study.
##
## The numbers come from data/stages.json. A stage asks its questions in a
## random order with the options shuffled, needs `pass_correct` right answers,
## and gives the player just enough hearts that the quiz can never be won
## without that many. Every attempt, and every answer in it, is logged into the
## stage's evaluation record.
##
## Passing shows the stage's final 3-star rating and moves on to the next stage.
## Singleplayer freezes the world while this is open; a LAN game does not.

signal closed(passed: bool)

const UI_THEME := preload("res://scenes/ui/game_ui_theme.tres")
const UI_SHEET := preload("res://assets/ui/basic_ui_sprites.png")

const HEART_FULL := Rect2(579, 98, 11, 12)
const HEART_EMPTY := Rect2(611, 98, 11, 12)
const STAR_FULL := Rect2(529, 97, 14, 13)
const STAR_EMPTY := Rect2(561, 97, 14, 13)

const COLOUR_TEXT := Color("f4ead6")
const COLOUR_SOFT := Color("d8cbb0")
const COLOUR_GOLD := Color("f2c94c")
const COLOUR_GOOD := Color("a5d6a7")
const COLOUR_BAD := Color("eb8a7d")

## Set by the gate before this enters the tree, so the keeper on the battle
## screen wears the same colours as the one on the bridge.
var keeper_texture_source: AnimatedSprite2D = null

var _stage: Dictionary = {}
var _keeper: Dictionary = {}
var _quiz: Dictionary = {}
var _questions: Array = []
var _pass_correct := 3
var _max_hearts := 2

var _attempt := 0
var _attempts: Array = []
var _correct := 0
var _asked := 0
var _hearts := 0

var _root: Control
var _keeper_sprite: TextureRect
var _player_sprite: TextureRect
var _keeper_bar: ProgressBar
var _heart_icons: Array[TextureRect] = []
var _message: Label
var _answer_grid: GridContainer
var _answer_buttons: Array[Button] = []
var _next_button: Button

var _choice := -1
signal _picked()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.pause_world()

	_stage = StageSession.definition()
	_keeper = _stage.get("keeper", {})
	_quiz = _stage.get("quiz", {})
	_pass_correct = int(_quiz.get("pass_correct", 3))
	var total := int(_quiz.get("questions", []).size())
	_pass_correct = clampi(_pass_correct, 1, maxi(total, 1))
	_max_hearts = maxi(total - _pass_correct + 1, 1)

	_build()
	_run()


func _exit_tree() -> void:
	GameManager.resume_world()


# --- flow -------------------------------------------------------------------

func _run() -> void:
	_start_attempt()

	await _intro()

	while true:
		var question: Dictionary = _questions[_asked]
		var right: bool = await _ask(question)
		_asked += 1
		if right:
			_correct += 1
		if _correct >= _pass_correct:
			await _win()
			return
		if _hearts <= 0 or _asked >= _questions.size():
			var retry: bool = await _lose()
			if not retry:
				_close(false)
				return
			_start_attempt()
			await _say("%s: Again, then. Fresh questions this time." % _keeper.get("name", "Keeper"), true)


func _start_attempt() -> void:
	_attempt += 1
	_correct = 0
	_asked = 0
	_hearts = _max_hearts
	_questions = _quiz.get("questions", []).duplicate(true)
	_questions.shuffle()
	_attempts.append({"attempt": _attempt, "answers": [], "correct": 0, "asked": 0, "passed": false})
	_keeper_bar.max_value = _pass_correct
	_keeper_bar.value = _pass_correct
	_refresh_hearts()


func _intro() -> void:
	var start := _keeper_sprite.position
	_keeper_sprite.position = start + Vector2(260, 0)
	var tween := create_tween()
	tween.tween_property(_keeper_sprite, "position", start, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _say("%s blocks the bridge!" % _keeper.get("name", "The keeper"), true)
	await _say("%s: %s" % [_keeper.get("name", "Keeper"), _keeper.get("intro", "Answer my questions!")], true)


## Shows one question and waits for an answer. Returns whether it was right.
func _ask(question: Dictionary) -> bool:
	var options: Array = question.get("options", [])
	var answer := int(question.get("answer", 0))

	# Shuffle the options, remembering where the right one lands.
	var order: Array = range(options.size())
	order.shuffle()

	_message.text = str(question.get("q", ""))
	_type_in()
	_next_button.visible = false
	for i in _answer_buttons.size():
		var button := _answer_buttons[i]
		button.visible = i < order.size()
		if button.visible:
			button.text = "%d. %s" % [i + 1, options[order[i]]]
			button.disabled = false
			button.modulate = Color.WHITE

	_choice = -1
	await _picked
	var chosen_index: int = order[_choice]
	var right := chosen_index == answer

	for i in _answer_buttons.size():
		_answer_buttons[i].disabled = true
		if i < order.size() and order[i] == answer:
			_answer_buttons[i].modulate = COLOUR_GOOD
		elif i == _choice and not right:
			_answer_buttons[i].modulate = COLOUR_BAD

	var entry: Dictionary = _attempts[-1]
	entry["answers"].append({
		"question": str(question.get("q", "")),
		"chosen": str(options[chosen_index]),
		"correct": right,
	})

	if right:
		_keeper_bar.value = _pass_correct - (_correct + 1)
		_shake(_keeper_sprite)
		_flash(_keeper_sprite, COLOUR_GOLD)
		await _say("Correct! %s" % question.get("explain", ""), true)
	else:
		_hearts -= 1
		_refresh_hearts()
		_shake(_player_sprite)
		_flash(_player_sprite, COLOUR_BAD)
		await _say("Not quite - it was \"%s\". %s" % [options[answer], question.get("explain", "")], true)

	entry["correct"] = _correct + (1 if right else 0)
	entry["asked"] = _asked + 1
	return right


func _win() -> void:
	_attempts[-1]["passed"] = true
	var tween := create_tween()
	tween.tween_property(_keeper_sprite, "modulate:a", 0.25, 0.6)
	await _say("%s: %s" % [_keeper.get("name", "Keeper"), _keeper.get("win", "You may pass.")], true)

	var evaluation := StageSession.build_evaluation(_correct, _asked, _attempts)
	await _show_results(evaluation)
	_close(true)
	StageSession.finish_stage(evaluation)


## Returns true to try again, false to step back off the bridge.
func _lose() -> bool:
	await _say("%s: %s" % [_keeper.get("name", "Keeper"), _keeper.get("lose", "Come back when you are ready.")], false)

	for button in _answer_buttons:
		button.visible = false
	_next_button.visible = false

	var retry := _make_button("TRY AGAIN")
	var leave := _make_button("STEP BACK")
	_answer_grid.add_child(retry)
	_answer_grid.add_child(leave)

	var picked := [false]
	retry.pressed.connect(func():
		picked[0] = true
		_picked.emit())
	leave.pressed.connect(func(): _picked.emit())
	await _picked

	retry.queue_free()
	leave.queue_free()
	_keeper_sprite.modulate = Color.WHITE
	return picked[0]


func _close(passed: bool) -> void:
	closed.emit(passed)
	queue_free()


# --- results ----------------------------------------------------------------

func _show_results(evaluation: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkWoodPanel"
	centre.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var title := _label("%s CLEAR!" % str(SceneManager.level_names.get(StageSession.stage_id, "STAGE")).to_upper(), COLOUR_GOLD, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 10)
	column.add_child(star_row)

	var stars := int(evaluation.get("stars_earned", 1))
	var star_rects: Array[TextureRect] = []
	for i in 3:
		var star := TextureRect.new()
		star.texture = _atlas(STAR_EMPTY)
		star.custom_minimum_size = Vector2(42, 39)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.pivot_offset = Vector2(21, 19)
		star_row.add_child(star)
		star_rects.append(star)

	var definition := StageSession.definition()
	var lines := [
		"Time  %s  (par %s)" % [_clock(int(evaluation.get("completion_time_sec", 0))), _clock(int(definition.get("par_time_sec", 0)))],
		"Harvested  %d / %d" % [int(evaluation.get("crops_harvested", 0)), int(definition.get("harvest_target", 0))],
		"Quiz  %d%%" % int(evaluation.get("quiz_score", 0)),
		"Score  %d%%" % int(round(float(evaluation.get("score", 0.0)) * 100.0)),
	]
	for line in lines:
		var label := _label(line, COLOUR_TEXT, 8)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)

	var next := StageSession.next_stage_id(StageSession.stage_id)
	var button_text := "FINISH"
	if not next.is_empty():
		button_text = "ON TO %s" % str(SceneManager.level_names.get(next, next)).to_upper()
	var go := _make_button(button_text)
	go.custom_minimum_size = Vector2(220, 22)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.visible = false
	column.add_child(go)

	# The stars pop in one at a time.
	await get_tree().create_timer(0.3).timeout
	for i in stars:
		star_rects[i].texture = _atlas(STAR_FULL)
		star_rects[i].scale = Vector2(0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(star_rects[i], "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_BACK)
		tween.tween_property(star_rects[i], "scale", Vector2.ONE, 0.12)
		await tween.finished

	go.visible = true
	await go.pressed


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		var index := key.keycode - KEY_1
		if index < _answer_buttons.size() and _answer_buttons[index].visible and not _answer_buttons[index].disabled:
			get_viewport().set_input_as_handled()
			_on_answer(index)
	elif key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
		if _next_button.visible:
			get_viewport().set_input_as_handled()
			_picked.emit()


func _on_answer(index: int) -> void:
	_choice = index
	_picked.emit()


func _say(text: String, wait_for_next: bool) -> void:
	_message.text = text
	_type_in()
	if not wait_for_next:
		return
	_next_button.visible = true
	await _picked
	_next_button.visible = false
	for button in _answer_buttons:
		button.visible = false


# --- building the screen ----------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UI_THEME
	add_child(_root)

	# Sky and field.
	var sky := ColorRect.new()
	sky.color = Color("cfe9d8")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(sky)

	var field := ColorRect.new()
	field.color = Color("a8d58a")
	field.anchor_top = 0.42
	field.anchor_right = 1.0
	field.anchor_bottom = 1.0
	_root.add_child(field)

	_add_platform(Vector2(398, 148), Vector2(190, 34))
	_add_platform(Vector2(40, 232), Vector2(210, 38))

	_keeper_sprite = _character_rect(_keeper_frame(), Vector2(421, 58), 3.0)
	if keeper_texture_source != null and keeper_texture_source.material != null:
		_keeper_sprite.material = keeper_texture_source.material
	_root.add_child(_keeper_sprite)

	_player_sprite = _character_rect(_player_frame(), Vector2(73, 138), 3.0)
	_root.add_child(_player_sprite)

	# Keeper's plate, top left.
	var keeper_plate := _plate(Vector2(24, 24))
	var keeper_column: VBoxContainer = keeper_plate.get_meta("column")
	keeper_column.add_child(_label(str(_keeper.get("name", "Keeper")).to_upper(), COLOUR_GOLD, 10))
	keeper_column.add_child(_label("KNOWLEDGE CHALLENGE", COLOUR_SOFT, 8))
	_keeper_bar = ProgressBar.new()
	_keeper_bar.custom_minimum_size = Vector2(150, 8)
	_keeper_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("6ab04c")
	_keeper_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("3b2f2a")
	_keeper_bar.add_theme_stylebox_override("background", back)
	keeper_column.add_child(_keeper_bar)

	# Player's plate, right of the player.
	var player_plate := _plate(Vector2(300, 200))
	var player_column: VBoxContainer = player_plate.get_meta("column")
	player_column.add_child(_label("YOU", COLOUR_GOLD, 10))
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 3)
	player_column.add_child(hearts)
	for i in _max_hearts:
		var heart := TextureRect.new()
		heart.texture = _atlas(HEART_FULL)
		heart.custom_minimum_size = Vector2(11, 12)
		hearts.add_child(heart)
		_heart_icons.append(heart)

	# The text box.
	var box := PanelContainer.new()
	box.theme_type_variation = &"DarkWoodPanel"
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = -86
	box.offset_bottom = -6
	_root.add_child(box)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	box.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	# The message and the NEXT button share the top row, so feedback can be read
	# with the answers still on show below it - the right one lit green.
	var message_row := HBoxContainer.new()
	message_row.add_theme_constant_override("separation", 6)
	column.add_child(message_row)

	_message = _label("", COLOUR_TEXT, 8)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(480, 26)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_row.add_child(_message)

	_next_button = _make_button("NEXT  (Space)")
	_next_button.custom_minimum_size = Vector2(110, 20)
	_next_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_next_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_button.visible = false
	_next_button.pressed.connect(func(): _picked.emit())
	message_row.add_child(_next_button)

	_answer_grid = GridContainer.new()
	_answer_grid.columns = 2
	_answer_grid.add_theme_constant_override("h_separation", 6)
	_answer_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_answer_grid)

	for i in 4:
		var button := _make_button("")
		button.visible = false
		button.pressed.connect(_on_answer.bind(i))
		_answer_grid.add_child(button)
		_answer_buttons.append(button)



func _add_platform(position: Vector2, size: Vector2) -> void:
	var platform := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("7fb069")
	style.border_color = Color("5c8a4a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(size.y * 0.5))
	platform.add_theme_stylebox_override("panel", style)
	platform.position = position
	platform.size = size
	_root.add_child(platform)


func _plate(position: Vector2) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"DarkWoodPanel"
	plate.position = position
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	plate.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	plate.set_meta("column", column)
	_root.add_child(plate)
	return plate


func _character_rect(texture: Texture2D, position: Vector2, zoom: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.position = position
	rect.size = Vector2(48, 48) * zoom
	return rect


func _keeper_frame() -> Texture2D:
	if keeper_texture_source != null and keeper_texture_source.sprite_frames != null:
		return keeper_texture_source.sprite_frames.get_frame_texture(&"idle", 0)
	return null


func _player_frame() -> Texture2D:
	var player := StageSession.local_player()
	if player == null:
		return null
	var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return null
	for animation in [&"idle_back", &"idle_front"]:
		if sprite.sprite_frames.has_animation(animation):
			return sprite.sprite_frames.get_frame_texture(animation, 0)
	return null


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = &"GameMenuButton"
	button.add_theme_font_size_override("font_size", 8)
	button.custom_minimum_size = Vector2(300, 20)
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


func _label(text: String, colour: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = UI_SHEET
	texture.region = region
	return texture


func _refresh_hearts() -> void:
	for i in _heart_icons.size():
		_heart_icons[i].texture = _atlas(HEART_FULL if i < _hearts else HEART_EMPTY)


func _type_in() -> void:
	_message.visible_ratio = 0.0
	var tween := create_tween()
	tween.tween_property(_message, "visible_ratio", 1.0, clampf(_message.text.length() * 0.012, 0.15, 1.2))


func _shake(node: Control) -> void:
	var origin := node.position
	var tween := create_tween()
	for i in 4:
		tween.tween_property(node, "position", origin + Vector2(6 if i % 2 == 0 else -6, 0), 0.04)
	tween.tween_property(node, "position", origin, 0.04)


func _flash(node: Control, colour: Color) -> void:
	var tween := create_tween()
	tween.tween_property(node, "self_modulate", colour, 0.08)
	tween.tween_property(node, "self_modulate", Color.WHITE, 0.2)


func _clock(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
