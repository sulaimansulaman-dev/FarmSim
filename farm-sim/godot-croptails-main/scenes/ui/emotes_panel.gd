extends Panel

const default_emote := 'emote_1_idle'
const idle_emotes: Array[String] = ['emote_1_idle', 'emote_2_smile', 'emote_3_ear_wave', 'emote_4_blink']

@onready var animated_sprite_2d: AnimatedSprite2D = $Emote/AnimatedSprite2D
@onready var emote_idle_timer: Timer = $EmoteIdleTimer


func _ready() -> void:
    InventoryManager.inventory_changed.connect(_on_inventory_changed)
    GameDialogueManager.feed_animals.connect(_on_feed_animals)


func play_emote(animation: String) -> void:
    animated_sprite_2d.play(animation)


func _on_emote_idle_timer_timeout() -> void:
    var emote = animated_sprite_2d.animation
    if emote == default_emote:
        var index = randi_range(0, len(idle_emotes) - 1)
        emote = idle_emotes[index]
    else:
        emote = default_emote

    play_emote(emote)


func _on_inventory_changed(_inventory: Dictionary) -> void:
    animated_sprite_2d.play('emote_7_excited')


func _on_feed_animals() -> void:
    animated_sprite_2d.play('emote_6_love_kiss')
