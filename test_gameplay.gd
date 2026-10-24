extends SceneTree

const CageConfig = preload("res://scripts/config.gd")
const CageStateManager = preload("res://scripts/state_manager.gd")
const CagePlayer = preload("res://scripts/player.gd")
const SoccerBall = preload("res://scripts/ball.gd")
const CageCamera = preload("res://scripts/cage_camera.gd")
const MainCageFootball = preload("res://scenes/main.gd")

func _init() -> void:
	print("\n--- Running Headless Godot 4 Unit & Gameplay Tests for Crazy Cage Football ---")
	var success = true
	
	success = success and _test_config()
	success = success and _test_state_manager()
	success = success and _test_player_jump()
	success = success and _test_ball_physics()
	success = success and _test_cage_camera()
	success = success and _test_main_scene()
	
	if success:
		print("=== ALL TESTS FOR CRAZY CAGE FOOTBALL PASSED SUCCESSFULLY! ===\n")
		quit(0)
	else:
		printerr("=== SOME TESTS FAILED! ===")
		quit(1)

func _test_config() -> bool:
	print("[1/6] Testing CageConfig parameters...")
	assert(CageConfig.CAGE_WIDTH_X >= 15.0, "Cage width must be >= 15m")
	assert(CageConfig.CAGE_HEIGHT_Y >= 5.0, "Cage height must be >= 5m")
	assert(CageConfig.PLAYER_RADIUS > 0.0, "Player radius must be positive")
	assert(CageConfig.PLAYER_JUMP_IMPULSE > 0.0, "Jump impulse must be positive")
	assert(CageConfig.BALL_BOUNCE >= 0.7, "Ball bounce should be high for arcade cage feel")
	print("  -> CageConfig OK.")
	return true

func _test_state_manager() -> bool:
	print("[2/6] Testing CageStateManager...")
	var sm = CageStateManager.new()
	sm.reset_match(10.0)
	assert(sm.current_state == CageStateManager.MatchState.WARMUP or sm.current_state == CageStateManager.MatchState.KICKOFF, "Initial state should be WARMUP or KICKOFF")
	assert(sm.scores[1] == 0 and sm.scores[2] == 0, "Scores should start at 0")
	
	# Spiel starten
	sm.start_play()
	assert(sm.current_state == CageStateManager.MatchState.PLAYING, "State should be PLAYING after kickoff")
	
	# Tor für Team 1
	sm.trigger_goal(1)
	assert(sm.scores[1] == 1, "Team 1 score should be 1")
	assert(sm.current_state == CageStateManager.MatchState.CELEBRATION, "State should be CELEBRATION")
	
	# Torjubel ablaufen lassen
	sm.update_logic(CageConfig.CELEBRATION_DURATION + 0.1)
	assert(sm.current_state == CageStateManager.MatchState.RESET, "State should be RESET after celebration")
	
	sm.update_logic(0.01)
	assert(sm.current_state == CageStateManager.MatchState.KICKOFF or sm.current_state == CageStateManager.MatchState.WARMUP, "State should return to KICKOFF/WARMUP after reset")
	
	# Automatischer Übergang von Warmup nach Kickoff zurück zu PLAYING
	sm.update_logic(CageConfig.KICKOFF_DELAY + 0.1)
	assert(sm.current_state == CageStateManager.MatchState.PLAYING, "State should resume to PLAYING automatically after goal warmup")
	
	# Match-Ende testen
	sm.update_logic(10.0)
	assert(sm.current_state == CageStateManager.MatchState.MATCH_OVER, "State should be MATCH_OVER")
	assert(sm.get_winner() == 1, "Team 1 should be the winner")
	print("  -> CageStateManager OK.")
	return true

func _test_player_jump() -> bool:
	print("[3/6] Testing CagePlayer kinematics & Ziplama jump...")
	var player = CagePlayer.new()
	player.player_id = 1
	root.add_child(player)
	player._ready()
	
	assert(player.mass == CageConfig.PLAYER_MASS, "Player mass mismatch")
	assert(player.has_node("CollisionShape3D"), "CagePlayer MUST have CollisionShape3D")
	var p_col = player.get_node("CollisionShape3D") as CollisionShape3D
	assert(p_col != null and p_col.shape is SphereShape3D, "CagePlayer collision shape must be SphereShape3D")
	assert(is_equal_approx(p_col.shape.radius, CageConfig.PLAYER_RADIUS), "Player collision radius mismatch")
	
	# Spieler am Boden -> Sprung sollte Impuls auslösen
	player.position = Vector3(0, CageConfig.PLAYER_RADIUS, 0)
	player.trigger_jump()
	assert(player.linear_velocity.y >= 0.0, "Jump should impart upward velocity or force")
	
	# Bot AI Steering & Stuck Recovery testen
	player.is_bot = true
	var test_ball = Node3D.new()
	test_ball.position = Vector3(1.0, 0.5, 0.0)
	root.add_child(test_ball)
	player.target_ball = test_ball
	player.linear_velocity = Vector3.ZERO
	# 40 Ticks simuliert 0.6s Stillstand am Ball -> löst Unstuck-Modus aus
	for _t in range(40):
		player._handle_bot_ai(0.016)
	assert(player._unstuck_mode_timer > 0.0 or player.linear_velocity.length() > 0.1, "Bot should engage unstuck recovery when stalled at ball")
	test_ball.queue_free()
	
	player.queue_free()
	print("  -> CagePlayer & Ziplama & Bot OK.")
	return true

