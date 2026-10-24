class_name SoccerBall
extends RigidBody3D

const CageConfig = preload("res://scripts/config.gd")

var _mesh_instance: MeshInstance3D

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
	
	_setup_visuals()

func _setup_visuals() -> void:
	if not has_node("BallMesh"):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "BallMesh"
		var sphere = SphereMesh.new()
		sphere.radius = CageConfig.BALL_RADIUS
		sphere.height = CageConfig.BALL_RADIUS * 2.0
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.96, 0.94, 0.88) # Classic soccer white/cream
		mat.roughness = 0.35
		_mesh_instance.mesh = sphere
		_mesh_instance.material_override = mat
		add_child(_mesh_instance)

func reset_to_center() -> void:
	if is_inside_tree():
		global_position = Vector3(0.0, CageConfig.BALL_RADIUS + 0.1, 0.0)
	else:
		position = Vector3(0.0, CageConfig.BALL_RADIUS + 0.1, 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
