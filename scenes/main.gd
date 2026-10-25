class_name MainCageFootball
extends Node3D

const CageConfig = preload("res://scripts/config.gd")
const CageStateManager = preload("res://scripts/state_manager.gd")
const CagePlayer = preload("res://scripts/player.gd")
const SoccerBall = preload("res://scripts/ball.gd")
const CageCamera = preload("res://scripts/cage_camera.gd")
const CageSoundManager = preload("res://scripts/cage_sound_manager.gd")
const CageJuiceManager = preload("res://scripts/cage_juice_manager.gd")
const CagePowerUp = preload("res://scripts/power_up.gd")
const CageThemeManager = preload("res://scripts/cage_theme_manager.gd")
const CageMatchStats = preload("res://scripts/match_stats.gd")

var theme_manager: CageThemeManager
var match_stats: CageMatchStats
var is_game_paused: bool = false
var world_env: WorldEnvironment
var stadium_light: DirectionalLight3D
var floor_inst: MeshInstance3D
var board_instances: Array[MeshInstance3D] = []
var fence_instances: Array[MeshInstance3D] = []
var goal_post_instances: Array[MeshInstance3D] = []
var goal_glow_lights: Array[OmniLight3D] = []
var corner_floodlights: Array[OmniLight3D] = []
var corner_floodlight_fixtures: Array[MeshInstance3D] = []

var state_manager: CageStateManager
var player1: CagePlayer
var player2: CagePlayer
var player3: CagePlayer
var player4: CagePlayer
var players: Array[CagePlayer] = []
var ball: SoccerBall
var camera: CageCamera
var whistle_player: AudioStreamPlayer
var sound_manager: CageSoundManager
var juice_manager: CageJuiceManager

var active_power_ups: Array[CagePowerUp] = []
var _power_up_spawn_timer: float = 0.0
var ui_theme_toggle_label: Label
var ui_powerup_toggle_label: Label

const BOARD_SPAWN_POINTS: Array[Vector3] = [
	Vector3(-7.5, 0.55, -5.8),
	Vector3(0.0, 0.55, -5.8),
	Vector3(7.5, 0.55, -5.8),
	Vector3(-7.5, 0.55, 5.8),
	Vector3(0.0, 0.55, 5.8),
	Vector3(7.5, 0.55, 5.8)
]

var ui_lobby_panel: Control
var ui_slot_labels: Array[Label] = []
var ui_team_labels: Array[Label] = []
var ui_score_label: Label
var ui_timer_label: Label
var ui_banner_label: Label
var ui_hud_container: Control
var ui_powerup_banner: Panel
var ui_powerup_title: Label
var ui_powerup_desc: Label
var ui_title_label: Label
var ui_subtitle_label: Label
var ui_hint_label: Label
var ui_card_slot_titles: Array[Label] = []
var ui_key_hint_labels: Array[Label] = []

# Pause & Options Menu
var ui_pause_container: Control
var ui_pause_title_lbl: Label
var ui_pause_options_title_lbl: Label
var ui_master_lbl: Label
var ui_bgm_lbl: Label
var ui_sfx_lbl: Label
var ui_master_slider: HSlider
var ui_bgm_slider: HSlider
var ui_sfx_slider: HSlider
var ui_pause_resume_btn: Button
var ui_pause_restart_btn: Button
var ui_pause_theme_btn: Button
var ui_pause_lang_btn: Button
var ui_pause_fs_btn: Button
var ui_pause_lobby_btn: Button
var ui_pause_ctrl_title_lbl: Label
var ui_pause_ctrl_p1_lbl: Label
var ui_pause_ctrl_p2_lbl: Label
var ui_pause_ctrl_gp_lbl: Label

# Match End Stats Menu
var ui_stats_container: Control
var ui_stats_title_lbl: Label
var ui_stats_winner_lbl: Label
var ui_stats_score_lbl: Label
var ui_stats_rematch_btn: Button
var ui_stats_lobby_btn: Button
var ui_stats_row_labels: Dictionary = {}

const SLOT_CONTROL_OPTIONS = [
	CagePlayer.ControlType.HUMAN_KB1,
	CagePlayer.ControlType.HUMAN_KB2,
	CagePlayer.ControlType.GAMEPAD_0,
	CagePlayer.ControlType.GAMEPAD_1,
	CagePlayer.ControlType.GAMEPAD_2,
	CagePlayer.ControlType.GAMEPAD_3,
	CagePlayer.ControlType.AI_BOT,
	CagePlayer.ControlType.OFF
]

func _ready() -> void:
	match_stats = CageMatchStats.new()
	_init_translations()
	state_manager = CageStateManager.new()
	state_manager.state_changed.connect(_on_state_changed)
	state_manager.score_updated.connect(_on_score_updated)
	state_manager.timer_updated.connect(_on_timer_updated)
	
	_build_audio()
	_build_scene()
	_build_ui()
	
	state_manager.enter_lobby()
	if sound_manager:
		sound_manager.play_menu_bgm()

func _init_translations() -> void:
	for lang in ["de", "en"]:
		var path = "res://i18n/translations.%s.translation" % lang
		if ResourceLoader.exists(path):
			var t = load(path)
			if t is Translation:
				TranslationServer.add_translation(t)

func _build_audio() -> void:
	sound_manager = CageSoundManager.new()
	sound_manager.name = "CageSoundManager"
	add_child(sound_manager)
	
	whistle_player = AudioStreamPlayer.new()
	whistle_player.name = "WhistleAudio"
	if ResourceLoader.exists("res://audio/duduk.wav"):
		whistle_player.stream = load("res://audio/duduk.wav")
	add_child(whistle_player)

func _build_scene() -> void:
	# 1. Umwelt, Skybox & Flutlicht
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var skybox_path = "res://assets/textures/cage_skybox.jpg"
	if ResourceLoader.exists(skybox_path):
		var pano = PanoramaSkyMaterial.new()
		pano.panorama = load(skybox_path)
		sky.sky_material = pano
	else:
		var proc_sky = ProceduralSkyMaterial.new()
		sky.sky_material = proc_sky
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.15
	
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	
	stadium_light = DirectionalLight3D.new()
	stadium_light.name = "StadiumLight"
	stadium_light.position = Vector3(15, 25, 15)
	stadium_light.rotation_degrees = Vector3(-55, 40, 0)
	stadium_light.light_energy = 1.25
	stadium_light.shadow_enabled = true
	stadium_light.shadow_opacity = 0.28
	stadium_light.shadow_blur = 3.5
	stadium_light.directional_shadow_max_distance = 45.0
	stadium_light.shadow_bias = 0.08
	stadium_light.shadow_normal_bias = 2.0
	add_child(stadium_light)
	
	# 4 Eck-Flutlichter an den Käfig-Pfosten (Multi-Winkel-Ausleuchtung gegen Schlagschatten)
	_build_corner_floodlights()
	
	# 2. Boden (Authentischer Street-Soccer Cage-Kunstrasen)
	var floor_body = StaticBody3D.new()
	floor_body.name = "CageFloor"
	floor_body.position = Vector3(0, -0.2, 0)
	
	var floor_phys = PhysicsMaterial.new()
	floor_phys.friction = 0.5
	floor_phys.bounce = 0.6
	floor_body.physics_material_override = floor_phys
	
	var floor_col = CollisionShape3D.new()
	var floor_box = BoxMesh.new()
	floor_box.size = Vector3(CageConfig.CAGE_WIDTH_X + CageConfig.GOAL_DEPTH * 2.0 + 4.0, 0.4, CageConfig.CAGE_DEPTH_Z + 4.0)
	floor_col.shape = BoxShape3D.new()
	floor_col.shape.size = floor_box.size
	floor_body.add_child(floor_col)
	
	floor_inst = MeshInstance3D.new()
	floor_inst.mesh = floor_box
	var floor_mat = StandardMaterial3D.new()
	var turf_path = "res://assets/textures/pitch_turf.png"
	if ResourceLoader.exists(turf_path):
		floor_mat.albedo_texture = load(turf_path)
		floor_mat.uv1_scale = Vector3(6.0, 4.0, 1.0)
		floor_mat.roughness = 0.75
		floor_mat.metallic = 0.05
	else:
		floor_mat.albedo_color = Color(0.28, 0.32, 0.36)
		floor_mat.metallic = 0.6
		floor_mat.roughness = 0.4
	floor_inst.material_override = floor_mat
	floor_body.add_child(floor_inst)
	add_child(floor_body)
	
	# 3. Käfig-Wände & Decke
	_build_wall(Vector3(0, CageConfig.CAGE_HEIGHT_Y * 0.5, -CageConfig.CAGE_DEPTH_Z * 0.5), Vector3(CageConfig.CAGE_WIDTH_X, CageConfig.CAGE_HEIGHT_Y, CageConfig.WALL_THICKNESS), "BackWall")
	_build_wall(Vector3(0, CageConfig.CAGE_HEIGHT_Y * 0.5, CageConfig.CAGE_DEPTH_Z * 0.5), Vector3(CageConfig.CAGE_WIDTH_X, CageConfig.CAGE_HEIGHT_Y, CageConfig.WALL_THICKNESS), "FrontWall")
	_build_wall(Vector3(0, CageConfig.CAGE_HEIGHT_Y, 0), Vector3(CageConfig.CAGE_WIDTH_X, CageConfig.WALL_THICKNESS, CageConfig.CAGE_DEPTH_Z), "Ceiling")
	
	_build_side_wall(-1, "LeftWall")
	_build_side_wall(1, "RightWall")
	
	# 45-Grad abgewinkelte Eck-Banden (verhindern Verklemmen in 90-Grad Ecken)
	_build_corner_bumpers()
	
	# 4. Tore mit Area3D
	_build_goal(-1, 2) # Tor links (Team 2 verteidigt, Team 1 punktet)
	_build_goal(1, 1)  # Tor rechts (Team 1 verteidigt, Team 2 punktet)
	
	# 5. Fußball
	ball = SoccerBall.new()
	ball.name = "SoccerBall"
	ball.position = Vector3(0.0, CageConfig.BALL_RADIUS + 0.1, 0.0)
	ball.post_hit.connect(_on_ball_post_hit)
	add_child(ball)
	
	# 6. Spieler 1 bis 4 (2v2 Team Setup)
	var p_configs = [
		{"id": 1, "team": 1, "name": "Player1_Red", "color": Color(0.95, 0.2, 0.2), "pos": Vector3(-6.0, CageConfig.PLAYER_RADIUS, -2.2), "ctrl": CagePlayer.ControlType.HUMAN_KB1},
		{"id": 2, "team": 2, "name": "Player2_Blue", "color": Color(0.2, 0.55, 0.95), "pos": Vector3(6.0, CageConfig.PLAYER_RADIUS, 2.2), "ctrl": CagePlayer.ControlType.AI_BOT},
		{"id": 3, "team": 1, "name": "Player3_Red", "color": Color(1.0, 0.5, 0.15), "pos": Vector3(-6.0, CageConfig.PLAYER_RADIUS, 2.2), "ctrl": CagePlayer.ControlType.OFF},
		{"id": 4, "team": 2, "name": "Player4_Blue", "color": Color(0.2, 0.85, 0.95), "pos": Vector3(6.0, CageConfig.PLAYER_RADIUS, -2.2), "ctrl": CagePlayer.ControlType.OFF}
	]
	
	players.clear()
	for cfg in p_configs:
		var p = CagePlayer.new()
		p.name = cfg["name"]
		p.player_id = cfg["id"]
		p.team_id = cfg["team"]
		p.ball_color = cfg["color"]
		p.position = cfg["pos"]
		p.target_ball = ball
		p.set_control_type(cfg["ctrl"])
		p.jumped.connect(_on_player_jumped)
		p.tackled.connect(_on_player_tackled)
		p.ball_hit.connect(_on_player_ball_hit)
		add_child(p)
		players.append(p)
	
	player1 = players[0]
	player2 = players[1]
	player3 = players[2]
	player4 = players[3]
	
	# 7. Cage Camera
	camera = CageCamera.new()
	camera.name = "CageCamera"
	camera.position = Vector3(0, CageConfig.CAMERA_HEIGHT, CageConfig.CAMERA_OFFSET_Z)
	camera.ball_node = ball
	camera.player1_node = player1
	camera.player2_node = player2
	camera.tracked_players.assign(players)
	camera.current = true
	add_child(camera)
	
	# 8. Cage Juice Manager (Partikel, Flash & Shake)
	juice_manager = CageJuiceManager.new()
	juice_manager.name = "CageJuiceManager"
	juice_manager.camera = camera
	add_child(juice_manager)
	
	# 9. Theme Manager & Initiale Theme-Anwendung
	theme_manager = CageThemeManager.get_instance()
	apply_theme(theme_manager.get_current_theme(), false)

