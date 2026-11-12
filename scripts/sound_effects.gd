class_name SoundEffects
extends Node

var player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 22050.0

var hum_player: AudioStreamPlayer
var hum_generator: AudioStreamGenerator
var hum_playback: AudioStreamGeneratorPlayback
var hum_phase: float = 0.0
var hum_freq: float = 58.0
var hum_volume: float = 0.035

func _ready() -> void:
	player = AudioStreamPlayer.new()
	generator = AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.1
	player.stream = generator
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	
	hum_player = AudioStreamPlayer.new()
	hum_generator = AudioStreamGenerator.new()
	hum_generator.mix_rate = sample_rate
	hum_generator.buffer_length = 0.15
	hum_player.stream = hum_generator
	add_child(hum_player)
	hum_player.play()
	hum_playback = hum_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if not hum_playback: return
	var frames_avail = hum_playback.get_frames_available()
	if frames_avail <= 0: return
	var inc = (TAU * hum_freq) / sample_rate
	for i in range(frames_avail):
		var sample = (sin(hum_phase) * 0.75 + sin(hum_phase * 2.0) * 0.25) * hum_volume
		hum_playback.push_frame(Vector2(sample, sample))
		hum_phase = fmod(hum_phase + inc, TAU)

func set_engine_power(power_mw: int) -> void:
	hum_freq = lerp(52.0, 78.0, clamp(float(power_mw) / 5.0, 0.0, 1.0))
	hum_volume = lerp(0.025, 0.065, clamp(float(power_mw) / 5.0, 0.0, 1.0))

func play_warp_jump() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.6)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var freq = lerp(60.0, 1400.0, t * t)
		var noise = (randf() * 2.0 - 1.0) * 0.15 * t
		var sample = (sin(phase) * 0.35 + noise) * (1.0 - t * 0.3)
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + (TAU * freq) / sample_rate, TAU)

func play_beep(freq: float = 880.0, duration: float = 0.05, volume: float = 0.2) -> void:
	if not playback:
		return
	var frames_to_fill = int(sample_rate * duration)
	var phase = 0.0
	var phase_increment = (TAU * freq) / sample_rate
	
	for i in range(frames_to_fill):
		var sample = sin(phase) * volume
		sample *= (1.0 - float(i) / float(frames_to_fill))
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + phase_increment, TAU)

func play_click() -> void:
	play_beep(1200.0, 0.02, 0.15)

func play_error() -> void:
	play_beep(220.0, 0.12, 0.3)

func play_laser() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.15)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var freq = lerp(1200.0, 200.0, t)
		var sample = sin(phase) * 0.25 * (1.0 - t)
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + (TAU * freq) / sample_rate, TAU)

func play_alert() -> void:
	play_beep(650.0, 0.08, 0.3)

func play_torpedo_warning() -> void:
	play_beep(950.0, 0.06, 0.35)

func play_transporter() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.25)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var freq = 600.0 + sin(t * 30.0) * 200.0
		var sample = sin(phase) * 0.2 * (1.0 - t * 0.5)
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + (TAU * freq) / sample_rate, TAU)

func play_chaff() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.12)
	for i in range(frames):
		var noise = (randf() * 2.0 - 1.0) * 0.25 * (1.0 - float(i) / float(frames))
		playback.push_frame(Vector2(noise, noise))

func play_explosion() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.35)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var freq = lerp(160.0, 35.0, t)
		var noise = (randf() * 2.0 - 1.0) * 0.35 * (1.0 - t)
		var bass = sin(phase) * 0.45 * (1.0 - t * 0.8)
		var sample = clamp(noise + bass, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + (TAU * freq) / sample_rate, TAU)

func play_shield_hit() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.16)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var freq = 520.0 + sin(t * 70.0) * 220.0
		var noise = (randf() * 2.0 - 1.0) * 0.22 * (1.0 - t)
		var buzz = sin(phase) * 0.28 * (1.0 - t)
		var sample = clamp(buzz + noise, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + (TAU * freq) / sample_rate, TAU)

func play_hull_stress() -> void:
	if not playback: return
	var frames = int(sample_rate * 0.28)
	var phase = 0.0
	for i in range(frames):
		var t = float(i) / float(frames)
		var freq = 85.0 + sin(t * 12.0) * 35.0
		var sample = sin(phase) * 0.3 * (1.0 - t)
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + (TAU * freq) / sample_rate, TAU)

func play_hack_keystroke() -> void:
	play_beep(randf_range(1400.0, 1800.0), 0.015, 0.12)

func play_hack_success() -> void:
	if not playback: return
	var notes = [523.25, 659.25, 783.99, 1046.50, 1318.51]
	for note in notes:
		var frames = int(sample_rate * 0.07)
		var phase = 0.0
		var inc = (TAU * note) / sample_rate
		for i in range(frames):
			var sample = sin(phase) * 0.22 * (1.0 - float(i) / float(frames))
			playback.push_frame(Vector2(sample, sample))
			phase = fmod(phase + inc, TAU)
