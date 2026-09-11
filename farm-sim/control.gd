extends Control

# UI References
var splash_screen: Control
var is_splash_done: bool = false
var login_screen: Control
var main_menu_screen: CenterContainer
var singleplayer_screen: CenterContainer
var local_multiplayer_screen: CenterContainer
var stats_screen: CenterContainer
var settings_screen: CenterContainer
var credits_screen: Control
var credits_scroll_container: Control
var username_input: LineEdit
var login_card_ref: PanelContainer
var remember_checkbox: CheckBox

# Singleplayer Sub-Menu Buttons & Scene Buttons
var continue_farm_btn: Button
var load_save_btn: Button
var scene_1_btn: Button
var scene_2_btn: Button
var scene_3_btn: Button
var scene_4_btn: Button
var scene_5_btn: Button

# Local Multiplayer (LAN) References & State
var server_ip_input: LineEdit
var local_status_lbl: Label
var lobby_players_lbl: Label

# Auth State & UI Toggle References
var is_register_mode: bool = false
var auth_card_title: Label
var auth_prompt_lbl: Label
var auth_submit_btn: Button
var toggle_mode_btn: Button
var error_lbl: Label

# SFX & Music Settings References
var music_slider: HSlider
var sound_slider: HSlider

# Audio Stream Players for Atmosphere & SFX
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var hover_sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# Dynamic Stats UI Label References
var lvl_val_lbl: Label
var gold_val_lbl: Label
var harvest_val_lbl: Label
var planted_val_lbl: Label
var yield_val_lbl: Label
var pests_val_lbl: Label
var rain_val_lbl: Label

# Data Paths & Player Profile Data
const PROFILES_PATH = "user://profiles.json"
const SAVE_PATH = "user://save_game.json"
const SETTINGS_PATH = "user://settings.json"
var active_username: String = ""

# Fresh Player Stats Data Container
var player_stats: Dictionary = {
	"farmer_level": 0,
	"gold_coins": 0,
	"total_harvests": 0,
	"seeds_planted": 0,
	"successful_yields": 0,
	"pests_handled": 0,
	"rainy_days_survived": 0
}

# Credits & Animation Variables
var is_scrolling_credits: bool = false
var scroll_speed: float = 60.0
var title_banner_ref: Control
var title_banner_base_y: float = 0.0
var title_banner_base_set: bool = false
var time_passed: float = 0.0
var parallax_clouds: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# --- LOAD FARMER MARKET FONT ---
	var farmer_market_font = load("res://fonts/Farmer Market.otf") #[cite: 3]
	if farmer_market_font: #[cite: 3]
		var global_theme = Theme.new() #[cite: 3]
		global_theme.set_font("font", "Label", farmer_market_font) #[cite: 3]
		global_theme.set_font("font", "Button", farmer_market_font) #[cite: 3]
		global_theme.set_font("font", "LineEdit", farmer_market_font) #[cite: 3]
		
		# Apply globally to the entire scene tree viewport
		get_tree().root.theme = global_theme #[cite: 3]

	# --- PROCEDURAL BRIGHT FARM SKY BACKGROUND ---
	var bg = TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var gradient = Gradient.new()
	gradient.colors = [
		Color("#5ec6f2"), # Bright sky blue at the top
		Color("#bdeaff"), # Pale sky near the horizon
		Color("#8fd35c")  # Fresh grass green at the bottom
	]
	
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1) # Vertical gradient flow
	bg.texture = texture
	add_child(bg)
	
	# --- ROLLING HILL / GRASS FOREGROUND ---
	_setup_grass_foreground()
	
	# --- ATMOSPHERIC VIGNETTE ---
	_setup_vignette()
	
	# --- DRIFTING CLOUD PARALLAX ---
	_setup_parallax_clouds()
	
	# --- FEATURE 2: AMBIENT FIREFLY PARTICLES ---
	_setup_ambient_particles()
	
	# Initialize Audio Players
	_setup_audio_players()
	
	_build_splash_screen()
	_build_login_screen()
	login_screen.visible = false
	_build_main_menu_screen()
	_build_singleplayer_screen()
	_build_local_multiplayer_screen()
	_build_stats_screen()
	_build_settings_screen()
	_build_credits_screen()
	
	_load_settings()
	
	# --- VERSION LABEL (added last so it stays on top of every screen) ---
	_create_version_label()

