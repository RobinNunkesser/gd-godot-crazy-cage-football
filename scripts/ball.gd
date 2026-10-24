class_name SoccerBall
extends RigidBody3D

const CageConfig = preload("res://scripts/config.gd")

var _mesh_instance: MeshInstance3D
var _pending_teleport: bool = false
var _teleport_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	mass = CageConfig.BALL_MASS
	linear_damp = CageConfig.BALL_LINEAR_DAMP
	angular_damp = CageConfig.BALL_ANGULAR_DAMP
	
	var phys_mat = PhysicsMaterial.new()
	phys_mat.bounce = CageConfig.BALL_BOUNCE
	phys_mat.friction = CageConfig.BALL_FRICTION
	physics_material_override = phys_mat
	
	contact_monitor = true
	max_contacts_reported = 4
	
	_setup_collision()
	_setup_visuals()

func _setup_collision() -> void:
	if not has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var sphere = SphereShape3D.new()
		sphere.radius = CageConfig.BALL_RADIUS
		col.shape = sphere
		add_child(col)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		state.transform.origin = _teleport_target
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_pending_teleport = false

func _physics_process(_delta: float) -> void:
	var cur_pos = global_position if is_inside_tree() else position
	if cur_pos.y < -0.8 or absf(cur_pos.x) > (CageConfig.CAGE_WIDTH_X * 0.5 + CageConfig.GOAL_DEPTH + 1.5) or absf(cur_pos.z) > (CageConfig.CAGE_DEPTH_Z * 0.5 + 1.5):
		reset_to_center()

func _setup_visuals() -> void:
	if not has_node("BallMesh"):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "BallMesh"
		var sphere = SphereMesh.new()
		sphere.radius = CageConfig.BALL_RADIUS
		sphere.height = CageConfig.BALL_RADIUS * 2.0
		
		var mat = StandardMaterial3D.new()
		var ball_tex_path = "res://assets/textures/soccer_ball.jpg"
		if ResourceLoader.exists(ball_tex_path):
			mat.albedo_texture = load(ball_tex_path)
			mat.albedo_color = Color(1.0, 1.0, 1.0)
		else:
			mat.albedo_color = Color(0.96, 0.94, 0.88) # Classic soccer white/cream
		mat.roughness = 0.25
		mat.metallic = 0.05
		_mesh_instance.mesh = sphere
		_mesh_instance.material_override = mat
		add_child(_mesh_instance)

func reset_to_center() -> void:
	_teleport_target = Vector3(0.0, CageConfig.BALL_RADIUS + 0.1, 0.0)
	if is_inside_tree():
		_pending_teleport = true
		global_position = _teleport_target
	else:
		position = _teleport_target
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
