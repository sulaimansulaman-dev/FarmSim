extends CanvasLayer

@onready var save_game_button: Button = $MarginContainer/VBoxContainer/SaveGameButton
@onready var resume_button: Button = $MarginContainer/VBoxContainer/ResumeButton
@onready var host_button: Button = $MarginContainer/VBoxContainer/HostButton
@onready var join_button: Button = $MarginContainer/VBoxContainer/JoinButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var join_popup: PanelContainer = $JoinGamePopup
@onready var join_address_edit: LineEdit = $JoinGamePopup/MarginContainer/VBoxContainer/AddressLineEdit
@onready var join_confirm_button: Button = $JoinGamePopup/MarginContainer/VBoxContainer/ButtonsContainer/JoinConfirmButton


func _ready() -> void:
    # This same screen is used both as the home screen (before the game has
    # started) and as the pause overlay shown mid-game via the "game_menu"
    # input action, so which buttons make sense depends on that context. A
    # game is "in progress" either in singleplayer (allow_save_game) or
    # because we're already hosting/connected to a multiplayer game.
    var is_paused_context: bool = SaveGameManager.allow_save_game \
            or MultiplayerManager.is_hosting or MultiplayerManager.is_client

    save_game_button.disabled = !SaveGameManager.allow_save_game
    save_game_button.focus_mode = Control.FOCUS_ALL if SaveGameManager.allow_save_game else Control.FOCUS_NONE

    resume_button.visible = is_paused_context
    host_button.visible = is_paused_context and not MultiplayerManager.is_hosting and not MultiplayerManager.is_client
    join_button.visible = !is_paused_context

    join_popup.hide()
    status_label.text = ''

    MultiplayerManager.server_created.connect(_on_multiplayer_ready)
    MultiplayerManager.game_joined.connect(_on_multiplayer_ready)
    MultiplayerManager.connection_failed.connect(_on_connection_failed)


func _on_start_game_button_pressed() -> void:
    GameManager.start_game()
    queue_free()


func _on_resume_button_pressed() -> void:
    queue_free()


func _on_save_game_button_pressed() -> void:
    SaveGameManager.save_game()


func _on_exit_game_button_pressed() -> void:
    GameManager.exit_game()


func _on_host_button_pressed() -> void:
    host_button.disabled = true
    status_label.text = 'Starting server...'
    await MultiplayerManager.host_game()


func _on_join_button_pressed() -> void:
    status_label.text = ''
    join_popup.show()
    join_address_edit.grab_focus()


func _on_join_popup_cancel_button_pressed() -> void:
    join_popup.hide()


func _on_join_confirm_button_pressed() -> void:
    join_confirm_button.disabled = true
    status_label.text = 'Connecting...'
    await MultiplayerManager.join_game(join_address_edit.text)
    if is_instance_valid(join_confirm_button):
        join_confirm_button.disabled = false


func _on_join_address_edit_text_submitted(_new_text: String) -> void:
    _on_join_confirm_button_pressed()


func _on_multiplayer_ready() -> void:
    queue_free()


func _on_connection_failed(reason: String) -> void:
    status_label.text = reason
    host_button.disabled = false
