extends Control

## The front door for the compiled project.
##
## This started life as the standalone FarmSim menu, which stood on its own with
## nothing behind it - "Scene 1" through "Scene 5" printed to the console and
## did nothing else. Croptails and the team's level drafts are now part of the
## same project, so those five dead buttons have been replaced by a level select
## that lists what actually exists and launches it.
##
## How it fits together
## --------------------
## This screen is the main scene, and it is never freed. Starting a level hides
## it and adds the level alongside it under /root; leaving a level frees the
## level and shows this again. That is why SceneManager.returned_to_title is
## connected below, and why nothing here calls change_scene_to_file - Croptails'
## multiplayer code reaches for /root/MainScene by absolute path, and swapping
## the current scene out from under it would break that.
##
## Everything is built in code rather than in the editor. That is inherited from
## the original menu and kept deliberately: this file is edited by several
## people and a one-node scene does not produce merge conflicts.

# --- layout constants -------------------------------------------------------
# The window is 640x360 with integer scaling, which is Croptails' setting and
# the reason the whole game looks like pixel art rather than a smeared mess.
# The original menu was written for a 1280x720 window, so every size here has
# been brought down to suit; at the old sizes the singleplayer card alone was
# taller than the screen.

const BUTTON_SIZE := Vector2(190, 26)
const NARROW_BUTTON := Vector2(120, 22)
const ICON_BUTTON := Vector2(34, 28)
const FONT_BODY := 11
const FONT_SMALL := 9
const FONT_HEADER := 14
const FONT_TITLE := 22

const PIXEL_FONT_PATH := 'res://assets/ui/fonts/pixel_font_sproutlands.ttf'

# --- screens ----------------------------------------------------------------
var splash_screen: Control
var login_screen: Control
var main_menu_screen: CenterContainer
var singleplayer_screen: CenterContainer
var level_select_screen: CenterContainer
var multiplayer_screen: CenterContainer
var stats_screen: CenterContainer
var settings_screen: CenterContainer
var credits_screen: Control

var is_splash_done: bool = false
var _active_screen: Control = null

# --- login ------------------------------------------------------------------
var username_input: LineEdit
var login_card_ref: PanelContainer
var remember_checkbox: CheckBox
var is_register_mode: bool = false
var auth_card_title: Label
var auth_prompt_lbl: Label
var auth_submit_btn: Button
var toggle_mode_btn: Button
var error_lbl: Label

# --- singleplayer -----------------------------------------------------------
var continue_farm_btn: Button
var load_save_btn: Button

# --- multiplayer ------------------------------------------------------------
var server_ip_input: LineEdit
var local_status_lbl: Label
var lobby_players_lbl: Label

# --- settings ---------------------------------------------------------------
var music_slider: HSlider
var sound_slider: HSlider
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var hover_sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# --- stats ------------------------------------------------------------------
var lvl_val_lbl: Label
var gold_val_lbl: Label
var harvest_val_lbl: Label
var planted_val_lbl: Label
var yield_val_lbl: Label
var pests_val_lbl: Label
var rain_val_lbl: Label

const PROFILES_PATH = "user://profiles.json"
const SAVE_PATH = "user://save_game.json"
const SETTINGS_PATH = "user://settings.json"
var active_username: String = ""

## Stage id -> its level select button, so locks and stars can be refreshed.
var _stage_buttons: Dictionary = {}

var player_stats: Dictionary = {
	"farmer_level": 0,
	"gold_coins": 0,
	"total_harvests": 0,
	"seeds_planted": 0,
	"successful_yields": 0,
	"pests_handled": 0,
	"rainy_days_survived": 0
}

# --- animation --------------------------------------------------------------
var is_scrolling_credits: bool = false
var credits_scroll_container: Control
var scroll_speed: float = 34.0
var title_banner_ref: Control
var title_banner_base_y: float = 0.0
var title_banner_base_set: bool = false
var time_passed: float = 0.0
var parallax_clouds: Array = []

# --- animated pixel-art scene (built by _setup_pixel_scene) -----------------
# The images live in MENU_ART_DIR. If bg_static.png is missing the original
# gradient background is used instead, so the menu never breaks without them.
const MENU_ART_DIR := "res://assets/ui/menu/"
const SCENE_SIZE := Vector2(640, 360)
const BLADE_FRAMES := 12
const BLADE_FRAME_SIZE := 64
const BLADE_HUB := Vector2(555, 208)
var _scene_root: Control = null
var _scene_title: TextureRect = null
var _scene_sun: TextureRect = null
var _scene_blades: TextureRect = null
var _blade_frames: Array[AtlasTexture] = []
var _scene_clouds: Array = []
var _scene_birds: Array = []
var _scene_actors: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Scoped to this Control rather than to get_tree().root. The original set
	# the font on the root viewport, which was harmless when the menu was the
	# whole program - now it would override Croptails' own UI theme everywhere
	# in the game.
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var pixel_font := load(PIXEL_FONT_PATH)
		if pixel_font:
			var menu_theme := Theme.new()
			menu_theme.set_font("font", "Label", pixel_font)
			menu_theme.set_font("font", "Button", pixel_font)
			menu_theme.set_font("font", "LineEdit", pixel_font)
			menu_theme.set_font("font", "CheckBox", pixel_font)
			menu_theme.set_font("font", "RichTextLabel", pixel_font)
			theme = menu_theme

	_setup_background()
	_setup_audio_players()

	_build_splash_screen()
	_build_login_screen()
	_build_main_menu_screen()
	_build_singleplayer_screen()
	_build_level_select_screen()
	_build_multiplayer_screen()
	_build_stats_screen()
	_build_settings_screen()
	_build_credits_screen()

	login_screen.visible = false
	_active_screen = splash_screen

	_load_settings()
	_create_version_label()

	SceneManager.returned_to_title.connect(_on_returned_to_title)


func _setup_background() -> void:
	if ResourceLoader.exists(MENU_ART_DIR + "bg_static.png"):
		_setup_pixel_scene()
		_setup_ambient_particles()
		return

	var bg = TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient = Gradient.new()
	gradient.colors = [
		Color("#5ec6f2"),
		Color("#bdeaff"),
		Color("#8fd35c")
	]
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	bg.texture = texture
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_setup_grass_foreground()
	_setup_vignette()
	_setup_parallax_clouds()
	_setup_ambient_particles()


# --- animated pixel-art scene -----------------------------------------------

## The scene is laid out in a fixed 640x360 space and that whole space is scaled
## to cover the window, so the animals, windmill and clouds stay lined up with
## the painted background at any window size.
func _setup_pixel_scene() -> void:
	_scene_root = Control.new()
	_scene_root.size = SCENE_SIZE
	_scene_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_scene_root)

	# Back to front: painted background, sky extras, windmill, animals, title.
	_scene_sprite("bg_static.png", Vector2.ZERO)

	_scene_sun = _scene_sprite("sun.png", Vector2(565, 10))
	if _scene_sun:
		_scene_sun.pivot_offset = _scene_sun.size / 2.0

	var cloud_files := ["cloud_a.png", "cloud_b.png", "cloud_c.png", "cloud_a.png", "cloud_b.png", "cloud_c.png"]
	for file_name in cloud_files:
		var cloud := _scene_sprite(file_name, Vector2(randf_range(-40.0, SCENE_SIZE.x), randf_range(10.0, 110.0)))
		if cloud:
			cloud.set_meta("speed", randf_range(2.0, 5.0))
			_scene_clouds.append(cloud)

	var bird_frames: Array[Texture2D] = []
	for file_name in ["bird_a.png", "bird_b.png"]:
		var bird_tex := _scene_texture(file_name)
		if bird_tex:
			bird_frames.append(bird_tex)
	if bird_frames.size() == 2:
		for _i in range(2):
			var bird := _scene_sprite_from(bird_frames[0], Vector2(randf_range(0.0, SCENE_SIZE.x), randf_range(36.0, 90.0)))
			bird.set_meta("frames", bird_frames)
			bird.set_meta("speed", randf_range(14.0, 22.0))
			bird.set_meta("base_y", bird.position.y)
			_scene_birds.append(bird)

	var blade_sheet := _scene_texture("windmill_blades_sheet.png")
	if blade_sheet:
		for i in range(BLADE_FRAMES):
			var frame := AtlasTexture.new()
			frame.atlas = blade_sheet
			frame.region = Rect2(i * BLADE_FRAME_SIZE, 0, BLADE_FRAME_SIZE, BLADE_FRAME_SIZE)
			_blade_frames.append(frame)
		var blade_pos := BLADE_HUB - Vector2(BLADE_FRAME_SIZE, BLADE_FRAME_SIZE) / 2.0
		_scene_blades = _scene_sprite_from(_blade_frames[0], blade_pos)

	# file, y, leftmost x, rightmost x, walking speed (px/s), hop height (px)
	var herd := [
		["cow.png", 280.0, 64.0, 112.0, 5.0, 1.0],
		["sheep.png", 281.0, 146.0, 178.0, 6.0, 1.0],
		["pig.png", 283.0, 462.0, 496.0, 8.0, 1.0],
		["cow.png", 279.0, 508.0, 546.0, 5.0, 1.0],
		["sheep.png", 281.0, 552.0, 586.0, 6.0, 1.0],
		["chicken.png", 322.0, 10.0, 90.0, 20.0, 2.0],
		["chicken.png", 328.0, 96.0, 170.0, 18.0, 2.0],
		["chicken.png", 324.0, 226.0, 320.0, 20.0, 2.0],
		["chicken.png", 330.0, 336.0, 428.0, 18.0, 2.0],
		["chicken.png", 325.0, 470.0, 540.0, 20.0, 2.0],
		["chicken.png", 329.0, 556.0, 618.0, 18.0, 2.0],
	]
	for entry in herd:
		_add_animal(entry[0], entry[1], entry[2], entry[3], entry[4], entry[5])

	_scene_title = _scene_sprite("title.png", Vector2.ZERO)

	_fit_scene()


func _scene_texture(file_name: String) -> Texture2D:
	var path: String = MENU_ART_DIR + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Menu art missing: " + path)
	return null


func _scene_sprite(file_name: String, pos: Vector2) -> TextureRect:
	var tex := _scene_texture(file_name)
	if tex == null:
		return null
	return _scene_sprite_from(tex, pos)


func _scene_sprite_from(tex: Texture2D, pos: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = pos
	_scene_root.add_child(rect)
	rect.size = tex.get_size()
	return rect


func _add_animal(file_name: String, y: float, min_x: float, max_x: float, speed: float, hop: float) -> void:
	var node := _scene_sprite(file_name, Vector2(randf_range(min_x, max_x), y))
	if node == null:
		return
	_scene_actors.append({
		"node": node,
		"base_y": y,
		"min_x": min_x,
		"max_x": max_x,
		"speed": speed,
		"hop": hop,
		"target": randf_range(min_x, max_x),
		"wait": randf_range(0.0, 3.0),
	})


## Scales the 640x360 scene to cover the window. A little more of the bottom
## than the top is cropped on very wide windows, which keeps the title in view.
func _fit_scene() -> void:
	if _scene_root == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var fit: float = maxf(size.x / SCENE_SIZE.x, size.y / SCENE_SIZE.y)
	_scene_root.scale = Vector2(fit, fit)
	var spare: Vector2 = size - SCENE_SIZE * fit
	_scene_root.position = Vector2(spare.x * 0.5, spare.y * 0.35)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_scene()
		_fit_splash_scene()


## Runs every frame from _process, so it pauses by itself while a level is
## running (_hide_for_level turns processing off).
func _animate_scene(delta: float) -> void:
	if _scene_title:
		_scene_title.position.y = sin(time_passed * 1.6) * 1.5

	if _scene_sun:
		var pulse := 1.0 + sin(time_passed * 1.2) * 0.04
		_scene_sun.scale = Vector2(pulse, pulse)

	if _scene_blades and not _blade_frames.is_empty():
		_scene_blades.texture = _blade_frames[int(time_passed * 10.0) % _blade_frames.size()]

	for cloud: TextureRect in _scene_clouds:
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		if cloud.position.x > SCENE_SIZE.x + 10.0:
			cloud.position.x = -cloud.size.x - randf_range(0.0, 80.0)

	var flap := int(time_passed * 7.0) % 2
	for bird: TextureRect in _scene_birds:
		var frames: Array = bird.get_meta("frames")
		bird.texture = frames[flap]
		bird.position.x += float(bird.get_meta("speed")) * delta
		bird.position.y = float(bird.get_meta("base_y")) + sin(time_passed * 2.0 + bird.position.x * 0.05) * 3.0
		if bird.position.x > SCENE_SIZE.x + 12.0:
			bird.position.x = -20.0
			bird.set_meta("base_y", randf_range(36.0, 90.0))

	for actor: Dictionary in _scene_actors:
		var node: TextureRect = actor["node"]
		var base_y: float = actor["base_y"]
		var wait: float = actor["wait"]
		if wait > 0.0:
			actor["wait"] = wait - delta
			node.position.y = base_y
			continue
		var target: float = actor["target"]
		var step: float = float(actor["speed"]) * delta
		var dist: float = target - node.position.x
		if absf(dist) <= step:
			node.position.x = target
			node.position.y = base_y
			actor["wait"] = randf_range(1.5, 5.0)
			actor["target"] = randf_range(float(actor["min_x"]), float(actor["max_x"]))
		else:
			var dir: float = signf(dist)
			node.position.x += dir * step
			node.flip_h = dir < 0.0
			node.position.y = base_y - absf(sin(time_passed * 9.0)) * float(actor["hop"])


# --- returning from a level -------------------------------------------------

## SceneManager has torn the level down; put the menu back the way the player
## left it, on the main menu rather than wherever they were before.
func _on_returned_to_title() -> void:
	visible = true
	set_process(true)

	for screen in [splash_screen, login_screen, singleplayer_screen,
			level_select_screen, multiplayer_screen, stats_screen,
			settings_screen, credits_screen]:
		if screen:
			screen.visible = false
			screen.modulate.a = 1.0

	is_scrolling_credits = false
	main_menu_screen.visible = true
	main_menu_screen.modulate.a = 1.0
	_active_screen = main_menu_screen


## Hides the menu so a level can run over the top of it. The menu keeps running
## its cloud animation otherwise, which is wasted work behind an opaque game.
func _hide_for_level() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	time_passed += delta

	if _scene_root:
		_animate_scene(delta)

	if _splash_scene:
		_animate_splash(delta)

	if title_banner_ref and title_banner_ref.is_inside_tree():
		title_banner_ref.pivot_offset = title_banner_ref.size / 2
		if not title_banner_base_set:
			title_banner_base_y = title_banner_ref.position.y
			title_banner_base_set = true
		title_banner_ref.rotation = sin(time_passed * 1.2) * 0.0015
		title_banner_ref.position.y = title_banner_base_y + cos(time_passed * 1.5) * 3.0

	var vp_size = get_viewport_rect().size
	for cloud in parallax_clouds:
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		if cloud.position.x > vp_size.x + 20:
			cloud.position.x = -cloud.size.x - randf_range(0, 120)

	if is_scrolling_credits and credits_scroll_container:
		credits_scroll_container.position.y -= scroll_speed * delta
		if credits_scroll_container.position.y < -credits_scroll_container.size.y - 60:
			_on_back_from_credits()


# --- audio ------------------------------------------------------------------

func _setup_audio_players() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	hover_sfx_player = AudioStreamPlayer.new()
	add_child(hover_sfx_player)
	ambient_player = AudioStreamPlayer.new()
	add_child(ambient_player)


func _play_click_sfx() -> void:
	if sfx_player.stream:
		sfx_player.play()


func _play_hover_sfx() -> void:
	if hover_sfx_player.stream:
		hover_sfx_player.play()


func _update_audio_volumes() -> void:
	if music_slider and sound_slider:
		var music_db = linear_to_db(maxf(music_slider.value, 0.001) / 100.0)
		var sound_db = linear_to_db(maxf(sound_slider.value, 0.001) / 100.0)
		music_player.volume_db = music_db
		ambient_player.volume_db = music_db
		sfx_player.volume_db = sound_db
		hover_sfx_player.volume_db = sound_db - 5.0


# --- background decoration --------------------------------------------------

func _setup_ambient_particles() -> void:
	var particles = CPUParticles2D.new()
	var vp_size = get_viewport_rect().size
	particles.position = vp_size / 2
	particles.amount = 18
	particles.lifetime = 8.0
	particles.preprocess = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = vp_size / 2
	particles.gravity = Vector2(5, -10)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	var grad = Gradient.new()
	grad.colors = [
		Color(1, 1, 0.9, 0.0),
		Color(1, 0.98, 0.85, 0.45),
		Color(1, 1, 0.9, 0.0)
	]
	particles.color_ramp = grad
	add_child(particles)


func _setup_vignette() -> void:
	var vignette = TextureRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var v_gradient = Gradient.new()
	v_gradient.colors = [Color(0, 0, 0, 0.0), Color(0.05, 0.08, 0.05, 0.18)]
	var v_texture = GradientTexture2D.new()
	v_texture.gradient = v_gradient
	v_texture.fill = GradientTexture2D.FILL_RADIAL
	v_texture.fill_from = Vector2(0.5, 0.5)
	v_texture.fill_to = Vector2(1.0, 0.5)
	v_texture.width = 256
	v_texture.height = 256
	vignette.texture = v_texture
	add_child(vignette)


func _setup_grass_foreground() -> void:
	var vp_size = get_viewport_rect().size
	var grass_layer = Control.new()
	grass_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grass_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grass_layer)

	var back_hill = Polygon2D.new()
	back_hill.color = Color("#7bc94d")
	var back_h = vp_size.y * 0.14
	back_hill.polygon = PackedVector2Array([
		Vector2(0, vp_size.y),
		Vector2(0, vp_size.y - back_h * 0.6),
		Vector2(vp_size.x * 0.3, vp_size.y - back_h),
		Vector2(vp_size.x * 0.7, vp_size.y - back_h * 0.5),
		Vector2(vp_size.x, vp_size.y - back_h * 0.8),
		Vector2(vp_size.x, vp_size.y)
	])
	grass_layer.add_child(back_hill)

	var front_hill = Polygon2D.new()
	front_hill.color = Color("#5fae3a")
	var front_h = vp_size.y * 0.09
	front_hill.polygon = PackedVector2Array([
		Vector2(0, vp_size.y),
		Vector2(0, vp_size.y - front_h * 0.4),
		Vector2(vp_size.x * 0.35, vp_size.y - front_h),
		Vector2(vp_size.x * 0.65, vp_size.y - front_h * 0.3),
		Vector2(vp_size.x, vp_size.y - front_h * 0.7),
		Vector2(vp_size.x, vp_size.y)
	])
	grass_layer.add_child(front_hill)