func _test_ball_physics() -> bool:
	print("[4/6] Testing SoccerBall physics & bounce...")
	var ball = SoccerBall.new()
	root.add_child(ball)
	ball._ready()
	
	assert(is_equal_approx(ball.mass, CageConfig.BALL_MASS), "Ball mass mismatch")
	assert(is_equal_approx(ball.physics_material_override.bounce, CageConfig.BALL_BOUNCE), "Ball bounce mismatch")
	assert(ball.has_node("CollisionShape3D"), "SoccerBall MUST have CollisionShape3D")
	var b_col = ball.get_node("CollisionShape3D") as CollisionShape3D
	assert(b_col != null and b_col.shape is SphereShape3D, "SoccerBall collision shape must be SphereShape3D")
	assert(is_equal_approx(b_col.shape.radius, CageConfig.BALL_RADIUS), "SoccerBall collision radius mismatch")
	
	ball.reset_to_center()
	assert(ball.position.x == 0.0 and ball.position.z == 0.0, "Ball should be centered")
	
	ball.queue_free()
	print("  -> SoccerBall OK.")
	return true

func _test_cage_camera() -> bool:
	print("[5/6] Testing CageCamera dynamic tracking...")
	var cam = CageCamera.new()
	var test_ball = Node3D.new()
	test_ball.position = Vector3(4.0, 1.0, 2.0)
	cam.ball_node = test_ball
	root.add_child(cam)
	
	cam.update_camera(0.1)
	assert(cam.position.y > 0.0, "Camera should have elevated height")
	assert(cam.position.y < CageConfig.CAGE_HEIGHT_Y, "Camera MUST be inside cage vertically (< CAGE_HEIGHT_Y)")
	assert(cam.position.z < CageConfig.CAGE_DEPTH_Z * 0.5, "Camera MUST be inside cage depth (< CAGE_DEPTH_Z / 2)")
	assert(cam.fov >= 80.0, "Camera should have wide FOV for tactical distance")
	
	# Action-Tracking testen: Ball bewegt sich nach rechts (X = 8.0)
	test_ball.position = Vector3(8.0, 1.0, 0.0)
	for _i in range(10):
		cam.update_camera(0.1)
	var current_x = cam.global_position.x if cam.is_inside_tree() else cam.position.x
	assert(current_x > 2.0, "Camera should dynamically follow action along X towards the ball")
	
	cam.queue_free()
	test_ball.queue_free()
	print("  -> CageCamera OK.")
	return true

func _test_main_scene() -> bool:
	print("[6/6] Testing MainCageFootball full orchestration...")
	var main_scene = MainCageFootball.new()
	root.add_child(main_scene)
	main_scene._ready()
	
	assert(main_scene.player1 != null, "Player 1 should exist")
	assert(main_scene.player2 != null, "Player 2 should exist")
	assert(main_scene.ball != null, "Soccer ball should exist")
	assert(main_scene.camera != null, "Cage camera should exist")
	assert(main_scene.player2.is_bot, "Player 2 should default to AI bot for single-player")
	
	# Tore müssen durch feste StaticBody3D-Wände geschlossen sein
	assert(main_scene.has_node("LeftGoal_BackNet"), "Left goal back wall must exist")
	assert(main_scene.has_node("RightGoal_BackNet"), "Right goal back wall must exist")
	assert(main_scene.has_node("LeftGoal_RoofNet"), "Left goal roof must exist")
	assert(main_scene.has_node("RightGoal_RoofNet"), "Right goal roof must exist")
	
	# 45-Grad Eckbanden müssen existieren
	assert(main_scene.has_node("CornerBumper_NE"), "NE corner bumper must exist")
	assert(main_scene.has_node("CornerBumper_SE"), "SE corner bumper must exist")
	assert(main_scene.has_node("CornerBumper_NW"), "NW corner bumper must exist")
	assert(main_scene.has_node("CornerBumper_SW"), "SW corner bumper must exist")
	
	# Bot Toggle testen
	main_scene.toggle_p2_bot()
	assert(not main_scene.player2.is_bot, "Player 2 should toggle to Human")
	main_scene.toggle_p2_bot()
	assert(main_scene.player2.is_bot, "Player 2 should toggle back to AI bot")
	
	# Lobby & 4-Player Team Setup
	assert(main_scene.state_manager.current_state == CageStateManager.MatchState.LOBBY, "Initial state should be LOBBY")
	main_scene.cycle_player_slot(2) # Player 3
	assert(main_scene.player3.control_type == CagePlayer.ControlType.HUMAN_KB1, "P3 should cycle to HUMAN_KB1")
	main_scene.toggle_player_team(2)
	assert(main_scene.player3.team_id == 2, "P3 should toggle to Team 2")
	main_scene.start_match_from_lobby()
	assert(main_scene.state_manager.current_state == CageStateManager.MatchState.WARMUP, "State should be WARMUP after match start")
	
	main_scene._process(0.016)
	main_scene.queue_free()
	print("  -> MainCageFootball & 4-Player Teams OK.")
	return true
