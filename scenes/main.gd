class_name MainCageFootball
extends Node3D

const CageConfig = preload("res://scripts/config.gd")
const CageStateManager = preload("res://scripts/state_manager.gd")
const CagePlayer = preload("res://scripts/player.gd")
const SoccerBall = preload("res://scripts/ball.gd")
const CageCamera = preload("res://scripts/cage_camera.gd")

var state_manager: CageStateManager
var player1: CagePlayer
var player2: CagePlayer
var player3: CagePlayer
var player4: CagePlayer
var players: Array[CagePlayer] = []
var ball: SoccerBall
var camera: CageCamera
var whistle_player: AudioStreamPlayer

var ui_lobby_panel: Control
var ui_slot_labels: Array[Label] = []
var ui_team_labels: Array[Label] = []
var ui_score_label: Label
var ui_timer_label: Label
var ui_banner_label: Label
var ui_hud_container: Control

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
	state_manager = CageStateManager.new()
	state_manager.state_changed.connect(_on_state_changed)
	state_manager.score_updated.connect(_on_score_updated)
	state_manager.timer_updated.connect(_on_timer_updated)
	
	_build_audio()
	_build_scene()
	_build_ui()
	
	state_manager.enter_lobby()

func _build_audio() -> void:
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
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.15
	
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	
	var sun = DirectionalLight3D.new()
	sun.name = "StadiumLight"
	sun.position = Vector3(15, 25, 15)
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	
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
	
	var floor_inst = MeshInstance3D.new()
	floor_inst.mesh = floor_box
	var floor_mat = StandardMaterial3D.new()
	var turf_path = "res://assets/textures/pitch_turf.jpg"
	if ResourceLoader.exists(turf_path):
		floor_mat.albedo_texture = load(turf_path)
		floor_mat.uv1_scale = Vector3(10.0, 6.0, 1.0)
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

func _build_wall(pos: Vector3, size: Vector3, wall_name: String, custom_color: Color = Color(0.75, 0.8, 0.85, 0.75)) -> void:
	var body = StaticBody3D.new()
	body.name = wall_name
	body.position = pos
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	
	var is_ground_wall = (pos.y - size.y * 0.5 < 0.05) and (size.y > 1.0)
	var board_height = 0.35 if is_ground_wall else 0.0
	
	# 1. Solide Prallwand / Kickboard (Bande) - verhindert Z-Fighting mit dem Spielfeldboden vollständig
	if is_ground_wall:
		var board_inst = MeshInstance3D.new()
		var board_box = BoxMesh.new()
		board_box.size = Vector3(size.x, board_height, size.z)
		board_inst.mesh = board_box
		board_inst.position = Vector3(0, -size.y * 0.5 + board_height * 0.5, 0)
		
		var board_mat = StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.18, 0.20, 0.24) # Solide dunkle Industrie-Bande
		board_mat.metallic = 0.6
		board_mat.roughness = 0.3
		board_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		board_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		board_inst.material_override = board_mat
		body.add_child(board_inst)
	
	# 2. Drahtgitter-Käfigwand oberhalb der Bande
	var fence_height = size.y - board_height
	var fence_inst = MeshInstance3D.new()
	var fence_box = BoxMesh.new()
	fence_box.size = Vector3(size.x, fence_height, size.z)
	fence_inst.mesh = fence_box
	fence_inst.position = Vector3(0, -size.y * 0.5 + board_height + fence_height * 0.5, 0)
	
	var mat = StandardMaterial3D.new()
	var fence_path = "res://assets/textures/chainlink_fence.jpg"
	if ResourceLoader.exists(fence_path):
		mat.albedo_texture = load(fence_path)
		var max_span = maxf(size.x, size.z)
		mat.uv1_scale = Vector3(max_span * 0.45, fence_height * 0.45, 1.0)
		mat.albedo_color = custom_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.25
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
			if whistle_player and whistle_player.stream:
				whistle_player.play()
			state_manager.trigger_goal(scoring_team)
	)
	add_child(area)

func _build_goal_posts(side: int) -> void:
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.95, 0.95, 0.95)
	post_mat.roughness = 0.2
	post_mat.metallic = 0.8
	
	var x_pos = side * CageConfig.CAGE_WIDTH_X * 0.5
	var post_radius = 0.08
	
	# Nord-Pfosten
	var post_n = MeshInstance3D.new()
	var cyl_n = CylinderMesh.new()
	cyl_n.top_radius = post_radius
	cyl_n.bottom_radius = post_radius
	cyl_n.height = CageConfig.GOAL_HEIGHT
	post_n.mesh = cyl_n
	post_n.material_override = post_mat
	post_n.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, -CageConfig.GOAL_WIDTH * 0.5)
	add_child(post_n)
	
	# Süd-Pfosten
	var post_s = MeshInstance3D.new()
	var cyl_s = CylinderMesh.new()
	cyl_s.top_radius = post_radius
	cyl_s.bottom_radius = post_radius
	cyl_s.height = CageConfig.GOAL_HEIGHT
	post_s.mesh = cyl_s
	post_s.material_override = post_mat
	post_s.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, CageConfig.GOAL_WIDTH * 0.5)
	add_child(post_s)
	
	# Querlatte
	var crossbar = MeshInstance3D.new()
	var cyl_c = CylinderMesh.new()
	cyl_c.top_radius = post_radius
	cyl_c.bottom_radius = post_radius
	cyl_c.height = CageConfig.GOAL_WIDTH
	crossbar.mesh = cyl_c
	crossbar.material_override = post_mat
	crossbar.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT, 0)
	crossbar.rotation_degrees = Vector3(90, 0, 0)
	add_child(crossbar)

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
		
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = box_size
		mesh_inst.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = bumper_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.metallic = 0.4
		mat.roughness = 0.35
		mesh_inst.material_override = mat
		body.add_child(mesh_inst)
		
		add_child(body)

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
	
	var ui_hint = Label.new()
	ui_hint.text = "[R]: Neustart  |  [ESC]: Zurück zur Lobby  |  [B]: P2 Bot Toggle"
	ui_hint.position = Vector2(40, 670)
	ui_hint.add_theme_font_size_override("font_size", 16)
	ui_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.8))
	ui_hud_container.add_child(ui_hint)
	
	# --- Pre-Match Lobby Panel ---
	ui_lobby_panel = Control.new()
	ui_lobby_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg_overlay = ColorRect.new()
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.color = Color(0.06, 0.09, 0.14, 0.90)
	ui_lobby_panel.add_child(bg_overlay)
	
	var title = Label.new()
	title.text = "CRAZY CAGE FOOTBALL — LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(240, 35)
	title.size = Vector2(800, 55)
	title.add_theme_font_size_override("font_size", 40)
	ui_lobby_panel.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Wähle Steuerung ([1]-[4]) & Team ([Q],[W],[E],[R])  |  Start mit [SPACE / ENTER]"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(240, 95)
	subtitle.size = Vector2(800, 30)
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	ui_lobby_panel.add_child(subtitle)
	
	ui_slot_labels.clear()
	ui_team_labels.clear()
	var col_width = 260
	var start_x = 80
	for i in range(4):
		var card = Panel.new()
		card.position = Vector2(start_x + i * (col_width + 20), 150)
		card.size = Vector2(col_width, 380)
		ui_lobby_panel.add_child(card)
		
		var p_title = Label.new()
		p_title.text = "SLOT %d" % (i + 1)
		p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_title.position = Vector2(10, 15)
		p_title.size = Vector2(col_width - 20, 30)
		p_title.add_theme_font_size_override("font_size", 22)
		card.add_child(p_title)
		
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
		key_hint.text = "Taste [%d]: Modus\nTaste [%s]: Team wechseln" % [i + 1, team_keys[i]]
		key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_hint.position = Vector2(10, 270)
		key_hint.size = Vector2(col_width - 20, 60)
		key_hint.add_theme_font_size_override("font_size", 16)
		key_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		card.add_child(key_hint)
	
	_update_lobby_ui()
	canvas.add_child(ui_lobby_panel)
	add_child(canvas)