func _setup_parallax_clouds() -> void:
	var cloud_layer = Control.new()
	cloud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cloud_layer)

	var vp_size = get_viewport_rect().size
	for i in range(4):
		var cloud = TextureRect.new()
		var c_gradient = Gradient.new()
		c_gradient.colors = [Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)]
		var c_texture = GradientTexture2D.new()
		c_texture.gradient = c_gradient
		c_texture.fill = GradientTexture2D.FILL_RADIAL
		c_texture.fill_from = Vector2(0.5, 0.5)
		c_texture.fill_to = Vector2(1.0, 0.5)
		c_texture.width = 120
		c_texture.height = 50
		cloud.texture = c_texture
		cloud.size = Vector2(120, 50)
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.position = Vector2(randf_range(-100, vp_size.x), randf_range(10, vp_size.y * 0.3))
		cloud.set_meta("speed", randf_range(3.0, 7.0))
		cloud_layer.add_child(cloud)
		parallax_clouds.append(cloud)


func _create_version_label() -> void:
	var version_lbl = Label.new()
	version_lbl.text = "v0.2.0 - compiled build"
	version_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	version_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	version_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version_lbl.anchor_top = 1.0
	version_lbl.anchor_bottom = 1.0
	version_lbl.offset_left = 6
	version_lbl.offset_top = -16
	version_lbl.offset_bottom = -3
	add_child(version_lbl)


func _shake_node(node: Control) -> void:
	var original_x = node.position.x
	var tween = create_tween()
	tween.tween_property(node, "position:x", original_x - 6, 0.05)
	tween.tween_property(node, "position:x", original_x + 6, 0.05)
	tween.tween_property(node, "position:x", original_x - 4, 0.05)
	tween.tween_property(node, "position:x", original_x + 4, 0.05)
	tween.tween_property(node, "position:x", original_x, 0.05)


func _switch_screen(current_screen: Control, target_screen: Control) -> void:
	if current_screen == target_screen:
		return

	var tween = create_tween().set_parallel(true)
	tween.tween_property(current_screen, "modulate:a", 0.0, 0.12)
	await tween.finished
	current_screen.visible = false
	current_screen.modulate.a = 1.0

	target_screen.modulate.a = 0.0
	target_screen.visible = true
	_active_screen = target_screen

	if target_screen == login_screen and username_input:
		username_input.grab_focus()

	var fade_in = create_tween()
	fade_in.tween_property(target_screen, "modulate:a", 1.0, 0.16)


# --- shared widget styling --------------------------------------------------

func _connect_hover_glow(btn: Button) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func():
		_play_hover_sfx()
		var style = btn.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			if not style.has_meta("original_border_color"):
				style.set_meta("original_border_color", style.border_color)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(style, "border_color", Color("#ffe8a3"), 0.15)
	)
	btn.mouse_exited.connect(func():
		var style = btn.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			var original_border = style.get_meta("original_border_color", style.border_color)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(style, "border_color", original_border, 0.15)
	)


func _connect_juicy_button(btn: Button, callback: Callable) -> void:
	btn.pressed.connect(func():
		_play_click_sfx()
		callback.call()
	)
	_connect_hover_glow(btn)
	btn.button_down.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.08)
	)
	btn.button_up.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)


func _get_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#f2e0b8")
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 5
	style.border_color = Color("#8a5a2b")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _create_header_banner(parent: Node, text_content: String) -> void:
	var header_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#d38b3f")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 4
	style.border_color = Color("#7a4a1e")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	header_panel.add_theme_stylebox_override("panel", style)

	var title_lbl = Label.new()
	title_lbl.text = text_content
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", FONT_HEADER)
	title_lbl.add_theme_color_override("font_color", Color("#fff6e0"))
	header_panel.add_child(title_lbl)
	parent.add_child(header_panel)


func _create_big_farm_title(parent: Node, text_content: String) -> void:
	var title_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#e0983f")
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 5
	style.border_color = Color("#7a4a1e")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	title_panel.add_theme_stylebox_override("panel", style)

	var title_lbl = Label.new()
	title_lbl.text = text_content
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", Color("#fff2c8"))
	title_panel.add_child(title_lbl)

	title_banner_ref = title_panel
	parent.add_child(title_panel)


func _apply_rounded_lineedit_style(line_edit: LineEdit) -> void:
	line_edit.custom_minimum_size = Vector2(190, 24)
	line_edit.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	line_edit.add_theme_font_size_override("font_size", FONT_BODY)
	line_edit.add_theme_color_override("font_color", Color("#4a3220"))
	line_edit.add_theme_color_override("font_placeholder_color", Color("#a88f6f"))
	line_edit.add_theme_color_override("caret_color", Color("#4a3220"))
	line_edit.add_theme_constant_override("caret_width", 1)
	line_edit.caret_blink = true

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#fff8e7")
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color("#c9a876")
	normal.content_margin_left = 8
	normal.content_margin_right = 8

	var focus = normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("#fffdf5")
	focus.border_color = Color("#e0a941")

	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", focus)


func _apply_beige_button_style(btn: Button) -> void:
	btn.custom_minimum_size = BUTTON_SIZE
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.add_theme_color_override("font_color", Color("#4a2f10"))
	btn.add_theme_color_override("font_hover_color", Color("#2c1d0c"))
	btn.add_theme_color_override("font_pressed_color", Color("#3d2811"))

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#f0c986")
	normal.corner_radius_top_left = 11
	normal.corner_radius_top_right = 11
	normal.corner_radius_bottom_left = 11
	normal.corner_radius_bottom_right = 11
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 4
	normal.border_color = Color("#8a5a2b")

	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f7d99e")
	hover.border_color = Color("#a06a32")

	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#dcae6a")
	pressed.border_width_bottom = 2
	pressed.border_color = Color("#6b4420")

	var disabled = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#c9bfa4")
	disabled.border_color = Color("#8f846c")

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color("#f5f0e4"))


func _apply_green_button_style(btn: Button) -> void:
	btn.custom_minimum_size = BUTTON_SIZE
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.add_theme_color_override("font_color", Color("#ffffff"))
	btn.add_theme_color_override("font_hover_color", Color("#f1f8e9"))

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#7ec52e")
	normal.corner_radius_top_left = 11
	normal.corner_radius_top_right = 11
	normal.corner_radius_bottom_left = 11
	normal.corner_radius_bottom_right = 11
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 4
	normal.border_color = Color("#4c8c15")

	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#8fdb3a")
	hover.border_color = Color("#5da01c")

	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#66a324")
	pressed.border_width_bottom = 2
	pressed.border_color = Color("#3b6e0f")

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


