class_name CageSoundManager
extends Node

## Prozedurale 16-Bit Audio-Synthese & Player-Pool für Crazy Cage Football.
## Erzeugt Arcade-Soundeffekte für Kicks, Bandenabpraller, Pfostentreffer,
## Zıplama-Sprünge, Schiedsrichter-Pfiff, Torfanfare und Zweikämpfe ohne externe Audio-Abhängigkeiten.

static var instance: CageSoundManager

var stream_kick: AudioStreamWAV
var stream_wall: AudioStreamWAV
var stream_post: AudioStreamWAV
var stream_whistle: AudioStreamWAV
var stream_goal: AudioStreamWAV
var stream_jump: AudioStreamWAV
var stream_boost: AudioStreamWAV
var stream_tackle: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 10
var _current_player_idx: int = 0

func _init() -> void:
	name = "CageSoundManager"
	instance = self
	_synthesize_all_sounds()

func _ready() -> void:
	instance = self
	_setup_player_pool()

func _setup_player_pool() -> void:
	for i in range(_pool_size):
		var p = AudioStreamPlayer.new()
		p.name = "AudioPlayer_%d" % i
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _get_available_player() -> AudioStreamPlayer:
	if _players.is_empty():
		return null
	var p = _players[_current_player_idx]
	_current_player_idx = (_current_player_idx + 1) % _players.size()
	return p

## 1. Schuss / Pass / Ballkontakt
func play_kick(force: float) -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_kick
	p.volume_db = clampf(-18.0 + force * 1.5, -20.0, 3.0)
	p.pitch_scale = randf_range(0.93, 1.07)
	p.play()

## 2. Banden- & Käfigabpraller
func play_wall(force: float) -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_wall
	p.volume_db = clampf(-20.0 + force * 1.3, -22.0, 2.0)
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()

## 3. Pfosten- und Lattentreffer (metallischer Ping)
func play_post() -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_post
	p.volume_db = 1.0
	p.pitch_scale = randf_range(0.97, 1.03)
	p.play()

## 4. Schiedsrichter-Pfiff (Doppelton mit Triller)
func play_whistle() -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_whistle
	p.volume_db = -1.0
	p.pitch_scale = 1.0
	p.play()

## 5. Torfanfare / Torsirene
func play_goal() -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_goal
	p.volume_db = 2.0
	p.pitch_scale = 1.0
	p.play()

## 6. Zıplama-Sprung
func play_jump() -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_jump
	p.volume_db = -4.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

## 7. Turbo-Boost / Rammstoß
func play_boost() -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_boost
	p.volume_db = -2.5
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()

## 8. Zweikampf / Bodycheck zwischen Spielern
func play_tackle(force: float) -> void:
	if not is_inside_tree():
		return
	var p = _get_available_player()
	if not p:
		return
	p.stream = stream_tackle
	p.volume_db = clampf(-16.0 + force * 1.2, -18.0, 1.0)
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()

func _synthesize_all_sounds() -> void:
	stream_kick = _generate_kick_wav()
	stream_wall = _generate_wall_wav()
	stream_post = _generate_post_wav()
	stream_whistle = _generate_whistle_wav()
	stream_goal = _generate_goal_wav()
	stream_jump = _generate_jump_wav()
	stream_boost = _generate_boost_wav()
	stream_tackle = _generate_tackle_wav()

func _generate_kick_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.14
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var freq = lerpf(220.0, 48.0, progress * progress)
		var env = exp(-progress * 8.5)
		var s = sin(t * freq * TAU) * env * 24000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_wall_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.18
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var freq = lerpf(150.0, 42.0, progress)
		var env = exp(-progress * 7.0)
		var thud = sin(t * freq * TAU) * 0.7
		var rattle = randf_range(-1.0, 1.0) * exp(-progress * 14.0) * 0.3
		var s = (thud + rattle) * env * 21000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_post_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.55
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var env = exp(-progress * 5.0)
		# Harmonische Metallschwingung (880 Hz + 1760 Hz + 2640 Hz)
		var chime = sin(t * 880.0 * TAU) * 0.65 + sin(t * 1760.0 * TAU) * 0.25 + sin(t * 2640.0 * TAU) * 0.1
		var s = chime * env * 23000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_whistle_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.42
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		# 35 Hz Triller-Modulation
		var trill = sin(t * 35.0 * TAU) * 110.0
		var f1 = 2850.0 + trill
		var f2 = 3120.0 + trill
		var env = sin(progress * PI)
		var tone = (sin(t * f1 * TAU) * 0.5 + sin(t * f2 * TAU) * 0.5) * env * 19000.0
		data.encode_s16(i * 2, int(tone))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_goal_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.85
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var env = sin(progress * PI * 0.5) if progress < 0.2 else (1.0 - (progress - 0.2) / 0.8)
		# Triumphal C-Dur Akkord (C5=523Hz, E5=659Hz, G5=784Hz) mit Tremolo
		var tremolo = 0.8 + 0.2 * sin(t * 18.0 * TAU)
		var chord = sin(t * 523.25 * TAU) * 0.4 + sin(t * 659.25 * TAU) * 0.35 + sin(t * 783.99 * TAU) * 0.35
		var s = chord * tremolo * env * 22000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_jump_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.16
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var freq = lerpf(140.0, 440.0, progress)
		var env = sin(progress * PI)
		var s = sin(t * freq * TAU) * env * 18000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_boost_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.22
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var freq = lerpf(520.0, 160.0, progress)
		var env = exp(-progress * 5.0)
		var noise = randf_range(-1.0, 1.0) * 0.3
		var s = (sin(t * freq * TAU) * 0.7 + noise) * env * 20000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav

func _generate_tackle_wav() -> AudioStreamWAV:
	var mix_rate = 22050
	var duration = 0.15
	var total_samples = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t = float(i) / float(mix_rate)
		var progress = t / duration
		var freq = lerpf(110.0, 35.0, progress)
		var env = exp(-progress * 8.0)
		var noise = randf_range(-1.0, 1.0) * exp(-progress * 15.0) * 0.4
		var s = (sin(t * freq * TAU) * 0.6 + noise) * env * 22000.0
		data.encode_s16(i * 2, int(s))
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav
