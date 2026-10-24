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
var ball: SoccerBall
var camera: CageCamera
var whistle_player: AudioStreamPlayer

var ui_score_label: Label
var ui_timer_label: Label
var ui_banner_label: Label

func _ready() -> void:
	state_manager = CageStateManager.new()
	state_manager.state_changed.connect(_on_state_changed)
	state_manager.score_updated.connect(_on_score_updated)
	state_manager.timer_updated.connect(_on_timer_updated)
	
	_build_audio()
	_build_scene()
	_build_ui()
	
	state_manager.reset_match()

func _build_audio() -> void:
	whistle_player = AudioStreamPlayer.new()
	whistle_player.name = "WhistleAudio"
	if ResourceLoader.exists("res://audio/duduk.wav"):
		whistle_player.stream = load("res://audio/duduk.wav")
	add_child(whistle_player)

func _build_scene() -> void:
	# 1. Umwelt & Licht
	var sun = DirectionalLight3D.new()
	sun.name = "StadiumLight"
	sun.position = Vector3(15, 25, 15)
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.shadow_enabled = true
	add_child(sun)
	
	# 2. Boden (Stahl-Riffelblech Look)
	var floor_body = StaticBody3D.new()
	floor_body.name = "CageFloor"
	var floor_col = CollisionShape3D.new()
	var floor_box = BoxMesh.new()
	floor_box.size = Vector3(CageConfig.CAGE_WIDTH_X + 4.0, 0.4, CageConfig.CAGE_DEPTH_Z + 4.0)
	floor_col.shape = BoxShape3D.new()
	floor_col.shape.size = floor_box.size
	floor_body.add_child(floor_col)
	
	var floor_inst = MeshInstance3D.new()
	floor_inst.mesh = floor_box
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.32, 0.36) # Steel metallic
	floor_mat.metallic = 0.6
	floor_mat.roughness = 0.4
	floor_inst.material_override = floor_mat
	floor_body.add_child(floor_inst)
	add_child(floor_body)
	
	# 3. Käfig-Wände & Decke
	_build_wall(Vector3(0, CageConfig.CAGE_HEIGHT_Y * 0.5, -CageConfig.CAGE_DEPTH_Z * 0.5), Vector3(CageConfig.CAGE_WIDTH_X, CageConfig.CAGE_HEIGHT_Y, CageConfig.WALL_THICKNESS), "BackWall")
	_build_wall(Vector3(0, CageConfig.CAGE_HEIGHT_Y * 0.5, CageConfig.CAGE_DEPTH_Z * 0.5), Vector3(CageConfig.CAGE_WIDTH_X, CageConfig.CAGE_HEIGHT_Y, CageConfig.WALL_THICKNESS), "FrontWall")
	_build_wall(Vector3(0, CageConfig.CAGE_HEIGHT_Y, 0), Vector3(CageConfig.CAGE_WIDTH_X, CageConfig.WALL_THICKNESS, CageConfig.CAGE_DEPTH_Z), "Ceiling")
	
	# Seitenwände mit Torausschnitten
	_build_side_wall(-1, "LeftWall")
	_build_side_wall(1, "RightWall")
	
	# 4. Tore mit Area3D
	_build_goal(-1, 2) # Tor links (Team 2 verteidigt, Team 1 punktet)
	_build_goal(1, 1)  # Tor rechts (Team 1 verteidigt, Team 2 punktet)
	
	# 5. Fußball
	ball = SoccerBall.new()
	ball.name = "SoccerBall"
	ball.position = Vector3(0.0, CageConfig.BALL_RADIUS + 0.1, 0.0)
	add_child(ball)
	
	# 6. Spieler 1 (Rot) & Spieler 2 (Blau)
	player1 = CagePlayer.new()
	player1.name = "Player1_Red"
	player1.player_id = 1
	player1.ball_color = Color(0.95, 0.2, 0.2)
	player1.position = Vector3(-6.0, CageConfig.PLAYER_RADIUS, 0.0)
	player1.target_ball = ball
	add_child(player1)
	
	player2 = CagePlayer.new()
	player2.name = "Player2_Blue"
	player2.player_id = 2
	player2.ball_color = Color(0.2, 0.55, 0.95)
	player2.position = Vector3(6.0, CageConfig.PLAYER_RADIUS, 0.0)
	player2.target_ball = ball
	add_child(player2)
	
	# 7. Cage Camera
	camera = CageCamera.new()
	camera.name = "CageCamera"
	camera.position = Vector3(0, CageConfig.CAMERA_HEIGHT, CageConfig.CAMERA_OFFSET_Z)
	camera.ball_node = ball
	camera.player1_node = player1
	camera.player2_node = player2
	camera.current = true
	add_child(camera)

func _build_wall(pos: Vector3, size: Vector3, wall_name: String) -> void:
	var body = StaticBody3D.new()
	body.name = wall_name
	body.position = pos
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.45, 0.5, 0.6) # Halbtransparenter Käfigzaun
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	add_child(body)

