extends Node
## Sound effect pool and music player. Autoload: Sfx.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _cache: Dictionary = {}
var _current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()


func apply_volumes() -> void:
	_set_bus("Music", GameState.music_volume)
	_set_bus("SFX", GameState.sfx_volume)


func play(sfx_name: String, pitch_jitter: float = 0.0) -> void:
	var stream := _load(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
	# pool exhausted: steal the first player (oldest sound)
	_pool[0].stream = stream
	_pool[0].play()


func play_music(music_name: String) -> void:
	if _current_music == music_name and _music.playing:
		return
	var stream := _load(MUSIC_DIR + music_name + ".wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		var bytes_per_sample := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if w.stereo:
			bytes_per_sample *= 2
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		@warning_ignore("integer_division")
		w.loop_end = w.data.size() / bytes_per_sample
	_music.stream = stream
	_current_music = music_name
	_music.play()


func stop_music() -> void:
	_music.stop()
	_current_music = ""


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("Missing audio: " + path)
		_cache[path] = null
		return null
	var s := load(path) as AudioStream
	_cache[path] = s
	return s


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
