extends Node

## Audio manager for game sounds.
## Uses procedurally generated sounds with clean, soft output.

# Audio players pool for overlapping sounds
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 12

# Sound settings - kept low to avoid distortion
var master_volume: float = 0.12
var sfx_volume: float = 0.5

func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_players.append(player)

func _get_available_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0]

func play_weapon_clash(intensity: float = 1.0) -> void:
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _generate_clack_sound()
	player.volume_db = -10.0 + (clampf(intensity, 0.5, 1.0) - 0.5) * 4.0
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()

func play_weapon_hit_ball(intensity: float = 1.0) -> void:
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _generate_hit_sound()
	player.volume_db = -8.0 + (clampf(intensity, 0.5, 1.0) - 0.5) * 4.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

func play_ball_collision(intensity: float = 1.0) -> void:
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _generate_thud_sound()
	player.volume_db = -12.0 + (clampf(intensity, 0.5, 1.0) - 0.5) * 6.0
	player.pitch_scale = randf_range(0.88, 1.12)
	player.play()

func play_ball_death() -> void:
	var player: AudioStreamPlayer = _get_available_player()
	player.stream = _generate_death_sound()
	player.volume_db = -6.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

func _generate_clack_sound() -> AudioStreamWAV:
	# Satisfying wooden clack - crisp but warm
	var sample_rate: int = 44100
	var duration: float = 0.09
	var samples: int = int(sample_rate * duration)

	var audio: AudioStreamWAV = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / sample_rate
		# Smooth attack, satisfying decay
		var attack: float = 1.0 - exp(-t * 400.0)
		var decay: float = exp(-t * 45.0)
		var envelope: float = attack * decay

		# Rich, warm tones
		var wave: float = 0.0
		wave += sin(t * 400.0 * TAU) * 0.3  # Warm base
		wave += sin(t * 800.0 * TAU) * 0.25  # Body
		wave += sin(t * 1200.0 * TAU) * 0.2 * exp(-t * 60.0)  # Crisp click
		wave += sin(t * 1600.0 * TAU) * 0.1 * exp(-t * 80.0)  # Sparkle

		var sample_val: float = wave * envelope * 0.5
		var sample_int: int = int(clampf(sample_val * 32767.0, -32768, 32767))

		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio.data = data
	return audio

func _generate_hit_sound() -> AudioStreamWAV:
	# Satisfying pop/thump - like a muted drum
	var sample_rate: int = 44100
	var duration: float = 0.12
	var samples: int = int(sample_rate * duration)

	var audio: AudioStreamWAV = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / sample_rate
		var attack: float = 1.0 - exp(-t * 600.0)
		var decay: float = exp(-t * 35.0)
		var envelope: float = attack * decay

		# Rounded, satisfying thump
		var wave: float = 0.0
		wave += sin(t * 100.0 * TAU) * 0.45  # Deep satisfying bass
		wave += sin(t * 200.0 * TAU) * 0.3   # Warm low-mid
		wave += sin(t * 350.0 * TAU) * 0.2 * exp(-t * 40.0)  # Punch
		wave += sin(t * 600.0 * TAU) * 0.1 * exp(-t * 60.0)  # Click

		var sample_val: float = wave * envelope * 0.5
		var sample_int: int = int(clampf(sample_val * 32767.0, -32768, 32767))

		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio.data = data
	return audio

func _generate_thud_sound() -> AudioStreamWAV:
	# Deep satisfying thud - like billiard balls
	var sample_rate: int = 44100
	var duration: float = 0.15
	var samples: int = int(sample_rate * duration)

	var audio: AudioStreamWAV = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / sample_rate
		var attack: float = 1.0 - exp(-t * 500.0)
		var decay: float = exp(-t * 28.0)
		var envelope: float = attack * decay

		# Rich, round thud like pool balls clacking
		var wave: float = 0.0
		wave += sin(t * 55.0 * TAU) * 0.4   # Sub bass rumble
		wave += sin(t * 110.0 * TAU) * 0.35  # Deep tone
		wave += sin(t * 220.0 * TAU) * 0.25  # Warmth
		wave += sin(t * 440.0 * TAU) * 0.15 * exp(-t * 35.0)  # Knock

		var sample_val: float = wave * envelope * 0.5
		var sample_int: int = int(clampf(sample_val * 32767.0, -32768, 32767))

		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio.data = data
	return audio

func _generate_death_sound() -> AudioStreamWAV:
	# Satisfying "poof" - soft descending with warmth
	var sample_rate: int = 44100
	var duration: float = 0.3
	var samples: int = int(sample_rate * duration)

	var audio: AudioStreamWAV = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t: float = float(i) / sample_rate
		var attack: float = 1.0 - exp(-t * 200.0)
		var decay: float = exp(-t * 10.0)
		var envelope: float = attack * decay

		# Gentle pitch drop
		var freq_mult: float = 0.3 + 0.7 * exp(-t * 5.0)

		# Warm, round tones
		var wave: float = 0.0
		wave += sin(t * 180.0 * freq_mult * TAU) * 0.4   # Warm fundamental
		wave += sin(t * 270.0 * freq_mult * TAU) * 0.3   # Fifth harmony
		wave += sin(t * 360.0 * freq_mult * TAU) * 0.2   # Octave
		wave += sin(t * 540.0 * freq_mult * TAU) * 0.1 * exp(-t * 15.0)  # Shimmer

		var sample_val: float = wave * envelope * 0.5
		var sample_int: int = int(clampf(sample_val * 32767.0, -32768, 32767))

		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	audio.data = data
	return audio
