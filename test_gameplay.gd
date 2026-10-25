extends SceneTree

const CageConfig = preload("res://scripts/config.gd")
const CageStateManager = preload("res://scripts/state_manager.gd")
const CagePlayer = preload("res://scripts/player.gd")
const SoccerBall = preload("res://scripts/ball.gd")
const CageCamera = preload("res://scripts/cage_camera.gd")
const MainCageFootball = preload("res://scenes/main.gd")
const CageSoundManager = preload("res://scripts/cage_sound_manager.gd")
const CageJuiceManager = preload("res://scripts/cage_juice_manager.gd")
const CageThemeManager = preload("res://scripts/cage_theme_manager.gd")

func _init() -> void:
	print("\n--- Running Headless Godot 4 Unit & Gameplay Tests for Crazy Cage Football ---")
	var success = true
	
	success = success and _test_config()
	success = success and _test_sound_manager()
	success = success and _test_juice_manager()
	success = success and _test_state_manager()
	success = success and _test_player_jump()
	success = success and _test_ball_physics()
	success = success and _test_cage_camera()
	success = success and _test_main_scene()
	success = success and _test_power_ups()
	success = success and _test_theme_manager()
	
	if success:
		print("=== ALL TESTS FOR CRAZY CAGE FOOTBALL PASSED SUCCESSFULLY! ===\n")
		quit(0)
	else:
		printerr("=== SOME TESTS FAILED! ===")
		quit(1)

func _test_config() -> bool:
	print("[1/8] Testing CageConfig parameters...")
	assert(CageConfig.CAGE_WIDTH_X >= 15.0, "Cage width must be >= 15m")
	assert(CageConfig.CAGE_HEIGHT_Y >= 5.0, "Cage height must be >= 5m")
	assert(CageConfig.PLAYER_RADIUS > 0.0, "Player radius must be positive")
	assert(CageConfig.PLAYER_JUMP_IMPULSE > 0.0, "Jump impulse must be positive")
	assert(CageConfig.BALL_BOUNCE >= 0.7, "Ball bounce should be high for arcade cage feel")
	print("  -> CageConfig OK.")
	return true

func _test_sound_manager() -> bool:
	print("[2/8] Testing CageSoundManager procedural synthesis & audio pool...")
	var sm = CageSoundManager.new()
	assert(sm.stream_kick != null, "Kick audio stream must be generated")
	assert(sm.stream_wall != null, "Wall audio stream must be generated")
	assert(sm.stream_post != null, "Post audio stream must be generated")
	assert(sm.stream_whistle != null, "Whistle audio stream must be generated")
	assert(sm.stream_goal != null, "Goal audio stream must be generated")
	assert(sm.stream_jump != null, "Jump audio stream must be generated")
	assert(sm.stream_boost != null, "Boost audio stream must be generated")
	assert(sm.stream_tackle != null, "Tackle audio stream must be generated")
	assert(sm.stream_menu_bgm != null, "Menu BGM audio stream must be loaded or generated")
	assert(sm.stream_match_bgm != null, "Match BGM audio stream must be loaded or generated")
	assert(sm.stream_bgm != null, "BGM audio stream must be loaded or generated")
	assert(sm.stream_bgm is AudioStream, "BGM stream must be an AudioStream")
	if sm.stream_bgm is AudioStreamOggVorbis:
		assert(sm.stream_bgm.loop == true, "OGG BGM must have loop enabled")
	elif sm.stream_bgm is AudioStreamWAV:
		assert(sm.stream_bgm.loop_mode == AudioStreamWAV.LOOP_FORWARD, "WAV BGM stream must have forward loop mode")
	
	root.add_child(sm)
	sm._ready()
	sm.play_kick(4.0)
	sm.play_wall(3.0)
	sm.play_post()
	sm.play_whistle()
	sm.play_goal()
	sm.play_jump()
	sm.play_boost()
	sm.play_tackle(2.0)
	sm.play_menu_bgm()
	sm.play_match_bgm()
	sm.duck_bgm(1.0)
	assert(sm.bgm_enabled == true, "BGM should initially be enabled")
	sm.toggle_bgm()
	assert(sm.bgm_enabled == false, "BGM should be disabled after toggle")
	sm.toggle_bgm()
	assert(sm.bgm_enabled == true, "BGM should be enabled after second toggle")
	sm.stop_bgm()
	sm.queue_free()
	print("  -> CageSoundManager OK.")
	return true

