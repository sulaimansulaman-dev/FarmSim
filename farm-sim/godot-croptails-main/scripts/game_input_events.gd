class_name GameInputEvents


static func movement_input() -> Vector2:
    if Input.is_action_pressed("walk_up"):
        return Vector2.UP
    elif Input.is_action_pressed("walk_down"):
        return Vector2.DOWN
    elif Input.is_action_pressed("walk_left"):
        return Vector2.LEFT
    elif Input.is_action_pressed("walk_right"):
        return Vector2.RIGHT
    else:
        return Vector2.ZERO


static func has_movement_input() -> bool:
    return movement_input() != Vector2.ZERO


static func use_tool() -> bool:
    return Input.is_action_just_pressed('hit')
