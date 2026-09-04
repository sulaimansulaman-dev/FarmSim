extends Node

const main_scene_path := 'res://scenes/levels/main_scene.tscn'
const main_scene_root_path := '/root/MainScene'
const main_scene_level_root_path := main_scene_root_path + '/GameRoot/LevelRoot'
const level_scenes: Dictionary = {
    'Level1': 'res://scenes/levels/level_1.tscn'
}


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