func _update_lobby_ui() -> void:
	for i in range(players.size()):
		var p = players[i]
		ui_slot_labels[i].text = _get_control_type_name(p.control_type)
		if p.team_id == 1:
			ui_team_labels[i].text = "TEAM ROT (1)"
			ui_team_labels[i].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			ui_team_labels[i].text = "TEAM BLAU (2)"
			ui_team_labels[i].add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))

func _get_control_type_name(ct: CagePlayer.ControlType) -> String:
	match ct:
		CagePlayer.ControlType.OFF:
			return "[ INAKTIV ]\n(OFF)"
		CagePlayer.ControlType.HUMAN_KB1:
			return "SPIELER\n(Tastatur 1: WASD + Space/Shift)"
		CagePlayer.ControlType.HUMAN_KB2:
			return "SPIELER\n(Tastatur 2: Pfeile + Enter/Ctrl)"
		CagePlayer.ControlType.GAMEPAD_0:
			return "SPIELER\n(Gamepad 1: Stick + A/B)"
		CagePlayer.ControlType.GAMEPAD_1:
			return "SPIELER\n(Gamepad 2: Stick + A/B)"
		CagePlayer.ControlType.GAMEPAD_2:
			return "SPIELER\n(Gamepad 3: Stick + A/B)"
		CagePlayer.ControlType.GAMEPAD_3:
			return "SPIELER\n(Gamepad 4: Stick + A/B)"
		CagePlayer.ControlType.AI_BOT:
			return "KI-BOT\n(Autonomes Dribbeln & Zıplama)"
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
			elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				start_match_from_lobby()
		else:
			if event.keycode == KEY_ESCAPE:
				return_to_lobby()
			elif event.keycode == KEY_B:
				toggle_p2_bot()

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
		ui_banner_label.text = "Mindestens 1 Spieler pro Team erforderlich!"
		return
	
	ui_lobby_panel.visible = false
	ui_hud_container.visible = true
	reset_positions()
	state_manager.start_match()

func return_to_lobby() -> void:
	for p in players:
		p.freeze = true
	if ball:
		ball.freeze = true
	state_manager.enter_lobby()
	ui_lobby_panel.visible = true
	_update_lobby_ui()

func _process(delta: float) -> void:
	if state_manager:
		state_manager.update_logic(delta)
	
	if state_manager.current_state == CageStateManager.MatchState.WARMUP:
		var sec = int(ceil(state_manager.warmup_timer))
		if sec > 0:
			ui_banner_label.text = str(sec)
		else:
			ui_banner_label.text = "⚽ KICK OFF! ⚽"
	
	if Input.is_action_just_pressed("restart") and state_manager.current_state != CageStateManager.MatchState.LOBBY:
		restart_game()

func restart_game() -> void:
	reset_positions()
	state_manager.reset_match()

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
			for p in players:
				if p.control_type != CagePlayer.ControlType.OFF:
					p.freeze = false
			if ball:
				ball.freeze = false
		CageStateManager.MatchState.GOAL_SCORED, CageStateManager.MatchState.CELEBRATION:
			ui_banner_label.visible = true
			if state_manager.last_scoring_team == 1:
				ui_banner_label.text = "⚽ GOOOOAL TEAM RED! ⚽"
			elif state_manager.last_scoring_team == 2:
				ui_banner_label.text = "⚽ GOOOOAL TEAM BLUE! ⚽"
			else:
				ui_banner_label.text = "⚽ GOOOOAL! ⚽"
			if ball:
				ball.linear_velocity *= 0.2
		CageStateManager.MatchState.RESET:
			reset_positions()
		CageStateManager.MatchState.MATCH_OVER:
			ui_banner_label.visible = true
			var w = state_manager.get_winner()
			if w == 1:
				ui_banner_label.text = "🏆 TEAM RED WINS! 🏆"
			elif w == 2:
				ui_banner_label.text = "🏆 TEAM BLUE WINS! 🏆"
			else:
				ui_banner_label.text = "DRAW! Press [R] to rematch"

func _on_score_updated(_team_id: int, _new_score: int) -> void:
	_update_score_label()

func _on_timer_updated(time_remaining: float) -> void:
	if ui_timer_label:
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		ui_timer_label.text = "%02d:%02d" % [mins, secs]

