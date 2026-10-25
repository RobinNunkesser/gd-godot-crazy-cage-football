class_name CageJuiceManager
extends Node3D

## Visual Juice, Impact Feedback & Particle Management für Crazy Cage Football.
## Bietet CPUParticles3D Pooling für:
## - Turf-Aufwirbelungen beim Schuss und Aufkommen (Grüne Kunstrasen-Partikel)
## - Funkenregen bei Banden- und Pfostenschüssen (Leuchtendes Metall-Glühen)
## - Tor-Konfetti-Explosionen bei Torerfolg (Farbenfroher Torjubel)
## - Boost-Dash Rauchwolken hinter Spielern
## - Kamera-Trauma und Torblitz

static var instance: CageJuiceManager

var camera: CageCamera = null

# 1. Rasen / Turf Puffs
var _turf_pool: Array[CPUParticles3D] = []
var _turf_pool_size: int = 8
var _current_turf_idx: int = 0
var _turf_material: StandardMaterial3D = null

# 2. Metall-Funken (Bande & Pfosten)
var _spark_pool: Array[CPUParticles3D] = []
var _spark_pool_size: int = 8
var _current_spark_idx: int = 0

# 3. Tor-Konfetti
var _confetti_pool: Array[CPUParticles3D] = []
var _confetti_pool_size: int = 4
var _current_confetti_idx: int = 0

# 4. Boost-Rauchwolken
var _dash_pool: Array[CPUParticles3D] = []
var _dash_pool_size: int = 6
var _current_dash_idx: int = 0

# 5. Tor-Blitzlicht
var _goal_light: OmniLight3D = null

func _init() -> void:
	name = "CageJuiceManager"
	instance = self

func _ready() -> void:
	instance = self
	_setup_turf_pool()
	_setup_spark_pool()
	_setup_confetti_pool()
	_setup_dash_pool()
	_setup_goal_light()

func _setup_turf_pool() -> void:
	var turf_mesh = BoxMesh.new()
	turf_mesh.size = Vector3(0.08, 0.08, 0.08)
	_turf_material = StandardMaterial3D.new()
	_turf_material.albedo_color = Color(0.2, 0.75, 0.25)
	_turf_material.roughness = 0.8
	turf_mesh.material = _turf_material
	
	for i in range(_turf_pool_size):
		var p = CPUParticles3D.new()
		p.name = "Turf_%d" % i
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 16
		p.lifetime = 0.4
		p.mesh = turf_mesh
		p.direction = Vector3.UP
		p.spread = 60.0
		p.gravity = Vector3(0, -14.0, 0)
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.1
		add_child(p)
		_turf_pool.append(p)

func set_turf_color(color: Color) -> void:
	if _turf_material:
		_turf_material.albedo_color = color

func _setup_spark_pool() -> void:
	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.06, 0.06, 0.12)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 3.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh.material = mat
	
	for i in range(_spark_pool_size):
		var p = CPUParticles3D.new()
		p.name = "Spark_%d" % i
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 18
		p.lifetime = 0.35
		p.mesh = spark_mesh
		p.direction = Vector3.UP
		p.spread = 70.0
		p.gravity = Vector3(0, -18.0, 0)
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 9.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		add_child(p)
		_spark_pool.append(p)

func _setup_confetti_pool() -> void:
	var conf_mesh = BoxMesh.new()
	conf_mesh.size = Vector3(0.12, 0.02, 0.12)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.7, 0.2)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	conf_mesh.material = mat
	
	for i in range(_confetti_pool_size):
		var p = CPUParticles3D.new()
		p.name = "Confetti_%d" % i
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.95
		p.amount = 45
		p.lifetime = 1.2
		p.mesh = conf_mesh
		p.direction = Vector3.UP
		p.spread = 85.0
		p.gravity = Vector3(0, -7.0, 0)
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 12.0
		p.damping_min = 3.0
		p.damping_max = 6.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.5
		add_child(p)
		_confetti_pool.append(p)

