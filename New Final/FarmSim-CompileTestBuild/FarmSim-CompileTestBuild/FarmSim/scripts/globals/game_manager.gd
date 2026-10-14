extends Node

const game_menu_screen: PackedScene = preload('res://scenes/ui/game_menu_screen.tscn')

## Which Croptails level a plain "start the game" begins on.
const default_level := 'Stage1'


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("game_menu"):
		return

	# The pause menu belongs to Croptails. On the title screen there is nothing
	# to pause, and the draft levels handle Escape themselves - their seed
	# picker uses it to close - so it stays out of both.
	if not SceneManager.in_game or SceneManager.draft_active:
		return

	# Escape pressed twice should not stack two menus on top of each other.
	if get_tree().root.has_node('GameMenuScreen'):
		return

	show_game_menu_screen()


## Starts Croptails on its default level. Kept so the existing START button on
## the in-game menu behaves the way it always has.
func start_game() -> void:
	start_level(default_level)


## Starts Croptails on a named level from SceneManager.level_scenes. This is
## what the title screen's level select calls, and it is the only difference
## between "play" and "play that one" - everything downstream is identical.
func start_level(level_name: String) -> void:
	if not SceneManager.level_scenes.has(level_name):
		push_warning('GameManager.start_level: unknown level "%s"' % level_name)
		return

	SceneManager.load_main_scene_container()
	await SceneManager.load_level(level_name)
	SaveGameManager.load_game()
	SaveGameManager.allow_save_game = true


## Loads one of the team's draft levels. Drafts are standalone scenes that do
## not use the Croptails save system, so nothing is loaded or enabled here.
func start_draft(draft_id: String) -> bool:
	return SceneManager.load_draft_level(draft_id)


## Leaves whatever is running and brings the title screen back.
func return_to_title() -> void:
	resume_world()
	if get_tree().root.has_node('GameMenuScreen'):
		get_tree().root.get_node('GameMenuScreen').queue_free()
	SceneManager.return_to_title()


func exit_game() -> void:
	get_tree().quit()


func show_game_menu_screen() -> void:
	var instance = game_menu_screen.instantiate()
	instance.name = 'GameMenuScreen'
	get_tree().root.add_child(instance)


## Freezes the world behind a menu or the quiz (FR-PAM-001).
##
## Singleplayer only. In a LAN game the host's world belongs to everyone on it,
## and one player opening a menu must not stop the clock for the others.
func pause_world() -> void:
	if is_networked():
		return
	get_tree().paused = true


## True only in a real LAN session. Godot keeps an OfflineMultiplayerPeer set
## in singleplayer, so has_multiplayer_peer() alone is true there too.
func is_networked() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func resume_world() -> void:
	get_tree().paused = false
