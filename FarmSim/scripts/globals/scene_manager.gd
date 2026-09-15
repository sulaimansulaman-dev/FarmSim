extends Node

## Emitted once a level is in the tree, with the name to show the player.
signal level_loaded(display_name: String)

## Emitted when the player leaves a level and the title screen should come back.
signal returned_to_title()

const main_scene_path := 'res://scenes/levels/main_scene.tscn'
const main_scene_root_path := '/root/MainScene'
const main_scene_level_root_path := main_scene_root_path + '/GameRoot/LevelRoot'
const main_scene_player_path := main_scene_root_path + '/GameRoot/Player'
const main_scene_players_path := main_scene_root_path + '/GameRoot/Players'
const main_scene_spawner_path := main_scene_root_path + '/GameRoot/MultiplayerSpawner'

## Wrapper that hosts a draft level and gives the player a way back out.
const draft_host_scene_path := 'res://scenes/ui/draft_level_host.tscn'
const draft_host_root_path := '/root/DraftLevelHost'

const level_scenes: Dictionary = {
	'Level1': 'res://scenes/levels/level_1.tscn',
	'Island1': 'res://scenes/levels/island_1.tscn',
	'Island3': 'res://scenes/levels/island_3.tscn'
}

## What each level is called on screen. Kept apart from the scene paths because
## one is a filename and the other is player-facing text - and because the team
## has not settled whether these are Islands or Stages. Change these strings and
## nothing else has to move.
const level_names: Dictionary = {
	'Level1': 'Level 1',
	'Island1': 'Island 1',
	'Island3': 'Island 3'
}

## The order the Croptails levels are offered in on the title screen, with the
## blurb shown under each. A Dictionary has no dependable order, so the menu
## reads this rather than level_scenes.
const croptails_level_order: Array = [
	{
		'id': 'Island1',
		'blurb': 'The starting island. Guide, tutorial prompts and the full tool set.'
	},
	{
		'id': 'Level1',
		'blurb': 'The original sandbox level - the widest spread of crops and animals.'
	},
	{
		'id': 'Island3',
		'blurb': 'A later island with its own guide conversation.'
	},
]

## The level drafts that came out of the team's branches.
##
## These were a separate Godot project until the two games were compiled
## together, so they do not share Croptails' player, tools or save system - they
## are standalone scenes with their own controls. They are listed here so the
## work is reachable from the title screen instead of sitting in a folder nobody
## opens. Each loads on its own over the top of the menu, and Escape comes back.
const draft_levels: Array = [
	{
		'id': 'DraftFarmWorld',
		'name': 'Farm World',
		'path': 'res://drafts/scenes/farm/farm_world.tscn',
		'blurb': 'Walkable farm with the full crop simulation. E plant/water, H harvest, C seed, T pests, Q season, Space next day.'
	},
	{
		'id': 'DraftFarmGrid',
		'name': 'Farm Grid',
		'path': 'res://drafts/scenes/farm/farm_grid.tscn',
		'blurb': 'Click-driven version of the same simulation. Pick an action, then click a plot.'
	},
	{
		'id': 'DraftTilemapPlayer',
		'name': 'Tilemap + Player',
		'path': 'res://drafts/scenes/test/test_scene_player.tscn',
		'blurb': 'Hand-built tilemap island with the draft player walking on it.'
	},
	{
		'id': 'DraftTilemap',
		'name': 'Tilemap Only',
		'path': 'res://drafts/scenes/test/test_scene_tilemap.tscn',
		'blurb': 'The same island with no character - the tilemap layer work on its own.'
	},
	{
		'id': 'DraftGreenfield',
		'name': 'Greenfield Level',
		'path': 'res://drafts/scenes/test/test_scene_default.tscn',
		'blurb': 'Larger draft level built on the alternate grass tilesets, with a player.'
	},
]

var current_level: String = ''

## True while a Croptails level or a draft is running. The title screen is not a
## level, and GameManager checks this before letting Escape open the in-game
## pause menu - otherwise Escape on the menu opens a pause screen for a game
## that has not started yet.
var in_game: bool = false

## True while a draft level is running. Drafts read their own keys, Escape
## included, so the Croptails pause menu stays out of their way.
var draft_active: bool = false


func load_main_scene_container() -> void:
	if get_tree().root.has_node(main_scene_root_path):
		return

	var node: Node = load(main_scene_path).instantiate()
	if node != null:
		get_tree().root.add_child(node)


func load_level(level_name: String) -> void:
	var scene_path: String = level_scenes.get(level_name)
	if scene_path == null:
		return

	var level_root = get_node(main_scene_level_root_path)
	if level_root == null:
		return

	var children = level_root.get_children()
	if children != null:
		for node: Node in children:
			node.queue_free()

	await  get_tree().process_frame

	var level_scene: Node = load(scene_path).instantiate()
	level_root.add_child(level_scene)

	current_level = level_name
	in_game = true
	draft_active = false
	level_loaded.emit(str(level_names.get(level_name, level_name)))


# --- draft levels -----------------------------------------------------------

func draft_definition(draft_id: String) -> Dictionary:
	for draft in draft_levels:
		if draft['id'] == draft_id:
			return draft
	return {}


## Loads a draft level inside the host wrapper, which supplies the title bar and
## the way back to the menu. Drafts sit alongside the title screen rather than
## replacing it, so returning is a matter of freeing this one node.
func load_draft_level(draft_id: String) -> bool:
	var draft := draft_definition(draft_id)
	if draft.is_empty():
		push_warning('SceneManager.load_draft_level: unknown draft "%s"' % draft_id)
		return false

	if not ResourceLoader.exists(str(draft['path'])):
		push_warning('SceneManager.load_draft_level: missing scene %s' % draft['path'])
		return false

	unload_current()

	var host: Node = load(draft_host_scene_path).instantiate()
	host.name = 'DraftLevelHost'
	host.draft = draft
	get_tree().root.add_child(host)

	current_level = draft_id
	in_game = true
	draft_active = true
	level_loaded.emit(str(draft['name']))
	return true


# --- leaving a level --------------------------------------------------------

## Tears down whatever is running, whether that is Croptails or a draft.
##
## remove_child before queue_free so the node is out of the tree immediately.
## queue_free alone leaves it live until the end of the frame, which is long
## enough for a level that is halfway through loading to keep running.
func unload_current() -> void:
	for path in [main_scene_root_path, draft_host_root_path]:
		if get_tree().root.has_node(path):
			var node: Node = get_tree().root.get_node(path)
			get_tree().root.remove_child(node)
			node.queue_free()

	current_level = ''
	in_game = false
	draft_active = false


## Drops back to the title screen. The title screen is never freed - it stays
## the current scene and hides itself while a level runs - so coming back is
## just unloading the level and telling the title to show itself again.
func return_to_title() -> void:
	unload_current()
	SaveGameManager.allow_save_game = false
	await get_tree().process_frame
	returned_to_title.emit()