func _build_wall(pos: Vector3, size: Vector3, wall_name: String, custom_color: Color = Color(0.75, 0.8, 0.85, 0.75)) -> void:
	var body = StaticBody3D.new()
	body.name = wall_name
	body.position = pos
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	# Kollisionsbox nach außen hin auf 2.2m verstärken gegen Tunneling bei Super-Shots
	var col_size = size
	var col_offset = Vector3.ZERO
	if size.z < 1.0:
		col_size.z = 2.2
		col_offset.z = signf(pos.z) * (col_size.z - size.z) * 0.5
	if size.x < 1.0:
		col_size.x = 2.2
		col_offset.x = signf(pos.x) * (col_size.x - size.x) * 0.5
	if size.y < 1.0:
		col_size.y = 2.2
		col_offset.y = (col_size.y - size.y) * 0.5 # Decke nach oben verstärken
	shape.size = col_size
	col.shape = shape
	col.position = col_offset
	body.add_child(col)
	
	var is_ground_wall = (pos.y - size.y * 0.5 < 0.05) and (size.y > 1.0)
	var board_height = 0.35 if is_ground_wall else 0.0
	
	# 1. Solide Prallwand / Kickboard (Bande) - reicht 30cm in den Boden um Z-Fighting an der Kante vollständig zu unterbinden
	if is_ground_wall:
		var extra_depth = 0.3
		var board_inst = MeshInstance3D.new()
		var board_box = BoxMesh.new()
		board_box.size = Vector3(size.x, board_height + extra_depth, size.z + 0.04)
		board_inst.mesh = board_box
		board_inst.position = Vector3(0, -size.y * 0.5 + (board_height - extra_depth) * 0.5, 0)
		
		var board_mat = StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.18, 0.20, 0.24) # Solide dunkle Industrie-Bande
		board_mat.metallic = 0.6
		board_mat.roughness = 0.3
		board_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		board_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		board_inst.material_override = board_mat
		board_instances.append(board_inst)
		body.add_child(board_inst)
	
	# 2. Drahtgitter-Käfigwand oberhalb der Bande (Einzelfläche / QuadMesh statt 40cm dicker Hohlkasten!)
	var fence_height = size.y - board_height
	var fence_inst = MeshInstance3D.new()
	var qm = QuadMesh.new()
	var max_span = maxf(size.x, size.z)
	var uv_scale = Vector3(max_span * 0.45, fence_height * 0.45, 1.0)
	
	if size.y <= CageConfig.WALL_THICKNESS + 0.05:
		# Horizontale Deckenfläche (Ceiling / Tordach)
		qm.size = Vector2(size.x, size.z)
		fence_inst.mesh = qm
		fence_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		fence_inst.position = Vector3(0.0, 0.0, 0.0)
		uv_scale = Vector3(size.x * 0.45, size.z * 0.45, 1.0)
	elif size.x <= CageConfig.WALL_THICKNESS + 0.05:
		# Seitenwand entlang Z (LeftWall, RightWall, Flügelwände)
		qm.size = Vector2(size.z, fence_height)
		fence_inst.mesh = qm
		fence_inst.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		fence_inst.position = Vector3(0.0, -size.y * 0.5 + board_height + fence_height * 0.5, 0.0)
		uv_scale = Vector3(size.z * 0.45, fence_height * 0.45, 1.0)
	else:
		# Vorder-/Rückwand entlang X (BackWall, FrontWall, Seitennetze des Tors)
		qm.size = Vector2(size.x, fence_height)
		fence_inst.mesh = qm
		fence_inst.rotation_degrees = Vector3.ZERO
		fence_inst.position = Vector3(0.0, -size.y * 0.5 + board_height + fence_height * 0.5, 0.0)
		uv_scale = Vector3(size.x * 0.45, fence_height * 0.45, 1.0)
		
	fence_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mat = StandardMaterial3D.new()
	var fence_path = "res://assets/textures/chainlink_fence.png"
	if ResourceLoader.exists(fence_path):
		mat.albedo_texture = load(fence_path)
		mat.uv1_scale = uv_scale
		mat.albedo_color = custom_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.metallic = 0.85
		mat.roughness = 0.25
	else:
		mat.albedo_color = custom_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.25
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.roughness = 0.3
	fence_inst.material_override = mat
	fence_instances.append(fence_inst)
	body.add_child(fence_inst)
	add_child(body)

func _build_side_wall(side: int, wall_name: String) -> void:
	var x_pos = side * CageConfig.CAGE_WIDTH_X * 0.5
	var top_h = CageConfig.CAGE_HEIGHT_Y - CageConfig.GOAL_HEIGHT
	_build_wall(Vector3(x_pos, CageConfig.GOAL_HEIGHT + top_h * 0.5, 0), Vector3(CageConfig.WALL_THICKNESS, top_h, CageConfig.CAGE_DEPTH_Z), wall_name + "_Top")
	
	var wing_z = (CageConfig.CAGE_DEPTH_Z - CageConfig.GOAL_WIDTH) * 0.5
	var z_offset = (CageConfig.GOAL_WIDTH + wing_z) * 0.5
	_build_wall(Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, -z_offset), Vector3(CageConfig.WALL_THICKNESS, CageConfig.GOAL_HEIGHT, wing_z), wall_name + "_WingNorth")
	_build_wall(Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, z_offset), Vector3(CageConfig.WALL_THICKNESS, CageConfig.GOAL_HEIGHT, wing_z), wall_name + "_WingSouth")

