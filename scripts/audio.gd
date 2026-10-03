class_name AudioDirector
extends Node

var music: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice = 0

func _ready() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in range(16):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		pool.append(player)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var stream: AudioStreamWAV = load("res://assets/audio/music.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	# Imported WAVs may be compressed; byte count is not their sample count.
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.volume_db = -7.0
	add_child(music)
	music.play()

func play(sound: String, volume: float = 0.0, pitch: float = 1.0) -> void:
	if pool.is_empty():
		return
	if not sounds.has(sound):
		sounds[sound] = load("res://assets/audio/" + sound + ".wav")
	var player = pool[voice % pool.size()]
	voice += 1
	player.stream = sounds[sound]
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()

func set_volumes(music_level: float, sfx_level: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.001, music_level)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music_level <= 0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.001, sfx_level)))

func _exit_tree() -> void:
	# Release active playbacks before the audio server shuts down.
	for player in pool:
		player.stop()
		player.stream = null
	if music != null:
		music.stop()
		music.stream = null
	sounds.clear()
	pool.clear()