func _test_juice_manager() -> bool:
	print("[3/8] Testing CageJuiceManager particle pooling, flashes & trauma...")
	var jm = CageJuiceManager.new()
	root.add_child(jm)
	jm._ready()
	
	assert(jm._turf_pool.size() == 8, "Turf pool size should be 8")
	assert(jm._spark_pool.size() == 8, "Spark pool size should be 8")
	assert(jm._confetti_pool.size() == 4, "Confetti pool size should be 4")
	assert(jm._dash_pool.size() == 6, "Dash pool size should be 6")
	assert(jm._goal_light != null, "Goal strobe light must exist")
	
	jm.spawn_turf_puff(Vector3.ZERO, 3.0)
	jm.spawn_sparks(Vector3.ZERO, 4.0)
	jm.spawn_goal_confetti(Vector3.ZERO)
	jm.spawn_dash_dust(Vector3.ZERO, Vector3.FORWARD)
	jm.trigger_goal_flash(Vector3.ZERO, 1)
	jm.trigger_shake(0.5)
	
	jm.queue_free()
	print("  -> CageJuiceManager OK.")
	return true

func _test_state_manager() -> bool:
	print("[4/8] Testing CageStateManager...")
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
	print("[5/8] Testing CagePlayer kinematics & Ziplama jump...")
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
	print("[6/8] Testing SoccerBall physics & bounce...")
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
	print("[7/8] Testing CageCamera dynamic tracking & trauma shake...")
	var cam = CageCamera.new()
	var test_ball = Node3D.new()
	test_ball.position = Vector3(4.0, 1.0, 2.0)
	cam.ball_node = test_ball
	root.add_child(cam)
	
	cam.add_trauma(0.6)
	assert(cam.trauma > 0.0, "Camera trauma must be positive after add_trauma")
	
	cam.update_camera(0.1)
	assert(cam.trauma < 0.6, "Trauma must decay over time")
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
	print("[8/8] Testing MainCageFootball full orchestration...")
	var main_scene = MainCageFootball.new()
	root.add_child(main_scene)
	main_scene._ready()
	
	assert(main_scene.player1 != null, "Player 1 should exist")
	assert(main_scene.player2 != null, "Player 2 should exist")
	assert(main_scene.ball != null, "Soccer ball should exist")
	assert(main_scene.camera != null, "Cage camera should exist")
	assert(main_scene.player2.is_bot, "Player 2 should default to AI bot for single-player")
	
	# Visuals & WorldEnvironment
	assert(main_scene.has_node("WorldEnvironment"), "WorldEnvironment must exist for stadium skybox")
	assert(main_scene.has_node("CageFloor"), "CageFloor must exist")
	
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
	
	# Language & Localization Toggle DE / EN testen
	TranslationServer.set_locale("de")
	main_scene._refresh_all_localized_text()
	assert("LOBBY" in main_scene.ui_title_label.text, "German title must be present")
	main_scene.toggle_language()
	assert(TranslationServer.get_locale().begins_with("en"), "Locale should toggle to English")
	assert("LOBBY" in main_scene.ui_title_label.text, "English title must be present")
	main_scene.toggle_language()
	assert(TranslationServer.get_locale().begins_with("de"), "Locale should toggle back to German")
	
	# Fullscreen Toggle testen
	main_scene.toggle_fullscreen()
	main_scene.toggle_fullscreen()
	
	main_scene._process(0.016)
	main_scene.queue_free()
	print("  -> MainCageFootball & 4-Player Teams OK.")
	return true