func _build_goal(side: int, scoring_team: int) -> void:
	var goal_center_x = side * (CageConfig.CAGE_WIDTH_X * 0.5 + CageConfig.GOAL_DEPTH * 0.5)
	var goal_back_x = side * (CageConfig.CAGE_WIDTH_X * 0.5 + CageConfig.GOAL_DEPTH + CageConfig.WALL_THICKNESS * 0.5)
	var prefix = "LeftGoal" if side < 0 else "RightGoal"
	var net_color = Color(0.2, 0.45, 0.85, 0.5) if side < 0 else Color(0.85, 0.25, 0.2, 0.5)
	
	# 1. Solide Rückwand des Tors (StaticBody3D verhindert Herausfallen!)
	_build_wall(Vector3(goal_back_x, CageConfig.GOAL_HEIGHT * 0.5, 0), Vector3(CageConfig.WALL_THICKNESS, CageConfig.GOAL_HEIGHT, CageConfig.GOAL_WIDTH + CageConfig.WALL_THICKNESS * 2.0), prefix + "_BackNet", net_color)
	
	# 2. Solide Seitenwände des Tors (Nord & Süd)
	var z_offset = (CageConfig.GOAL_WIDTH + CageConfig.WALL_THICKNESS) * 0.5
	_build_wall(Vector3(goal_center_x, CageConfig.GOAL_HEIGHT * 0.5, -z_offset), Vector3(CageConfig.GOAL_DEPTH, CageConfig.GOAL_HEIGHT, CageConfig.WALL_THICKNESS), prefix + "_SideNetNorth", net_color)
	_build_wall(Vector3(goal_center_x, CageConfig.GOAL_HEIGHT * 0.5, z_offset), Vector3(CageConfig.GOAL_DEPTH, CageConfig.GOAL_HEIGHT, CageConfig.WALL_THICKNESS), prefix + "_SideNetSouth", net_color)
	
	# 3. Solides Tordach
	_build_wall(Vector3(goal_center_x, CageConfig.GOAL_HEIGHT + CageConfig.WALL_THICKNESS * 0.5, 0), Vector3(CageConfig.GOAL_DEPTH, CageConfig.WALL_THICKNESS, CageConfig.GOAL_WIDTH + CageConfig.WALL_THICKNESS * 2.0), prefix + "_RoofNet", net_color)
	
	# 4. Optische Torpfosten & Querlatte
	_build_goal_posts(side)
	
	# 5. Torbereich Trigger Area
	var area = Area3D.new()
	area.name = "GoalArea_Team%d" % scoring_team
	area.position = Vector3(goal_center_x, CageConfig.GOAL_HEIGHT * 0.5, 0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(CageConfig.GOAL_DEPTH * 0.9, CageConfig.GOAL_HEIGHT * 0.9, CageConfig.GOAL_WIDTH * 0.9)
	col.shape = shape
	area.add_child(col)
	
	area.body_entered.connect(func(body: Node3D):
		if body is SoccerBall and state_manager.current_state == CageStateManager.MatchState.PLAYING:
			if sound_manager:
				sound_manager.play_whistle()
				sound_manager.play_goal()
			elif whistle_player and whistle_player.stream:
				whistle_player.play()
			if juice_manager:
				juice_manager.spawn_goal_confetti(Vector3(goal_center_x, CageConfig.GOAL_HEIGHT * 0.5, 0))
				juice_manager.trigger_goal_flash(Vector3(goal_center_x, CageConfig.GOAL_HEIGHT * 0.6, 0), scoring_team)
				juice_manager.trigger_shake(0.8)
			state_manager.trigger_goal(scoring_team)
	)
	add_child(area)
	
	# 6. Tor-Beleuchtung (Neon Glow Light im Cyber-Modus)
	var glow_light = OmniLight3D.new()
	glow_light.name = "%s_GlowLight" % prefix
	glow_light.position = Vector3(goal_center_x, CageConfig.GOAL_HEIGHT * 0.75, 0)
	glow_light.light_color = Color(0.15, 0.75, 1.0) if side < 0 else Color(1.0, 0.15, 0.65)
	glow_light.light_energy = 3.5
	glow_light.omni_range = 8.0
	glow_light.visible = false
	add_child(glow_light)
	goal_glow_lights.append(glow_light)

func _build_goal_posts(side: int) -> void:
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.95, 0.95, 0.95)
	post_mat.roughness = 0.2
	post_mat.metallic = 0.8
	
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = 0.95
	phys_mat.friction = 0.1
	
	var x_pos = side * CageConfig.CAGE_WIDTH_X * 0.5
	var post_radius = 0.08
	var prefix = "LeftGoal" if side < 0 else "RightGoal"
	
	# Nord-Pfosten
	var post_n_body = StaticBody3D.new()
	post_n_body.name = "GoalPost_%s_North" % prefix
	post_n_body.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, -CageConfig.GOAL_WIDTH * 0.5)
	post_n_body.physics_material_override = phys_mat
	
	var col_n = CollisionShape3D.new()
	var cyl_shape_n = CylinderShape3D.new()
	cyl_shape_n.radius = post_radius
	cyl_shape_n.height = CageConfig.GOAL_HEIGHT
	col_n.shape = cyl_shape_n
	post_n_body.add_child(col_n)
	
	var post_n_mesh = MeshInstance3D.new()
	var cyl_n = CylinderMesh.new()
	cyl_n.top_radius = post_radius
	cyl_n.bottom_radius = post_radius
	cyl_n.height = CageConfig.GOAL_HEIGHT
	post_n_mesh.mesh = cyl_n
	post_n_mesh.material_override = post_mat
	goal_post_instances.append(post_n_mesh)
	post_n_body.add_child(post_n_mesh)
	add_child(post_n_body)
	
	# Süd-Pfosten
	var post_s_body = StaticBody3D.new()
	post_s_body.name = "GoalPost_%s_South" % prefix
	post_s_body.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, CageConfig.GOAL_WIDTH * 0.5)
	post_s_body.physics_material_override = phys_mat
	
	var col_s = CollisionShape3D.new()
	var cyl_shape_s = CylinderShape3D.new()
	cyl_shape_s.radius = post_radius
	cyl_shape_s.height = CageConfig.GOAL_HEIGHT
	col_s.shape = cyl_shape_s
	post_s_body.add_child(col_s)
	
	var post_s_mesh = MeshInstance3D.new()
	var cyl_s = CylinderMesh.new()
	cyl_s.top_radius = post_radius
	cyl_s.bottom_radius = post_radius
	cyl_s.height = CageConfig.GOAL_HEIGHT
	post_s_mesh.mesh = cyl_s
	post_s_mesh.material_override = post_mat
	goal_post_instances.append(post_s_mesh)
	post_s_body.add_child(post_s_mesh)
	add_child(post_s_body)
	
	# Querlatte
	var bar_body = StaticBody3D.new()
	bar_body.name = "GoalCrossbar_%s" % prefix
	bar_body.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT, 0)
	bar_body.rotation_degrees = Vector3(90, 0, 0)
	bar_body.physics_material_override = phys_mat
	
	var col_bar = CollisionShape3D.new()
	var cyl_shape_bar = CylinderShape3D.new()
	cyl_shape_bar.radius = post_radius
	cyl_shape_bar.height = CageConfig.GOAL_WIDTH
	col_bar.shape = cyl_shape_bar
	bar_body.add_child(col_bar)
	
	var crossbar_mesh = MeshInstance3D.new()
	var cyl_bar = CylinderMesh.new()
	cyl_bar.top_radius = post_radius
	cyl_bar.bottom_radius = post_radius
	cyl_bar.height = CageConfig.GOAL_WIDTH
	crossbar_mesh.mesh = cyl_bar
	crossbar_mesh.material_override = post_mat
	goal_post_instances.append(crossbar_mesh)
	bar_body.add_child(crossbar_mesh)
	add_child(bar_body)

func _build_corner_bumpers() -> void:
	var chamfer_len = 2.6
	var box_size = Vector3(chamfer_len, CageConfig.CAGE_HEIGHT_Y, CageConfig.WALL_THICKNESS * 1.5)
	var bumper_color = Color(0.85, 0.72, 0.15) # Solide Industrie-Warnbande
	
	var corner_configs = [
		{"name": "CornerBumper_NE", "pos": Vector3(11.1, CageConfig.CAGE_HEIGHT_Y * 0.5, -6.1), "rot": -45.0},
		{"name": "CornerBumper_SE", "pos": Vector3(11.1, CageConfig.CAGE_HEIGHT_Y * 0.5, 6.1), "rot": 45.0},
		{"name": "CornerBumper_NW", "pos": Vector3(-11.1, CageConfig.CAGE_HEIGHT_Y * 0.5, -6.1), "rot": 45.0},
		{"name": "CornerBumper_SW", "pos": Vector3(-11.1, CageConfig.CAGE_HEIGHT_Y * 0.5, 6.1), "rot": -45.0}
	]
	
	for cfg in corner_configs:
		var body = StaticBody3D.new()
		body.name = cfg["name"]
		body.position = cfg["pos"]
		body.rotation_degrees = Vector3(0, cfg["rot"], 0)
		
		var phys_mat = PhysicsMaterial.new()
		phys_mat.bounce = 0.85 # Hohe Federwirkung für dynamisches Herausprallen
		phys_mat.friction = 0.2
		body.physics_material_override = phys_mat
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = box_size
		col.shape = shape
		body.add_child(col)
		
		var extra_depth = 0.3
		var bumper_h = 0.35 + extra_depth
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(chamfer_len, bumper_h, CageConfig.WALL_THICKNESS * 1.5)
		mesh_inst.mesh = box
		mesh_inst.position = Vector3(0, -CageConfig.CAGE_HEIGHT_Y * 0.5 + (0.35 - extra_depth) * 0.5, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = bumper_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.metallic = 0.4
		mat.roughness = 0.35
		mesh_inst.material_override = mat
		board_instances.append(mesh_inst)
		body.add_child(mesh_inst)
		
		add_child(body)

func _build_corner_floodlights() -> void:
	corner_floodlights.clear()
	corner_floodlight_fixtures.clear()
	
	var corner_configs = [
		{"name": "CornerFloodlight_NE", "pos": Vector3(11.2, CageConfig.CAGE_HEIGHT_Y * 0.95, -6.2)},
		{"name": "CornerFloodlight_SE", "pos": Vector3(11.2, CageConfig.CAGE_HEIGHT_Y * 0.95, 6.2)},
		{"name": "CornerFloodlight_NW", "pos": Vector3(-11.2, CageConfig.CAGE_HEIGHT_Y * 0.95, -6.2)},
		{"name": "CornerFloodlight_SW", "pos": Vector3(-11.2, CageConfig.CAGE_HEIGHT_Y * 0.95, 6.2)}
	]
	
	for cfg in corner_configs:
		var cpos: Vector3 = cfg["pos"]
		
		# Leuchten-Gehäuse (Flutlichtstrahler-Mesh an den oberen Käfigholmen)
		var fix = MeshInstance3D.new()
		fix.name = "Fixture_" + cfg["name"]
		var box = BoxMesh.new()
		box.size = Vector3(0.65, 0.4, 0.5)
		fix.mesh = box
		add_child(fix)
		fix.look_at_from_position(cpos, Vector3(0.0, 1.0, 0.0), Vector3.UP)
		
		var fix_mat = StandardMaterial3D.new()
		fix_mat.albedo_color = Color(0.2, 0.22, 0.26)
		fix_mat.metallic = 0.8
		fix_mat.roughness = 0.25
		fix_mat.emission_enabled = true
		fix_mat.emission = Color(0.95, 0.96, 1.0)
		fix_mat.emission_energy_multiplier = 3.0
		fix.material_override = fix_mat
		corner_floodlight_fixtures.append(fix)
		
		# OmniLight3D für gleichmäßige 4-Eck-Ausleuchtung ohne Schlagschatten
		var fl = OmniLight3D.new()
		fl.name = cfg["name"]
		var inward_dir = (Vector3(0.0, 1.0, 0.0) - cpos).normalized()
		fl.position = cpos + inward_dir * 0.5
		fl.omni_range = 30.0
		fl.omni_attenuation = 1.15
		fl.light_energy = 0.95
		fl.light_color = Color(0.92, 0.95, 1.0)
		fl.shadow_enabled = false
		add_child(fl)
		corner_floodlights.append(fl)

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	
	# In-Game HUD
	ui_hud_container = Control.new()
	ui_hud_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui_hud_container)
	
	# Score Center
	ui_score_label = Label.new()
	ui_score_label.text = "RED  0 : 0  BLUE"
	ui_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_score_label.position = Vector2(440, 20)
	ui_score_label.size = Vector2(400, 50)
	ui_score_label.add_theme_font_size_override("font_size", 38)
	ui_hud_container.add_child(ui_score_label)
	
	# Timer
	ui_timer_label = Label.new()
	ui_timer_label.text = "03:00"
	ui_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_timer_label.position = Vector2(540, 75)
	ui_timer_label.size = Vector2(200, 35)
	ui_timer_label.add_theme_font_size_override("font_size", 24)
	ui_hud_container.add_child(ui_timer_label)
	
	# Banner
	ui_banner_label = Label.new()
	ui_banner_label.text = "KICK OFF!"
	ui_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_banner_label.position = Vector2(340, 290)
	ui_banner_label.size = Vector2(600, 90)
	ui_banner_label.add_theme_font_size_override("font_size", 44)
	ui_hud_container.add_child(ui_banner_label)
	
	# Power-Up Notification Banner (Stylishes Popup unterhalb des Timers)
	ui_powerup_banner = Panel.new()
	ui_powerup_banner.position = Vector2(340, 115)
	ui_powerup_banner.size = Vector2(600, 68)
	ui_powerup_banner.visible = false
	
	var pub_style = StyleBoxFlat.new()
	pub_style.bg_color = Color(0.06, 0.10, 0.16, 0.94)
	pub_style.border_width_left = 3
	pub_style.border_width_top = 3
	pub_style.border_width_right = 3
	pub_style.border_width_bottom = 3
	pub_style.border_color = Color(1.0, 0.85, 0.2)
	pub_style.corner_radius_top_left = 8
	pub_style.corner_radius_top_right = 8
	pub_style.corner_radius_bottom_left = 8
	pub_style.corner_radius_bottom_right = 8
	ui_powerup_banner.add_theme_stylebox_override("panel", pub_style)
	
	ui_powerup_title = Label.new()
	ui_powerup_title.position = Vector2(10, 6)
	ui_powerup_title.size = Vector2(580, 30)
	ui_powerup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_powerup_title.add_theme_font_size_override("font_size", 20)
	ui_powerup_banner.add_child(ui_powerup_title)
	
	ui_powerup_desc = Label.new()
	ui_powerup_desc.position = Vector2(10, 36)
	ui_powerup_desc.size = Vector2(580, 24)
	ui_powerup_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_powerup_desc.add_theme_font_size_override("font_size", 14)
	ui_powerup_desc.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
	ui_powerup_banner.add_child(ui_powerup_desc)
	
	ui_hud_container.add_child(ui_powerup_banner)
	
	ui_hint_label = Label.new()
	ui_hint_label.text = tr("UI_HINTS_BAR")
	ui_hint_label.position = Vector2(40, 670)
	ui_hint_label.add_theme_font_size_override("font_size", 16)
	ui_hint_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	ui_hud_container.add_child(ui_hint_label)
	
	# --- Pre-Match Lobby Panel ---
	ui_lobby_panel = Control.new()
	ui_lobby_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg_overlay = ColorRect.new()
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.color = Color(0.06, 0.09, 0.14, 0.90)
	ui_lobby_panel.add_child(bg_overlay)
	
	ui_title_label = Label.new()
	ui_title_label.text = tr("LOBBY_TITLE")
	ui_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_title_label.position = Vector2(240, 35)
	ui_title_label.size = Vector2(800, 55)
	ui_title_label.add_theme_font_size_override("font_size", 40)
	ui_lobby_panel.add_child(ui_title_label)
	
	ui_subtitle_label = Label.new()
	ui_subtitle_label.text = tr("LOBBY_SUBTITLE")
	ui_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_subtitle_label.position = Vector2(240, 95)
	ui_subtitle_label.size = Vector2(800, 30)
	ui_subtitle_label.add_theme_font_size_override("font_size", 20)
	ui_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	ui_lobby_panel.add_child(ui_subtitle_label)
	
	ui_slot_labels.clear()
	ui_team_labels.clear()
	ui_card_slot_titles.clear()
	ui_key_hint_labels.clear()
	var col_width = 260
	var start_x = 80
	for i in range(4):
		var card = Panel.new()
		card.position = Vector2(start_x + i * (col_width + 20), 150)
		card.size = Vector2(col_width, 380)
		ui_lobby_panel.add_child(card)
		
		var p_title = Label.new()
		var slot_fmt = tr("SLOT_TITLE")
		if not ("%d" in slot_fmt):
			slot_fmt = "SLOT %d"
		p_title.text = slot_fmt % (i + 1)
		p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_title.position = Vector2(10, 15)
		p_title.size = Vector2(col_width - 20, 30)
		p_title.add_theme_font_size_override("font_size", 22)
		card.add_child(p_title)
		ui_card_slot_titles.append(p_title)
		
		var team_lbl = Label.new()
		team_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		team_lbl.position = Vector2(10, 55)
		team_lbl.size = Vector2(col_width - 20, 30)
		team_lbl.add_theme_font_size_override("font_size", 20)
		card.add_child(team_lbl)
		ui_team_labels.append(team_lbl)
		
		var slot_lbl = Label.new()
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_lbl.position = Vector2(10, 95)
		slot_lbl.size = Vector2(col_width - 20, 140)
		slot_lbl.add_theme_font_size_override("font_size", 20)
		slot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_child(slot_lbl)
		ui_slot_labels.append(slot_lbl)
		
		var key_hint = Label.new()
		var team_keys = ["Q", "W", "E", "R"]
		var hint_fmt = tr("KEY_HINT")
		if not ("%d" in hint_fmt and "%s" in hint_fmt):
			hint_fmt = "Taste [%d]: Modus\nTaste [%s]: Team wechseln"
		key_hint.text = hint_fmt % [i + 1, team_keys[i]]
		key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_hint.position = Vector2(10, 270)
		key_hint.size = Vector2(col_width - 20, 60)
		key_hint.add_theme_font_size_override("font_size", 16)
		key_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		card.add_child(key_hint)
		ui_key_hint_labels.append(key_hint)
	
	ui_theme_toggle_label = Label.new()
	ui_theme_toggle_label.position = Vector2(100, 520)
	ui_theme_toggle_label.size = Vector2(1080, 36)
	ui_theme_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_theme_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_theme_toggle_label.add_theme_font_size_override("font_size", 21)
	ui_theme_toggle_label.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_theme_toggle_label.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cycle_arena_theme()
	)
	ui_lobby_panel.add_child(ui_theme_toggle_label)

	ui_powerup_toggle_label = Label.new()
	ui_powerup_toggle_label.position = Vector2(100, 560)
	ui_powerup_toggle_label.size = Vector2(1080, 36)
	ui_powerup_toggle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_powerup_toggle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_powerup_toggle_label.add_theme_font_size_override("font_size", 20)
	ui_powerup_toggle_label.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_powerup_toggle_label.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			toggle_powerups()
	)
	ui_lobby_panel.add_child(ui_powerup_toggle_label)
	
	_update_lobby_ui()
	canvas.add_child(ui_lobby_panel)
	_build_pause_menu(canvas)
	_build_stats_menu(canvas)
	add_child(canvas)

