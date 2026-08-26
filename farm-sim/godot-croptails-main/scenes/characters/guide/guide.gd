extends CharacterBody2D

const balloon_scene: PackedScene = preload("res://dialogue/game_dialogue_balloon.tscn")

@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var interactable_label_component: Control = $InteractableLabelComponent


func _ready() -> void:
    interactable_component.interactable_activated.connect(on_interactable_activated)
    interactable_component.interactable_deactivated.connect(on_interactable_deactivated)

    GameDialogueManager.gave_crop_seeds.connect(on_gave_crop_seeds)


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed('show_dialogue'):
        return

    if not interactable_label_component.visible:
        return

    var balloon: BaseGameDialogueBalloon = balloon_scene.instantiate()
    get_tree().root.add_child(balloon)
    balloon.start(load("res://dialogue/conversations/guide.dialogue"), 'start')


func on_interactable_activated(_body: Node2D) -> void:
    interactable_label_component.visible = true


func on_interactable_deactivated(_body: Node2D) -> void:
    interactable_label_component.visible = false


func on_gave_crop_seeds() -> void:
    ToolManager.enable_tool(DataTypes.Tools.TillGround)
    ToolManager.enable_tool(DataTypes.Tools.WaterCrops)
    ToolManager.enable_tool(DataTypes.Tools.PlantCorn)
    ToolManager.enable_tool(DataTypes.Tools.PlantTomato)