func _build_side_wall(side: int, wall_name: String) -> void:
	# Obere Wand über dem Tor
	var x_pos = side * CageConfig.CAGE_WIDTH_X * 0.5
	var top_h = CageConfig.CAGE_HEIGHT_Y - CageConfig.GOAL_HEIGHT
	_build_wall(Vector3(x_pos, CageConfig.GOAL_HEIGHT + top_h * 0.5, 0), Vector3(CageConfig.WALL_THICKNESS, top_h, CageConfig.CAGE_DEPTH_Z), wall_name + "_Top")
	
	# Zwei Flügelwände neben dem Tor
	var wing_z = (CageConfig.CAGE_DEPTH_Z - CageConfig.GOAL_WIDTH) * 0.5
	var z_offset = (CageConfig.GOAL_WIDTH + wing_z) * 0.5
	_build_wall(Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, -z_offset), Vector3(CageConfig.WALL_THICKNESS, CageConfig.GOAL_HEIGHT, wing_z), wall_name + "_WingNorth")
	_build_wall(Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, z_offset), Vector3(CageConfig.WALL_THICKNESS, CageConfig.GOAL_HEIGHT, wing_z), wall_name + "_WingSouth")

func _build_goal(side: int, scoring_team: int) -> void:
	var x_pos = side * (CageConfig.CAGE_WIDTH_X * 0.5 + CageConfig.GOAL_DEPTH * 0.5)
	
	# Tornetz-Trigger
	var area = Area3D.new()
	area.name = "GoalArea_Team%d" % scoring_team
	area.position = Vector3(x_pos, CageConfig.GOAL_HEIGHT * 0.5, 0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(CageConfig.GOAL_DEPTH, CageConfig.GOAL_HEIGHT, CageConfig.GOAL_WIDTH)
	col.shape = shape
	area.add_child(col)
	
	area.body_entered.connect(func(body: Node3D):
		if body is SoccerBall and state_manager.current_state == CageStateManager.MatchState.PLAYING:
			if whistle_player and whistle_player.stream:
				whistle_player.play()
			state_manager.trigger_goal(scoring_team)
	)
	add_child(area)

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "HUD"
	
	var ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui_root)
	
	# Score Center
	ui_score_label = Label.new()
	ui_score_label.text = "RED  0 : 0  BLUE"
	ui_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_score_label.position = Vector2(440, 20)
	ui_score_label.size = Vector2(400, 50)
	ui_score_label.add_theme_font_size_override("font_size", 38)
	ui_root.add_child(ui_score_label)
	
	# Timer
	ui_timer_label = Label.new()
	ui_timer_label.text = "03:00"
	ui_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_timer_label.position = Vector2(540, 75)
	ui_timer_label.size = Vector2(200, 35)
	ui_timer_label.add_theme_font_size_override("font_size", 24)
	ui_root.add_child(ui_timer_label)
	
	# Banner (Goal / Winner / Ready)
	ui_banner_label = Label.new()
	ui_banner_label.text = "KICK OFF! PRESS ANY KEY TO PLAY"
	ui_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_banner_label.position = Vector2(340, 310)
	ui_banner_label.size = Vector2(600, 80)
	ui_banner_label.add_theme_font_size_override("font_size", 36)
	ui_root.add_child(ui_banner_label)
	
	add_child(canvas)

func _process(delta: float) -> void:
	if state_manager:
		state_manager.update_logic(delta)
	
	# Erster Spiel-Start bei Bewegung
	if state_manager and state_manager.current_state == CageStateManager.MatchState.KICKOFF:
		if Input.is_action_just_pressed("p1_up") or Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_up") or Input.is_action_just_pressed("p1_jump") or Input.is_action_just_pressed("p2_jump"):
			state_manager.start_play()
	
	if Input.is_action_just_pressed("restart"):
		restart_game()

func restart_game() -> void:
	reset_positions()
	state_manager.reset_match()

func reset_positions() -> void:
	if player1:
		player1.reset_to(Vector3(-6.0, CageConfig.PLAYER_RADIUS, 0.0))
	if player2:
		player2.reset_to(Vector3(6.0, CageConfig.PLAYER_RADIUS, 0.0))
	if ball:
		ball.reset_to_center()

func _on_state_changed(new_state: CageStateManager.MatchState) -> void:
	if not ui_banner_label:
		return
	match new_state:
		CageStateManager.MatchState.KICKOFF:
			ui_banner_label.visible = true
			ui_banner_label.text = "KICK OFF!"
		CageStateManager.MatchState.PLAYING:
			ui_banner_label.visible = false
		CageStateManager.MatchState.GOAL_SCORED, CageStateManager.MatchState.CELEBRATION:
			ui_banner_label.visible = true
			ui_banner_label.text = "⚽ GOOOOAL! ⚽"
		CageStateManager.MatchState.RESET:
			reset_positions()
		CageStateManager.MatchState.MATCH_OVER:
			ui_banner_label.visible = true
			var w = state_manager.get_winner()
			if w == 1:
				ui_banner_label.text = "🏆 RED WINS THE CAGE MATCH! 🏆"
			elif w == 2:
				ui_banner_label.text = "🏆 BLUE WINS THE CAGE MATCH! 🏆"
			else:
				ui_banner_label.text = "DRAW! Press R to rematch"

func _on_score_updated(_team_id: int, _new_score: int) -> void:
	if ui_score_label and state_manager:
		ui_score_label.text = "RED  %d : %d  BLUE" % [state_manager.scores[1], state_manager.scores[2]]

func _on_timer_updated(time_remaining: float) -> void:
	if ui_timer_label:
		var mins = int(time_remaining) / 60
		var secs = int(time_remaining) % 60
		ui_timer_label.text = "%02d:%02d" % [mins, secs]