func _apply_square_icon_button_style(btn: Button) -> void:
	btn.custom_minimum_size = ICON_BUTTON
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.add_theme_color_override("font_color", Color("#2c1d0c"))

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#f0c986")
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 3
	normal.border_color = Color("#8a5a2b")

	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f7d99e")
	hover.border_color = Color("#a06a32")

	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#dcae6a")
	pressed.border_width_bottom = 1

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


func _apply_slider_style(slider: HSlider) -> void:
	slider.custom_minimum_size = Vector2(120, 16)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color("#c89355")
	grabber.corner_radius_top_left = 4
	grabber.corner_radius_top_right = 4
	grabber.corner_radius_bottom_left = 4
	grabber.corner_radius_bottom_right = 4
	grabber.border_width_left = 1
	grabber.border_width_top = 1
	grabber.border_width_right = 1
	grabber.border_width_bottom = 2
	grabber.border_color = Color("#382310")
	grabber.expand_margin_top = 3
	grabber.expand_margin_bottom = 3
	grabber.expand_margin_left = 3
	grabber.expand_margin_right = 3

	var grabber_area = StyleBoxFlat.new()
	grabber_area.bg_color = Color("#55923b")
	grabber_area.corner_radius_top_left = 3
	grabber_area.corner_radius_bottom_left = 3

	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color("#d8c396")
	bg_bar.corner_radius_top_left = 3
	bg_bar.corner_radius_top_right = 3
	bg_bar.corner_radius_bottom_left = 3
	bg_bar.corner_radius_bottom_right = 3
	bg_bar.border_width_left = 1
	bg_bar.border_width_top = 1
	bg_bar.border_width_right = 1
	bg_bar.border_width_bottom = 1
	bg_bar.border_color = Color("#3d2f23")

	slider.add_theme_stylebox_override("slider", bg_bar)
	slider.add_theme_stylebox_override("grabber_area", grabber_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area)
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber)


# --- splash -----------------------------------------------------------------

const SPLASH_GREEN := Color("#c9efc0")       # soft light green wash
const SPLASH_TITLE_COLOR := Color("#2f6b3a") # dark green so it reads on white
const SPLASH_SUB_COLOR := Color("#6aa56f")
const SPLASH_LEAF_COUNT := 14
const SPLASH_LEAF_COLORS := [
	Color("#7bc96f"), Color("#a5d6a7"), Color("#f2c14e"),
	Color("#e9a23b"), Color("#d9773b"),
]

var _splash_tween: Tween

# Animated scene behind the splash text. Uses the same 640x360 layout space
# and the same art as the main menu, so the two feel like one world.
var _splash_scene: Control = null
var _splash_sun: TextureRect = null
var _splash_blades: TextureRect = null
var _splash_blade_frames: Array[AtlasTexture] = []
var _splash_clouds: Array = []
var _splash_birds: Array = []
var _splash_leaves: Array = []


func _build_splash_screen() -> void:
	splash_screen = Control.new()
	splash_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash_screen)

	# White base.
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.WHITE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_screen.add_child(bg)

	# Light green that fades in over the white: clear in the middle, green
	# toward the edges, so the text always sits on a clean, bright area.
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.15, 1.0])
	gradient.colors = PackedColorArray([
		Color(SPLASH_GREEN, 0.0),
		Color(SPLASH_GREEN, 1.0)
	])
	var wash_tex = GradientTexture2D.new()
	wash_tex.gradient = gradient
	wash_tex.fill = GradientTexture2D.FILL_RADIAL
	wash_tex.fill_from = Vector2(0.5, 0.5)
	wash_tex.fill_to = Vector2(1.0, 0.5)
	wash_tex.width = 256
	wash_tex.height = 256

	var wash = TextureRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.texture = wash_tex
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.modulate.a = 0.0
	splash_screen.add_child(wash)

	# Sun, clouds, birds, hills, windmill and falling leaves.
	_build_splash_scene()

	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_screen.add_child(center_container)

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_container.add_child(box)

	var title_lbl = Label.new()
	title_lbl.text = "The FarmSim team"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", SPLASH_TITLE_COLOR)
	title_lbl.visible_characters = 0
	title_lbl.modulate.a = 0.0
	box.add_child(title_lbl)

	var presents_lbl = Label.new()
	presents_lbl.text = "presents"
	presents_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	presents_lbl.add_theme_color_override("font_color", SPLASH_SUB_COLOR)
	presents_lbl.visible_characters = 0
	presents_lbl.modulate.a = 0.0
	box.add_child(presents_lbl)

	# Sequence: green + scene fade in (sun rises) -> title types in ->
	# "presents" types in -> hold -> everything fades out as the next screen
	# fades in.
	_splash_tween = create_tween()
	_splash_tween.tween_property(wash, "modulate:a", 1.0, 1.2)
	_splash_tween.parallel().tween_property(_splash_scene, "modulate:a", 1.0, 1.2)
	if _splash_sun:
		_splash_tween.parallel().tween_property(_splash_sun, "position:y", 10.0, 1.8) \
			.from(60.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_splash_tween.tween_interval(0.2)

	_splash_tween.tween_property(title_lbl, "modulate:a", 1.0, 0.4)
	_splash_tween.parallel().tween_property(
		title_lbl, "visible_characters", title_lbl.text.length(), 1.2)
	_splash_tween.tween_interval(0.25)

	_splash_tween.tween_property(presents_lbl, "modulate:a", 1.0, 0.3)
	_splash_tween.parallel().tween_property(
		presents_lbl, "visible_characters", presents_lbl.text.length(), 0.6)

	_splash_tween.tween_interval(1.6)
	_splash_tween.tween_callback(_finish_splash)

	# Click / tap skips straight to the fade-out.
	splash_screen.gui_input.connect(func(event):
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			_finish_splash()
	)


func _finish_splash() -> void:
	if is_splash_done:
		return
	is_splash_done = true
	if _splash_tween and _splash_tween.is_valid():
		_splash_tween.kill()
	splash_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Crossfade: the whole splash (text and scene included) fades out while
	# the next screen fades in underneath it.
	login_screen.modulate.a = 0.0
	login_screen.visible = true
	_active_screen = login_screen
	if username_input:
		username_input.grab_focus()

	var fade = create_tween().set_parallel(true)
	fade.tween_property(splash_screen, "modulate:a", 0.0, 0.9)
	fade.tween_property(login_screen, "modulate:a", 1.0, 0.9)
	await fade.finished

	splash_screen.visible = false
	splash_screen.modulate.a = 1.0

	# The splash only plays once, so stop animating and free its scene.
	if _splash_scene:
		_splash_scene.queue_free()
		_splash_scene = null
		_splash_sun = null
		_splash_blades = null
		_splash_clouds.clear()
		_splash_birds.clear()
		_splash_leaves.clear()


# --- splash scene -----------------------------------------------------------

func _build_splash_scene() -> void:
	_splash_scene = Control.new()
	_splash_scene.size = SCENE_SIZE
	_splash_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash_scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_splash_scene.modulate.a = 0.0
	splash_screen.add_child(_splash_scene)

	# Back to front: sun, clouds, birds, far hill, windmill, near hill,
	# leaves.
	_splash_sun = _splash_sprite("sun.png", Vector2(565, 10))
	if _splash_sun:
		_splash_sun.pivot_offset = _splash_sun.size / 2.0

	for file_name in ["cloud_a.png", "cloud_b.png", "cloud_c.png", "cloud_a.png"]:
		var cloud := _splash_sprite(file_name, Vector2(randf_range(-40.0, SCENE_SIZE.x), randf_range(14.0, 90.0)))
		if cloud:
			cloud.set_meta("speed", randf_range(3.0, 6.0))
			_splash_clouds.append(cloud)

	var bird_frames: Array[Texture2D] = []
	for file_name in ["bird_a.png", "bird_b.png"]:
		var bird_tex := _scene_texture(file_name)
		if bird_tex:
			bird_frames.append(bird_tex)
	if bird_frames.size() == 2:
		for _i in range(2):
			var bird := _splash_sprite_from(bird_frames[0], Vector2(randf_range(0.0, SCENE_SIZE.x), randf_range(36.0, 90.0)))
			bird.set_meta("frames", bird_frames)
			bird.set_meta("speed", randf_range(14.0, 22.0))
			bird.set_meta("base_y", bird.position.y)
			_splash_birds.append(bird)

	_splash_scene.add_child(_make_hill(300.0, 6.0, 0.012, 1.0, Color("#b5e6a6")))
	_build_splash_windmill()
	_splash_scene.add_child(_make_hill(316.0, 5.0, 0.02, 0.0, Color("#8fd35c")))

	for _i in range(SPLASH_LEAF_COUNT):
		_add_splash_leaf()

	_fit_splash_scene()


func _splash_sprite(file_name: String, pos: Vector2) -> TextureRect:
	var tex := _scene_texture(file_name)
	if tex == null:
		return null
	return _splash_sprite_from(tex, pos)


func _splash_sprite_from(tex: Texture2D, pos: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = pos
	_splash_scene.add_child(rect)
	rect.size = tex.get_size()
	return rect


## A rolling hill: a sine-wave ridge snapped to whole pixels (so it keeps the
## pixel-art look) filled down to the bottom of the scene.
func _make_hill(base_y: float, amp: float, freq: float, phase: float, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	var x := 0.0
	while x <= SCENE_SIZE.x:
		points.append(Vector2(x, roundf(base_y + sin(x * freq + phase) * amp)))
		x += 8.0
	points.append(Vector2(SCENE_SIZE.x, SCENE_SIZE.y))
	points.append(Vector2(0.0, SCENE_SIZE.y))
	var hill := Polygon2D.new()
	hill.polygon = points
	hill.color = color
	return hill


## The tower is drawn from simple shapes; the spinning blades are the same
## windmill_blades_sheet.png the main menu uses.
func _build_splash_windmill() -> void:
	var hub := Vector2(520.0, 236.0)

	var tower := Polygon2D.new()
	tower.polygon = PackedVector2Array([
		Vector2(512, 240), Vector2(528, 240), Vector2(537, 336), Vector2(503, 336)])
	tower.color = Color("#efe3c4")
	_splash_scene.add_child(tower)

	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([
		Vector2(520, 240), Vector2(528, 240), Vector2(537, 336), Vector2(520, 336)])
	shade.color = Color("#d9c9a0")
	_splash_scene.add_child(shade)

	var window := Polygon2D.new()
	window.polygon = PackedVector2Array([
		Vector2(517, 264), Vector2(523, 264), Vector2(523, 272), Vector2(517, 272)])
	window.color = Color("#7a5a3a")
	_splash_scene.add_child(window)

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(509, 242), Vector2(531, 242), Vector2(520, 224)])
	roof.color = Color("#b9553f")
	_splash_scene.add_child(roof)

	var blade_sheet := _scene_texture("windmill_blades_sheet.png")
	if blade_sheet:
		for i in range(BLADE_FRAMES):
			var frame := AtlasTexture.new()
			frame.atlas = blade_sheet
			frame.region = Rect2(i * BLADE_FRAME_SIZE, 0, BLADE_FRAME_SIZE, BLADE_FRAME_SIZE)
			_splash_blade_frames.append(frame)
		_splash_blades = _splash_sprite_from(
			_splash_blade_frames[0], hub - Vector2(BLADE_FRAME_SIZE, BLADE_FRAME_SIZE) / 2.0)


func _add_splash_leaf() -> void:
	var leaf := Polygon2D.new()
	leaf.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(3, -1), Vector2(2, 3),
		Vector2(0, 5), Vector2(-2, 3), Vector2(-3, -1)])
	var s := randf_range(0.8, 1.5)
	leaf.scale = Vector2(s, s)
	leaf.color = SPLASH_LEAF_COLORS[randi() % SPLASH_LEAF_COLORS.size()]
	leaf.rotation = randf_range(0.0, TAU)
	leaf.position = Vector2(randf_range(0.0, SCENE_SIZE.x), randf_range(-20.0, SCENE_SIZE.y))
	_splash_scene.add_child(leaf)
	_splash_leaves.append({
		"node": leaf,
		"base_x": leaf.position.x,
		"fall": randf_range(18.0, 34.0),
		"drift": randf_range(4.0, 10.0),
		"sway": randf_range(6.0, 16.0),
		"sway_speed": randf_range(0.8, 1.8),
		"phase": randf_range(0.0, TAU),
		"spin": randf_range(-2.0, 2.0),
	})


