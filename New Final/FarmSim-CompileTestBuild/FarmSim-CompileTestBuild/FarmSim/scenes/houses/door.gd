extends StaticBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var interactable_component: InteractableComponent = $InteractableComponent


func _ready() -> void:
    interactable_component.interactable_activated.connect(func(_body): open())
    interactable_component.interactable_deactivated.connect(func(_body): close())


func open() -> void:
    print('door activated')
    animated_sprite_2d.play('open')
    collision_layer = 2
    #collision_shape_2d.disabled = true
    #collision_shape_2d.set_deferred("disabled", true)



func close() -> void:
    print('door deactivated')
    animated_sprite_2d.play('close')
    collision_layer = 1
