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
var stream_bgm: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 10
var _current_player_idx: int = 0
var _bgm_player: AudioStreamPlayer
var bgm_enabled: bool = true
const BGM_BASE_VOLUME_DB: float = -11.0
var _bgm_duck_tween: Tween

func _init() -> void:
	name = "CageSoundManager"
	instance = self
	_synthesize_all_sounds()

func _ready() -> void:
	instance = self
	_setup_player_pool()
	_setup_bgm_player()

func _setup_player_pool() -> void:
	for i in range(_pool_size):
		var p = AudioStreamPlayer.new()
		p.name = "AudioPlayer_%d" % i
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	_bgm_player.stream = stream_bgm
	_bgm_player.volume_db = BGM_BASE_VOLUME_DB
	add_child(_bgm_player)

func _get_available_player() -> AudioStreamPlayer:
	if _players.is_empty():
		return null
	var p = _players[_current_player_idx]
	_current_player_idx = (_current_player_idx + 1) % _players.size()
	return p

## BGM-Steuerung
func play_bgm() -> void:
	if not is_inside_tree() or not bgm_enabled or not _bgm_player or not _bgm_player.is_inside_tree():
		return
	if not _bgm_player.playing:
		_bgm_player.volume_db = BGM_BASE_VOLUME_DB
		_bgm_player.play()

func stop_bgm() -> void:
	if _bgm_player and _bgm_player.is_inside_tree() and _bgm_player.playing:
		_bgm_player.stop()

func toggle_bgm() -> bool:
	bgm_enabled = not bgm_enabled
	if bgm_enabled:
		play_bgm()
	else:
		stop_bgm()
	return bgm_enabled

func duck_bgm(duration: float = 2.5) -> void:
	if not _bgm_player or not _bgm_player.playing or not is_inside_tree():
		return
	if _bgm_duck_tween and _bgm_duck_tween.is_valid():
		_bgm_duck_tween.kill()
	_bgm_duck_tween = create_tween()
	_bgm_duck_tween.tween_property(_bgm_player, "volume_db", -26.0, 0.15)
	_bgm_duck_tween.tween_interval(duration)
	_bgm_duck_tween.tween_property(_bgm_player, "volume_db", BGM_BASE_VOLUME_DB, 0.6)

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
	stream_bgm = _generate_bgm_wav()

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