func _animate_splash(delta: float) -> void:
	if _splash_sun:
		var pulse := 1.0 + sin(time_passed * 1.2) * 0.04
		_splash_sun.scale = Vector2(pulse, pulse)

	if _splash_blades and not _splash_blade_frames.is_empty():
		_splash_blades.texture = _splash_blade_frames[int(time_passed * 10.0) % _splash_blade_frames.size()]

	for cloud: TextureRect in _splash_clouds:
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		if cloud.position.x > SCENE_SIZE.x + 10.0:
			cloud.position.x = -cloud.size.x - randf_range(0.0, 80.0)

	var flap := int(time_passed * 7.0) % 2
	for bird: TextureRect in _splash_birds:
		var frames: Array = bird.get_meta("frames")
		bird.texture = frames[flap]
		bird.position.x += float(bird.get_meta("speed")) * delta
		bird.position.y = float(bird.get_meta("base_y")) + sin(time_passed * 2.0 + bird.position.x * 0.05) * 3.0
		if bird.position.x > SCENE_SIZE.x + 12.0:
			bird.position.x = -20.0
			bird.set_meta("base_y", randf_range(36.0, 90.0))

	for leaf: Dictionary in _splash_leaves:
		var node: Polygon2D = leaf["node"]
		leaf["base_x"] = float(leaf["base_x"]) + float(leaf["drift"]) * delta
		node.position.x = float(leaf["base_x"]) + sin(time_passed * float(leaf["sway_speed"]) + float(leaf["phase"])) * float(leaf["sway"])
		node.position.y += float(leaf["fall"]) * delta
		node.rotation += float(leaf["spin"]) * delta
		if node.position.y > SCENE_SIZE.y + 12.0:
			node.position.y = -12.0
			leaf["base_x"] = randf_range(-20.0, SCENE_SIZE.x)
		elif float(leaf["base_x"]) > SCENE_SIZE.x + 20.0:
			leaf["base_x"] = -20.0


## Same scale-to-cover maths as the main menu scene, centred vertically.
func _fit_splash_scene() -> void:
	if _splash_scene == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var fit: float = maxf(size.x / SCENE_SIZE.x, size.y / SCENE_SIZE.y)
	_splash_scene.scale = Vector2(fit, fit)
	var spare: Vector2 = size - SCENE_SIZE * fit
	_splash_scene.position = spare * 0.5


# --- login ------------------------------------------------------------------

func _build_login_screen() -> void:
	login_screen = Control.new()
	login_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(login_screen)

	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	login_screen.add_child(center_container)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	center_container.add_child(card)
	login_card_ref = card

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# The FARMSIM title is painted into the menu background now.

	auth_prompt_lbl = Label.new()
	auth_prompt_lbl.text = "Enter Username:"
	auth_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auth_prompt_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	auth_prompt_lbl.add_theme_color_override("font_color", Color("#5c3a15"))
	box.add_child(auth_prompt_lbl)

	username_input = LineEdit.new()
	username_input.placeholder_text = "e.g. Player1"
	_apply_rounded_lineedit_style(username_input)
	box.add_child(username_input)

	error_lbl = Label.new()
	error_lbl.text = ""
	error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	error_lbl.add_theme_color_override("font_color", Color("#c1442e"))
	box.add_child(error_lbl)

	auth_submit_btn = Button.new()
	auth_submit_btn.text = "Log In"
	_apply_green_button_style(auth_submit_btn)
	_connect_juicy_button(auth_submit_btn, _on_auth_submitted)
	box.add_child(auth_submit_btn)

	# Enter submits. Typing a name and pressing Return is what everyone tries
	# first, and the original only accepted a click on the button.
	username_input.text_submitted.connect(func(_t): _on_auth_submitted())

	# A player who just wants to look at the game should not have to invent an
	# account first. The profile only exists to label the stats screen.
	var skip_btn = Button.new()
	skip_btn.text = "Play as Guest"
	_apply_beige_button_style(skip_btn)
	_connect_juicy_button(skip_btn, func(): _login_success("Guest"))
	box.add_child(skip_btn)

	remember_checkbox = CheckBox.new()
	remember_checkbox.text = "Stay logged in"
	remember_checkbox.add_theme_color_override("font_color", Color("#5c3a15"))
	remember_checkbox.add_theme_font_size_override("font_size", FONT_SMALL)
	box.add_child(remember_checkbox)

	toggle_mode_btn = Button.new()
	toggle_mode_btn.text = "Need an account? Register here"
	toggle_mode_btn.flat = true
	toggle_mode_btn.add_theme_color_override("font_color", Color("#4c8c15"))
	toggle_mode_btn.add_theme_font_size_override("font_size", FONT_SMALL)
	_connect_juicy_button(toggle_mode_btn, _toggle_auth_mode)
	box.add_child(toggle_mode_btn)


