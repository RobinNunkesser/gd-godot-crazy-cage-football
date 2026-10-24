class_name CagePlayer
extends RigidBody3D

const CageConfig = preload("res://scripts/config.gd")

enum ControlType {
	OFF,
	HUMAN_KB1,
	HUMAN_KB2,
	GAMEPAD_0,
	GAMEPAD_1,
	GAMEPAD_2,
	GAMEPAD_3,
	AI_BOT
}

@export var player_id: int = 1
@export var team_id: int = 1 # 1 = Red (attacks right), 2 = Blue (attacks left)
@export var ball_color: Color = Color(0.9, 0.2, 0.2)
@export var control_type: ControlType = ControlType.HUMAN_KB1
@export var bot_difficulty: float = 1.0

var is_bot: bool:
	get:
		return control_type == ControlType.AI_BOT
	set(val):
		control_type = ControlType.AI_BOT if val else ControlType.HUMAN_KB1

var boost_cooldown: float = 0.0
var target_ball: Node3D = null

var _eyes_pivot: Node3D
var _mesh_instance: MeshInstance3D
var _pending_teleport: bool = false
var _teleport_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	mass = CageConfig.PLAYER_MASS
	linear_damp = 1.0
	angular_damp = 1.0
	
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = CageConfig.PLAYER_BOUNCE
	phys_mat.friction = CageConfig.PLAYER_FRICTION
	physics_material_override = phys_mat
	
	_setup_collision()
	_setup_visuals()

func _setup_collision() -> void:
	if not has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere = SphereShape3D.new()
		sphere.radius = CageConfig.PLAYER_RADIUS
		col.shape = sphere
		add_child(col)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		state.transform.origin = _teleport_target
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_teleport = false

func _setup_visuals() -> void:
	if not has_node("SphereMesh"):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "SphereMesh"
		var sphere = SphereMesh.new()
		sphere.radius = CageConfig.PLAYER_RADIUS
		sphere.height = CageConfig.PLAYER_RADIUS * 2.0
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = ball_color
		mat.roughness = 0.3
		mat.metallic = 0.2
		_mesh_instance.mesh = sphere
		_mesh_instance.material_override = mat
		add_child(_mesh_instance)
	
	if not has_node("EyesPivot"):
		_eyes_pivot = Node3D.new()
		_eyes_pivot.name = "EyesPivot"
		add_child(_eyes_pivot)
		
		# Zwei Comic-Augen
		for eye_x in [-0.2, 0.2]:
			var eye = MeshInstance3D.new()
			var eye_mesh = SphereMesh.new()
			eye_mesh.radius = 0.13
			eye_mesh.height = 0.26
			eye.mesh = eye_mesh
			eye.position = Vector3(eye_x, 0.25, -0.48)
			
			var eye_mat = StandardMaterial3D.new()
			eye_mat.albedo_color = Color.WHITE
			eye.material_override = eye_mat
			_eyes_pivot.add_child(eye)
			
			var pupil = MeshInstance3D.new()
			var pupil_mesh = SphereMesh.new()
			pupil_mesh.radius = 0.05
			pupil_mesh.height = 0.10
			pupil.mesh = pupil_mesh
			pupil.position = Vector3(0, 0, -0.10)
			var pupil_mat = StandardMaterial3D.new()
			pupil_mat.albedo_color = Color.BLACK
			pupil.material_override = pupil_mat
			eye.add_child(pupil)

func _physics_process(delta: float) -> void:
	if boost_cooldown > 0.0:
		boost_cooldown -= delta
	
	if is_bot:
		_handle_bot_ai(delta)
	else:
		_handle_input(delta)
	_clamp_speed()
	_update_eyes()

func _handle_bot_ai(_delta: float) -> void:
	if not is_instance_valid(target_ball):
		return
	
	var my_pos = global_position if is_inside_tree() else position
	var ball_pos = target_ball.global_position if (is_inside_tree() and target_ball.is_inside_tree()) else target_ball.position
	
	# Ziel-Tor: Team 1 (Rot) greift nach rechts (X > 0) an; Team 2 (Blau) greift nach links (X < 0) an.
	var goal_x = CageConfig.CAGE_WIDTH_X * 0.5 if team_id == 1 else -CageConfig.CAGE_WIDTH_X * 0.5
	var to_goal = Vector2(goal_x - ball_pos.x, 0.0).normalized()
	
	# Positioniere dich leicht hinter den Ball bezogen auf das Ziel-Tor
	var attack_spot = Vector2(ball_pos.x - to_goal.x * 0.8, ball_pos.z)
	var steer_vec = attack_spot - Vector2(my_pos.x, my_pos.z)
	var dist_to_ball = Vector2(ball_pos.x - my_pos.x, ball_pos.z - my_pos.z).length()
	
	if steer_vec.length_squared() > 0.01:
		steer_vec = steer_vec.normalized()
		var move_dir = Vector3(steer_vec.x, 0.0, steer_vec.y)
		apply_central_force(move_dir * CageConfig.PLAYER_DRIVE_FORCE * bot_difficulty)
	
	# Zıplama Sprung bei hoher Kugel in Tor-Nähe
	if dist_to_ball < 2.2 and ball_pos.y > 1.0:
		trigger_jump()
	
	# Boost / Rammstoß wenn Ball im Schussfeld liegt
	if dist_to_ball < 2.5 and boost_cooldown <= 0.0:
		var dir_to_ball = Vector2(ball_pos.x - my_pos.x, ball_pos.z - my_pos.z).normalized()
		if dir_to_ball.dot(to_goal) > 0.6:
			trigger_boost(dir_to_ball)