func _create_styled_button(text: String, font_size: int = 18, bg_col: Color = Color(0.14, 0.20, 0.32, 0.95)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = bg_col
	normal_sb.corner_radius_top_left = 6
	normal_sb.corner_radius_top_right = 6
	normal_sb.corner_radius_bottom_left = 6
	normal_sb.corner_radius_bottom_right = 6
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 2
	normal_sb.border_color = Color(0.3, 0.6, 0.9, 0.7)
	btn.add_theme_stylebox_override("normal", normal_sb)
	
	var hover_sb = normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = bg_col.lightened(0.25)
	hover_sb.border_color = Color(0.5, 0.85, 1.0, 1.0)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	return btn

func _build_pause_menu(canvas: CanvasLayer) -> void:
	ui_pause_container = Control.new()
	ui_pause_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_pause_container.visible = false
	ui_pause_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.07, 0.12, 0.88)
	ui_pause_container.add_child(backdrop)
	
	var panel = Panel.new()
	panel.position = Vector2(300, 70)
	panel.size = Vector2(680, 580)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.11, 0.18, 0.96)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.2, 0.75, 1.0, 0.85)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", sb)
	ui_pause_container.add_child(panel)
	
	ui_pause_title_lbl = Label.new()
	ui_pause_title_lbl.text = tr("PAUSE_TITLE")
	ui_pause_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_pause_title_lbl.position = Vector2(20, 16)
	ui_pause_title_lbl.size = Vector2(640, 42)
	ui_pause_title_lbl.add_theme_font_size_override("font_size", 32)
	ui_pause_title_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	panel.add_child(ui_pause_title_lbl)
	
	ui_pause_options_title_lbl = Label.new()
	ui_pause_options_title_lbl.text = tr("OPTIONS_TITLE")
	ui_pause_options_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_pause_options_title_lbl.position = Vector2(20, 64)
	ui_pause_options_title_lbl.size = Vector2(640, 24)
	ui_pause_options_title_lbl.add_theme_font_size_override("font_size", 16)
	ui_pause_options_title_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	panel.add_child(ui_pause_options_title_lbl)
	
	var slider_start_y = 100
	ui_master_lbl = Label.new()
	ui_master_lbl.position = Vector2(40, slider_start_y)
	ui_master_lbl.size = Vector2(240, 28)
	ui_master_lbl.add_theme_font_size_override("font_size", 16)
	panel.add_child(ui_master_lbl)
	
	ui_master_slider = HSlider.new()
	ui_master_slider.position = Vector2(290, slider_start_y + 4)
	ui_master_slider.size = Vector2(340, 24)
	ui_master_slider.min_value = 0.0
	ui_master_slider.max_value = 1.0
	ui_master_slider.step = 0.05
	ui_master_slider.value = 1.0
	ui_master_slider.value_changed.connect(func(val: float):
		if sound_manager:
			sound_manager.set_master_volume(val)
		_update_volume_labels()
	)
	panel.add_child(ui_master_slider)
	
	ui_bgm_lbl = Label.new()
	ui_bgm_lbl.position = Vector2(40, slider_start_y + 40)
	ui_bgm_lbl.size = Vector2(240, 28)
	ui_bgm_lbl.add_theme_font_size_override("font_size", 16)
	panel.add_child(ui_bgm_lbl)
	
	ui_bgm_slider = HSlider.new()
	ui_bgm_slider.position = Vector2(290, slider_start_y + 44)
	ui_bgm_slider.size = Vector2(340, 24)
	ui_bgm_slider.min_value = 0.0
	ui_bgm_slider.max_value = 1.0
	ui_bgm_slider.step = 0.05
	ui_bgm_slider.value = 0.75
	ui_bgm_slider.value_changed.connect(func(val: float):
		if sound_manager:
			sound_manager.set_bgm_volume(val)
		_update_volume_labels()
	)
	panel.add_child(ui_bgm_slider)
	
	ui_sfx_lbl = Label.new()
	ui_sfx_lbl.position = Vector2(40, slider_start_y + 80)
	ui_sfx_lbl.size = Vector2(240, 28)
	ui_sfx_lbl.add_theme_font_size_override("font_size", 16)
	panel.add_child(ui_sfx_lbl)
	
	ui_sfx_slider = HSlider.new()
	ui_sfx_slider.position = Vector2(290, slider_start_y + 84)
	ui_sfx_slider.size = Vector2(340, 24)
	ui_sfx_slider.min_value = 0.0
	ui_sfx_slider.max_value = 1.0
	ui_sfx_slider.step = 0.05
	ui_sfx_slider.value = 1.0
	ui_sfx_slider.value_changed.connect(func(val: float):
		if sound_manager:
			sound_manager.set_sfx_volume(val)
		_update_volume_labels()
	)
	panel.add_child(ui_sfx_slider)
	
	_update_volume_labels()
	
	var btn_y = 235
	var bw = 285
	var bh = 42
	
	ui_pause_resume_btn = _create_styled_button(tr("PAUSE_RESUME"), 17, Color(0.12, 0.28, 0.22, 0.95))
	ui_pause_resume_btn.position = Vector2(40, btn_y)
	ui_pause_resume_btn.size = Vector2(bw, bh)
	ui_pause_resume_btn.pressed.connect(func():
		toggle_pause()
	)
	panel.add_child(ui_pause_resume_btn)
	
	ui_pause_restart_btn = _create_styled_button(tr("PAUSE_RESTART"), 17, Color(0.28, 0.18, 0.12, 0.95))
	ui_pause_restart_btn.position = Vector2(350, btn_y)
	ui_pause_restart_btn.size = Vector2(bw, bh)
	ui_pause_restart_btn.pressed.connect(func():
		toggle_pause()
		restart_game()
	)
	panel.add_child(ui_pause_restart_btn)
	
	ui_pause_theme_btn = _create_styled_button("🏟️ [T] ARENA", 16)
	ui_pause_theme_btn.position = Vector2(40, btn_y + 50)
	ui_pause_theme_btn.size = Vector2(bw, bh)
	ui_pause_theme_btn.pressed.connect(func():
		cycle_arena_theme()
		_update_pause_buttons_text()
	)
	panel.add_child(ui_pause_theme_btn)
	
	ui_pause_lang_btn = _create_styled_button("🌐 [L] DE / EN", 16)
	ui_pause_lang_btn.position = Vector2(350, btn_y + 50)
	ui_pause_lang_btn.size = Vector2(bw, bh)
	ui_pause_lang_btn.pressed.connect(func():
		toggle_language()
		_update_pause_buttons_text()
	)
	panel.add_child(ui_pause_lang_btn)
	
	ui_pause_fs_btn = _create_styled_button("🖥️ [F11] VOLLBILD", 16)
	ui_pause_fs_btn.position = Vector2(40, btn_y + 100)
	ui_pause_fs_btn.size = Vector2(bw, bh)
	ui_pause_fs_btn.pressed.connect(func():
		toggle_fullscreen()
		_update_pause_buttons_text()
	)
	panel.add_child(ui_pause_fs_btn)
	
	ui_pause_lobby_btn = _create_styled_button(tr("PAUSE_LOBBY"), 16, Color(0.25, 0.10, 0.10, 0.95))
	ui_pause_lobby_btn.position = Vector2(350, btn_y + 100)
	ui_pause_lobby_btn.size = Vector2(bw, bh)
	ui_pause_lobby_btn.pressed.connect(func():
		toggle_pause()
		return_to_lobby()
	)
	panel.add_child(ui_pause_lobby_btn)
	
	ui_pause_ctrl_title_lbl = Label.new()
	ui_pause_ctrl_title_lbl.text = tr("CONTROLS_TITLE")
	ui_pause_ctrl_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_pause_ctrl_title_lbl.position = Vector2(20, 395)
	ui_pause_ctrl_title_lbl.size = Vector2(640, 24)
	ui_pause_ctrl_title_lbl.add_theme_font_size_override("font_size", 15)
	ui_pause_ctrl_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(ui_pause_ctrl_title_lbl)
	
	ui_pause_ctrl_p1_lbl = Label.new()
	ui_pause_ctrl_p1_lbl.text = tr("CONTROLS_P1")
	ui_pause_ctrl_p1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_pause_ctrl_p1_lbl.position = Vector2(20, 424)
	ui_pause_ctrl_p1_lbl.size = Vector2(640, 22)
	ui_pause_ctrl_p1_lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(ui_pause_ctrl_p1_lbl)
	
	ui_pause_ctrl_p2_lbl = Label.new()
	ui_pause_ctrl_p2_lbl.text = tr("CONTROLS_P2")
	ui_pause_ctrl_p2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_pause_ctrl_p2_lbl.position = Vector2(20, 448)
	ui_pause_ctrl_p2_lbl.size = Vector2(640, 22)
	ui_pause_ctrl_p2_lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(ui_pause_ctrl_p2_lbl)
	
	ui_pause_ctrl_gp_lbl = Label.new()
	ui_pause_ctrl_gp_lbl.text = tr("CONTROLS_GAMEPAD")
	ui_pause_ctrl_gp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_pause_ctrl_gp_lbl.position = Vector2(20, 472)
	ui_pause_ctrl_gp_lbl.size = Vector2(640, 22)
	ui_pause_ctrl_gp_lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(ui_pause_ctrl_gp_lbl)
	
	canvas.add_child(ui_pause_container)

