class_name SoccerBall
extends RigidBody3D

const CageConfig = preload("res://scripts/config.gd")
const CageSoundManager = preload("res://scripts/cage_sound_manager.gd")

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
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	_setup_collision()
	_setup_visuals()

func _on_body_entered(body: Node) -> void:
	if not CageSoundManager.instance:
		return
	var speed = linear_velocity.length()
	if body is CagePlayer:
		CageSoundManager.instance.play_kick(speed)
	elif body.name.begins_with("GoalPost") or body.name.begins_with("GoalCrossbar"):
		CageSoundManager.instance.play_post()
	elif body.name != "CageFloor":
		CageSoundManager.instance.play_wall(speed)

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
		sphere.radial_segments = 48
		sphere.rings = 24
		
		var shader = Shader.new()
		shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

varying vec3 v_pos;

const vec3 PENT_CENTERS[12] = vec3[12](
	vec3(-0.525731, -0.850651, 0.000000),
	vec3(0.000000, -0.525731, -0.850651),
	vec3(-0.850651, 0.000000, -0.525731),
	vec3(-0.525731, 0.850651, 0.000000),
	vec3(0.000000, -0.525731, 0.850651),
	vec3(0.850651, 0.000000, -0.525731),
	vec3(0.525731, -0.850651, 0.000000),
	vec3(0.000000, 0.525731, -0.850651),
	vec3(-0.850651, 0.000000, 0.525731),
	vec3(0.525731, 0.850651, 0.000000),
	vec3(0.000000, 0.525731, 0.850651),
	vec3(0.850651, 0.000000, 0.525731)
);

const vec3 HEX_CENTERS[20] = vec3[20](
	vec3(-0.577350, -0.577350, -0.577350),
	vec3(0.000000, -0.934172, -0.356822),
	vec3(-0.934172, -0.356822, 0.000000),
	vec3(0.000000, -0.934172, 0.356822),
	vec3(-0.577350, -0.577350, 0.577350),
	vec3(-0.356822, 0.000000, -0.934172),
	vec3(0.577350, -0.577350, -0.577350),
	vec3(0.356822, 0.000000, -0.934172),
	vec3(-0.577350, 0.577350, -0.577350),
	vec3(-0.934172, 0.356822, 0.000000),
	vec3(0.000000, 0.934172, -0.356822),
	vec3(-0.577350, 0.577350, 0.577350),
	vec3(0.000000, 0.934172, 0.356822),
	vec3(0.577350, -0.577350, 0.577350),
	vec3(-0.356822, 0.000000, 0.934172),
	vec3(0.356822, 0.000000, 0.934172),
	vec3(0.934172, -0.356822, 0.000000),
	vec3(0.577350, 0.577350, -0.577350),
	vec3(0.934172, 0.356822, 0.000000),
	vec3(0.577350, 0.577350, 0.577350)
);

void vertex() {
	v_pos = normalize(VERTEX);
}

void fragment() {
	float best_dot = -1.0;
	float second_dot = -1.0;
	bool is_pent = false;

	for (int i = 0; i < 12; i++) {
		float d = dot(v_pos, PENT_CENTERS[i]);
		if (d > best_dot) {
			second_dot = best_dot;
			best_dot = d;
			is_pent = true;
		} else if (d > second_dot) {
			second_dot = d;
		}
	}

	for (int i = 0; i < 20; i++) {
		float d = dot(v_pos, HEX_CENTERS[i]);
		if (d > best_dot) {
			second_dot = best_dot;
			best_dot = d;
			is_pent = false;
		} else if (d > second_dot) {
			second_dot = d;
		}
	}

	float seam_dist = best_dot - second_dot;
	float seam_width = 0.024;

	if (seam_dist < seam_width) {
		float seam_factor = smoothstep(0.0, seam_width, seam_dist);
		vec3 base_col = is_pent ? vec3(0.12, 0.12, 0.14) : vec3(0.96, 0.96, 0.97);
		ALBEDO = mix(vec3(0.06, 0.06, 0.08), base_col, seam_factor);
		ROUGHNESS = mix(0.9, 0.28, seam_factor);
		METALLIC = 0.02;
	} else if (is_pent) {
		ALBEDO = vec3(0.12, 0.12, 0.14);
		ROUGHNESS = 0.32;
		METALLIC = 0.04;
	} else {
		ALBEDO = vec3(0.96, 0.96, 0.97);
		ROUGHNESS = 0.25;
		METALLIC = 0.03;
	}
}
"""
		var mat = ShaderMaterial.new()
		mat.shader = shader
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