func _setup_dash_pool() -> void:
	var dash_mesh = SphereMesh.new()
	dash_mesh.radius = 0.09
	dash_mesh.height = 0.18
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dash_mesh.material = mat
	
	for i in range(_dash_pool_size):
		var p = CPUParticles3D.new()
		p.name = "Dash_%d" % i
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 0.75
		p.amount = 14
		p.lifetime = 0.35
		p.mesh = dash_mesh
		p.gravity = Vector3(0, 0.5, 0)
		p.initial_velocity_min = 2.5
		p.initial_velocity_max = 5.0
		p.scale_amount_min = 0.4
		p.scale_amount_max = 1.0
		add_child(p)
		_dash_pool.append(p)

func _setup_goal_light() -> void:
	_goal_light = OmniLight3D.new()
	_goal_light.name = "GoalStrobeLight"
	_goal_light.light_energy = 0.0
	_goal_light.omni_range = 10.0
	_goal_light.light_color = Color(1.0, 0.9, 0.3)
	add_child(_goal_light)

## 1. Rasen-Aufwirbelung beim Schuss oder Aufprall
func spawn_turf_puff(pos: Vector3, force: float = 1.0) -> void:
	if not is_inside_tree() or _turf_pool.is_empty():
		return
	var p = _turf_pool[_current_turf_idx]
	_current_turf_idx = (_current_turf_idx + 1) % _turf_pool.size()
	if not p.is_inside_tree():
		return
	p.global_position = pos
	p.amount = int(clampf(force * 3.5, 10.0, 24.0))
	p.initial_velocity_min = clampf(force * 0.7, 3.0, 7.0)
	p.initial_velocity_max = clampf(force * 1.3, 5.0, 11.0)
	p.restart()
	p.emitting = true

## 2. Funkenregen bei Banden- oder Pfostentreffer
func spawn_sparks(pos: Vector3, force: float = 1.0) -> void:
	if not is_inside_tree() or _spark_pool.is_empty():
		return
	var p = _spark_pool[_current_spark_idx]
	_current_spark_idx = (_current_spark_idx + 1) % _spark_pool.size()
	if not p.is_inside_tree():
		return
	p.global_position = pos
	p.amount = int(clampf(force * 3.0, 12.0, 30.0))
	p.initial_velocity_min = clampf(force * 0.8, 4.0, 10.0)
	p.initial_velocity_max = clampf(force * 1.5, 6.0, 15.0)
	p.restart()
	p.emitting = true

## 3. Tor-Konfetti
func spawn_goal_confetti(pos: Vector3) -> void:
	if not is_inside_tree() or _confetti_pool.is_empty():
		return
	var p = _confetti_pool[_current_confetti_idx]
	_current_confetti_idx = (_current_confetti_idx + 1) % _confetti_pool.size()
	if not p.is_inside_tree():
		return
	p.global_position = pos
	p.restart()
	p.emitting = true

## 4. Boost-Rauchwolke
func spawn_dash_dust(pos: Vector3, dir: Vector3) -> void:
	if not is_inside_tree() or _dash_pool.is_empty():
		return
	var p = _dash_pool[_current_dash_idx]
	_current_dash_idx = (_current_dash_idx + 1) % _dash_pool.size()
	if not p.is_inside_tree():
		return
	p.global_position = pos
	p.direction = -dir
	p.restart()
	p.emitting = true

## 5. Tor-Stroboskop-Blitz
func trigger_goal_flash(pos: Vector3, team_id: int) -> void:
	if not is_inside_tree() or not _goal_light:
		return
	_goal_light.global_position = pos
	_goal_light.light_color = Color(1.0, 0.3, 0.2) if team_id == 1 else Color(0.2, 0.6, 1.0)
	
	var tween = create_tween()
	tween.tween_property(_goal_light, "light_energy", 4.0, 0.06)
	tween.tween_property(_goal_light, "light_energy", 0.5, 0.08)
	tween.tween_property(_goal_light, "light_energy", 3.5, 0.06)
	tween.tween_property(_goal_light, "light_energy", 0.0, 0.25)

## 6. Screenshake Trauma an die Kamera weitergeben
func trigger_shake(amount: float) -> void:
	if camera and is_instance_valid(camera):
		camera.add_trauma(amount)