func _build_stats_menu(canvas: CanvasLayer) -> void:
	ui_stats_container = Control.new()
	ui_stats_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_stats_container.visible = false
	ui_stats_container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.05, 0.08, 0.92)
	ui_stats_container.add_child(backdrop)
	
	var panel = Panel.new()
	panel.position = Vector2(240, 50)
	panel.size = Vector2(800, 620)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 0.82, 0.22, 0.95)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	panel.add_theme_stylebox_override("panel", sb)
	ui_stats_container.add_child(panel)
	
	ui_stats_title_lbl = Label.new()
	ui_stats_title_lbl.text = tr("STATS_TITLE")
	ui_stats_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_stats_title_lbl.position = Vector2(20, 14)
	ui_stats_title_lbl.size = Vector2(760, 36)
	ui_stats_title_lbl.add_theme_font_size_override("font_size", 26)
	ui_stats_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	panel.add_child(ui_stats_title_lbl)
	
	ui_stats_winner_lbl = Label.new()
	ui_stats_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_stats_winner_lbl.position = Vector2(20, 52)
	ui_stats_winner_lbl.size = Vector2(760, 38)
	ui_stats_winner_lbl.add_theme_font_size_override("font_size", 28)
	panel.add_child(ui_stats_winner_lbl)
	
	ui_stats_score_lbl = Label.new()
	ui_stats_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_stats_score_lbl.position = Vector2(20, 92)
	ui_stats_score_lbl.size = Vector2(760, 42)
	ui_stats_score_lbl.add_theme_font_size_override("font_size", 34)
	panel.add_child(ui_stats_score_lbl)
	
	var th_y = 145
	var th_red = Label.new()
	th_red.text = "🔴 " + tr("TEAM_RED_LBL")
	th_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th_red.position = Vector2(30, th_y)
	th_red.size = Vector2(200, 28)
	th_red.add_theme_font_size_override("font_size", 18)
	th_red.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	panel.add_child(th_red)
	
	var th_mid = Label.new()
	th_mid.text = "KATEGORIE"
	th_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th_mid.position = Vector2(250, th_y)
	th_mid.size = Vector2(300, 28)
	th_mid.add_theme_font_size_override("font_size", 16)
	th_mid.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	panel.add_child(th_mid)
	
	var th_blue = Label.new()
	th_blue.text = "🔵 " + tr("TEAM_BLUE_LBL")
	th_blue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	th_blue.position = Vector2(570, th_y)
	th_blue.size = Vector2(200, 28)
	th_blue.add_theme_font_size_override("font_size", 18)
	th_blue.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0))
	panel.add_child(th_blue)
	
	var rows = [
		{"key": "goals", "tr_key": "STATS_GOALS"},
		{"key": "shots", "tr_key": "STATS_SHOTS"},
		{"key": "posts", "tr_key": "STATS_POST_HITS"},
		{"key": "powerups", "tr_key": "STATS_POWERUPS"},
		{"key": "jumps", "tr_key": "STATS_JUMPS"},
		{"key": "tackles", "tr_key": "STATS_TACKLES"},
		{"key": "possession", "tr_key": "STATS_POSSESSION"},
		{"key": "speed", "tr_key": "STATS_TOP_SPEED"}
	]
	
	ui_stats_row_labels.clear()
	var row_y = 178
	for r in rows:
		var r_bg = ColorRect.new()
		r_bg.position = Vector2(30, row_y)
		r_bg.size = Vector2(740, 32)
		r_bg.color = Color(0.12, 0.16, 0.24, 0.45) if (ui_stats_row_labels.size() % 2 == 0) else Color(0.08, 0.11, 0.18, 0.25)
		panel.add_child(r_bg)
		
		var l_red = Label.new()
		l_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_red.position = Vector2(30, row_y)
		l_red.size = Vector2(200, 32)
		l_red.add_theme_font_size_override("font_size", 18)
		panel.add_child(l_red)
		
		var l_title = Label.new()
		l_title.text = tr(r["tr_key"])
		l_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_title.position = Vector2(250, row_y)
		l_title.size = Vector2(300, 32)
		l_title.add_theme_font_size_override("font_size", 16)
		l_title.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
		panel.add_child(l_title)
		
		var l_blue = Label.new()
		l_blue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_blue.position = Vector2(570, row_y)
		l_blue.size = Vector2(200, 32)
		l_blue.add_theme_font_size_override("font_size", 18)
		panel.add_child(l_blue)
		
		ui_stats_row_labels[r["key"]] = {
			"red": l_red,
			"title": l_title,
			"blue": l_blue,
			"tr_key": r["tr_key"]
		}
		row_y += 36
	
	var btn_y2 = 545
	ui_stats_rematch_btn = _create_styled_button(tr("BTN_REMATCH"), 18, Color(0.14, 0.32, 0.18, 0.95))
	ui_stats_rematch_btn.position = Vector2(100, btn_y2)
	ui_stats_rematch_btn.size = Vector2(270, 48)
	ui_stats_rematch_btn.pressed.connect(func():
		if sound_manager:
			sound_manager.play_ui_click()
		ui_stats_container.visible = false
		restart_game()
	)
	panel.add_child(ui_stats_rematch_btn)
	
	ui_stats_lobby_btn = _create_styled_button(tr("BTN_LOBBY"), 18, Color(0.28, 0.15, 0.15, 0.95))
	ui_stats_lobby_btn.position = Vector2(430, btn_y2)
	ui_stats_lobby_btn.size = Vector2(270, 48)
	ui_stats_lobby_btn.pressed.connect(func():
		if sound_manager:
			sound_manager.play_ui_click()
		ui_stats_container.visible = false
		return_to_lobby()
	)
	panel.add_child(ui_stats_lobby_btn)
	
	canvas.add_child(ui_stats_container)

func _update_volume_labels() -> void:
	if ui_master_lbl and ui_master_slider:
		ui_master_lbl.text = tr("VOL_MASTER") + ": %d%%" % int(ui_master_slider.value * 100)
	if ui_bgm_lbl and ui_bgm_slider:
		ui_bgm_lbl.text = tr("VOL_BGM") + ": %d%%" % int(ui_bgm_slider.value * 100)
	if ui_sfx_lbl and ui_sfx_slider:
		ui_sfx_lbl.text = tr("VOL_SFX") + ": %d%%" % int(ui_sfx_slider.value * 100)

