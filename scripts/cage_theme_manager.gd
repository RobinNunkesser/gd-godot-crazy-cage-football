class_name CageThemeManager
extends RefCounted

## Theme- & Arena-Management für Crazy Cage Football (Godot 4 3D).
## Verwaltet Arena-Stile (Boden, Wände/Käfig, Banden, Ball-Shader, Licht & Effekte).

const SETTINGS_PATH: String = "user://cage_football_settings.cfg"

static var instance = null

signal theme_changed(theme: Dictionary)

var current_theme_index: int = 0
var themes: Array[Dictionary] = []

func _init() -> void:
	instance = self
	_init_themes()
	load_saved_theme()

static func get_instance():
	if not instance:
		var script: GDScript = load("res://scripts/cage_theme_manager.gd")
		instance = script.new()
	return instance

func _init_themes() -> void:
	themes = [
		{
			"id": "industrial",
			"name_key": "THEME_INDUSTRIAL",
			"default_name": "Industrie-Käfig (Nacht)",
			"sky_type": "panorama",
			"skybox_path": "res://assets/textures/cage_skybox.jpg",
			"sun_color": Color(1.0, 0.98, 0.95),
			"sun_energy": 1.25,
			"sun_rotation": Vector3(-55, 40, 0),
			"sun_shadow_opacity": 0.28,
			"sun_shadow_blur": 3.5,
			"floodlight_color": Color(0.92, 0.95, 1.0),
			"floodlight_energy": 0.95,
			"ambient_color": Color(0.32, 0.34, 0.40),
			"ambient_energy": 0.75,
			"glow_bloom": 0.15,
			"glow_intensity": 0.4,
			"floor_texture": "res://assets/textures/pitch_turf.png",
			"floor_color": Color(1.0, 1.0, 1.0),
			"floor_roughness": 0.75,
			"floor_metallic": 0.05,
			"floor_uv_scale": Vector3(6.0, 4.0, 1.0),
			"board_color": Color(0.18, 0.20, 0.24),
			"board_roughness": 0.3,
			"board_metallic": 0.6,
			"fence_texture": "res://assets/textures/chainlink_fence.png",
			"fence_color": Color(0.75, 0.8, 0.85, 0.75),
			"fence_roughness": 0.25,
			"fence_metallic": 0.85,
			"goal_post_color": Color(0.95, 0.95, 0.95),
			"ball_pent_color": Color(0.12, 0.12, 0.14),
			"ball_hex_color": Color(0.96, 0.96, 0.97),
			"ball_seam_color": Color(0.06, 0.06, 0.08),
			"ball_emission_color": Color.BLACK,
			"ball_emission_energy": 0.0,
			"turf_puff_color": Color(0.2, 0.75, 0.25)
		},
		{
			"id": "sunny_rooftop",
			"name_key": "THEME_SUNNY",
			"default_name": "Sonnendach (Sommer)",
			"sky_type": "panorama",
			"skybox_path": "res://assets/textures/rooftop_skybox.jpg",
			"sun_color": Color(1.0, 0.98, 0.92),
			"sun_energy": 1.75,
			"sun_rotation": Vector3(-45, 30, 0),
			"sun_shadow_opacity": 0.24,
			"sun_shadow_blur": 3.8,
			"floodlight_color": Color(1.0, 0.97, 0.92),
			"floodlight_energy": 0.75,
			"ambient_color": Color(0.65, 0.75, 0.90),
			"ambient_energy": 1.15,
			"glow_bloom": 0.08,
			"glow_intensity": 0.2,
			"floor_texture": "res://assets/textures/rooftop_court_floor.png",
			"floor_color": Color(1.0, 1.0, 1.0),
			"floor_roughness": 0.82,
			"floor_metallic": 0.02,
			"floor_uv_scale": Vector3(1.0, 1.0, 1.0),
			"board_color": Color(0.95, 0.95, 0.98), # Saubere weiße Sportbanden
			"board_roughness": 0.35,
			"board_metallic": 0.1,
			"fence_texture": "res://assets/textures/chainlink_fence.png",
			"fence_color": Color(1.0, 1.0, 1.0, 0.88), # Weiß lackierter Sportkäfig
			"fence_roughness": 0.3,
			"fence_metallic": 0.35,
			"goal_post_color": Color(1.0, 0.88, 0.15), # Strahlend sonnengelbe Pfosten
			"goal_emission_enabled": false,
			"player_glow_enabled": false,
			"ball_pent_color": Color(0.96, 0.22, 0.42), # Sommer-Pink
			"ball_hex_color": Color(1.0, 0.86, 0.12), # Sommer-Neongelb
			"ball_seam_color": Color(0.2, 0.1, 0.12),
			"ball_emission_color": Color.BLACK,
			"ball_emission_energy": 0.0,
			"turf_puff_color": Color(0.92, 0.65, 0.45) # Tartan-/Ziegelstaub
		},
		{
			"id": "cyber_neon",
			"name_key": "THEME_CYBER",
			"default_name": "Cyber Neon (Synthwave)",
			"sky_type": "panorama",
			"skybox_path": "res://assets/textures/cyber_skybox.jpg",
			"sun_color": Color(0.85, 0.55, 1.0), # Strahlendes UV / Synthwave-Licht
			"sun_energy": 1.9,
			"sun_rotation": Vector3(-60, 45, 0),
			"sun_shadow_opacity": 0.18,
			"sun_shadow_blur": 4.0,
			"floodlight_color": Color(0.0, 0.95, 1.0), # Leuchtendes Synthwave-Cyan
			"floodlight_energy": 1.25,
			"ambient_color": Color(0.45, 0.32, 0.68),
			"ambient_energy": 1.45,
			"glow_bloom": 0.40,
			"glow_intensity": 0.90,
			"floor_texture": "res://assets/textures/cyber_grid_floor.png",
			"floor_color": Color(1.0, 1.0, 1.0),
			"floor_roughness": 0.28,
			"floor_metallic": 0.65,
			"floor_uv_scale": Vector3(1.0, 1.0, 1.0),
			"board_color": Color(0.08, 0.12, 0.22), # Dunkle Cyber-Bande
			"board_roughness": 0.2,
			"board_metallic": 0.8,
			"fence_texture": "res://assets/textures/chainlink_fence.png",
			"fence_color": Color(0.0, 0.9, 1.0, 0.9), # Leuchtendes Cyan-Kraftfeld
			"fence_roughness": 0.1,
			"fence_metallic": 0.95,
			"goal_post_color": Color(1.0, 0.15, 0.65), # Leuchtendes Magenta-Pink
			"goal_emission_enabled": true,
			"player_glow_enabled": true,
			"ball_pent_color": Color(0.04, 0.06, 0.14),
			"ball_hex_color": Color(0.08, 0.15, 0.25),
			"ball_seam_color": Color(0.0, 1.0, 0.9), # Glühende Cyan-Nähte
			"ball_emission_color": Color(0.0, 0.95, 1.0),
			"ball_emission_energy": 2.5, # Stark leuchtender Ball
			"turf_puff_color": Color(0.0, 0.95, 1.0) # Cyan-Plasmafunken
		}
	]

func get_themes() -> Array[Dictionary]:
	return themes

func get_theme_count() -> int:
	return themes.size()

func get_current_theme() -> Dictionary:
	if themes.is_empty():
		return {}
	current_theme_index = clampi(current_theme_index, 0, themes.size() - 1)
	return themes[current_theme_index]

func cycle_theme() -> Dictionary:
	if themes.is_empty():
		return {}
	current_theme_index = (current_theme_index + 1) % themes.size()
	var t = themes[current_theme_index]
	save_theme()
	theme_changed.emit(t)
	return t

func set_theme_by_id(theme_id: String) -> bool:
	for i in range(themes.size()):
		if str(themes[i]["id"]) == theme_id:
			current_theme_index = i
			var t = themes[i]
			save_theme()
			theme_changed.emit(t)
			return true
	return false

func get_theme_display_name(theme_dict: Dictionary) -> String:
	var key = str(theme_dict.get("name_key", ""))
	if not key.is_empty():
		var tr_text = TranslationServer.translate(StringName(key))
		if not tr_text.is_empty() and tr_text != key:
			return tr_text
	return str(theme_dict.get("default_name", "Theme"))

func save_theme() -> void:
	var cfg = ConfigFile.new()
	var _err = cfg.load(SETTINGS_PATH)
	var cur_theme = get_current_theme()
	cfg.set_value("graphics", "theme_id", cur_theme.get("id", "industrial"))
	cfg.save(SETTINGS_PATH)

func load_saved_theme() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	if err == OK:
		var saved_id = str(cfg.get_value("graphics", "theme_id", "industrial"))
		for i in range(themes.size()):
			if str(themes[i]["id"]) == saved_id:
				current_theme_index = i
				return
	current_theme_index = 0
