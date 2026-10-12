class_name MobileControls
extends Control

## Touch controls: a virtual joystick, an A button and a Menu button.
##
## Added to the HUD (game_screen.tscn). Off by default on desktop; on for
## Android, iOS and phone browsers. To try it with a mouse, tick Force Enabled
## in the Inspector on this scene's root.
##
## What the buttons do
##   Joystick  walks, exactly like WASD.
##   A         does the most useful thing available, in this order:
##               1. a dialogue is open       -> continues it
##               2. an object shows its "A"  -> interacts with it (what E did)
##               3. a tool is held           -> uses it on the highlighted tile
##               4. otherwise                -> confirm (ui_accept)
##   Menu      opens the pause menu (what Escape did).

## Caption on the A button for each tool, so the thumb knows what it will do.
const TOOL_CAPTIONS := {
	DataTypes.Tools.AxeWood: "CHOP",
	DataTypes.Tools.TillGround: "TILL",
	DataTypes.Tools.WaterCrops: "WATER",
	DataTypes.Tools.PlantCorn: "SOW",
	DataTypes.Tools.PlantTomato: "SOW",
	DataTypes.Tools.SprayPest: "SPRAY",
	DataTypes.Tools.OrganicControl: "TREAT",
	DataTypes.Tools.PlantSapling: "PLANT",
}

## Show the controls even on a desktop build. For testing with a mouse.
@export var force_enabled: bool = true

@onready var _joystick: TouchJoystick = $Joystick
@onready var _interact: TouchActionButton = $InteractButton
@onready var _menu: TouchActionButton = $MenuButton

var _highlight: InteractionHighlight


func _ready() -> void:
	if not MobileInput.should_enable(force_enabled):
		visible = false
		set_process(false)
		return

	# Keeps running under the pause menu so it can hide itself there.
	process_mode = Node.PROCESS_MODE_ALWAYS
	MobileInput.enable()
	_interact.pressed.connect(_on_interact_pressed)
	_menu.pressed.connect(_on_menu_pressed)

	# Everything in the level that was already loaded when this HUD came up,
	# then anything that loads after.
	_scan(get_tree().root)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if MobileInput.enabled:
		MobileInput.disable()
	if _highlight != null and is_instance_valid(_highlight):
		_highlight.queue_free()


func _process(_delta: float) -> void:
	# The pause menu and the quiz are screens of their own; the pads would only sit on top of them.
	visible = not get_tree().paused and not get_tree().root.has_node("QuizBattle")
	_attach_highlight()
	_update_button()


## The highlight is drawn in the world, so it hangs off the player. The player
## can be replaced (a networked spawn, a level change), so this keeps checking.
func _attach_highlight() -> void:
	var player := StageSession.local_player()
	if player == null:
		return
	if _highlight == null or not is_instance_valid(_highlight):
		_highlight = InteractionHighlight.new()
	if _highlight.get_parent() == player:
		return
	if _highlight.get_parent() != null:
		_highlight.get_parent().remove_child(_highlight)
	player.add_child(_highlight)


func _update_button() -> void:
	var tool: DataTypes.Tools = ToolManager.selected_tool
	var has_object := _highlight != null and _highlight.object_target != null

	if _dialogue_open():
		_interact.caption = "NEXT"
		_interact.dimmed = false
	elif has_object:
		_interact.caption = "USE"
		_interact.dimmed = false
	elif tool != DataTypes.Tools.None:
		_interact.caption = TOOL_CAPTIONS.get(tool, "USE")
		# Bright when the tool would do something on the highlighted tile.
		_interact.dimmed = _highlight == null or not (_highlight.tile_active and _highlight.tile_ready)
	else:
		_interact.caption = ""
		_interact.dimmed = true


func _on_interact_pressed() -> void:
	if _dialogue_open():
		MobileInput.tap(self, &"ui_accept")
	elif _highlight != null and _highlight.object_target != null:
		MobileInput.tap(self, &"show_dialogue")
	elif ToolManager.selected_tool != DataTypes.Tools.None:
		MobileInput.tap(self, &"hit")
	else:
		MobileInput.tap(self, &"ui_accept")


func _on_menu_pressed() -> void:
	MobileInput.tap(self, &"game_menu")


## A dialogue balloon is added straight to the root while a conversation runs.
func _dialogue_open() -> bool:
	for child in get_tree().root.get_children():
		if child is BaseGameDialogueBalloon:
			return true
	return false


# --- finding things in the world ---------------------------------------------

func _on_node_added(node: Node) -> void:
	_consider(node)


func _scan(from: Node) -> void:
	for node in from.find_children("*", "", true, false):
		_consider(node)


func _consider(node: Node) -> void:
	if node is CropsCursorComponent:
		MobileInput.crops_cursor = node
	elif node is FieldCursorComponent:
		MobileInput.field_cursor = node
	elif node is Control and String(node.name).begins_with("InteractableLabelComponent"):
		_track_prompt(node as Control)


## An object's "E" prompt marks it as interactable while it is showing. On a
## touch screen there is no E, so the prompt is relabelled to match the button.
func _track_prompt(prompt: Control) -> void:
	if MobileInput.prompt_labels.has(prompt):
		return
	MobileInput.prompt_labels.append(prompt)
	prompt.tree_exiting.connect(func() -> void: MobileInput.prompt_labels.erase(prompt))

	var key := prompt.get_node_or_null("Label") as Label
	if key != null and key.text == "E":
		key.text = "A"