func _update_pause_buttons_text() -> void:
	if ui_pause_resume_btn:
		ui_pause_resume_btn.text = tr("PAUSE_RESUME")
	if ui_pause_restart_btn:
		ui_pause_restart_btn.text = tr("PAUSE_RESTART")
	if ui_pause_lobby_btn:
		ui_pause_lobby_btn.text = tr("PAUSE_LOBBY")
	if ui_pause_theme_btn and theme_manager:
		var cur = theme_manager.get_current_theme()
		var dname = theme_manager.get_theme_display_name(cur)
		ui_pause_theme_btn.text = "🏟️ [T] " + dname
	if ui_pause_lang_btn:
		var cur_loc = TranslationServer.get_locale().to_upper()
		ui_pause_lang_btn.text = "🌐 [L] " + cur_loc
	if ui_pause_fs_btn:
		var mode = DisplayServer.window_get_mode()
		var is_fs = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		ui_pause_fs_btn.text = "🖥️ [F11] " + (tr("FULLSCREEN_ON") if is_fs else tr("FULLSCREEN_OFF"))
	if ui_pause_ctrl_title_lbl:
		ui_pause_ctrl_title_lbl.text = tr("CONTROLS_TITLE")
	if ui_pause_ctrl_p1_lbl:
		ui_pause_ctrl_p1_lbl.text = tr("CONTROLS_P1")
	if ui_pause_ctrl_p2_lbl:
		ui_pause_ctrl_p2_lbl.text = tr("CONTROLS_P2")
	if ui_pause_ctrl_gp_lbl:
		ui_pause_ctrl_gp_lbl.text = tr("CONTROLS_GAMEPAD")
	if ui_pause_title_lbl:
		ui_pause_title_lbl.text = tr("PAUSE_TITLE")
	if ui_pause_options_title_lbl:
		ui_pause_options_title_lbl.text = tr("OPTIONS_TITLE")

func toggle_pause() -> void:
	if state_manager.current_state == CageStateManager.MatchState.LOBBY or state_manager.current_state == CageStateManager.MatchState.MATCH_OVER:
		return
	is_game_paused = !is_game_paused
	if ui_pause_container:
		ui_pause_container.visible = is_game_paused
		if is_game_paused:
			_update_volume_labels()
			_update_pause_buttons_text()
	for p in players:
		p.freeze = is_game_paused
	if ball:
		ball.freeze = is_game_paused
	if sound_manager:
		sound_manager.play_ui_click()

func show_match_stats() -> void:
	if not ui_stats_container:
		return
	
	if ui_banner_label:
		ui_banner_label.visible = false
	
	var w = state_manager.get_winner()
	if ui_stats_winner_lbl:
		if w == 1:
			ui_stats_winner_lbl.text = "🏆 " + tr("WIN_RED") + " 🏆"
			ui_stats_winner_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		elif w == 2:
			ui_stats_winner_lbl.text = "🏆 " + tr("WIN_BLUE") + " 🏆"
			ui_stats_winner_lbl.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0))
		else:
			ui_stats_winner_lbl.text = "🤝 " + tr("MATCH_DRAW") + " 🤝"
			ui_stats_winner_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	
	if ui_stats_score_lbl:
		ui_stats_score_lbl.text = "RED  %d : %d  BLUE" % [state_manager.scores[1], state_manager.scores[2]]
		ui_stats_score_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	
	if match_stats and not ui_stats_row_labels.is_empty():
		ui_stats_row_labels["goals"]["red"].text = str(match_stats.goals[1])
		ui_stats_row_labels["goals"]["blue"].text = str(match_stats.goals[2])
		ui_stats_row_labels["shots"]["red"].text = str(match_stats.shots[1])
		ui_stats_row_labels["shots"]["blue"].text = str(match_stats.shots[2])
		ui_stats_row_labels["posts"]["red"].text = str(match_stats.post_hits[1])
		ui_stats_row_labels["posts"]["blue"].text = str(match_stats.post_hits[2])
		ui_stats_row_labels["powerups"]["red"].text = str(match_stats.powerups[1])
		ui_stats_row_labels["powerups"]["blue"].text = str(match_stats.powerups[2])
		ui_stats_row_labels["jumps"]["red"].text = str(match_stats.jumps[1])
		ui_stats_row_labels["jumps"]["blue"].text = str(match_stats.jumps[2])
		ui_stats_row_labels["tackles"]["red"].text = str(match_stats.tackles[1])
		ui_stats_row_labels["tackles"]["blue"].text = str(match_stats.tackles[2])
		var p1 = match_stats.get_possession_percent(1)
		var p2 = match_stats.get_possession_percent(2)
		ui_stats_row_labels["possession"]["red"].text = "%0.0f%%" % p1
		ui_stats_row_labels["possession"]["blue"].text = "%0.0f%%" % p2
		ui_stats_row_labels["speed"]["red"].text = "-"
		ui_stats_row_labels["speed"]["blue"].text = "%0.1f km/h" % match_stats.get_max_speed_kmh()
		
		for key in ui_stats_row_labels:
			var info = ui_stats_row_labels[key]
			info["title"].text = tr(info["tr_key"])
	
	if ui_stats_rematch_btn:
		ui_stats_rematch_btn.text = tr("BTN_REMATCH")
	if ui_stats_lobby_btn:
		ui_stats_lobby_btn.text = tr("BTN_LOBBY")
	if ui_stats_title_lbl:
		ui_stats_title_lbl.text = tr("STATS_TITLE")
	
	ui_stats_container.visible = true
	ui_stats_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(ui_stats_container, "modulate:a", 1.0, 0.3)

func _on_ball_post_hit() -> void:
	if match_stats and is_instance_valid(ball):
		match_stats.record_post_hit(ball.last_touched_team)

func _on_player_jumped(p: CagePlayer) -> void:
	if match_stats and is_instance_valid(p) and p.control_type != CagePlayer.ControlType.OFF:
		match_stats.record_jump(p.team_id)

func _on_player_tackled(p: CagePlayer) -> void:
	if match_stats and is_instance_valid(p) and p.control_type != CagePlayer.ControlType.OFF:
		match_stats.record_tackle(p.team_id)

func _on_player_ball_hit(p: CagePlayer) -> void:
	if match_stats and is_instance_valid(p) and p.control_type != CagePlayer.ControlType.OFF:
		match_stats.record_shot(p.team_id)

func _refresh_all_localized_text() -> void:
	if ui_title_label:
		ui_title_label.text = tr("LOBBY_TITLE")
	if ui_subtitle_label:
		ui_subtitle_label.text = tr("LOBBY_SUBTITLE")
	if ui_hint_label:
		ui_hint_label.text = tr("UI_HINTS_BAR")
	var slot_fmt = tr("SLOT_TITLE")
	if not ("%d" in slot_fmt):
		slot_fmt = "SLOT %d"
	for i in range(ui_card_slot_titles.size()):
		ui_card_slot_titles[i].text = slot_fmt % (i + 1)
	var team_keys = ["Q", "W", "E", "R"]
	var hint_fmt = tr("KEY_HINT")
	if not ("%d" in hint_fmt and "%s" in hint_fmt):
		hint_fmt = "Taste [%d]: Modus\nTaste [%s]: Team wechseln"
	for i in range(ui_key_hint_labels.size()):
		ui_key_hint_labels[i].text = hint_fmt % [i + 1, team_keys[i]]
	_update_lobby_ui()
	_update_pause_buttons_text()
	_update_volume_labels()
	if ui_stats_container and ui_stats_container.visible:
		show_match_stats()

func _update_lobby_ui() -> void:
	for i in range(players.size()):
		var p = players[i]
		if i < ui_slot_labels.size():
			ui_slot_labels[i].text = _get_control_type_name(p.control_type)
		if i < ui_team_labels.size():
			if p.team_id == 1:
				ui_team_labels[i].text = tr("TEAM_RED_LBL")
				ui_team_labels[i].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				ui_team_labels[i].text = tr("TEAM_BLUE_LBL")
				ui_team_labels[i].add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	
	if ui_theme_toggle_label and theme_manager:
		var cur_theme = theme_manager.get_current_theme()
		var dname = theme_manager.get_theme_display_name(cur_theme)
		var btn_fmt = tr("LOBBY_THEME_BTN")
		if not ("%s" in btn_fmt):
			btn_fmt = "🏟️ [T] ARENA: %s"
		ui_theme_toggle_label.text = btn_fmt % dname
		ui_theme_toggle_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
	
	if ui_powerup_toggle_label:
		if CageConfig.powerups_enabled:
			ui_powerup_toggle_label.text = tr("POWERUPS_ENABLED_LOBBY")
			ui_powerup_toggle_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		else:
			ui_powerup_toggle_label.text = tr("POWERUPS_DISABLED_LOBBY")
			ui_powerup_toggle_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.45))

func _get_control_type_name(ct: CagePlayer.ControlType) -> String:
	match ct:
		CagePlayer.ControlType.OFF:
			return tr("CTRL_OFF")
		CagePlayer.ControlType.HUMAN_KB1:
			return tr("CTRL_KB1")
		CagePlayer.ControlType.HUMAN_KB2:
			return tr("CTRL_KB2")
		CagePlayer.ControlType.GAMEPAD_0:
			return tr("CTRL_GAMEPAD_0")
		CagePlayer.ControlType.GAMEPAD_1:
			return tr("CTRL_GAMEPAD_1")
		CagePlayer.ControlType.GAMEPAD_2:
			return tr("CTRL_GAMEPAD_2")
		CagePlayer.ControlType.GAMEPAD_3:
			return tr("CTRL_GAMEPAD_3")
		CagePlayer.ControlType.AI_BOT:
			return tr("CTRL_AI_BOT")
	return "UNKNOWN"

func cycle_player_slot(index: int) -> void:
	if index < 0 or index >= players.size():
		return
	var p = players[index]
	var cur_idx = SLOT_CONTROL_OPTIONS.find(p.control_type)
	var next_idx = (cur_idx + 1) % SLOT_CONTROL_OPTIONS.size()
	p.set_control_type(SLOT_CONTROL_OPTIONS[next_idx])
	_update_lobby_ui()

func toggle_player_team(index: int) -> void:
	if index < 0 or index >= players.size():
		return
	var p = players[index]
	p.team_id = 2 if p.team_id == 1 else 1
	_update_lobby_ui()

func toggle_p2_bot() -> void:
	if player2:
		if player2.control_type == CagePlayer.ControlType.AI_BOT:
			player2.set_control_type(CagePlayer.ControlType.HUMAN_KB2)
		else:
			player2.set_control_type(CagePlayer.ControlType.AI_BOT)
		_update_lobby_ui()
		_update_score_label()