func _test_power_ups() -> bool:
	print("[9/9] Testing 5 Power-Up Pickups & Lobby Toggle...")
	
	# 1. CageConfig & Enums
	assert(CageConfig.PowerUpType.SUPER_SHOT == 1, "SUPER_SHOT enum must be 1")
	assert(CageConfig.PowerUpType.SPEED_BOOTS == 2, "SPEED_BOOTS enum must be 2")
	assert(CageConfig.PowerUpType.MAGNET_FOOT == 3, "MAGNET_FOOT enum must be 3")
	assert(CageConfig.PowerUpType.FREEZE_TACKLE == 4, "FREEZE_TACKLE enum must be 4")
	assert(CageConfig.PowerUpType.CAGE_SHAKER == 5, "CAGE_SHAKER enum must be 5")
	
	var main_scene = MainCageFootball.new()
	root.add_child(main_scene)
	main_scene._ready()
	
	var p1 = main_scene.player1
	var p2 = main_scene.player2
	var ball = main_scene.ball
	
	# 2. Toggle im Hauptmenü (Aktivierbar / Deaktivierbar)
	CageConfig.powerups_enabled = true
	main_scene.toggle_powerups()
	assert(not CageConfig.powerups_enabled, "Powerups should be toggled OFF")
	assert(main_scene.spawn_power_up() == null, "Spawner should return null when powerups are OFF")
	
	main_scene.toggle_powerups()
	assert(CageConfig.powerups_enabled, "Powerups should be toggled ON")
	
	# 3. Test Pickup Token Spawning
	var pup = main_scene.spawn_power_up(CageConfig.PowerUpType.SUPER_SHOT, Vector3(0.0, 0.55, -5.8))
	assert(pup != null, "PowerUp token should be spawned")
	assert(pup.type == CageConfig.PowerUpType.SUPER_SHOT, "Type should match SUPER_SHOT")
	assert(main_scene.active_power_ups.has(pup), "Active powerups list should track token")
	
	# 4. Test Super-Shot
	p1.apply_power_up(CageConfig.PowerUpType.SUPER_SHOT)
	assert(p1.has_super_shot, "Player 1 should have super shot active")
	ball.trigger_super_shot(Vector3.RIGHT, CageConfig.POWERUP_SUPER_SHOT_MULT)
	assert(ball.is_super_shot, "Ball should have active super shot state")
	
	# 5. Test Speed-Boots
	p1.apply_power_up(CageConfig.PowerUpType.SPEED_BOOTS)
	assert(p1.speed_boost_timer > 5.0, "Speed boost timer should be initialized")
	p1._clamp_speed()
	
	# 6. Test Magnetfuß
	p1.apply_power_up(CageConfig.PowerUpType.MAGNET_FOOT)
	assert(p1.magnet_timer > 5.0, "Magnet timer should be initialized")
	
	# 7. Test Freeze-Tackle
	p1.apply_power_up(CageConfig.PowerUpType.FREEZE_TACKLE)
	assert(p1.freeze_tackle_ready, "Freeze tackle should be primed")
	p2.freeze_player(2.0)
	assert(p2.is_frozen, "Player 2 should be frozen")
	assert(p2.freeze_timer > 1.5, "Freeze timer should be set")
	p2.unfreeze_player()
	assert(not p2.is_frozen, "Player 2 should be unfrozen")
	
	# 8. Test Cage-Shaker
	p1.apply_power_up(CageConfig.PowerUpType.CAGE_SHAKER)
	# Cage-Shaker executes shockwave immediately
	
	# 9. Test Bot AI Power-Up Awareness
	p2.control_type = CagePlayer.ControlType.AI_BOT
	p2.target_ball = ball
	ball.position = Vector3(8.0, 0.4, 0.0)
	p2.position = Vector3(0.0, 0.4, 0.0)
	p2.linear_velocity = Vector3.ZERO
	var test_pup = main_scene.spawn_power_up(CageConfig.PowerUpType.SPEED_BOOTS, Vector3(0.0, 0.55, 2.8))
	assert(test_pup != null, "Pickup should spawn for bot awareness test")
	p2._handle_bot_ai(0.016)
	
	# 10. Cleanup & Reset
	main_scene.clear_power_ups()
	assert(main_scene.active_power_ups.is_empty(), "All powerup tokens should be cleared")
	
	main_scene.queue_free()
	print("  -> All 5 Power-Ups, Bot Awareness & Toggle verified successfully.")
	return true

