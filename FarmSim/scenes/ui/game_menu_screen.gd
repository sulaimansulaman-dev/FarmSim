extends CanvasLayer

@onready var save_game_button: Button = $MarginContainer/VBoxContainer/SaveGameButton
@onready var start_game_button: Button = $MarginContainer/VBoxContainer/StartGameButton
@onready var main_menu_button: Button = $MarginContainer/VBoxContainer/MainMenuButton
@onready var resume_button: Button = $MarginContainer/VBoxContainer/ResumeButton
@onready var host_button: Button = $MarginContainer/VBoxContainer/HostButton
@onready var join_button: Button = $MarginContainer/VBoxContainer/JoinButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var join_popup: PanelContainer = $JoinGamePopup
@onready var join_address_edit: LineEdit = $JoinGamePopup/MarginContainer/VBoxContainer/AddressLineEdit
@onready var join_confirm_button: Button = $JoinGamePopup/MarginContainer/VBoxContainer/ButtonsContainer/JoinConfirmButton


func _ready() -> void:
    # The menu has to keep working while it holds the rest of the game paused.
    process_mode = Node.PROCESS_MODE_ALWAYS
    if SceneManager.in_game:
        GameManager.pause_world()

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
    # The multiplayer toggle (FR-PAM-001): host from here, or stop hosting.
    host_button.visible = is_paused_context and not MultiplayerManager.is_client
    host_button.text = 'STOP HOSTING' if MultiplayerManager.is_hosting else host_button.text
    join_button.visible = !is_paused_context

    # Since the two games were compiled together this screen is only ever a
    # pause overlay - the FarmSim title screen is the home screen now, and it
    # is what decides which level starts. So START has nothing left to do here,
    # and there is somewhere to go back to.
    start_game_button.visible = !is_paused_context
    main_menu_button.visible = is_paused_context

    join_popup.hide()
    status_label.text = ''

    MultiplayerManager.server_created.connect(_on_multiplayer_ready)
    MultiplayerManager.game_joined.connect(_on_multiplayer_ready)
    MultiplayerManager.connection_failed.connect(_on_connection_failed)


func _on_start_game_button_pressed() -> void:
    GameManager.start_game()
    queue_free()


func _exit_tree() -> void:
    # However the menu closes - resume, a finished join, main menu - the world
    # must not stay frozen behind it.
    if not get_tree().root.has_node('QuizBattle'):
        GameManager.resume_world()


func _on_resume_button_pressed() -> void:
    queue_free()


func _on_save_game_button_pressed() -> void:
    SaveGameManager.save_game()


func _on_main_menu_button_pressed() -> void:
    # Leaving a multiplayer session has to close the peer too, or the next
    # level starts with a live connection still attached to a freed scene.
    if MultiplayerManager.is_hosting or MultiplayerManager.is_client:
        MultiplayerManager.leave_game()
    GameManager.return_to_title()


func _on_exit_game_button_pressed() -> void:
    GameManager.exit_game()


func _on_host_button_pressed() -> void:
    if MultiplayerManager.is_hosting:
        # Closing the server takes every player with it, so this goes back to
        # the title rather than leaving the host on a map with no player.
        MultiplayerManager.leave_game()
        GameManager.return_to_title()
        return
    # Hosting runs the world for other people, so it cannot stay paused.
    GameManager.resume_world()
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
