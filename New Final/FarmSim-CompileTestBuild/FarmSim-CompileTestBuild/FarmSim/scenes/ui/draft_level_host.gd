extends Node

## Runs one of the team's draft levels and gives it a frame to sit in.
##
## The drafts came from a separate project. They have their own controls, their
## own HUDs and no notion of a menu to go back to, so dropping the player into
## one with no way out would be a dead end. This wrapper adds the one thing they
## all lack: a label saying what you are looking at, and a way back.
##
## It deliberately does nothing else. The draft scene is instanced untouched -
## no injected player, no camera override, no reparenting - because the point of
## the level select is to show the drafts as their authors left them.

## Set by SceneManager before this node enters the tree. Keys: id, name, path,
## blurb.
var draft: Dictionary = {}

var _level: Node = null
var _bar: CanvasLayer = null
var _hint_label: Label = null


func _ready() -> void:
	_build_bar()
	_load_level()


func _load_level() -> void:
	var path := str(draft.get('path', ''))
	if path.is_empty() or not ResourceLoader.exists(path):
		_show_failure('Draft scene not found:\n%s' % path)
		return

	var packed: PackedScene = load(path)
	if packed == null:
		_show_failure('Draft scene failed to load:\n%s' % path)
		return

	_level = packed.instantiate()
	if _level == null:
		_show_failure('Draft scene could not be instanced:\n%s' % path)
		return

	# Added below the bar in tree order so the bar's CanvasLayer stays on top,
	# and so the draft receives unhandled input before this wrapper does. That
	# ordering is what lets Farm World's seed picker keep Escape for itself.
	add_child(_level)


func _build_bar() -> void:
	_bar = CanvasLayer.new()
	# Well above anything the drafts create; Farm World builds its HUD on a
	# CanvasLayer of its own and that must not cover the way out.
	_bar.layer = 100
	add_child(_bar)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(root)

	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override('panel', _strip_style())
	strip.anchor_right = 1.0
	strip.offset_bottom = 18
	strip.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override('separation', 8)
	strip.add_child(row)

	var back := Button.new()
	back.text = '< Menu'
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(52, 14)
	back.add_theme_font_size_override('font_size', 9)
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	var title := Label.new()
	title.text = 'DRAFT - %s' % str(draft.get('name', 'Level'))
	title.add_theme_font_size_override('font_size', 9)
	title.add_theme_color_override('font_color', Color('#ffe9b0'))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	_hint_label = Label.new()
	_hint_label.text = 'Esc to leave'
	_hint_label.add_theme_font_size_override('font_size', 9)
	_hint_label.add_theme_color_override('font_color', Color('#b9c6a8'))
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hint_label)


func _strip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.05, 0.82)
	style.border_width_bottom = 1
	style.border_color = Color(0.32, 0.42, 0.28, 0.9)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style


## A draft that will not load should say so on screen rather than leaving the
## player looking at an empty viewport wondering whether it is still loading.
func _show_failure(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override('font_size', 11)
	label.add_theme_color_override('font_color', Color('#ffb4a2'))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -200
	label.offset_right = 200
	label.offset_top = -20
	label.offset_bottom = 20
	_bar.get_child(0).add_child(label)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return

	# Reached only when the draft itself did not consume Escape - Farm World
	# consumes it while its seed picker is open, which is what we want.
	get_viewport().set_input_as_handled()
	_on_back_pressed()


func _on_back_pressed() -> void:
	GameManager.return_to_title()