func _generate_bgm_wav() -> AudioStreamWAV:
	var mix_rate: int = 22050
	var bpm: float = 130.0
	var samples_per_step: int = int(round(float(mix_rate) * 60.0 / (bpm * 4.0))) # 2544 samples pro 16tel
	var total_steps: int = 64 # 4 Takte à 16 Sechzehntel
	var total_samples: int = samples_per_step * total_steps # 162816 samples (~7.38 s)
	
	const D2 = 73.42
	const F2 = 87.31
	const G2 = 98.00
	const A2 = 110.00
	const C3 = 130.81
	const D3 = 146.83

	const C4 = 261.63
	const D4 = 293.66
	const F4 = 349.23
	const G4 = 392.00
	const A4 = 440.00
	const C5 = 523.25
	const D5 = 587.33
	const F5 = 698.46
	
	var lead_pattern: Array[float] = [
		# Bar 1
		D4, 0.0, D4, F4, G4, 0.0, A4, 0.0, C5, A4, G4, F4, D4, 0.0, F4, G4,
		# Bar 2
		A4, 0.0, C5, D5, 0.0, C5, A4, G4, F4, 0.0, G4, 0.0, A4, G4, F4, C4,
		# Bar 3
		D4, D4, F4, G4, A4, 0.0, C5, 0.0, D5, 0.0, F5, D5, C5, A4, G4, F4,
		# Bar 4
		G4, 0.0, A4, 0.0, C5, D5, C5, A4, G4, F4, D4, 0.0, 0.0, 0.0, 0.0, 0.0
	]
	
	var bass_pattern: Array[float] = [
		# Bar 1
		D2, 0.0, D2, D2, F2, 0.0, G2, 0.0, D2, 0.0, D2, D2, C3, 0.0, A2, 0.0,
		# Bar 2
		D2, 0.0, D2, D2, F2, 0.0, G2, 0.0, A2, 0.0, G2, 0.0, F2, 0.0, C3, 0.0,
		# Bar 3
		D2, 0.0, D2, D2, F2, 0.0, G2, 0.0, D2, 0.0, D2, D2, C3, 0.0, D3, 0.0,
		# Bar 4
		G2, 0.0, G2, 0.0, A2, 0.0, A2, 0.0, C3, 0.0, C3, 0.0, A2, 0.0, C3, 0.0
	]
	
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	
	var sample_idx: int = 0
	var t_lead_accum: float = 0.0
	var t_bass_accum: float = 0.0
	var inv_mix_rate: float = 1.0 / float(mix_rate)
	
	for step in range(total_steps):
		var lead_freq = lead_pattern[step]
		var bass_freq = bass_pattern[step]
		var is_kick = (step % 4 == 0)
		var is_snare = ((step % 8) == 4)
		var is_open_hat = (step == 30 or step == 62)
		var is_closed_hat = (step % 2 == 1 and not is_open_hat)
		
		for sub_i in range(samples_per_step):
			var t_step = float(sub_i) * inv_mix_rate
			var step_prog = float(sub_i) / float(samples_per_step)
			
			# 1. Lead Chiptune Melodie (25% Duty Pulse Wave)
			var lead_s: float = 0.0
			if lead_freq > 0.0:
				var phase = fmod(t_lead_accum, 1.0)
				lead_s = 0.65 if phase < 0.25 else -0.65
				var env = (float(sub_i) / 75.0) if sub_i < 75 else exp(-step_prog * 2.7)
				lead_s *= env
				t_lead_accum += lead_freq * inv_mix_rate
			
			# 2. Driving Bass (Triangle + Sub-Harmonic)
			var bass_s: float = 0.0
			if bass_freq > 0.0:
				var b_phase = fmod(t_bass_accum, 1.0)
				var tri = 4.0 * abs(b_phase - 0.5) - 1.0
				var sub = sin(b_phase * TAU)
				var env = exp(-step_prog * 2.1)
				bass_s = (tri * 0.7 + sub * 0.4) * env
				t_bass_accum += bass_freq * inv_mix_rate
			
			# 3. Chiptune Percussion
			var drum_s: float = 0.0
			if is_kick:
				var kick_freq = lerpf(135.0, 42.0, clampf(t_step / 0.11, 0.0, 1.0))
				var kick_env = exp(-t_step * 28.0)
				drum_s += sin(t_step * kick_freq * TAU) * kick_env * 1.3
			
			if is_snare:
				var snare_env = exp(-t_step * 22.0)
				var snare_noise = randf_range(-1.0, 1.0) * 0.7
				var snare_tone = sin(t_step * 175.0 * TAU) * 0.4
				drum_s += (snare_noise + snare_tone) * snare_env * 1.15
			
			if is_closed_hat:
				var hat_env = exp(-t_step * 68.0)
				var hat_noise = randf_range(-1.0, 1.0)
				drum_s += hat_noise * hat_env * 0.42
			
			if is_open_hat:
				var open_env = exp(-t_step * 15.0)
				var open_noise = randf_range(-1.0, 1.0)
				drum_s += open_noise * open_env * 0.52
			
			# Gesamt-Mix (Lead + Bass + Drums)
			var mix = lead_s * 0.35 + bass_s * 0.42 + drum_s * 0.45
			mix = clampf(mix, -1.0, 1.0)
			
			# Nahtlose Loop-Verblendung an den Rändern (kein Knacken beim Wiederholen)
			if sample_idx < 384:
				mix *= float(sample_idx) / 384.0
			elif sample_idx > total_samples - 384:
				mix *= float(total_samples - sample_idx) / 384.0
			
			var s16 = int(mix * 21500.0)
			data.encode_s16(sample_idx * 2, s16)
			sample_idx += 1
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav
