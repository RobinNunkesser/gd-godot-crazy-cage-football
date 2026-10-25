class_name CagePowerUp
extends Area3D

const CageConfig = preload("res://scripts/config.gd")
const CageSoundManager = preload("res://scripts/cage_sound_manager.gd")
const CageJuiceManager = preload("res://scripts/cage_juice_manager.gd")

signal power_up_collected(player: CagePlayer, power_up_type: CageConfig.PowerUpType)

@export var type: CageConfig.PowerUpType = CageConfig.PowerUpType.SUPER_SHOT

var _mesh_node: Node3D
var _rot_speed: float = 2.4
var _base_y: float = 0.55
var _time_alive: float = 0.0
var _collected: bool = false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_setup_visuals()

static func get_type_name(t: CageConfig.PowerUpType) -> String:
	match t:
		CageConfig.PowerUpType.SUPER_SHOT:
			return "🔥 SUPER-SHOT (Feuerball)"
		CageConfig.PowerUpType.SPEED_BOOTS:
			return "⚡ SPEED-BOOTS (Sprint)"
		CageConfig.PowerUpType.MAGNET_FOOT:
			return "🧲 MAGNETFUSS (Dribbling)"
		CageConfig.PowerUpType.FREEZE_TACKLE:
			return "❄️ FREEZE-TACKLE (Frost)"
		CageConfig.PowerUpType.CAGE_SHAKER:
			return "💥 CAGE-SHAKER (Stoßwelle)"
	return "POWER-UP"

static func get_type_color(t: CageConfig.PowerUpType) -> Color:
	match t:
		CageConfig.PowerUpType.SUPER_SHOT:
			return Color(1.0, 0.32, 0.05) # Feuriges Rot-Orange
		CageConfig.PowerUpType.SPEED_BOOTS:
			return Color(1.0, 0.88, 0.12) # Goldgelb
		CageConfig.PowerUpType.MAGNET_FOOT:
			return Color(0.85, 0.18, 0.95) # Neon-Magenta
		CageConfig.PowerUpType.FREEZE_TACKLE:
			return Color(0.20, 0.85, 1.0) # Eis-Cyan
		CageConfig.PowerUpType.CAGE_SHAKER:
			return Color(0.25, 1.0, 0.35) # Smaragd / Lime
	return Color.WHITE

func _setup_visuals() -> void:
	_base_y = position.y if position.y > 0.1 else 0.55
	
	# Kollisionskugel
	var col = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = CageConfig.POWERUP_RADIUS
	col.shape = sphere_shape
	add_child(col)
	
	_mesh_node = Node3D.new()
	_mesh_node.name = "VisualPivot"
	add_child(_mesh_node)
	
	var col_accent = get_type_color(type)
	
	# Zentrales rotierendes Token-Mesh
	var token_mesh: MeshInstance3D = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.18)
	token_mesh.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col_accent
	mat.emission_enabled = true
	mat.emission = col_accent
	mat.emission_energy_multiplier = 2.2
	mat.metallic = 0.5
	mat.roughness = 0.2
	token_mesh.material_override = mat
	_mesh_node.add_child(token_mesh)
	
	# Schwebender Leucht-Ring darum
	var ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.44
	ring_mesh.mesh = torus
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color.WHITE
	ring_mat.emission_enabled = true
	ring_mat.emission = col_accent
	ring_mat.emission_energy_multiplier = 1.6
	ring_mesh.material_override = ring_mat
	ring_mesh.rotation_degrees = Vector3(90, 0, 0)
	_mesh_node.add_child(ring_mesh)
	
	# Sanfte OmniLight3D-Lichtquelle
	var light = OmniLight3D.new()
	light.light_color = col_accent
	light.light_energy = 1.2
	light.omni_range = 3.0
	_mesh_node.add_child(light)

func _process(delta: float) -> void:
	_time_alive += delta
	if _mesh_node:
		_mesh_node.rotate_y(_rot_speed * delta)
		_mesh_node.position.y = sin(_time_alive * 3.2) * 0.12

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body is CagePlayer:
		_collected = true
		power_up_collected.emit(body, type)
		
		var pos = global_position if is_inside_tree() else position
		if CageJuiceManager.instance:
			CageJuiceManager.instance.spawn_sparks(pos, 8.0)
			CageJuiceManager.instance.trigger_shake(0.2)
		if CageSoundManager.instance:
			CageSoundManager.instance.play_boost()
		
		# Sanftes Aufblitzen und Verschwinden
		if is_inside_tree():
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(_mesh_node, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
			tween.tween_property(_mesh_node, "position:y", _mesh_node.position.y + 0.5, 0.15)
			tween.chain().tween_callback(queue_free)
		else:
			queue_free()