func _toggle_auth_mode() -> void:
	is_register_mode = !is_register_mode
	error_lbl.text = ""
	username_input.text = ""
	username_input.grab_focus()

	if is_register_mode:
		auth_prompt_lbl.text = "Choose a Username:"
		auth_submit_btn.text = "Register"
		toggle_mode_btn.text = "Already have an account? Log in"
	else:
		auth_prompt_lbl.text = "Enter Username:"
		auth_submit_btn.text = "Log In"
		toggle_mode_btn.text = "Need an account? Register here"


func _on_auth_submitted() -> void:
	var user = username_input.text.strip_edges()
	if user == "":
		_show_login_error("Username cannot be empty!")
		return

	var profiles = _load_profiles()

	if is_register_mode:
		if profiles.has(user):
			_show_login_error("Username taken! Pick another.")
		else:
			profiles[user] = {"created_at": Time.get_datetime_string_from_system()}
			_save_profiles(profiles)
			_login_success(user)
	else:
		if profiles.has(user):
			_login_success(user)
		else:
			_show_login_error("User not found! Check spelling or register.")


func _show_login_error(message: String) -> void:
	error_lbl.text = message
	if login_card_ref:
		_shake_node(login_card_ref)


func _login_success(user: String) -> void:
	active_username = user
	_save_remember_me_state()
	_switch_screen(login_screen, main_menu_screen)


func _load_profiles() -> Dictionary:
	if not FileAccess.file_exists(PROFILES_PATH):
		return {}
	var file = FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}


func _save_profiles(data: Dictionary) -> void:
	var file = FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


# --- main menu --------------------------------------------------------------

func _build_main_menu_screen() -> void:
	main_menu_screen = CenterContainer.new()
	main_menu_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_screen.visible = false
	add_child(main_menu_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	main_menu_screen.add_child(card)

	var menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 7)
	card.add_child(menu_box)

	_create_header_banner(menu_box, "MAIN MENU")

	_create_menu_button(menu_box, "PLAY CROPTAILS", _on_play_croptails)
	_create_menu_button(menu_box, "LEVEL SELECT", _on_level_select)
	_create_menu_button(menu_box, "MULTIPLAYER", _on_multiplayer)

	var icons_hbox = HBoxContainer.new()
	icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	icons_hbox.add_theme_constant_override("separation", 6)
	menu_box.add_child(icons_hbox)

	_create_icon_block_button(icons_hbox, "STATS", "Progress & Stats", _on_stats)
	_create_icon_block_button(icons_hbox, "OPTS", "Settings", _on_settings)
	_create_icon_block_button(icons_hbox, "CRED", "Credits", _on_credits)
	_create_icon_block_button(icons_hbox, "QUIT", "Exit", _on_exit)


func _create_menu_button(parent: Node, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	_apply_beige_button_style(btn)
	_connect_juicy_button(btn, callback)
	parent.add_child(btn)


func _create_icon_block_button(parent: Node, icon_text: String, tooltip_text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = icon_text
	btn.tooltip_text = tooltip_text
	_apply_square_icon_button_style(btn)
	btn.add_theme_font_size_override("font_size", FONT_SMALL)
	_connect_juicy_button(btn, callback)
	parent.add_child(btn)


# --- singleplayer -----------------------------------------------------------

func _build_singleplayer_screen() -> void:
	singleplayer_screen = CenterContainer.new()
	singleplayer_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	singleplayer_screen.visible = false
	add_child(singleplayer_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	singleplayer_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	_create_header_banner(box, "CROPTAILS")

	var subtitle = Label.new()
	subtitle.text = "Start a farm, or pick up where you left off"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", FONT_SMALL)
	subtitle.add_theme_color_override("font_color", Color("#6b4a2c"))
	box.add_child(subtitle)

	continue_farm_btn = Button.new()
	continue_farm_btn.text = "Continue Farm"
	_apply_green_button_style(continue_farm_btn)
	_connect_juicy_button(continue_farm_btn, _on_continue_farm)
	box.add_child(continue_farm_btn)

	var new_farm_btn = Button.new()
	new_farm_btn.text = "New Farm"
	_apply_beige_button_style(new_farm_btn)
	_connect_juicy_button(new_farm_btn, _on_new_farm)
	box.add_child(new_farm_btn)

	var levels_btn = Button.new()
	levels_btn.text = "Choose a Level"
	_apply_beige_button_style(levels_btn)
	_connect_juicy_button(levels_btn, _on_level_select_from_singleplayer)
	box.add_child(levels_btn)

	var back_btn = Button.new()
	back_btn.text = "Back"
	_apply_beige_button_style(back_btn)
	_connect_juicy_button(back_btn, func(): _switch_screen(singleplayer_screen, main_menu_screen))
	box.add_child(back_btn)


func _update_singleplayer_buttons() -> void:
	var has_save = ProgressManager.has_progress()
	continue_farm_btn.disabled = not has_save
	continue_farm_btn.tooltip_text = "" if has_save else "No progress yet - start a new farm first."


# --- level select -----------------------------------------------------------

## The heart of the compiled build: one screen listing every level in the
## project, from both games, each launching through the same two calls.
func _build_level_select_screen() -> void:
	level_select_screen = CenterContainer.new()
	level_select_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_select_screen.visible = false
	add_child(level_select_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	level_select_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)

	_create_header_banner(box, "LEVEL SELECT")

	# A fixed-height scroller, because the list grows every time somebody adds
	# a level and the card must not grow past the bottom of a 360px screen.
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 196)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# The staged build, in order. Stage 1 teaches the loop and each stage after
	# it adds one system, so the order on screen is the order they are meant to
	# be played in.
	_add_list_heading(list, "THE FARM - STAGES 1 TO 5")

	var index := 0
	for entry in SceneManager.croptails_level_order:
		if index == SceneManager.extras_start_at:
			_add_list_heading(list, "OLDER LEVELS")
			_add_list_note(list, "Kept for reference. Not part of the staged build.")

		var level_id := str(entry['id'])
		var display_name := str(SceneManager.level_names.get(level_id, level_id))
		var button := _add_level_entry(
			list,
			display_name,
			str(entry['blurb']),
			func(): _on_play_croptails_level(level_id)
		)
		if StageSession.is_stage(level_id):
			_stage_buttons[level_id] = button
		index += 1

	_add_list_heading(list, "TEAM LEVEL DRAFTS")
	_add_list_note(list, "Work in progress from the team's branches. These run on their own and have their own controls.")

	for draft in SceneManager.draft_levels:
		var draft_id := str(draft['id'])
		_add_level_entry(
			list,
			str(draft['name']),
			str(draft['blurb']),
			func(): _on_play_draft(draft_id)
		)

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, func(): _switch_screen(level_select_screen, main_menu_screen))
	box.add_child(back_btn)


## A line of explanation under a heading, for sections that need one.
func _add_list_note(parent: Node, text: String) -> void:
	var note = Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(288, 0)
	note.add_theme_font_size_override("font_size", FONT_SMALL)
	note.add_theme_color_override("font_color", Color("#6b4a2c"))
	parent.add_child(note)


func _add_list_heading(parent: Node, text: String) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	parent.add_child(spacer)

	var heading = Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", FONT_BODY)
	heading.add_theme_color_override("font_color", Color("#8a5a2b"))
	parent.add_child(heading)


## One row per level: a button that launches it, with the blurb underneath so
## the player knows what they are choosing before they commit to a load.
func _add_level_entry(parent: Node, title: String, blurb: String, callback: Callable) -> Button:
	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 0)
	parent.add_child(entry)

	var btn = Button.new()
	btn.text = title
	_apply_beige_button_style(btn)
	btn.custom_minimum_size = Vector2(288, 24)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_connect_juicy_button(btn, callback)
	entry.add_child(btn)

	var blurb_lbl = Label.new()
	blurb_lbl.text = blurb
	blurb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_lbl.custom_minimum_size = Vector2(288, 0)
	blurb_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	blurb_lbl.add_theme_color_override("font_color", Color("#7a6248"))
	entry.add_child(blurb_lbl)
	return btn


