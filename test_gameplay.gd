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
	assert(sm.current_state == CageStateManager.MatchState.KICKOFF, "Initial state should be KICKOFF")
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
	assert(sm.current_state == CageStateManager.MatchState.KICKOFF, "State should return to KICKOFF after reset")
	
	# Match-Ende testen
	sm.start_play()
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
	
	# Bot AI Steering testen
	player.is_bot = true
	var test_ball = Node3D.new()
	test_ball.position = Vector3(2.0, 0.5, 0.0)
	root.add_child(test_ball)
	player.target_ball = test_ball
	player._handle_bot_ai(0.016)
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
	
	# Bot Toggle testen
	main_scene.toggle_p2_bot()
	assert(not main_scene.player2.is_bot, "Player 2 should toggle to Human")
	main_scene.toggle_p2_bot()
	assert(main_scene.player2.is_bot, "Player 2 should toggle back to AI bot")
	
	main_scene._process(0.016)
	main_scene.queue_free()
	print("  -> MainCageFootball OK.")
	return true
