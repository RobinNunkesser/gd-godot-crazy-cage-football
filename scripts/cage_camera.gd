class_name CageCamera
extends Camera3D

const CageConfig = preload("res://scripts/config.gd")

@export var ball_node: Node3D = null
@export var player1_node: Node3D = null
@export var player2_node: Node3D = null

func _process(delta: float) -> void:
	update_camera(delta)

func update_camera(delta: float) -> void:
	var target_x: float = 0.0
	var target_y: float = 1.0
	var target_z: float = 0.0
	
	if is_instance_valid(ball_node):
		var bpos = ball_node.global_position if (is_inside_tree() and ball_node.is_inside_tree()) else ball_node.position
		target_x = clampf(bpos.x * 0.4, -CageConfig.CAGE_WIDTH_X * 0.25, CageConfig.CAGE_WIDTH_X * 0.25)
		target_z = clampf(bpos.z * 0.3, -CageConfig.CAGE_DEPTH_Z * 0.2, CageConfig.CAGE_DEPTH_Z * 0.2)
	
	var desired_pos = Vector3(target_x, CageConfig.CAMERA_HEIGHT, CageConfig.CAMERA_OFFSET_Z + target_z)
	
	if is_inside_tree():
		global_position = global_position.lerp(desired_pos, delta * CageConfig.CAMERA_LERP_SPEED)
		look_at(Vector3(target_x * 0.6, 0.5, target_z * 0.5), Vector3.UP)
	else:
		position = position.lerp(desired_pos, delta * CageConfig.CAMERA_LERP_SPEED)
