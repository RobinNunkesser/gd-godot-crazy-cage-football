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
var _label3d: Label3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_setup_visuals()

static func get_short_title(t: CageConfig.PowerUpType) -> String:
	match t:
		CageConfig.PowerUpType.SUPER_SHOT:
			return "🔥 " + TranslationServer.translate("PUP_SUPER_SHOT_NAME")
		CageConfig.PowerUpType.SPEED_BOOTS:
			return "⚡ " + TranslationServer.translate("PUP_SPEED_BOOTS_NAME")
		CageConfig.PowerUpType.MAGNET_FOOT:
			return "🧲 " + TranslationServer.translate("PUP_MAGNET_FOOT_NAME")
		CageConfig.PowerUpType.FREEZE_TACKLE:
			return "❄️ " + TranslationServer.translate("PUP_FREEZE_TACKLE_NAME")
		CageConfig.PowerUpType.CAGE_SHAKER:
			return "💥 " + TranslationServer.translate("PUP_CAGE_SHAKER_NAME")
	return "POWER-UP"

static func get_type_name(t: CageConfig.PowerUpType) -> String:
	return get_short_title(t)

static func get_explanation(t: CageConfig.PowerUpType) -> String:
	match t:
		CageConfig.PowerUpType.SUPER_SHOT:
			return TranslationServer.translate("PUP_SUPER_SHOT_DESC")
		CageConfig.PowerUpType.SPEED_BOOTS:
			return TranslationServer.translate("PUP_SPEED_BOOTS_DESC")
		CageConfig.PowerUpType.MAGNET_FOOT:
			return TranslationServer.translate("PUP_MAGNET_FOOT_DESC")
		CageConfig.PowerUpType.FREEZE_TACKLE:
			return TranslationServer.translate("PUP_FREEZE_TACKLE_DESC")
		CageConfig.PowerUpType.CAGE_SHAKER:
			return TranslationServer.translate("PUP_CAGE_SHAKER_DESC")
	return ""

static func get_type_color(t: CageConfig.PowerUpType) -> Color:
	match t:
		CageConfig.PowerUpType.SUPER_SHOT:
			return Color(1.0, 0.15, 0.02) # Feuriges Signal-Rot
		CageConfig.PowerUpType.SPEED_BOOTS:
			return Color(1.0, 0.95, 0.05) # Leuchtendes Blitz-Gelb
		CageConfig.PowerUpType.MAGNET_FOOT:
			return Color(0.85, 0.05, 1.0) # Reines Neon-Violett
		CageConfig.PowerUpType.FREEZE_TACKLE:
			return Color(0.15, 0.90, 1.0) # Kristall-Eisblau
		CageConfig.PowerUpType.CAGE_SHAKER:
			return Color(0.15, 1.0, 0.25) # Signal-Giftgrün
	return Color.WHITE

func _setup_visuals() -> void:
	_base_y = position.y if position.y > 0.1 else 0.55
	
	# 1. Kollisionskugel
	var col = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = CageConfig.POWERUP_RADIUS
	col.shape = sphere_shape
	add_child(col)
	
	_mesh_node = Node3D.new()
	_mesh_node.name = "VisualPivot"
	add_child(_mesh_node)
	
	var col_accent = get_type_color(type)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col_accent
	mat.emission_enabled = true
	mat.emission = col_accent
	mat.emission_energy_multiplier = 3.2
	mat.metallic = 0.5
	mat.roughness = 0.15
	
	# 2. Individuelle geometrische Silhouette je nach Typ
	match type:
		CageConfig.PowerUpType.SUPER_SHOT:
			# Glühende Flammen-Kugel mit Spike-Kranz
			var ball_inst = MeshInstance3D.new()
			var s = SphereMesh.new()
			s.radius = 0.28
			s.height = 0.56
			ball_inst.mesh = s
			ball_inst.material_override = mat
			_mesh_node.add_child(ball_inst)
			
			var ring = MeshInstance3D.new()
			var torus = TorusMesh.new()
			torus.inner_radius = 0.32
			torus.outer_radius = 0.42
			ring.mesh = torus
			ring.material_override = mat
			ring.rotation_degrees = Vector3(45, 0, 45)
			_mesh_node.add_child(ring)
			
		CageConfig.PowerUpType.SPEED_BOOTS:
			# Keil / Blitzförmiges Doppel-Prisma
			var prism_inst = MeshInstance3D.new()
			var prism = PrismMesh.new()
			prism.size = Vector3(0.48, 0.48, 0.32)
			prism_inst.mesh = prism
			prism_inst.material_override = mat
			prism_inst.rotation_degrees = Vector3(0, 45, 90)
			_mesh_node.add_child(prism_inst)
			
		CageConfig.PowerUpType.MAGNET_FOOT:
			# Großer vertikaler Magnet-Torus
			var magnet_inst = MeshInstance3D.new()
			var torus = TorusMesh.new()
			torus.inner_radius = 0.22
			torus.outer_radius = 0.44
			magnet_inst.mesh = torus
			magnet_inst.material_override = mat
			magnet_inst.rotation_degrees = Vector3(90, 0, 0)
			_mesh_node.add_child(magnet_inst)
			
		CageConfig.PowerUpType.FREEZE_TACKLE:
			# Kristall-Zylinder mit scharfen Kanten
			var crystal_inst = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.radial_segments = 6
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.32
			cyl.height = 0.55
			crystal_inst.mesh = cyl
			crystal_inst.material_override = mat
			_mesh_node.add_child(crystal_inst)
			
		CageConfig.PowerUpType.CAGE_SHAKER:
			# Wuchtiger Hexagon-Zylinder (Stoß-Generator)
			var shaker_inst = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.radial_segments = 6
			cyl.top_radius = 0.35
			cyl.bottom_radius = 0.35
			cyl.height = 0.45
			shaker_inst.mesh = cyl
			shaker_inst.material_override = mat
			_mesh_node.add_child(shaker_inst)
	
	# 3. Kristallklares 3D-Billboard Textlabel direkt über dem Token
	_label3d = Label3D.new()
	_label3d.name = "BillboardLabel"
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.text = get_short_title(type)
	_label3d.font_size = 28
	_label3d.outline_size = 8
	_label3d.outline_modulate = Color(0.04, 0.04, 0.06, 0.95)
	_label3d.modulate = col_accent
	_label3d.position = Vector3(0, 0.72, 0)
	add_child(_label3d)
	
	# 4. Leuchtfeuer / OmniLight
	var light = OmniLight3D.new()
	light.light_color = col_accent
	light.light_energy = 1.5
	light.omni_range = 3.2
	_mesh_node.add_child(light)

func _process(delta: float) -> void:
	_time_alive += delta
	if _mesh_node:
		_mesh_node.rotate_y(_rot_speed * delta)
		_mesh_node.position.y = sin(_time_alive * 3.4) * 0.12
	if _label3d:
		_label3d.position.y = 0.72 + sin(_time_alive * 3.4) * 0.12

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body is CagePlayer:
		_collected = true
		power_up_collected.emit(body, type)
		
		var pos = global_position if is_inside_tree() else position
		if CageJuiceManager.instance:
			CageJuiceManager.instance.spawn_sparks(pos, 10.0)
			CageJuiceManager.instance.trigger_shake(0.2)
		if CageSoundManager.instance:
			CageSoundManager.instance.play_boost()
		
		# Sanftes Aufblitzen und Verschwinden
		if is_inside_tree():
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(_mesh_node, "scale", Vector3(1.6, 1.6, 1.6), 0.16)
			tween.tween_property(_mesh_node, "position:y", _mesh_node.position.y + 0.4, 0.16)
			if _label3d:
				tween.tween_property(_label3d, "modulate:a", 0.0, 0.16)
			tween.chain().tween_callback(queue_free)
		else:
			queue_free()
