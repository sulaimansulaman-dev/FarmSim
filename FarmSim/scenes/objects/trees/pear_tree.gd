extends Sprite2D

## A perennial pear tree. Near-identical to apple_tree.gd (same mechanic,
## different fruit/art) -- kept as a separate file rather than refactored
## together, to avoid risking already-tested trees this close to a deadline.
##
## Unlike a crop (Tomato, Corn), this tree is never consumed. It grows up
## through the same stage progression as a crop (using the existing
## GrowthCycleComponent), but once it reaches Mature it stays on the map
## forever and instead cycles between "bare" and "bearing fruit":
##
##   Sapling -> Young -> Growing -> Mature (bare)
##                                     |
##                                     v
##                    +---- fruit_regrow_days pass ----+
##                    |                                |
##                    v                                |
##             Bearing fruit  --- harvested by player --+
##
## fruit_tree_growth.png holds the bare growth-stage art (12x4 grid, 48px
## cells): row 0 = sapling (1 frame), row 1 = young (4 frames), row 2 =
## growing (6 frames), row 3 = full-grown/mature (12 frames).
##
## pear_tree_fruiting.png is the same tree at the same four sizes, but with
## fruit/blossom art layered on top (12x5 grid, 48px cells). We only use its
## row 3 (full-grown) and row 4 (just-harvested) here.

const fruit_harvest_scene: PackedScene = preload("res://scenes/objects/trees/pear_harvest.tscn")
const growth_texture: Texture2D = preload("res://assets/game/objects/trees/fruit_tree_growth.png")
const fruiting_texture: Texture2D = preload("res://assets/game/objects/trees/pear_tree_fruiting.png")

const GRID_COLUMNS := 12
## Rows in each sheet (both are 12 columns of 48px cells).
const GROWTH_SHEET_ROWS := 4
const FRUITING_SHEET_ROWS := 5

const log_scene: PackedScene = preload("res://scenes/objects/trees/log.tscn")

## Row 3 of the GROWTH sheet (fruit_tree_growth.png) is the bare, full-grown
## tree. Do NOT use row 3 of a *_tree_fruiting.png sheet as the "bare" frame:
## that row is the "fruit pops off" animation, and its first frame is a tree
## still covered in fruit.
const ROW_MATURE := 3
## Row 2 is the same full-grown canopy size, but with fruit visibly sitting
## in the foliage. (Row 3 of the fruiting sheet turned out to be a "hearts
## floating away" animation with no fruit shown on the tree at all -- easy
## to misread from a static thumbnail. Row 2 is the one that actually shows
## fruit on the tree.)
const ROW_FRUITING := 2
## Row 4 of pear_tree_fruiting.png: fruit just fell, hearts still on the ground.
const ROW_JUST_HARVESTED := 4

## How many in-game days a harvested tree takes to grow fruit again.
@export var fruit_regrow_days: int = 3

## Lets a level designer drop this scene in already fully grown, instead of
## always starting as a sapling.
## BUG FIX: this used to drop the value on the floor in the exact case it was
## written for. Godot assigns exported properties while the scene is being built
## and before _ready, so growth_cycle_component is still null at that moment and
## the old setter's `if growth_cycle_component:` guard silently skipped the
## assignment. A tree placed in a level as Mature came up a sapling anyway.
##
## The value is now kept and applied in _ready, once the child exists. The
## setter still writes straight through when it can, so changing it at runtime
## keeps working.
@export var initial_growth_state: DataTypes.GrowthStates = DataTypes.GrowthStates.Germination:
	set(state):
		initial_growth_state = state
		if growth_cycle_component:
			growth_cycle_component.current_state = state

@onready var growth_cycle_component: GrowthCycleComponent = $GrowthCycleComponent
@onready var harvest_hurt_component: HurtComponent = $HarvestHurtComponent
## Reacts to the AXE (the harvest component above only reacts to the hoe).
@onready var chop_hurt_component: HurtComponent = $ChopHurtComponent
@onready var damage_component: DamageComponent = $DamageComponent

var is_mature: bool = false
var has_fruit: bool = false
var _days_since_last_harvest: int = 0
var _destroyed: bool = false


