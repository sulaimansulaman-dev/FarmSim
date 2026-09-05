class_name CropStatusIcon
extends Sprite2D

## The one thing a player must be able to read about a growing crop at a glance:
## does this plant want something from me right now?
##
## Deliberately blank when the answer is no. A tilled field is dozens of tiles,
## and dozens of permanent status badges is noise a player learns to ignore.
## An icon appears only when the crop is thirsty, ready to cut, or dead.

## 16x16 cells of assets/ui/basic_ui_sprites.png.
const ICON_THIRSTY := Rect2(848, 208, 16, 16)  ## exclamation mark
const ICON_REFUSED := Rect2(816, 192, 16, 16)  ## question mark
const ICON_READY := Rect2(832, 192, 16, 16)    ## star
const ICON_DEAD := Rect2(880, 192, 16, 16)     ## skull

## The sheet art is a flat tan, so all colour is carried by modulate.
const TINT_THIRSTY := Color("5fa8d3")
const TINT_REFUSED := Color("d95f4f")
const TINT_READY := Color("f2c94c")
const TINT_DEAD := Color("6f6257")

## How long "not ready yet" stays up after a swing at an unripe crop.
const REFUSED_SECONDS := 1.2

var _crop: Crop
var _showing_refusal := false


func _ready() -> void:
	# Set here as well as in the scene. Without it the Sprite2D draws the whole
	# 896x240 UI sheet, which is a baffling thing to debug from the symptom.
	region_enabled = true
	visible = false


## Starts following a crop. Called by crop_plant.gd once the simulation exists.
func watch(crop: Crop) -> void:
	_crop = crop
	_crop.health_changed.connect(_on_health_changed)
	_crop.matured.connect(refresh)
	_crop.died.connect(refresh)
	refresh()


## Re-reads the crop and shows the matching icon, or hides.
##
## Order matters: dead outranks ready outranks thirsty. A crop can be both ripe
## and dry, and "come and cut me" is the more useful of the two.
func refresh() -> void:
	if _crop == null or _showing_refusal:
		return

	if _crop.state == Crop.State.DEAD:
		_show_icon(ICON_DEAD, TINT_DEAD)
	elif _crop.is_ready_to_harvest():
		_show_icon(ICON_READY, TINT_READY)
	elif _crop.is_thirsty():
		_show_icon(ICON_THIRSTY, TINT_THIRSTY)
	else:
		visible = false


## The answer to "why did nothing happen?" when the hoe hits an unripe crop.
## Takes the display over briefly, then hands it back to refresh().
func refuse() -> void:
	_showing_refusal = true
	_show_icon(ICON_REFUSED, TINT_REFUSED)

	# A one-shot connection rather than await: if the player digs this crop up
	# while the question mark is still showing, Godot drops the connection along
	# with the node instead of resuming a coroutine on a freed object.
	get_tree().create_timer(REFUSED_SECONDS).timeout.connect(_end_refusal)


func _end_refusal() -> void:
	_showing_refusal = false
	refresh()


func _show_icon(region: Rect2, tint: Color) -> void:
	region_rect = region
	modulate = tint
	visible = true


func _on_health_changed(_new_health: float) -> void:
	refresh()
