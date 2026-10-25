class_name CageCamera
extends Camera3D

const CageConfig = preload("res://scripts/config.gd")

@export var ball_node: Node3D = null
@export var player1_node: Node3D = null
@export var player2_node: Node3D = null

@export var tracked_players: Array[Node3D] = []

var _current_look_target: Vector3 = Vector3(0.0, 0.6, 0.0)

var trauma: float = 0.0
var _trauma_decay: float = 1.4
var _max_shake_offset: Vector3 = Vector3(0.4, 0.25, 0.4)
var _noise_timer: float = 0.0

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _init() -> void:
	fov = 82.0
	near = 0.25
	far = 150.0
	_current_look_target = Vector3(0.0, 0.6, 0.0)

func _ready() -> void:
	fov = 82.0
	near = 0.25
	far = 150.0
	_current_look_target = Vector3(0.0, 0.6, 0.0)

func _process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	var action_pos = Vector3.ZERO
	var weight_total = 0.0
	
	# 1. Hauptfokus: Ball
	if is_instance_valid(ball_node):
		var bpos = ball_node.global_position if (is_inside_tree() and ball_node.is_inside_tree()) else ball_node.position
		action_pos += bpos * 3.0
		weight_total += 3.0
	
	# 2. Spielgeschehen: Aktive Spieler um den Ball
	var candidates: Array[Node3D] = []
	if not tracked_players.is_empty():
		candidates = tracked_players
	else:
		if is_instance_valid(player1_node):
			candidates.append(player1_node)
		if is_instance_valid(player2_node):
			candidates.append(player2_node)
	
	var players_mid = Vector3.ZERO
	var active_count = 0
	for p in candidates:
		if is_instance_valid(p) and ("control_type" not in p or p.control_type != 0):
			var ppos = p.global_position if (is_inside_tree() and p.is_inside_tree()) else p.position
			players_mid += ppos
			active_count += 1
	
	if active_count > 0:
		players_mid /= float(active_count)
		action_pos += players_mid * 1.0
		weight_total += 1.0
	
	if weight_total > 0.0:
		action_pos /= weight_total
	
	# 3. Positionierung: Mehr Distanz, dynamisches Mitziehen entlang X
	var cam_x = clampf(action_pos.x * 0.70, -CageConfig.CAGE_WIDTH_X * 0.35, CageConfig.CAGE_WIDTH_X * 0.35)
	var cam_y = clampf(CageConfig.CAMERA_HEIGHT + action_pos.y * 0.20, 4.2, CageConfig.CAGE_HEIGHT_Y - 1.2)
	var cam_z = clampf(CageConfig.CAMERA_OFFSET_Z + action_pos.z * 0.15, 5.0, CageConfig.CAGE_DEPTH_Z * 0.5 - 0.8)
	var desired_pos = Vector3(cam_x, cam_y, cam_z)
	
	# 4. Blickpunkt folgt dem Spielgeschehen
	var target_look = Vector3(
		action_pos.x * 0.85,
		clampf(action_pos.y * 0.5 + 0.4, 0.4, 2.0),
		action_pos.z * 0.60
	)
	
	# 5. Screen Shake Trauma
	if trauma > 0.0:
		_noise_timer += delta * 32.0
		var shake = trauma * trauma
		var offset = Vector3(
			sin(_noise_timer * 1.3) * _max_shake_offset.x * shake,
			cos(_noise_timer * 1.7) * _max_shake_offset.y * shake,
			sin(_noise_timer * 2.1) * _max_shake_offset.z * shake
		)
		desired_pos += offset
		target_look += offset * 0.4
		trauma = maxf(0.0, trauma - delta * _trauma_decay)
	
	if is_inside_tree():
		global_position = global_position.lerp(desired_pos, delta * CageConfig.CAMERA_LERP_SPEED)
		_current_look_target = _current_look_target.lerp(target_look, delta * (CageConfig.CAMERA_LERP_SPEED + 1.5))
		look_at(_current_look_target, Vector3.UP)
	else:
		position = position.lerp(desired_pos, delta * CageConfig.CAMERA_LERP_SPEED)
		_current_look_target = target_look