func _process(delta: float) -> void:
	time_passed += delta
	
	# Floating / Swaying motion for title banner if active
	if title_banner_ref and title_banner_ref.is_inside_tree():
		title_banner_ref.pivot_offset = title_banner_ref.size / 2
		if not title_banner_base_set:
			title_banner_base_y = title_banner_ref.position.y
			title_banner_base_set = true
		title_banner_ref.rotation = sin(time_passed * 1.2) * 0.0015
		title_banner_ref.position.y = title_banner_base_y + cos(time_passed * 1.5) * 4.0

	# Drifting cloud parallax
	var vp_size = get_viewport_rect().size
	for cloud in parallax_clouds:
		cloud.position.x += float(cloud.get_meta("speed")) * delta
		if cloud.position.x > vp_size.x + 40:
			cloud.position.x = -cloud.size.x - randf_range(0, 200)

	# Credits Scroll Logic
	if is_scrolling_credits and credits_scroll_container:
		credits_scroll_container.position.y -= scroll_speed * delta
		if credits_scroll_container.position.y < -credits_scroll_container.size.y - 100:
			_on_back_from_credits()

# --- AUDIO SYSTEM SETUP ---
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
	else:
		print("♪ [SFX Click Triggered]")

func _play_hover_sfx() -> void:
	if hover_sfx_player.stream:
		hover_sfx_player.play()
	else:
		pass

func _update_audio_volumes() -> void:
	if music_slider and sound_slider:
		var music_db = linear_to_db(music_slider.value / 100.0)
		var sound_db = linear_to_db(sound_slider.value / 100.0)
		
		music_player.volume_db = music_db
		ambient_player.volume_db = music_db
		sfx_player.volume_db = sound_db
		hover_sfx_player.volume_db = sound_db - 5.0

# --- FEATURE 2: AMBIENT DAYLIGHT POLLEN / DUST MOTES ---
func _setup_ambient_particles() -> void:
	var particles = CPUParticles2D.new()
	
	var vp_size = get_viewport_rect().size
	particles.position = vp_size / 2
	
	particles.amount = 25
	particles.lifetime = 8.0
	particles.preprocess = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = vp_size / 2
	particles.gravity = Vector2(5, -10) # Float gently upwards and right
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	
	# Soft warm sunlight dust color
	var grad = Gradient.new()
	grad.colors = [
		Color(1, 1, 0.9, 0.0),
		Color(1, 0.98, 0.85, 0.45),
		Color(1, 1, 0.9, 0.0)
	]
	particles.color_ramp = grad
	
	add_child(particles)

# --- ATMOSPHERIC VIGNETTE ---
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
	v_texture.width = 512
	v_texture.height = 512
	vignette.texture = v_texture
	add_child(vignette)

# --- ROLLING GRASS FOREGROUND ---
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

# --- DRIFTING CLOUD PARALLAX ---
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
		c_texture.width = 240
		c_texture.height = 100
		cloud.texture = c_texture
		cloud.size = Vector2(240, 100)
		cloud.position = Vector2(randf_range(-200, vp_size.x), randf_range(20, vp_size.y * 0.3))
		cloud.set_meta("speed", randf_range(4.0, 10.0))
		cloud_layer.add_child(cloud)
		parallax_clouds.append(cloud)

# --- VERSION LABEL ---
func _create_version_label() -> void:
	var version_lbl = Label.new()
	version_lbl.text = "v0.1.0-alpha"
	version_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_lbl.add_theme_font_size_override("font_size", 11)
	version_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	version_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version_lbl.anchor_top = 1.0
	version_lbl.anchor_bottom = 1.0
	version_lbl.offset_left = 10
	version_lbl.offset_top = -22
	version_lbl.offset_bottom = -4
	add_child(version_lbl)

# --- SHAKE EFFECT ---
func _shake_node(node: Control) -> void:
	var original_x = node.position.x
	var tween = create_tween()
	tween.tween_property(node, "position:x", original_x - 10, 0.05)
	tween.tween_property(node, "position:x", original_x + 10, 0.05)
	tween.tween_property(node, "position:x", original_x - 6, 0.05)
	tween.tween_property(node, "position:x", original_x + 6, 0.05)
	tween.tween_property(node, "position:x", original_x, 0.05)

# --- FEATURE 1: SMOOTH SCREEN TRANSITIONS ---
func _switch_screen(current_screen: Control, target_screen: Control) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(current_screen, "modulate:a", 0.0, 0.15)
	
	await tween.finished
	current_screen.visible = false
	current_screen.modulate.a = 1.0
	
	target_screen.modulate.a = 0.0
	target_screen.visible = true
	
	# If switching to login screen, ensure the username box grabs focus to show the caret
	if target_screen == login_screen and username_input:
		username_input.grab_focus()
	
	var fadeIn = create_tween()
	fadeIn.tween_property(target_screen, "modulate:a", 1.0, 0.2)

# --- JUICY BUTTON PRESS & HOVER ANIMATIONS ---
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
			tween.tween_property(style, "shadow_size", 8, 0.15)
	)
	
	btn.mouse_exited.connect(func():
		var style = btn.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			var original_border = style.get_meta("original_border_color", style.border_color)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(style, "border_color", original_border, 0.15)
			tween.tween_property(style, "shadow_size", 0, 0.15)
	)

func _connect_juicy_button(btn: Button, callback: Callable) -> void:
	btn.pressed.connect(func():
		_play_click_sfx()
		callback.call()
	)
	
	_connect_hover_glow(btn)
	
	btn.button_down.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08)
	)
	
	btn.button_up.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
	)

# --- CARVED 3D STYLES ---

func _get_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#f2e0b8")
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 9
	style.border_color = Color("#8a5a2b")
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 10)
	return style

func _create_header_banner(parent: Node, text_content: String) -> void:
	var header_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#d38b3f") 
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 7
	style.border_color = Color("#7a4a1e")
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	header_panel.add_theme_stylebox_override("panel", style)

	var title_lbl = Label.new()
	title_lbl.text = text_content
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color("#fff6e0")) 
	header_panel.add_child(title_lbl)

	parent.add_child(header_panel)

func _create_big_farm_title(parent: Node, text_content: String) -> void:
	var title_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#e0983f")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 9
	style.border_color = Color("#7a4a1e")
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	title_panel.add_theme_stylebox_override("panel", style)

	var title_lbl = Label.new()
	title_lbl.text = text_content
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color("#fff2c8"))
	title_panel.add_child(title_lbl)

	title_banner_ref = title_panel
	parent.add_child(title_panel)

# --- PROFESSIONAL ROUNDED LINEEDIT STYLE ---
func _apply_rounded_lineedit_style(line_edit: LineEdit) -> void:
	line_edit.custom_minimum_size = Vector2(300, 44)
	line_edit.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	line_edit.add_theme_font_size_override("font_size", 14)
	line_edit.add_theme_color_override("font_color", Color("#4a3220"))
	line_edit.add_theme_color_override("font_placeholder_color", Color("#a88f6f"))
	line_edit.add_theme_color_override("font_uneditable_color", Color("#a88f6f"))
	line_edit.add_theme_color_override("clear_button_color", Color("#8a5a2b"))
	line_edit.add_theme_color_override("clear_button_color_pressed", Color("#5c3a15"))
	
	# Make the vertical flashing cursor dark, thick, and blinking normally
	line_edit.add_theme_color_override("caret_color", Color("#4a3220"))
	line_edit.add_theme_constant_override("caret_width", 2)
	line_edit.caret_blink = true
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#fff8e7")
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color("#c9a876")
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	
	var focus = normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("#fffdf5")
	focus.border_color = Color("#e0a941")
	focus.shadow_color = Color(0, 0, 0, 0.15)
	focus.shadow_size = 6
	
	line_edit.add_theme_stylebox_override("normal", normal)
	line_edit.add_theme_stylebox_override("focus", focus)

# --- BUTTON STYLES ---
func _apply_beige_button_style(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(300, 52)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color("#4a2f10"))
	btn.add_theme_color_override("font_hover_color", Color("#2c1d0c"))
	btn.add_theme_color_override("font_pressed_color", Color("#3d2811"))
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#f0c986")
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 8
	normal.border_color = Color("#8a5a2b")
	
	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f7d99e")
	hover.border_color = Color("#a06a32")
	
	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#dcae6a")
	pressed.border_width_bottom = 3
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
	btn.custom_minimum_size = Vector2(300, 54)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#ffffff"))
	btn.add_theme_color_override("font_hover_color", Color("#f1f8e9"))
	btn.add_theme_color_override("font_pressed_color", Color("#dff2c8"))
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#7ec52e")
	normal.corner_radius_top_left = 22
	normal.corner_radius_top_right = 22
	normal.corner_radius_bottom_left = 22
	normal.corner_radius_bottom_right = 22
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 8
	normal.border_color = Color("#4c8c15")
	
	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#8fdb3a")
	hover.border_color = Color("#5da01c")
	
	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#66a324")
	pressed.border_width_bottom = 3
	pressed.border_color = Color("#3b6e0f")
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

func _apply_square_icon_button_style(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(56, 56)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("#2c1d0c"))
	btn.add_theme_color_override("font_hover_color", Color("#1a1005"))
	btn.add_theme_color_override("font_pressed_color", Color("#3d2811"))
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#f0c986")
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 6
	normal.border_color = Color("#8a5a2b")
	
	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#f7d99e")
	hover.border_color = Color("#a06a32")
	
	var pressed = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#dcae6a")
	pressed.border_width_bottom = 2
	pressed.border_color = Color("#6b4420")
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

func _apply_slider_style(slider: HSlider) -> void:
	slider.custom_minimum_size = Vector2(200, 28)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color("#c89355")
	grabber.corner_radius_top_left = 8
	grabber.corner_radius_top_right = 8
	grabber.corner_radius_bottom_left = 8
	grabber.corner_radius_bottom_right = 8
	grabber.border_width_left = 2
	grabber.border_width_top = 2
	grabber.border_width_right = 2
	grabber.border_width_bottom = 4
	grabber.border_color = Color("#382310")
	grabber.expand_margin_top = 4
	grabber.expand_margin_bottom = 4
	grabber.expand_margin_left = 4
	grabber.expand_margin_right = 4
	
	var grabber_area = StyleBoxFlat.new()
	grabber_area.bg_color = Color("#55923b")
	grabber_area.corner_radius_top_left = 6
	grabber_area.corner_radius_bottom_left = 6
	grabber_area.border_width_top = 1
	grabber_area.border_width_bottom = 1
	grabber_area.border_color = Color("#2d501e")
	
	var bg_bar = StyleBoxFlat.new()
	bg_bar.bg_color = Color("#d8c396")
	bg_bar.corner_radius_top_left = 6
	bg_bar.corner_radius_top_right = 6
	bg_bar.corner_radius_bottom_left = 6
	bg_bar.corner_radius_bottom_right = 6
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

# --- SPLASH SCREEN ---
func _build_splash_screen() -> void:
	splash_screen = Control.new()
	splash_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash_screen)

	# Solid pitch-black background for studio branding look
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0a0a0a")
	splash_screen.add_child(bg)

	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash_screen.add_child(center_container)

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center_container.add_child(box)

	# Studio or Game Brand Name
	var studio_lbl = Label.new()
	studio_lbl.text = "STUDIO NAME"
	studio_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_lbl.add_theme_font_size_override("font_size", 16)
	studio_lbl.add_theme_color_override("font_color", Color("#7a7a7a"))
	box.add_child(studio_lbl)

	_create_big_farm_title(box, "FARMSIM")

	var tap_lbl = Label.new()
	tap_lbl.text = "Click anywhere to continue"
	tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_lbl.add_theme_font_size_override("font_size", 13)
	tap_lbl.add_theme_color_override("font_color", Color("#a88f6f"))
	box.add_child(tap_lbl)

	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(tap_lbl, "modulate:a", 0.3, 0.8)
	pulse_tween.tween_property(tap_lbl, "modulate:a", 1.0, 0.8)

	splash_screen.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed:
			_finish_splash()
		elif event is InputEventMouseButton and event.pressed:
			_finish_splash()
	)

	var timer = get_tree().create_timer(6.0)
	timer.timeout.connect(_finish_splash)

func _finish_splash() -> void:
	if is_splash_done:
		return
	is_splash_done = true
	_switch_screen(splash_screen, login_screen)
	if username_input:
		username_input.grab_focus()

# --- LOGIN SCREEN ---
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
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	_create_big_farm_title(box, "FARMSIM")

	auth_prompt_lbl = Label.new()
	auth_prompt_lbl.text = "Enter Username:"
	auth_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auth_prompt_lbl.add_theme_color_override("font_color", Color("#5c3a15"))
	box.add_child(auth_prompt_lbl)

	username_input = LineEdit.new()
	username_input.placeholder_text = "e.g. Player1"
	_apply_rounded_lineedit_style(username_input)
	box.add_child(username_input)

	error_lbl = Label.new()
	error_lbl.text = ""
	error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_lbl.add_theme_font_size_override("font_size", 12)
	error_lbl.add_theme_color_override("font_color", Color("#c1442e"))
	box.add_child(error_lbl)

	auth_submit_btn = Button.new()
	auth_submit_btn.text = "Log In"
	_apply_green_button_style(auth_submit_btn)
	_connect_juicy_button(auth_submit_btn, _on_auth_submitted)
	box.add_child(auth_submit_btn)

	remember_checkbox = CheckBox.new()
	remember_checkbox.text = "Stay logged in"
	remember_checkbox.add_theme_color_override("font_color", Color("#5c3a15"))
	remember_checkbox.add_theme_font_size_override("font_size", 13)
	box.add_child(remember_checkbox)

	toggle_mode_btn = Button.new()
	toggle_mode_btn.text = "Need an account? Register here"
	toggle_mode_btn.flat = true
	toggle_mode_btn.add_theme_color_override("font_color", Color("#4c8c15"))
	toggle_mode_btn.add_theme_font_size_override("font_size", 13)
	_connect_juicy_button(toggle_mode_btn, _toggle_auth_mode)
	box.add_child(toggle_mode_btn)

	var bottom_right_exit_btn = Button.new()
	bottom_right_exit_btn.text = "Exit Game"
	_apply_beige_button_style(bottom_right_exit_btn)
	bottom_right_exit_btn.custom_minimum_size = Vector2(160, 48)
	bottom_right_exit_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right_exit_btn.anchor_left = 1.0
	bottom_right_exit_btn.anchor_top = 1.0
	bottom_right_exit_btn.anchor_right = 1.0
	bottom_right_exit_btn.anchor_bottom = 1.0
	bottom_right_exit_btn.offset_left = -180
	bottom_right_exit_btn.offset_top = -68
	bottom_right_exit_btn.offset_right = -20
	bottom_right_exit_btn.offset_bottom = -20
	_connect_juicy_button(bottom_right_exit_btn, _on_exit)
	login_screen.add_child(bottom_right_exit_btn)

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
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.data
	return {}

func _save_profiles(data: Dictionary) -> void:
	var file = FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

# --- MAIN MENU SCREEN ---
func _build_main_menu_screen() -> void:
	main_menu_screen = CenterContainer.new()
	main_menu_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu_screen.visible = false
	add_child(main_menu_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	main_menu_screen.add_child(card)

	var menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 14)
	card.add_child(menu_box)

	_create_header_banner(menu_box, "MAIN MENU")

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	menu_box.add_child(spacer)

	_create_menu_button(menu_box, "PLAY SINGLEPLAYER", _on_singleplayer)
	_create_menu_button(menu_box, "PLAY MULTIPLAYER", _on_multiplayer)

	var icons_hbox = HBoxContainer.new()
	icons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	icons_hbox.add_theme_constant_override("separation", 10)
	
	var spacer_bottom = Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 10)
	menu_box.add_child(spacer_bottom)
	menu_box.add_child(icons_hbox)

	_create_icon_block_button(icons_hbox, "📊", "Progress & Stats", _on_stats)
	_create_icon_block_button(icons_hbox, "⚙️", "Settings", _on_settings)
	_create_icon_block_button(icons_hbox, "📜", "Credits", _on_credits)
	_create_icon_block_button(icons_hbox, "❌", "Exit", _on_exit)

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
	_connect_juicy_button(btn, callback)
	parent.add_child(btn)

# --- SINGLEPLAYER SUB-MENU ---
func _build_singleplayer_screen() -> void:
	singleplayer_screen = CenterContainer.new()
	singleplayer_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	singleplayer_screen.visible = false
	add_child(singleplayer_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	singleplayer_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	_create_header_banner(box, "SINGLEPLAYER")

	var subtitle = Label.new()
	subtitle.text = "Select an option to begin"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("#6b4a2c"))
	box.add_child(subtitle)

	continue_farm_btn = Button.new()
	continue_farm_btn.text = "Continue Farm"
	_apply_beige_button_style(continue_farm_btn)
	_connect_juicy_button(continue_farm_btn, _on_continue_farm)
	box.add_child(continue_farm_btn)

	var new_farm_btn = Button.new()
	new_farm_btn.text = "New Farm"
	_apply_beige_button_style(new_farm_btn)
	_connect_juicy_button(new_farm_btn, _on_new_farm)
	box.add_child(new_farm_btn)

	load_save_btn = Button.new()
	load_save_btn.text = "Load Save"
	_apply_beige_button_style(load_save_btn)
	_connect_juicy_button(load_save_btn, _on_load_save)
	box.add_child(load_save_btn)

	# --- SCENE 1 TO 5 BUTTONS ---
	scene_1_btn = Button.new()
	scene_1_btn.text = "Scene 1"
	_apply_beige_button_style(scene_1_btn)
	_connect_juicy_button(scene_1_btn, _on_scene_1)
	box.add_child(scene_1_btn)

	scene_2_btn = Button.new()
	scene_2_btn.text = "Scene 2"
	_apply_beige_button_style(scene_2_btn)
	_connect_juicy_button(scene_2_btn, _on_scene_2)
	box.add_child(scene_2_btn)

	scene_3_btn = Button.new()
	scene_3_btn.text = "Scene 3"
	_apply_beige_button_style(scene_3_btn)
	_connect_juicy_button(scene_3_btn, _on_scene_3)
	box.add_child(scene_3_btn)

	scene_4_btn = Button.new()
	scene_4_btn.text = "Scene 4"
	_apply_beige_button_style(scene_4_btn)
	_connect_juicy_button(scene_4_btn, _on_scene_4)
	box.add_child(scene_4_btn)

	scene_5_btn = Button.new()
	scene_5_btn.text = "Scene 5"
	_apply_beige_button_style(scene_5_btn)
	_connect_juicy_button(scene_5_btn, _on_scene_5)
	box.add_child(scene_5_btn)

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, _on_back_from_singleplayer)
	box.add_child(back_btn)

func _update_singleplayer_buttons() -> void:
	var has_save = FileAccess.file_exists(SAVE_PATH)
	continue_farm_btn.disabled = not has_save
	load_save_btn.disabled = not has_save

# --- LOCAL MULTIPLAYER (LAN) SUB-MENU ---
func _build_local_multiplayer_screen() -> void:
	local_multiplayer_screen = CenterContainer.new()
	local_multiplayer_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	local_multiplayer_screen.visible = false
	add_child(local_multiplayer_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	local_multiplayer_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	_create_header_banner(box, "MULTIPLAYER")

	var subtitle = Label.new()
	subtitle.text = "Enter a farm code to join"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#6b4a2c"))
	box.add_child(subtitle)

	server_ip_input = LineEdit.new()
	server_ip_input.placeholder_text = "Farm Code / Host IP"
	_apply_rounded_lineedit_style(server_ip_input)
	box.add_child(server_ip_input)

	local_status_lbl = Label.new()
	local_status_lbl.text = ""
	local_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	local_status_lbl.add_theme_font_size_override("font_size", 12)
	local_status_lbl.add_theme_color_override("font_color", Color("#c1442e"))
	box.add_child(local_status_lbl)

	lobby_players_lbl = Label.new()
	lobby_players_lbl.text = "Lobby Status: Disconnected"
	lobby_players_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_players_lbl.add_theme_font_size_override("font_size", 13)
	lobby_players_lbl.add_theme_color_override("font_color", Color("#4c8c15"))
	box.add_child(lobby_players_lbl)

	var join_btn = Button.new()
	join_btn.text = "Join Farm"
	_apply_beige_button_style(join_btn)
	_connect_juicy_button(join_btn, _on_join_farm)
	box.add_child(join_btn)

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, _on_back_from_local_multiplayer)
	box.add_child(back_btn)

func _on_join_farm() -> void:
	var ip = server_ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	local_status_lbl.text = "Connecting to " + ip + "..."
	lobby_players_lbl.text = "Lobby Status: Connecting..."

func _on_back_from_local_multiplayer() -> void:
	_switch_screen(local_multiplayer_screen, main_menu_screen)

# --- SETTINGS SCREEN ---
func _build_settings_screen() -> void:
	settings_screen = CenterContainer.new()
	settings_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_screen.visible = false
	add_child(settings_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	settings_screen.add_child(card)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	_create_header_banner(box, "SETTINGS")

	var music_hbox = HBoxContainer.new()
	var music_lbl = Label.new()
	music_lbl.text = "MUSIC"
	music_lbl.custom_minimum_size = Vector2(80, 0)
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
	var sound_lbl = Label.new()
	sound_lbl.text = "SOUND"
	sound_lbl.custom_minimum_size = Vector2(80, 0)
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
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
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

# --- STATS SCREEN ---
func _build_stats_screen() -> void:
	stats_screen = CenterContainer.new()
	stats_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_screen.visible = false
	add_child(stats_screen)

	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _get_card_style())
	stats_screen.add_child(card)

	var main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 14)
	card.add_child(main_box)

	_create_header_banner(main_box, "PROGRESS & STATS")

	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	main_box.add_child(cards_hbox)

	harvest_val_lbl = _create_stat_card(cards_hbox, "Total Harvests")
	lvl_val_lbl = _create_stat_card(cards_hbox, "Farmer Level")
	gold_val_lbl = _create_stat_card(cards_hbox, "Gold Coins")

	var table_panel = PanelContainer.new()
	var table_style = StyleBoxFlat.new()
	table_style.bg_color = Color("#1c1510")
	table_style.corner_radius_top_left = 8
	table_style.corner_radius_top_right = 8
	table_style.corner_radius_bottom_left = 8
	table_style.corner_radius_bottom_right = 8
	table_style.content_margin_left = 14
	table_style.content_margin_right = 14
	table_style.content_margin_top = 10
	table_style.content_margin_bottom = 10
	table_panel.add_theme_stylebox_override("panel", table_style)
	main_box.add_child(table_panel)

	var table_vbox = VBoxContainer.new()
	table_vbox.add_theme_constant_override("separation", 6)
	table_panel.add_child(table_vbox)

	planted_val_lbl = _create_stat_row(table_vbox, "Seeds Planted")
	yield_val_lbl = _create_stat_row(table_vbox, "Successful Yields")
	pests_val_lbl = _create_stat_row(table_vbox, "Pests Handled")
	rain_val_lbl = _create_stat_row(table_vbox, "Rainy Days Survived")

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, _on_back_from_stats)
	main_box.add_child(back_btn)

func _create_stat_card(parent: Node, title_text: String) -> Label:
	var card_panel = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#1c1510")
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 12
	card_style.content_margin_right = 12
	card_style.content_margin_top = 8
	card_style.content_margin_bottom = 8
	card_panel.add_theme_stylebox_override("panel", card_style)
	card_panel.custom_minimum_size = Vector2(95, 55)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color("#d7ccc8"))
	vbox.add_child(title_lbl)

	var val_lbl = Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 17)
	val_lbl.add_theme_color_override("font_color", Color("#ffe082"))
	vbox.add_child(val_lbl)

	parent.add_child(card_panel)
	return val_lbl

func _create_stat_row(parent: Node, label_text: String) -> Label:
	var hbox = HBoxContainer.new()
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#ffffff"))
	hbox.add_child(lbl)

	var val = Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color("#a5d6a7"))
	hbox.add_child(val)

	parent.add_child(hbox)
	return val

func _update_stats_display() -> void:
	lvl_val_lbl.text = str(player_stats.get("farmer_level", 0))
	gold_val_lbl.text = str(player_stats.get("gold_coins", 0)) + "g"
	harvest_val_lbl.text = str(player_stats.get("total_harvests", 0))
	planted_val_lbl.text = str(player_stats.get("seeds_planted", 0))
	yield_val_lbl.text = str(player_stats.get("successful_yields", 0))
	pests_val_lbl.text = str(player_stats.get("pests_handled", 0))
	rain_val_lbl.text = str(player_stats.get("rainy_days_survived", 0))

# --- CREDITS SCREEN ---
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
	credits_scroll_container.add_theme_constant_override("separation", 24)
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
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#ffe082"))
	credits_scroll_container.add_child(title)

	for section in credits_data:
		var sec_box = VBoxContainer.new()
		sec_box.add_theme_constant_override("separation", 4)
		
		var role_lbl = Label.new()
		role_lbl.text = section["role"]
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_lbl.add_theme_font_size_override("font_size", 16)
		role_lbl.add_theme_color_override("font_color", Color("#a5d6a7"))
		sec_box.add_child(role_lbl)
		
		for name_str in section["names"]:
			var name_lbl = Label.new()
			name_lbl.text = name_str
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
			sec_box.add_child(name_lbl)
			
		credits_scroll_container.add_child(sec_box)

	var back_btn = Button.new()
	back_btn.text = "Back to Main Menu"
	back_btn.position = Vector2(20, 20)
	_apply_green_button_style(back_btn)
	_connect_juicy_button(back_btn, _on_back_from_credits)
	credits_screen.add_child(back_btn)

# --- ACTION LOGIC ---
func _on_singleplayer() -> void:
	_update_singleplayer_buttons()
	_switch_screen(main_menu_screen, singleplayer_screen)

func _on_back_from_singleplayer() -> void:
	_switch_screen(singleplayer_screen, main_menu_screen)

func _on_continue_farm() -> void:
	print("Continuing Farm for user: ", active_username)

func _on_new_farm() -> void:
	print("Starting New Farm for user: ", active_username)

func _on_load_save() -> void:
	print("Loading Save for user: ", active_username)

func _on_scene_1() -> void:
	print("Launching Scene 1 for user: ", active_username)

func _on_scene_2() -> void:
	print("Launching Scene 2 for user: ", active_username)

func _on_scene_3() -> void:
	print("Launching Scene 3 for user: ", active_username)

func _on_scene_4() -> void:
	print("Launching Scene 4 for user: ", active_username)

func _on_scene_5() -> void:
	print("Launching Scene 5 for user: ", active_username)

func _on_multiplayer() -> void:
	_switch_screen(main_menu_screen, local_multiplayer_screen)

func _on_stats() -> void:
	_update_stats_display()
	_switch_screen(main_menu_screen, stats_screen)

func _on_back_from_stats() -> void:
	_switch_screen(stats_screen, main_menu_screen)

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
