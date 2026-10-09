extends PanelContainer

## Says which island the player is standing on.
##
## Nothing on screen used to name the level. You found out by talking to Marlow,
## or on Island 3 by waiting for a caterpillar to turn up - which is a poor way
## to learn where you are.

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pad := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5)
	add_child(pad)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_label)

	visible = false
	SceneManager.level_loaded.connect(_on_level_loaded)

	# The HUD is built before the first level loads, so at startup there is
	# nothing to show and the signal does the work. This covers the other order,
	# in case a menu ever loads a level before the interface exists.
	if not SceneManager.current_level.is_empty():
		_on_level_loaded(str(SceneManager.level_names.get(SceneManager.current_level, "")))


func _on_level_loaded(display_name: String) -> void:
	_label.text = display_name
	visible = not display_name.is_empty()