func _update_score_label() -> void:
	if ui_score_label and state_manager:
		ui_score_label.text = "RED  %d : %d  BLUE" % [state_manager.scores[1], state_manager.scores[2]]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if ui_stats_container and ui_stats_container.visible:
			if event.keycode == KEY_R:
				if sound_manager:
					sound_manager.play_ui_click()
				ui_stats_container.visible = false
				restart_game()
				return
			elif event.keycode == KEY_L or event.keycode == KEY_ESCAPE:
				if sound_manager:
					sound_manager.play_ui_click()
				ui_stats_container.visible = false
				return_to_lobby()
				return

		if is_game_paused:
			if event.keycode == KEY_ESCAPE:
				toggle_pause()
				return
			elif event.keycode == KEY_R:
				toggle_pause()
				restart_game()
				return
			elif event.keycode == KEY_L:
				toggle_pause()
				return_to_lobby()
				return
			elif event.keycode == KEY_T:
				cycle_arena_theme()
				_update_pause_buttons_text()
				return
			elif event.keycode == KEY_M:
				toggle_bgm_music()
				return
			elif event.keycode == KEY_F11:
				toggle_fullscreen()
				_update_pause_buttons_text()
				return

		if event.keycode == KEY_M:
			toggle_bgm_music()
			return
		elif event.keycode == KEY_L:
			toggle_language()
			return
		elif event.keycode == KEY_F11:
			toggle_fullscreen()
			return
		elif event.keycode == KEY_T:
			cycle_arena_theme()
			return
			
		if state_manager.current_state == CageStateManager.MatchState.LOBBY:
			if event.keycode == KEY_1:
				cycle_player_slot(0)
			elif event.keycode == KEY_2:
				cycle_player_slot(1)
			elif event.keycode == KEY_3:
				cycle_player_slot(2)
			elif event.keycode == KEY_4:
				cycle_player_slot(3)
			elif event.keycode == KEY_Q:
				toggle_player_team(0)
			elif event.keycode == KEY_W:
				toggle_player_team(1)
			elif event.keycode == KEY_E:
				toggle_player_team(2)
			elif event.keycode == KEY_R:
				toggle_player_team(3)
			elif event.keycode == KEY_P:
				toggle_powerups()
			elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				start_match_from_lobby()
		else:
			if event.keycode == KEY_ESCAPE:
				toggle_pause()
			elif event.keycode == KEY_B:
				toggle_p2_bot()
			elif event.keycode == KEY_P:
				toggle_powerups()

func toggle_bgm_music() -> void:
	if sound_manager:
		var active = sound_manager.toggle_bgm()
		if ui_banner_label:
			ui_banner_label.visible = true
			ui_banner_label.text = tr("MUSIC_STATUS_ON") if active else tr("MUSIC_STATUS_OFF")
			var tween = create_tween()
			tween.tween_interval(1.2)
			tween.tween_callback(func():
				if is_instance_valid(ui_banner_label) and (state_manager.current_state == CageStateManager.MatchState.PLAYING or state_manager.current_state == CageStateManager.MatchState.LOBBY):
					ui_banner_label.visible = false
			)

func toggle_language() -> void:
	var cur = TranslationServer.get_locale()
	var new_locale = "en" if cur.begins_with("de") else "de"
	TranslationServer.set_locale(new_locale)
	_refresh_all_localized_text()
	if ui_banner_label:
		ui_banner_label.visible = true
		ui_banner_label.text = tr("LANG_STATUS_EN") if new_locale == "en" else tr("LANG_STATUS_DE")
		var tween = create_tween()
		tween.tween_interval(1.2)
		tween.tween_callback(func():
			if is_instance_valid(ui_banner_label) and (state_manager.current_state == CageStateManager.MatchState.PLAYING or state_manager.current_state == CageStateManager.MatchState.LOBBY):
				ui_banner_label.visible = false
		)

func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	var is_fs = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if ui_banner_label:
		ui_banner_label.visible = true
		ui_banner_label.text = tr("FULLSCREEN_OFF") if is_fs else tr("FULLSCREEN_ON")
		var tween = create_tween()
		tween.tween_interval(1.2)
		tween.tween_callback(func():
			if is_instance_valid(ui_banner_label) and (state_manager.current_state == CageStateManager.MatchState.PLAYING or state_manager.current_state == CageStateManager.MatchState.LOBBY):
				ui_banner_label.visible = false
		)

func cycle_arena_theme() -> void:
	if not theme_manager:
		theme_manager = CageThemeManager.get_instance()
	var next_theme = theme_manager.cycle_theme()
	apply_theme(next_theme, true)

func apply_theme(t: Dictionary, is_live_switch: bool = false) -> void:
	if t.is_empty():
		return
		
	# 1. World Environment & Sky
	if world_env and world_env.environment:
		var env = world_env.environment
		var sky_type = str(t.get("sky_type", "procedural"))
		if sky_type == "panorama":
			var skybox_path = str(t.get("skybox_path", ""))
			if ResourceLoader.exists(skybox_path):
				var pano = PanoramaSkyMaterial.new()
				pano.panorama = load(skybox_path)
				var sky = Sky.new()
				sky.sky_material = pano
				env.sky = sky
				env.background_mode = Environment.BG_SKY
		else:
			var proc = ProceduralSkyMaterial.new()
			proc.sky_top_color = t.get("sky_top_color", Color(0.35, 0.65, 0.95))
			proc.sky_horizon_color = t.get("sky_horizon_color", Color(0.75, 0.88, 1.0))
			proc.ground_bottom_color = t.get("ground_bottom_color", Color(0.4, 0.35, 0.3))
			proc.ground_horizon_color = t.get("ground_horizon_color", Color(0.7, 0.8, 0.9))
			var sky = Sky.new()
			sky.sky_material = proc
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			
		env.glow_bloom = float(t.get("glow_bloom", 0.15))
		env.glow_intensity = float(t.get("glow_intensity", 0.4))
		env.ambient_light_color = t.get("ambient_color", Color(0.2, 0.22, 0.28))
		env.ambient_light_energy = float(t.get("ambient_energy", 0.5))

	# 2. Stadium Light & Corner Floodlights
	if stadium_light:
		stadium_light.light_color = t.get("sun_color", Color.WHITE)
		stadium_light.light_energy = float(t.get("sun_energy", 1.25))
		stadium_light.rotation_degrees = t.get("sun_rotation", Vector3(-55, 40, 0))
		stadium_light.shadow_opacity = float(t.get("sun_shadow_opacity", 0.28))
		stadium_light.shadow_blur = float(t.get("sun_shadow_blur", 3.5))
		
	var fl_color = t.get("floodlight_color", Color(0.95, 0.96, 1.0))
	var fl_energy = float(t.get("floodlight_energy", 0.95))
	for fl in corner_floodlights:
		if is_instance_valid(fl):
			fl.light_color = fl_color
			fl.light_energy = fl_energy
	for fix in corner_floodlight_fixtures:
		if is_instance_valid(fix) and fix.material_override is StandardMaterial3D:
			var fix_mat = fix.material_override as StandardMaterial3D
			fix_mat.emission = fl_color
			fix_mat.emission_energy_multiplier = 2.0 + fl_energy

	# 3. Floor
	if floor_inst:
		var floor_mat = StandardMaterial3D.new()
		var tex_path = str(t.get("floor_texture", ""))
		if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			var tex = load(tex_path)
			floor_mat.albedo_texture = tex
			floor_mat.uv1_scale = t.get("floor_uv_scale", Vector3(10.0, 6.0, 1.0))
		else:
			floor_mat.albedo_color = t.get("floor_color", Color(0.28, 0.32, 0.36))
		floor_mat.roughness = float(t.get("floor_roughness", 0.75))
		floor_mat.metallic = float(t.get("floor_metallic", 0.05))
		floor_inst.material_override = floor_mat

	# 4. Boards
	for b in board_instances:
		if is_instance_valid(b):
			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = t.get("board_color", Color(0.18, 0.2, 0.24))
			b_mat.roughness = float(t.get("board_roughness", 0.3))
			b_mat.metallic = float(t.get("board_metallic", 0.6))
			b_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			b_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			b.material_override = b_mat

	# 5. Fences
	for f in fence_instances:
		if is_instance_valid(f):
			var f_mat = StandardMaterial3D.new()
			var fence_path = str(t.get("fence_texture", ""))
			if not fence_path.is_empty() and ResourceLoader.exists(fence_path):
				f_mat.albedo_texture = load(fence_path)
				f_mat.uv1_scale = f.material_override.uv1_scale if f.material_override else Vector3(4.0, 2.0, 1.0)
			f_mat.albedo_color = t.get("fence_color", Color(0.75, 0.8, 0.85, 0.75))
			f_mat.roughness = float(t.get("fence_roughness", 0.25))
			f_mat.metallic = float(t.get("fence_metallic", 0.85))
			f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			f_mat.alpha_scissor_threshold = 0.5
			f_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
			f_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			f.material_override = f_mat
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 6. Goal Posts & Neon Glow
	var goal_emission = bool(t.get("goal_emission_enabled", false))
	for p in goal_post_instances:
		if is_instance_valid(p):
			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = t.get("goal_post_color", Color(0.95, 0.95, 0.95))
			p_mat.roughness = 0.2
			p_mat.metallic = 0.8
			if goal_emission:
				p_mat.emission_enabled = true
				p_mat.emission = t.get("goal_post_color", Color(1.0, 0.15, 0.65))
				p_mat.emission_energy_multiplier = 3.0
			p.material_override = p_mat

	for gl in goal_glow_lights:
		if is_instance_valid(gl):
			gl.visible = goal_emission

	# 7. Ball
	if ball and ball.has_method("set_theme_colors"):
		ball.set_theme_colors(
			t.get("ball_pent_color", Color(0.12, 0.12, 0.14)),
			t.get("ball_hex_color", Color(0.96, 0.96, 0.97)),
			t.get("ball_seam_color", Color(0.06, 0.06, 0.08)),
			t.get("ball_emission_color", Color.BLACK),
			float(t.get("ball_emission_energy", 0.0))
		)

	# 8. Players Underglow & Light
	var player_glow = bool(t.get("player_glow_enabled", false))
	for p in players:
		if is_instance_valid(p) and p.has_method("set_cyber_glow"):
			p.set_cyber_glow(player_glow)

	# 9. Juice Manager
	if juice_manager and juice_manager.has_method("set_turf_color"):
		juice_manager.set_turf_color(t.get("turf_puff_color", Color(0.2, 0.75, 0.25)))

	_update_lobby_ui()

	if is_live_switch and ui_banner_label:
		var dname = CageThemeManager.get_instance().get_theme_display_name(t)
		ui_banner_label.visible = true
		var banner_fmt = tr("THEME_STATUS_BANNER")
		if not ("%s" in banner_fmt):
			banner_fmt = "ARENA: %s"
		ui_banner_label.text = banner_fmt % dname
		var tween = create_tween()
		tween.tween_interval(1.4)
		tween.tween_callback(func():
			if is_instance_valid(ui_banner_label) and (state_manager.current_state == CageStateManager.MatchState.PLAYING or state_manager.current_state == CageStateManager.MatchState.LOBBY):
				ui_banner_label.visible = false
		)

