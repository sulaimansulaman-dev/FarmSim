class_name Player
extends CharacterBody2D

@export var current_tool: DataTypes.Tools = DataTypes.Tools.None

var direction: Vector2 = Vector2.DOWN

@onready var hit_component: HitComponent = $HitComponent
@onready var camera: Camera2D = $Camera2D
@onready var state_machine: NodeStateMachine = $StateMachine


func _ready() -> void:
    hit_component.current_tool = current_tool
    ToolManager.tool_selected.connect(on_tool_selected)

    # player.tscn is also instanced purely for decoration (e.g. the home
    # screen background). Only the real gameplay instances - the static
    # Player under GameRoot, or ones networked-spawned into GameRoot/Players -
    # should touch camera/authority setup below.
    var parent_name: String = get_parent().name if get_parent() else ''
    var is_live_gameplay_player: bool = parent_name == 'GameRoot' or parent_name == 'Players'
    if not is_live_gameplay_player:
        return

    # In multiplayer, only the peer that owns this player should read local
    # input and drive movement; other peers just mirror the replicated
    # position/animation coming from the MultiplayerSynchronizer. In
    # singleplayer (no multiplayer_peer set) this always runs normally.
    var is_remote_player: bool = multiplayer.has_multiplayer_peer() and not is_multiplayer_authority()
    state_machine.set_physics_process(!is_remote_player)
    state_machine.set_process(!is_remote_player)
    camera.enabled = !is_remote_player
    if camera.enabled:
        camera.make_current()


func on_tool_selected(tool: DataTypes.Tools) -> void:
    current_tool = tool
    hit_component.current_tool = tool
