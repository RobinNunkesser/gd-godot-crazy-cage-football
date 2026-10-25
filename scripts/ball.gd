class_name SoccerBall
extends RigidBody3D

const CageConfig = preload("res://scripts/config.gd")
const CageSoundManager = preload("res://scripts/cage_sound_manager.gd")
const CageJuiceManager = preload("res://scripts/cage_juice_manager.gd")

var _mesh_instance: MeshInstance3D
var _ball_light: OmniLight3D = null
var _pending_teleport: bool = false
var _teleport_target: Vector3 = Vector3.ZERO
var is_super_shot: bool = false
var _super_shot_timer: float = 0.0

func trigger_super_shot(dir: Vector3, _force_multiplier: float = CageConfig.POWERUP_SUPER_SHOT_MULT) -> void:
	is_super_shot = true
	_super_shot_timer = 2.5
	var shoot_dir = dir.normalized()
	shoot_dir.y = clampf(shoot_dir.y, 0.12, 0.45)
	shoot_dir = shoot_dir.normalized()
	linear_velocity = shoot_dir * 24.0 # Starker aber physikalisch sicherer Impuls gegen Tunneling
	var pos = global_position if is_inside_tree() else position
	if CageJuiceManager.instance:
		CageJuiceManager.instance.spawn_sparks(pos, 25.0)
		CageJuiceManager.instance.trigger_shake(0.55)
	if CageSoundManager.instance:
		CageSoundManager.instance.play_kick(28.0)

func _ready() -> void:
	continuous_cd = true # Verhindert Physics-Tunneling durch Banden bei hohen Geschwindigkeiten
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

func trigger_squash(force: float) -> void:
	if not _mesh_instance or not is_inside_tree():
		return
	var factor = clampf(force * 0.025, 0.08, 0.28)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mesh_instance.scale = Vector3(1.0 + factor, 1.0 - factor, 1.0 + factor)
	tween.tween_property(_mesh_instance, "scale", Vector3.ONE, 0.12)

func _on_body_entered(body: Node) -> void:
	var speed = linear_velocity.length()
	var pos = global_position if is_inside_tree() else position
	
	if speed > 2.0:
		trigger_squash(speed)
	
	if body is CagePlayer:
		if CageSoundManager.instance:
			CageSoundManager.instance.play_kick(speed)
		if CageJuiceManager.instance:
			CageJuiceManager.instance.spawn_turf_puff(pos, speed)
			if speed > 6.0:
				CageJuiceManager.instance.trigger_shake(0.2)
	elif body.name.begins_with("GoalPost") or body.name.begins_with("GoalCrossbar"):
		if CageSoundManager.instance:
			CageSoundManager.instance.play_post()
		if CageJuiceManager.instance:
			CageJuiceManager.instance.spawn_sparks(pos, speed * 1.5)
			CageJuiceManager.instance.trigger_shake(0.45)
	elif body.name == "CageFloor":
		if speed > 3.0 and CageJuiceManager.instance:
			CageJuiceManager.instance.spawn_turf_puff(pos, speed * 0.5)
	else:
		if CageSoundManager.instance:
			CageSoundManager.instance.play_wall(speed)
		if CageJuiceManager.instance and speed > 4.0:
			CageJuiceManager.instance.spawn_sparks(pos, speed)
			CageJuiceManager.instance.trigger_shake(clampf(speed * 0.03, 0.1, 0.35))

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

func _physics_process(delta: float) -> void:
	if is_super_shot:
		_super_shot_timer -= delta
		if _super_shot_timer <= 0.0:
			is_super_shot = false
			
	# Maximale Ballgeschwindigkeit dämpfen um Durchtunneln zu verhindern
	if linear_velocity.length() > 25.0:
		linear_velocity = linear_velocity.normalized() * 25.0
			
	var cur_pos = global_position if is_inside_tree() else position
	# Großzügige Bounds, damit Schüsse ins Tornetz niemals fälschlicherweise zum Anstoßpunkt resetten
	var max_x = CageConfig.CAGE_WIDTH_X * 0.5 + CageConfig.GOAL_DEPTH + 4.0
	var max_z = CageConfig.CAGE_DEPTH_Z * 0.5 + 4.0
	if cur_pos.y < -1.5 or absf(cur_pos.x) > max_x or absf(cur_pos.z) > max_z:
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

uniform vec3 pent_color : source_color = vec3(0.12, 0.12, 0.14);
uniform vec3 hex_color : source_color = vec3(0.96, 0.96, 0.97);
uniform vec3 seam_color : source_color = vec3(0.06, 0.06, 0.08);
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy = 0.0;

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
		vec3 base_col = is_pent ? pent_color : hex_color;
		ALBEDO = mix(seam_color, base_col, seam_factor);
		ROUGHNESS = mix(0.9, 0.28, seam_factor);
		METALLIC = 0.02;
	} else if (is_pent) {
		ALBEDO = pent_color;
		ROUGHNESS = 0.32;
		METALLIC = 0.04;
	} else {
		ALBEDO = hex_color;
		ROUGHNESS = 0.25;
		METALLIC = 0.03;
	}

	if (emission_energy > 0.01) {
		EMISSION = emission_color * emission_energy;
	}
}
"""
		var mat = ShaderMaterial.new()
		mat.shader = shader
		_mesh_instance.mesh = sphere
		_mesh_instance.material_override = mat
		add_child(_mesh_instance)

func set_theme_colors(pent: Color, hex: Color, seam: Color, emissive: Color = Color.BLACK, emissive_energy: float = 0.0) -> void:
	if _mesh_instance and _mesh_instance.material_override is ShaderMaterial:
		var sm = _mesh_instance.material_override as ShaderMaterial
		sm.set_shader_parameter("pent_color", Vector3(pent.r, pent.g, pent.b))
		sm.set_shader_parameter("hex_color", Vector3(hex.r, hex.g, hex.b))
		sm.set_shader_parameter("seam_color", Vector3(seam.r, seam.g, seam.b))
		sm.set_shader_parameter("emission_color", Vector3(emissive.r, emissive.g, emissive.b))
		sm.set_shader_parameter("emission_energy", emissive_energy)
	
	if emissive_energy > 0.05:
		if not _ball_light and is_inside_tree():
			_ball_light = OmniLight3D.new()
			_ball_light.name = "BallLight"
			add_child(_ball_light)
		if _ball_light:
			_ball_light.visible = true
			_ball_light.light_color = emissive
			_ball_light.light_energy = emissive_energy * 1.5
			_ball_light.omni_range = 6.0
	elif _ball_light:
		_ball_light.visible = false

func reset_to_center() -> void:
	_teleport_target = Vector3(0.0, CageConfig.BALL_RADIUS + 0.1, 0.0)
	if is_inside_tree():
		_pending_teleport = true
		global_position = _teleport_target
	else:
		position = _teleport_target
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