## Stages unlock in order as their bridge keeper is beaten, and each shows the
## best star rating earned on it. Re-read every time the list is opened, because
## finishing a stage changes both.
func _refresh_stage_buttons() -> void:
	for level_id in _stage_buttons:
		var button: Button = _stage_buttons[level_id]
		var display_name := str(SceneManager.level_names.get(level_id, level_id))
		var unlocked := ProgressManager.is_stage_unlocked(level_id)
		button.disabled = not unlocked
		if not unlocked:
			button.text = "%s  (locked)" % display_name
			button.tooltip_text = "Beat the bridge keeper on the stage before to unlock this one."
		else:
			var stars := ProgressManager.stars_for(level_id)
			button.text = display_name if stars == 0 else "%s  [%d/3 stars]" % [display_name, stars]
			button.tooltip_text = ""


# --- multiplayer ------------------------------------------------------------

## Wired to Croptails' MultiplayerManager rather than the placeholder the
## original menu had, which only ever printed "Connecting..." and stopped.
func _build_multiplayer_screen() -> void:
	multiplayer_screen = CenterContainer.new()
	multiplayer_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	multiplayer_screen.visible = false
	add_child(multiplayer_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	multiplayer_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	_create_header_banner(box, "MULTIPLAYER")

	var subtitle = Label.new()
	subtitle.text = "Host a farm, or join one on your network"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", FONT_SMALL)
	subtitle.add_theme_color_override("font_color", Color("#6b4a2c"))
	box.add_child(subtitle)

	var host_btn = Button.new()
	host_btn.text = "Host Farm"
	_apply_green_button_style(host_btn)
	_connect_juicy_button(host_btn, _on_host_farm)
	box.add_child(host_btn)

	server_ip_input = LineEdit.new()
	server_ip_input.placeholder_text = "Host IP (blank = 127.0.0.1)"
	_apply_rounded_lineedit_style(server_ip_input)
	box.add_child(server_ip_input)

	var join_btn = Button.new()
	join_btn.text = "Join Farm"
	_apply_beige_button_style(join_btn)
	_connect_juicy_button(join_btn, _on_join_farm)
	box.add_child(join_btn)

	local_status_lbl = Label.new()
	local_status_lbl.text = ""
	local_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	local_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local_status_lbl.custom_minimum_size = Vector2(190, 0)
	local_status_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	local_status_lbl.add_theme_color_override("font_color", Color("#c1442e"))
	box.add_child(local_status_lbl)

	lobby_players_lbl = Label.new()
	lobby_players_lbl.text = "Not connected"
	lobby_players_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_players_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	lobby_players_lbl.add_theme_color_override("font_color", Color("#4c8c15"))
	box.add_child(lobby_players_lbl)

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	_apply_beige_button_style(back_btn)
	_connect_juicy_button(back_btn, func(): _switch_screen(multiplayer_screen, main_menu_screen))
	box.add_child(back_btn)

	MultiplayerManager.server_created.connect(_on_multiplayer_ready)
	MultiplayerManager.game_joined.connect(_on_multiplayer_ready)
	MultiplayerManager.connection_failed.connect(_on_multiplayer_failed)


func _on_host_farm() -> void:
	local_status_lbl.text = ""
	lobby_players_lbl.text = "Starting server on %s..." % MultiplayerManager.get_local_ip()
	await MultiplayerManager.host_game()


func _on_join_farm() -> void:
	var ip = server_ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	local_status_lbl.text = ""
	lobby_players_lbl.text = "Connecting to %s..." % ip
	await MultiplayerManager.join_game(ip)


func _on_multiplayer_ready() -> void:
	lobby_players_lbl.text = "Connected"
	_hide_for_level()


func _on_multiplayer_failed(reason: String) -> void:
	local_status_lbl.text = reason
	lobby_players_lbl.text = "Not connected"


# --- settings ---------------------------------------------------------------

func _build_settings_screen() -> void:
	settings_screen = CenterContainer.new()
	settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_screen.visible = false
	add_child(settings_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	settings_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	_create_header_banner(box, "SETTINGS")

	var music_hbox = HBoxContainer.new()
	music_hbox.add_theme_constant_override("separation", 8)
	var music_lbl = Label.new()
	music_lbl.text = "MUSIC"
	music_lbl.custom_minimum_size = Vector2(50, 0)
	music_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	music_lbl.add_theme_color_override("font_color", Color("#4a2f10"))
	music_hbox.add_child(music_lbl)

	music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.value = 100
	_apply_slider_style(music_slider)
	music_slider.value_changed.connect(func(_val): _update_audio_volumes())
	music_hbox.add_child(music_slider)
	box.add_child(music_hbox)

	var sound_hbox = HBoxContainer.new()
	sound_hbox.add_theme_constant_override("separation", 8)
	var sound_lbl = Label.new()
	sound_lbl.text = "SOUND"
	sound_lbl.custom_minimum_size = Vector2(50, 0)
	sound_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	sound_lbl.add_theme_color_override("font_color", Color("#4a2f10"))
	sound_hbox.add_child(sound_lbl)

	sound_slider = HSlider.new()
	sound_slider.min_value = 0
	sound_slider.max_value = 100
	sound_slider.value = 50
	_apply_slider_style(sound_slider)
	sound_slider.value_changed.connect(func(_val): _update_audio_volumes())
	sound_hbox.add_child(sound_slider)
	box.add_child(sound_hbox)

	var back_btn = Button.new()
	back_btn.text = "Save & Back"
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, _on_back_from_settings)
	box.add_child(back_btn)


func _read_settings_file() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}


func _save_settings() -> void:
	var settings_data = _read_settings_file()
	settings_data["music_val"] = music_slider.value
	settings_data["sound_val"] = sound_slider.value
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data, "\t"))


func _save_remember_me_state() -> void:
	var settings_data = _read_settings_file()
	if remember_checkbox and remember_checkbox.button_pressed:
		settings_data["remember_me"] = true
		settings_data["last_username"] = active_username
	else:
		settings_data["remember_me"] = false
		settings_data.erase("last_username")
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data, "\t"))


func _load_settings() -> void:
	var data = _read_settings_file()
	if data.is_empty():
		return
	music_slider.value = data.get("music_val", 100)
	sound_slider.value = data.get("sound_val", 50)
	_update_audio_volumes()

	if data.get("remember_me", false):
		var last_user = data.get("last_username", "")
		if last_user != "":
			username_input.text = last_user
			remember_checkbox.button_pressed = true


# --- stats ------------------------------------------------------------------

func _build_stats_screen() -> void:
	stats_screen = CenterContainer.new()
	stats_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_screen.visible = false
	add_child(stats_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	stats_screen.add_child(card)

	var main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 8)
	card.add_child(main_box)

	_create_header_banner(main_box, "PROGRESS & STATS")

	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 5)
	main_box.add_child(cards_hbox)

	harvest_val_lbl = _create_stat_card(cards_hbox, "Harvests")
	lvl_val_lbl = _create_stat_card(cards_hbox, "Level")
	gold_val_lbl = _create_stat_card(cards_hbox, "Gold")

	var table_panel = PanelContainer.new()
	var table_style = StyleBoxFlat.new()
	table_style.bg_color = Color("#1c1510")
	table_style.corner_radius_top_left = 5
	table_style.corner_radius_top_right = 5
	table_style.corner_radius_bottom_left = 5
	table_style.corner_radius_bottom_right = 5
	table_style.content_margin_left = 8
	table_style.content_margin_right = 8
	table_style.content_margin_top = 6
	table_style.content_margin_bottom = 6
	table_panel.add_theme_stylebox_override("panel", table_style)
	main_box.add_child(table_panel)

	var table_vbox = VBoxContainer.new()
	table_vbox.add_theme_constant_override("separation", 3)
	table_panel.add_child(table_vbox)

	planted_val_lbl = _create_stat_row(table_vbox, "Stages Completed")
	yield_val_lbl = _create_stat_row(table_vbox, "Grade A Crops")
	pests_val_lbl = _create_stat_row(table_vbox, "Stars Earned")
	rain_val_lbl = _create_stat_row(table_vbox, "Rainy Days Survived")

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, func(): _switch_screen(stats_screen, main_menu_screen))
	main_box.add_child(back_btn)