func _ready() -> void:
	growth_cycle_component.current_state = initial_growth_state

	texture = growth_texture
	hframes = GRID_COLUMNS
	vframes = GROWTH_SHEET_ROWS

	growth_cycle_component.grew_up.connect(on_grew_up)
	harvest_hurt_component.hurt.connect(on_harvested)
	chop_hurt_component.hurt.connect(on_chopped)
	damage_component.max_damage_reached.connect(on_max_damage_reached)
	DayNightCycleManager.time_tick_day.connect(on_time_tick_day)

	# Trees don't need the player to water them like crops do, but
	# GrowthCycleComponent still requires is_watered to be true before it
	# will advance a stage. Keep it permanently "watered" for a tree.
	growth_cycle_component.is_watered = true

	on_grew_up(growth_cycle_component.current_state)


func on_grew_up(growth_state: DataTypes.GrowthStates) -> void:
	# GrowthCycleComponent resets is_watered to false after every stage
	# transition, so put it right back to true for the next one.
	growth_cycle_component.is_watered = true

	if is_mature:
		return

	if growth_state == DataTypes.GrowthStates.Mature:
		_become_mature()
		return

	# Germination/Vegetative/Reproduction map to rows 0/1/2. Show column 0
	# of that row as a simple static frame for the stage.
	frame = int(growth_state) * GRID_COLUMNS


func _become_mature() -> void:
	is_mature = true
	# A newly-grown tree starts bearing fruit right away instead of making
	# the player wait through a first, fruitless regrow cycle. Going through
	# _grow_fruit() keeps what the player SEES and what they can HARVEST in
	# step. (This used to paint a fruit-covered frame while has_fruit was still
	# false, so the tree looked ripe but could not be harvested.)
	_grow_fruit()


func on_time_tick_day(_day: int) -> void:
	if not is_mature or has_fruit:
		return

	_days_since_last_harvest += 1
	if _days_since_last_harvest >= fruit_regrow_days:
		_grow_fruit()


func _grow_fruit() -> void:
	has_fruit = true
	_show_fruit()
	harvest_hurt_component.set_deferred("monitoring", true)


func on_harvested(_hit_damage: int) -> void:
	if not has_fruit:
		return

	has_fruit = false
	_days_since_last_harvest = 0
	# Godot refuses to change an Area2D's `monitoring` while it is delivering an
	# area_entered signal, and this handler runs inside exactly that signal, so
	# the change has to be deferred.
	harvest_hurt_component.set_deferred("monitoring", false)
	call_deferred("spawn_fruit")

	_show_just_harvested()
	await get_tree().create_timer(0.6).timeout
	if not has_fruit and not _destroyed:
		_show_bare()


func spawn_fruit() -> void:
	var fruit_instance := fruit_harvest_scene.instantiate() as Node2D
	# Don't drop it exactly on the tree's own position -- that's where the
	# tree's solid collision blocks the player from ever walking, so it'd be
	# impossible to actually reach. Scatter it a little to the side instead.
	var offset := Vector2(randf_range(-16, 16), randf_range(8, 20))
	fruit_instance.global_position = global_position + offset
	get_parent().add_child(fruit_instance)


# --- chopping ---------------------------------------------------------------

func on_chopped(damage: int) -> void:
	if _destroyed:
		return
	damage_component.apply_damage(damage)
	# Quick red flash so the player can see the swing connected. (The big trees
	# shake with a shader; the fruit trees have no shader material.)
	modulate = Color(1.0, 0.65, 0.65)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.25)


func on_max_damage_reached() -> void:
	if _destroyed:
		return
	_destroyed = true
	FarmEvents.tree_chopped.emit()
	call_deferred("spawn_log")
	queue_free()


func spawn_log() -> void:
	var log_instance := log_scene.instantiate() as Node2D
	log_instance.global_position = global_position
	get_parent().add_child(log_instance)


# --- which picture is showing -----------------------------------------------
# Bare tree and fruiting tree live on DIFFERENT sprite sheets, so every change
# of state goes through one of these three so texture, grid and frame always
# change together.

## Bare, full-grown tree (growth sheet, row 3).
func _show_bare() -> void:
	texture = growth_texture
	hframes = GRID_COLUMNS
	vframes = GROWTH_SHEET_ROWS
	frame = ROW_MATURE * GRID_COLUMNS


## Full-grown tree with fruit on it (fruiting sheet, row 2).
func _show_fruit() -> void:
	texture = fruiting_texture
	hframes = GRID_COLUMNS
	vframes = FRUITING_SHEET_ROWS
	frame = ROW_FRUITING * GRID_COLUMNS


## Fruit has just fallen and is lying on the ground (fruiting sheet, row 4).
func _show_just_harvested() -> void:
	texture = fruiting_texture
	hframes = GRID_COLUMNS
	vframes = FRUITING_SHEET_ROWS
	frame = ROW_JUST_HARVESTED * GRID_COLUMNS
