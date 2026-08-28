extends Node

## High-level multiplayer (ENetMultiplayerPeer / SceneMultiplayer) manager.
## Handles hosting, joining, and spawning networked players via a
## MultiplayerSpawner placed in the main scene.

signal server_created
signal game_joined
signal connection_failed(reason: String)
signal disconnected_from_game
signal player_list_changed

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
const player_scene_path := 'res://scenes/characters/player/player.tscn'
const default_spawn_position := Vector2(485, 241)

var is_hosting: bool = false
var is_client: bool = false
var connected_peer_ids: Array[int] = []

var _spawner: MultiplayerSpawner


func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(port, MAX_PLAYERS)
    if err != OK:
        connection_failed.emit('Could not start server (%s).' % error_string(err))
        return err

    multiplayer.multiplayer_peer = peer
    is_hosting = true
    is_client = false
    connected_peer_ids = [1]

    await _prepare_multiplayer_scene()
    _spawn_player(1)

    server_created.emit()
    player_list_changed.emit()
    return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
    var host := address.strip_edges()
    if host.is_empty():
        connection_failed.emit('Enter a server address to join.')
        return ERR_INVALID_PARAMETER

    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(host, port)
    if err != OK:
        connection_failed.emit('Could not reach %s (%s).' % [host, error_string(err)])
        return err

    multiplayer.multiplayer_peer = peer
    is_hosting = false
    is_client = true

    await _prepare_multiplayer_scene()
    return OK


func leave_game() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null

    _clear_spawned_players()
    is_hosting = false
    is_client = false
    connected_peer_ids.clear()
    disconnected_from_game.emit()
    player_list_changed.emit()


func get_local_ip() -> String:
    for address in IP.get_local_addresses():
        if address.begins_with('192.') or address.begins_with('10.') or address.begins_with('172.'):
            return address
    return '127.0.0.1'


func _prepare_multiplayer_scene() -> void:
    var main_scene_already_running := has_node(SceneManager.main_scene_root_path)
    SceneManager.load_main_scene_container()

    if not main_scene_already_running:
        await SceneManager.load_level('Level1')
    else:
        await get_tree().process_frame

    var static_player := get_node_or_null(SceneManager.main_scene_player_path)
    if static_player:
        static_player.queue_free()

    _spawner = get_node_or_null(SceneManager.main_scene_spawner_path)
    if _spawner:
        _spawner.spawn_function = _create_player_node


func _create_player_node(peer_id: int) -> Node:
    var player: Node2D = load(player_scene_path).instantiate()
    player.name = str(peer_id)
    player.position = default_spawn_position + Vector2(randi_range(-16, 16), randi_range(-16, 16))
    player.set_multiplayer_authority(peer_id)
    return player


func _spawn_player(peer_id: int) -> void:
    if not multiplayer.is_server() or _spawner == null:
        return

    if not connected_peer_ids.has(peer_id):
        connected_peer_ids.append(peer_id)

    _spawner.spawn(peer_id)


func _despawn_player(peer_id: int) -> void:
    if not multiplayer.is_server():
        return

    connected_peer_ids.erase(peer_id)

    var players_root := get_node_or_null(SceneManager.main_scene_players_path)
    if players_root == null:
        return

    var player_node := players_root.get_node_or_null(str(peer_id))
    if player_node:
        player_node.queue_free()


func _clear_spawned_players() -> void:
    var players_root := get_node_or_null(SceneManager.main_scene_players_path)
    if players_root == null:
        return

    for child in players_root.get_children():
        child.queue_free()


func _on_peer_connected(peer_id: int) -> void:
    if multiplayer.is_server():
        _spawn_player(peer_id)
        player_list_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
    if multiplayer.is_server():
        _despawn_player(peer_id)
        player_list_changed.emit()


func _on_connected_to_server() -> void:
    connected_peer_ids.clear()
    for peer_id in multiplayer.get_peers():
        connected_peer_ids.append(peer_id)
    connected_peer_ids.append(multiplayer.get_unique_id())
    game_joined.emit()
    player_list_changed.emit()


func _on_connection_failed() -> void:
    is_client = false
    multiplayer.multiplayer_peer = null
    connection_failed.emit('Failed to connect to the host.')


func _on_server_disconnected() -> void:
    leave_game()
    connection_failed.emit('Lost connection to the host.')