func _handle_input(_delta: float) -> void:
	if control_type == ControlType.OFF or control_type == ControlType.AI_BOT:
		return
	
	var input_vec = Vector2.ZERO
	var jump_pressed = false
	var boost_pressed = false
	
	match control_type:
		ControlType.HUMAN_KB1:
			if Input.is_action_pressed("p1_left") or Input.is_key_pressed(KEY_A):
				input_vec.x -= 1.0
			if Input.is_action_pressed("p1_right") or Input.is_key_pressed(KEY_D):
				input_vec.x += 1.0
			if Input.is_action_pressed("p1_up") or Input.is_key_pressed(KEY_W):
				input_vec.y -= 1.0
			if Input.is_action_pressed("p1_down") or Input.is_key_pressed(KEY_S):
				input_vec.y += 1.0
			jump_pressed = Input.is_action_just_pressed("p1_jump") or Input.is_key_pressed(KEY_SPACE)
			boost_pressed = Input.is_action_just_pressed("p1_boost") or Input.is_key_pressed(KEY_SHIFT)
			
		ControlType.HUMAN_KB2:
			if Input.is_action_pressed("p2_left") or Input.is_key_pressed(KEY_LEFT):
				input_vec.x -= 1.0
			if Input.is_action_pressed("p2_right") or Input.is_key_pressed(KEY_RIGHT):
				input_vec.x += 1.0
			if Input.is_action_pressed("p2_up") or Input.is_key_pressed(KEY_UP):
				input_vec.y -= 1.0
			if Input.is_action_pressed("p2_down") or Input.is_key_pressed(KEY_DOWN):
				input_vec.y += 1.0
			jump_pressed = Input.is_action_just_pressed("p2_jump") or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
			boost_pressed = Input.is_action_just_pressed("p2_boost") or Input.is_key_pressed(KEY_CTRL)
			
		ControlType.GAMEPAD_0, ControlType.GAMEPAD_1, ControlType.GAMEPAD_2, ControlType.GAMEPAD_3:
			var dev = int(control_type) - int(ControlType.GAMEPAD_0)
			var raw_x = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
			var raw_y = Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
			if absf(raw_x) > 0.2:
				input_vec.x = raw_x
			if absf(raw_y) > 0.2:
				input_vec.y = raw_y
			jump_pressed = Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
			boost_pressed = Input.is_joy_button_pressed(dev, JOY_BUTTON_B) or Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER)
	
	if input_vec.length_squared() > 0.01:
		input_vec = input_vec.normalized()
		var move_dir = Vector3(input_vec.x, 0.0, input_vec.y)
		apply_central_force(move_dir * CageConfig.PLAYER_DRIVE_FORCE)
	
	if jump_pressed:
		trigger_jump()
	if boost_pressed and boost_cooldown <= 0.0:
		trigger_boost(input_vec)

func set_control_type(new_type: ControlType) -> void:
	control_type = new_type
	if control_type == ControlType.OFF:
		visible = false
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		visible = true
		freeze = false
		collision_layer = 1
		collision_mask = 1

func trigger_jump() -> void:
	# Prüfen, ob der Spieler nahe dem Boden ist
	var cur_y = global_position.y if is_inside_tree() else position.y
	if cur_y <= CageConfig.PLAYER_RADIUS + 0.35:
		apply_central_impulse(Vector3.UP * CageConfig.PLAYER_JUMP_IMPULSE)

func trigger_boost(input_vec: Vector2) -> void:
	boost_cooldown = CageConfig.PLAYER_BOOST_COOLDOWN
	var boost_dir = Vector3.FORWARD
	if input_vec.length_squared() > 0.01:
		boost_dir = Vector3(input_vec.x, 0.0, input_vec.y).normalized()
	elif linear_velocity.length_squared() > 0.1:
		boost_dir = Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized()
	
	apply_central_impulse(boost_dir * CageConfig.PLAYER_BOOST_IMPULSE)

func _clamp_speed() -> void:
	var horiz_vel = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if horiz_vel.length() > CageConfig.PLAYER_MAX_SPEED:
		var clamped = horiz_vel.normalized() * CageConfig.PLAYER_MAX_SPEED
		linear_velocity.x = clamped.x
		linear_velocity.z = clamped.z

func _update_eyes() -> void:
	if _eyes_pivot and is_instance_valid(target_ball) and is_inside_tree() and target_ball.is_inside_tree():
		var target_pos = target_ball.global_position
		_eyes_pivot.look_at(target_pos, Vector3.UP)

func reset_to(pos: Vector3) -> void:
	_teleport_target = pos
	if is_inside_tree():
		_pending_teleport = true
		global_position = pos
	else:
		position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	boost_cooldown = 0.0