func _create_stat_card(parent: Node, title_text: String) -> Label:
	var card_panel = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#1c1510")
	card_style.corner_radius_top_left = 5
	card_style.corner_radius_top_right = 5
	card_style.corner_radius_bottom_left = 5
	card_style.corner_radius_bottom_right = 5
	card_style.content_margin_left = 8
	card_style.content_margin_right = 8
	card_style.content_margin_top = 5
	card_style.content_margin_bottom = 5
	card_panel.add_theme_stylebox_override("panel", card_style)
	card_panel.custom_minimum_size = Vector2(62, 38)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	card_panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	title_lbl.add_theme_color_override("font_color", Color("#d7ccc8"))
	vbox.add_child(title_lbl)

	var val_lbl = Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", FONT_HEADER)
	val_lbl.add_theme_color_override("font_color", Color("#ffe082"))
	vbox.add_child(val_lbl)

	parent.add_child(card_panel)
	return val_lbl


func _create_stat_row(parent: Node, label_text: String) -> Label:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", FONT_SMALL)
	lbl.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(lbl)

	var val = Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", FONT_SMALL)
	val.add_theme_color_override("font_color", Color("#a5d6a7"))
	hbox.add_child(val)

	parent.add_child(hbox)
	return val


## The stats screen was never wired to anything and always read zero. It now
## reads the JSON progress file the stages write.
func _load_stats_from_progress() -> void:
	var profile: Dictionary = ProgressManager.data.get("player_profile", {})
	var harvests := 0
	var grade_a := 0
	var planted_stages := 0
	for record in ProgressManager.stage_evaluations().values():
		harvests += int(record.get("crops_harvested", 0))
		grade_a += int(record.get("grade_a_crops", 0))
		planted_stages += 1
	player_stats["farmer_level"] = int(profile.get("farmer_level", 1))
	player_stats["gold_coins"] = int(profile.get("currency_balance", 0))
	player_stats["total_harvests"] = harvests
	player_stats["seeds_planted"] = planted_stages
	player_stats["successful_yields"] = grade_a
	player_stats["pests_handled"] = ProgressManager.total_stars()


func _update_stats_display() -> void:
	lvl_val_lbl.text = str(player_stats.get("farmer_level", 0))
	gold_val_lbl.text = str(player_stats.get("gold_coins", 0))
	harvest_val_lbl.text = str(player_stats.get("total_harvests", 0))
	planted_val_lbl.text = str(player_stats.get("seeds_planted", 0))
	yield_val_lbl.text = str(player_stats.get("successful_yields", 0))
	pests_val_lbl.text = str(player_stats.get("pests_handled", 0))
	rain_val_lbl.text = str(player_stats.get("rainy_days_survived", 0))


# --- credits ----------------------------------------------------------------

func _build_credits_screen() -> void:
	credits_screen = Control.new()
	credits_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	credits_screen.visible = false
	add_child(credits_screen)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.05, 0.04, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_screen.add_child(backdrop)

	credits_scroll_container = VBoxContainer.new()
	credits_scroll_container.add_theme_constant_override("separation", 12)
	credits_screen.add_child(credits_scroll_container)

	var credits_data = [
		{
			"role": "Documentation Lead A: Business Case, Feasibility Study, Functional/Technical Specs, Project Plan",
			"names": ["Ayesha Aziz Muhammad", "Ruan Zandberg"]
		},
		{
			"role": "Documentation Lead B: UAT scripts, User/Technical Manuals, Spin Video, Poster",
			"names": ["Ayesha Aziz Muhammad", "Vutivi Khosa"]
		},
		{
			"role": "Core Gameplay Programmer: farm cycle, crop growth, weather/pest systems",
			"names": ["Raken Belayet", "Gordon Matthew", "Marne Vermaak"]
		},
		{
			"role": "Multiplayer/Networking Programmer: shared-farm sync, save/load, reconnect handling (Database Design)",
			"names": ["Raken Belayet", "Francois Coetzee"]
		},
		{
			"role": "UI/UX Programmer: menus, HUD, touch controls, usability testing (Database Design)",
			"names": ["Ruan Zandberg", "Donovan Botha", "Vutivi Khosa"]
		},
		{
			"role": "2D/2.5D Artist: low-poly assets, environment, style guide",
			"names": ["Gordon Matthew", "Marne Vermaak"]
		},
		{
			"role": "QA & Educational Content: crop knowledge content, test plan, bug tracking (Database Sign)",
			"names": ["Donovan Botha", "Francois Coetzee", "Vutivi Khosa"]
		}
	]

	var title = Label.new()
	title.text = "FARMSIM CREDITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color("#ffe082"))
	credits_scroll_container.add_child(title)

	for section in credits_data:
		var sec_box = VBoxContainer.new()
		sec_box.add_theme_constant_override("separation", 2)

		var role_lbl = Label.new()
		role_lbl.text = section["role"]
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role_lbl.custom_minimum_size = Vector2(560, 0)
		role_lbl.add_theme_font_size_override("font_size", FONT_BODY)
		role_lbl.add_theme_color_override("font_color", Color("#a5d6a7"))
		sec_box.add_child(role_lbl)

		for name_str in section["names"]:
			var name_lbl = Label.new()
			name_lbl.text = name_str
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.custom_minimum_size = Vector2(560, 0)
			name_lbl.add_theme_font_size_override("font_size", FONT_SMALL)
			name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
			sec_box.add_child(name_lbl)

		credits_scroll_container.add_child(sec_box)

	var attribution = Label.new()
	attribution.text = "Art: Sprout Lands by Cup Nooble. See ATTRIBUTION.md."
	attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attribution.custom_minimum_size = Vector2(560, 0)
	attribution.add_theme_font_size_override("font_size", FONT_SMALL)
	attribution.add_theme_color_override("font_color", Color("#cbbfa8"))
	credits_scroll_container.add_child(attribution)

	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(8, 8)
	_apply_green_button_style(back_btn)
	back_btn.custom_minimum_size = NARROW_BUTTON
	_connect_juicy_button(back_btn, _on_back_from_credits)
	credits_screen.add_child(back_btn)


# --- actions ----------------------------------------------------------------

func _on_play_croptails() -> void:
	_update_singleplayer_buttons()
	_switch_screen(main_menu_screen, singleplayer_screen)


func _on_level_select() -> void:
	_refresh_stage_buttons()
	_switch_screen(main_menu_screen, level_select_screen)


func _on_level_select_from_singleplayer() -> void:
	_refresh_stage_buttons()
	_switch_screen(singleplayer_screen, level_select_screen)


## Continue and New Farm both land on the default level; the difference is
## whether the save is loaded on top. start_level always calls load_game, so a
## new farm clears the save first.
func _on_continue_farm() -> void:
	_start_croptails(ProgressManager.furthest_unlocked_stage())


func _on_new_farm() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	ProgressManager.reset()
	_start_croptails(GameManager.default_level)


func _on_play_croptails_level(level_id: String) -> void:
	_start_croptails(level_id)


func _start_croptails(level_id: String) -> void:
	_hide_for_level()
	await GameManager.start_level(level_id)


func _on_play_draft(draft_id: String) -> void:
	_hide_for_level()
	if not GameManager.start_draft(draft_id):
		# Nothing loaded, so there is nothing to go back from - show the menu
		# again rather than leaving the player on a blank screen.
		_on_returned_to_title()


func _on_multiplayer() -> void:
	_switch_screen(main_menu_screen, multiplayer_screen)


func _on_stats() -> void:
	_load_stats_from_progress()
	_update_stats_display()
	_switch_screen(main_menu_screen, stats_screen)


func _on_settings() -> void:
	_switch_screen(main_menu_screen, settings_screen)


func _on_back_from_settings() -> void:
	_save_settings()
	_switch_screen(settings_screen, main_menu_screen)


func _on_credits() -> void:
	_switch_screen(main_menu_screen, credits_screen)
	var vp_size = get_viewport_rect().size
	credits_scroll_container.size = Vector2(vp_size.x, 0)
	credits_scroll_container.position = Vector2(0, vp_size.y)
	is_scrolling_credits = true


func _on_back_from_credits() -> void:
	is_scrolling_credits = false
	_switch_screen(credits_screen, main_menu_screen)


func _on_exit() -> void:
	get_tree().quit()