func toggle_powerups() -> void:
	CageConfig.powerups_enabled = not CageConfig.powerups_enabled
	if not CageConfig.powerups_enabled:
		clear_power_ups()
	_update_lobby_ui()
	if ui_banner_label and state_manager.current_state != CageStateManager.MatchState.LOBBY:
		ui_banner_label.text = tr("POWERUPS_NOW_ON") if CageConfig.powerups_enabled else tr("POWERUPS_NOW_OFF")

func clear_power_ups() -> void:
	for p in active_power_ups:
		if is_instance_valid(p):
			p.queue_free()
	active_power_ups.clear()

func spawn_power_up(chosen_type: CageConfig.PowerUpType = CageConfig.PowerUpType.NONE, spawn_pos: Vector3 = Vector3.ZERO) -> CagePowerUp:
	if not CageConfig.powerups_enabled:
		return null
	
	if spawn_pos == Vector3.ZERO:
		var free_spots: Array[Vector3] = []
		for spot in BOARD_SPAWN_POINTS:
			var occupied = false
			for pup in active_power_ups:
				if is_instance_valid(pup) and pup.position.distance_to(spot) < 2.2:
					occupied = true
					break
			if not occupied:
				free_spots.append(spot)
		if free_spots.is_empty():
			return null
		spawn_pos = free_spots[randi() % free_spots.size()]
	
	if chosen_type == CageConfig.PowerUpType.NONE:
		chosen_type = randi_range(1, 5) as CageConfig.PowerUpType
	
	var pup = CagePowerUp.new()
	pup.type = chosen_type
	pup.position = spawn_pos
	pup.power_up_collected.connect(_on_power_up_collected)
	active_power_ups.append(pup)
	add_child(pup)
	return pup

func _on_power_up_collected(player: CagePlayer, type: CageConfig.PowerUpType) -> void:
	for i in range(active_power_ups.size() - 1, -1, -1):
		if not is_instance_valid(active_power_ups[i]) or active_power_ups[i].is_queued_for_deletion():
			active_power_ups.remove_at(i)
	if match_stats and is_instance_valid(player):
		match_stats.record_powerup(player.team_id)
	player.apply_power_up(type)
	show_powerup_banner(player, type)

func show_powerup_banner(player: CagePlayer, type: CageConfig.PowerUpType) -> void:
	if not ui_powerup_banner or not is_inside_tree():
		return
	var col = CagePowerUp.get_type_color(type)
	if ui_powerup_title:
		ui_powerup_title.text = tr("PUP_COLLECTED_TITLE") % [player.player_id, CagePowerUp.get_short_title(type)]
		ui_powerup_title.add_theme_color_override("font_color", col)
	if ui_powerup_desc:
		ui_powerup_desc.text = CagePowerUp.get_explanation(type)
	
	var sb = ui_powerup_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = col
	
	ui_powerup_banner.visible = true
	ui_powerup_banner.modulate.a = 1.0
	ui_powerup_banner.pivot_offset = ui_powerup_banner.size * 0.5
	ui_powerup_banner.scale = Vector2(1.15, 1.15)
	
	var tween = create_tween()
	tween.tween_property(ui_powerup_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.2)
	tween.tween_property(ui_powerup_banner, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(func():
		if is_instance_valid(ui_powerup_banner):
			ui_powerup_banner.visible = false
	)

func start_match_from_lobby() -> void:
	var team1_count = 0
	var team2_count = 0
	for p in players:
		if p.control_type != CagePlayer.ControlType.OFF:
			if p.team_id == 1:
				team1_count += 1
			else:
				team2_count += 1
	
	if team1_count < 1 or team2_count < 1:
		ui_banner_label.text = tr("MIN_PLAYERS_WARN")
		return
	
	is_game_paused = false
	if ui_pause_container:
		ui_pause_container.visible = false
	if ui_stats_container:
		ui_stats_container.visible = false
	if match_stats:
		match_stats.reset()
	
	ui_lobby_panel.visible = false
	ui_hud_container.visible = true
	_power_up_spawn_timer = 0.0
	clear_power_ups()
	reset_positions()
	state_manager.start_match()
	if sound_manager:
		sound_manager.play_match_bgm()
	
	if CageConfig.powerups_enabled:
		spawn_power_up()
		spawn_power_up()

func return_to_lobby() -> void:
	is_game_paused = false
	if ui_pause_container:
		ui_pause_container.visible = false
	if ui_stats_container:
		ui_stats_container.visible = false
	clear_power_ups()
	for p in players:
		p.freeze = true
	if ball:
		ball.freeze = true
	state_manager.enter_lobby()
	if sound_manager:
		sound_manager.play_menu_bgm()
	ui_lobby_panel.visible = true
	_update_lobby_ui()

func _process(delta: float) -> void:
	if is_game_paused:
		return
		
	if state_manager:
		state_manager.update_logic(delta)
	
	if state_manager.current_state == CageStateManager.MatchState.WARMUP:
		var sec = int(ceil(state_manager.warmup_timer))
		if sec > 0:
			ui_banner_label.text = str(sec)
		else:
			ui_banner_label.text = tr("BANNER_KICKOFF")
	
	if state_manager.current_state == CageStateManager.MatchState.PLAYING:
		if match_stats and is_instance_valid(ball):
			match_stats.record_speed(ball.linear_velocity.length())
			var closest_team = 1
			var min_dist = 9999.0
			for p in players:
				if p.control_type != CagePlayer.ControlType.OFF:
					var d = p.global_position.distance_to(ball.global_position) if (p.is_inside_tree() and ball.is_inside_tree()) else p.position.distance_to(ball.position)
					if d < min_dist:
						min_dist = d
						closest_team = p.team_id
			if min_dist < 4.5:
				match_stats.update_possession(delta, closest_team)
				
		if CageConfig.powerups_enabled:
			_power_up_spawn_timer += delta
			if _power_up_spawn_timer >= CageConfig.POWERUP_SPAWN_INTERVAL:
				_power_up_spawn_timer = 0.0
				for i in range(active_power_ups.size() - 1, -1, -1):
					if not is_instance_valid(active_power_ups[i]):
						active_power_ups.remove_at(i)
				if active_power_ups.size() < CageConfig.POWERUP_MAX_ACTIVE:
					spawn_power_up()
	
	if Input.is_action_just_pressed("restart") and state_manager.current_state != CageStateManager.MatchState.LOBBY:
		restart_game()

func restart_game() -> void:
	is_game_paused = false
	if ui_pause_container:
		ui_pause_container.visible = false
	if ui_stats_container:
		ui_stats_container.visible = false
	if match_stats:
		match_stats.reset()
	clear_power_ups()
	reset_positions()
	state_manager.reset_match()
	if CageConfig.powerups_enabled:
		spawn_power_up()
		spawn_power_up()

func reset_positions() -> void:
	var spawn_spots_team1 = [
		Vector3(-6.0, CageConfig.PLAYER_RADIUS, -2.2),
		Vector3(-6.0, CageConfig.PLAYER_RADIUS, 2.2)
	]
	var spawn_spots_team2 = [
		Vector3(6.0, CageConfig.PLAYER_RADIUS, 2.2),
		Vector3(6.0, CageConfig.PLAYER_RADIUS, -2.2)
	]
	
	var idx1 = 0
	var idx2 = 0
	for p in players:
		if p.control_type != CagePlayer.ControlType.OFF:
			if p.team_id == 1:
				p.reset_to(spawn_spots_team1[idx1 % spawn_spots_team1.size()])
				idx1 += 1
			else:
				p.reset_to(spawn_spots_team2[idx2 % spawn_spots_team2.size()])
				idx2 += 1
			p.freeze = true
	
	if ball:
		ball.reset_to_center()
		ball.freeze = true

func _on_state_changed(new_state: CageStateManager.MatchState) -> void:
	if not ui_banner_label:
		return
	match new_state:
		CageStateManager.MatchState.LOBBY:
			ui_banner_label.visible = false
			for p in players:
				p.freeze = true
			if ball:
				ball.freeze = true
		CageStateManager.MatchState.WARMUP:
			ui_banner_label.visible = true
			ui_banner_label.text = "3"
			for p in players:
				if p.control_type != CagePlayer.ControlType.OFF:
					p.freeze = true
			if ball:
				ball.freeze = true
		CageStateManager.MatchState.PLAYING:
			ui_banner_label.visible = false
			if sound_manager:
				sound_manager.play_whistle()
			for p in players:
				if p.control_type != CagePlayer.ControlType.OFF:
					p.freeze = false
			if ball:
				ball.freeze = false
		CageStateManager.MatchState.GOAL_SCORED, CageStateManager.MatchState.CELEBRATION:
			ui_banner_label.visible = true
			if match_stats and state_manager.last_scoring_team in [1, 2]:
				match_stats.record_goal(state_manager.last_scoring_team)
			if sound_manager:
				sound_manager.play_goal()
				sound_manager.duck_bgm(2.5)
			if is_inside_tree():
				ui_banner_label.pivot_offset = ui_banner_label.size * 0.5
				ui_banner_label.scale = Vector2(1.4, 1.4)
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(ui_banner_label, "scale", Vector2.ONE, 0.45)
			if state_manager.last_scoring_team == 1:
				ui_banner_label.text = tr("GOAL_RED")
			elif state_manager.last_scoring_team == 2:
				ui_banner_label.text = tr("GOAL_BLUE")
			else:
				ui_banner_label.text = tr("GOAL_GENERIC")
			if ball:
				ball.linear_velocity *= 0.2
		CageStateManager.MatchState.RESET:
			reset_positions()
		CageStateManager.MatchState.MATCH_OVER:
			ui_banner_label.visible = false
			if sound_manager:
				sound_manager.play_final_whistle()
			show_match_stats()

func _on_score_updated(_team_id: int, _new_score: int) -> void:
	_update_score_label()

func _on_timer_updated(time_remaining: float) -> void:
	if ui_timer_label:
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		ui_timer_label.text = "%02d:%02d" % [mins, secs]