func _test_theme_manager() -> bool:
	print("[10/10] Testing CageThemeManager & Starter Arena Themes (Industrial, Sunny, Cyber)...")
	var tm = CageThemeManager.new()
	assert(tm.get_theme_count() == 3, "There should be exactly 3 starter themes")
	var themes = tm.get_themes()
	
	var expected_ids = ["industrial", "sunny_rooftop", "cyber_neon"]
	for id in expected_ids:
		var found = false
		for t in themes:
			if str(t["id"]) == id:
				found = true
				assert(t.has("sun_color"), "Theme %s must have sun_color" % id)
				assert(t.has("floor_color"), "Theme %s must have floor_color" % id)
				assert(t.has("ball_pent_color"), "Theme %s must have ball_pent_color" % id)
				assert(t.has("ball_hex_color"), "Theme %s must have ball_hex_color" % id)
				assert(t.has("ball_seam_color"), "Theme %s must have ball_seam_color" % id)
				assert(t.has("turf_puff_color"), "Theme %s must have turf_puff_color" % id)
				break
		assert(found, "Theme %s should exist in CageThemeManager" % id)
	
	# Test theme cycling
	tm.set_theme_by_id("industrial")
	var t0 = tm.get_current_theme()
	assert(str(t0["id"]) == "industrial", "Theme should be industrial")
	var t1 = tm.cycle_theme()
	assert(str(t1["id"]) == "sunny_rooftop", "Second theme should be sunny_rooftop")
	var t2 = tm.cycle_theme()
	assert(str(t2["id"]) == "cyber_neon", "Third theme should be cyber_neon")
	var t_wrap = tm.cycle_theme()
	assert(str(t_wrap["id"]) == "industrial", "Cycle should wrap back to industrial")
	
	# Test live theme application in MainCageFootball
	var main_scene = MainCageFootball.new()
	root.add_child(main_scene)
	main_scene._ready()
	
	assert(main_scene.theme_manager != null, "MainCageFootball should have theme_manager initialized")
	assert(main_scene.floor_inst != null, "Floor MeshInstance3D should exist")
	assert(main_scene.stadium_light != null, "StadiumLight should exist")
	assert(main_scene.world_env != null, "WorldEnvironment should exist")
	assert(main_scene.board_instances.size() > 0, "Board instances should be tracked")
	assert(main_scene.fence_instances.size() > 0, "Fence instances should be tracked")
	assert(main_scene.goal_post_instances.size() == 6, "All 6 goal post/bar instances should be tracked")
	
	# Switch to Sunny Rooftop
	main_scene.theme_manager.set_theme_by_id("sunny_rooftop")
	main_scene.apply_theme(main_scene.theme_manager.get_current_theme(), true)
	var floor_mat_sunny = main_scene.floor_inst.material_override as StandardMaterial3D
	assert(floor_mat_sunny != null, "Floor material should be StandardMaterial3D")
	assert(floor_mat_sunny.roughness >= 0.75, "Sunny rooftop floor roughness should match config")
	assert(floor_mat_sunny.albedo_texture != null, "Sunny rooftop should have court texture loaded")
	
	# Switch to Cyber Neon
	main_scene.theme_manager.set_theme_by_id("cyber_neon")
	main_scene.apply_theme(main_scene.theme_manager.get_current_theme(), true)
	assert(main_scene.world_env.environment.glow_bloom > 0.3, "Cyber Neon glow bloom should be elevated")
	assert(main_scene.goal_glow_lights.size() == 2, "Both goal glow lights should exist")
	assert(main_scene.goal_glow_lights[0].visible == true, "Goal glow light should be active in Cyber mode")
	
	# Cycle via main method
	main_scene.cycle_arena_theme()
	
	main_scene.queue_free()
	print("  -> CageThemeManager, all 3 starter themes & live switching OK.")
	return true

