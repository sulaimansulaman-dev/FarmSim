extends Node2D


func _ready() -> void:
    call_deferred('disable_process_mode')


func disable_process_mode() -> void:
    process_mode = PROCESS_MODE_DISABLED
