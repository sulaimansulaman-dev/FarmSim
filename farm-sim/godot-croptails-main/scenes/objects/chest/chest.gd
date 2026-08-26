extends Node2D

const ballon_scene: PackedScene = preload("res://dialogue/game_dialogue_balloon.tscn")
const corn_harvest_scene: PackedScene = preload("res://scenes/objects/plants/corn_harvest.tscn")
const tomato_harvest_scene: PackedScene = preload("res://scenes/objects/plants/tomato_harvest.tscn")

@export var dialogue_start_command: String
@export var food_drop_height: int = 40
@export var reward_output_radius: int = 20
@export var output_reward_scenes: Array[PackedScene] = []

var in_range := false
var is_open := false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var interactable_label_component: Control = $InteractableLabelComponent
@onready var feed_component: FeedComponent = $FeedComponent
@onready var harvest_marker: Marker2D = $HarvestMarker
@onready var reward_marker: Marker2D = $RewardMarker


func _ready() -> void:
    GameDialogueManager.feed_animals.connect(_on_feed_animals)
    feed_component.food_received.connect(_on_food_received)

func _unhandled_input(event: InputEvent) -> void:
    if not in_range:
        return

    if not event.is_action_pressed('show_dialogue'):
        return

    interactable_label_component.hide()
    animated_sprite_2d.play('open')
    is_open = true

    var balloon: BaseGameDialogueBalloon = ballon_scene.instantiate()
    get_tree().root.add_child(balloon)
    balloon.start(load('res://dialogue/conversations/chest.dialogue'), dialogue_start_command)


func trigger_feed_harvest(inventory_item: String, scene: PackedScene) -> void:
    if not InventoryManager.inventory.has(inventory_item):
        return

    var item_count = InventoryManager.inventory[inventory_item]
    for index in item_count:
        var harvest_instance = scene.instantiate() as Node2D
        #(harvest_instance.find_child('CollisionShape2D') as CollisionShape2D).disabled = true
        harvest_instance.global_position = Vector2(global_position.x, global_position.y - food_drop_height)
        get_tree().root.add_child(harvest_instance)
        var target_position = harvest_marker.global_position

        var time_delay = randf_range(0.5, 2.0)
        await get_tree().create_timer(time_delay).timeout

        var tween = get_tree().create_tween()
        tween.tween_property(harvest_instance, 'position', target_position, 1.0)
        tween.tween_property(harvest_instance, 'scale', Vector2(0.1, 0.1), 1.0)
        tween.tween_callback(harvest_instance.queue_free)

        InventoryManager.remove_collectable(inventory_item)


func _on_interactable_activated(_body: Node2D) -> void:
    in_range = true
    interactable_label_component.show()


func _on_interactable_deactivated(_body: Node2D) -> void:
    if is_open:
        animated_sprite_2d.play_backwards('open')

    is_open = false
    in_range = false
    interactable_label_component.hide()


func _on_feed_animals() -> void:
    if in_range:
        trigger_feed_harvest('corn', corn_harvest_scene)
        trigger_feed_harvest('tomato', tomato_harvest_scene)


func _on_food_received(_area) -> void:
    call_deferred('_add_reward_scene')


func _add_reward_scene() -> void:
    for scene in output_reward_scenes:
        var reward_scene := scene.instantiate() as Node2D
        reward_scene.global_position = _get_random_position_in_circle(reward_marker.global_position, reward_output_radius)
        get_tree().root.add_child(reward_scene)


func _get_random_position_in_circle(center: Vector2, radius: float) -> Vector2:
    var angle := randf() * TAU
    var distance := sqrt(randf()) * radius
    var displacement = Vector2(distance * cos(angle), distance * sin(angle))
    return center + displacement
