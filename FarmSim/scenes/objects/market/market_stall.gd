extends StaticBody2D

## The market stall. Walk up to it, press E, and the market opens.
##
## Deliberately a place in the world rather than a key you can press anywhere.
## Having to walk back from the field to sell is what makes "how much can I
## carry, and when do I go" a decision, and it puts the shop somewhere the
## player can see from the start of the stage.
##
## The art is the chest spritesheet. Croptails has no stall sprite and inventing
## one is an artist's job, not a merge's - the crate reads as a trader's crate
## well enough to stand in until the art lands.

const market_panel_scene: PackedScene = preload("res://scenes/ui/market_panel.tscn")

@onready var interactable_label_component: Control = $InteractableLabelComponent

var in_range: bool = false
var _open_panel: CanvasLayer = null


func _unhandled_input(event: InputEvent) -> void:
	if not in_range or is_instance_valid(_open_panel):
		return
	if not event.is_action_pressed('show_dialogue'):
		return

	get_viewport().set_input_as_handled()
	open_market()


func open_market() -> void:
	interactable_label_component.hide()
	_open_panel = market_panel_scene.instantiate()
	get_tree().root.add_child(_open_panel)
	_open_panel.closed.connect(_on_market_closed)


func _on_market_closed() -> void:
	_open_panel = null
	# Only offer the prompt again if the player is still standing here; they can
	# walk away with the market open.
	interactable_label_component.visible = in_range


func _on_interactable_activated(_body: Node2D) -> void:
	in_range = true
	if not is_instance_valid(_open_panel):
		interactable_label_component.show()


func _on_interactable_deactivated(_body: Node2D) -> void:
	in_range = false
	interactable_label_component.hide()
