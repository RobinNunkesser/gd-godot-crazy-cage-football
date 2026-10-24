class_name CageCamera
extends Camera3D

const CageConfig = preload("res://scripts/config.gd")

@export var ball_node: Node3D = null
@export var player1_node: Node3D = null
@export var player2_node: Node3D = null

func _ready() -> void:
	fov = 76.0
	near = 0.05

func _process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	var target_x: float = 0.0
	var target_z: float = 0.0
	
	if is_instance_valid(ball_node):
		var bpos = ball_node.global_position if (is_inside_tree() and ball_node.is_inside_tree()) else ball_node.position
		target_x = clampf(bpos.x * 0.35, -CageConfig.CAGE_WIDTH_X * 0.22, CageConfig.CAGE_WIDTH_X * 0.22)
		target_z = clampf(bpos.z * 0.2, -1.2, 0.8)
	
	# Strikt innerhalb der Käfig-Grenzen (-12..12, 0..7, -7..7)
	var cam_x = clampf(target_x, -5.5, 5.5)
	var cam_y = clampf(CageConfig.CAMERA_HEIGHT, 2.5, CageConfig.CAGE_HEIGHT_Y - 1.8)
	var cam_z = clampf(CageConfig.CAMERA_OFFSET_Z + target_z, 3.8, CageConfig.CAGE_DEPTH_Z * 0.5 - 1.2)
	var desired_pos = Vector3(cam_x, cam_y, cam_z)
	
	if is_inside_tree():
		global_position = global_position.lerp(desired_pos, delta * CageConfig.CAMERA_LERP_SPEED)
		look_at(Vector3(target_x * 0.65, 0.7, target_z * 0.35), Vector3.UP)
	else:
		position = position.lerp(desired_pos, delta * CageConfig.CAMERA_LERP_SPEED)
