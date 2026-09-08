extends Node
## Precomputed original synthesis. Shared buses, a 20-voice pool and event throttles
## keep combat readable and prevent dense hit events from clipping the output.

const SOUND_IDS := ["lance_charge", "lance", "crown", "crown_fire", "cataclysm_charge", "cataclysm", "hit", "death", "dash", "step", "enemy_charge", "enemy_attack", "upgrade", "victory", "defeat"]
const VOICE_COUNT := 20
const LEVELS := {
	"lance_charge": -6.0, "lance": -4.0, "crown": -4.0,
	"crown_fire": -7.0, "cataclysm_charge": -3.0, "cataclysm": -1.0,
	"hit": -10.0, "death": -6.0, "dash": -8.0, "step": -14.0,
	"enemy_charge": -10.0, "enemy_attack": -9.0,
	"upgrade": -4.0, "victory": -3.0, "defeat": -4.0,
}
const PRIORITY := {
	"step": 0, "hit": 1, "death": 2, "enemy_attack": 2, "enemy_charge": 3,
	"dash": 4, "lance_charge": 4, "lance": 5, "crown_fire": 5, "crown": 6,
	"cataclysm_charge": 8, "cataclysm": 9, "upgrade": 8, "victory": 10, "defeat": 10,
}
const THROTTLE := {"step": 0.19, "hit": 0.032, "death": 0.052, "enemy_charge": 0.10, "enemy_attack": 0.065, "crown_fire": 0.024}

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _last: Dictionary = {}
var _ambience: AudioStreamPlayer
var _clock := 0.0
var _counter := 0
var _master := 0.8
var _effects_level := 0.9
var _ambience_level := 0.55
var _ready_done := false
var _owned_buses: Array[StringName] = []
var _headless := false


func _ready() -> void:
	# Presentation audio remains controllable from settings while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_setup_buses()
	for id in SOUND_IDS:
		_streams[id] = load("res://assets/audio/%s.wav" % id)
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = &"StormEffects"
		player.max_polyphony = 1
		player.set_meta("priority", -1)
		player.set_meta("started", -10.0)
		add_child(player)
		_voices.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "ArenaAmbience"
	_ambience.bus = &"StormAmbience"
	var loop: AudioStreamWAV = load("res://assets/audio/arena_ambience.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_ambience.stream = loop
	_ambience.volume_db = -4.0
	add_child(_ambience)
	_ready_done = true
	set_levels(_master, _effects_level, _ambience_level)


func _process(delta: float) -> void:
	_clock += delta


func _setup_buses() -> void:
	for bus_name in [&"StormMaster", &"StormEffects", &"StormAmbience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			_owned_buses.append(bus_name)
	AudioServer.set_bus_send(AudioServer.get_bus_index(&"StormEffects"), &"StormMaster")
	AudioServer.set_bus_send(AudioServer.get_bus_index(&"StormAmbience"), &"StormMaster")
	var master_index := AudioServer.get_bus_index(&"StormMaster")
	if AudioServer.get_bus_effect_count(master_index) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db = -3.0
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(master_index, limiter)


func play_sound(id: String, intensity: float = 1.0) -> void:
	if _headless or not _ready_done or not _streams.has(id):
		return
	var gap: float = THROTTLE.get(id, 0.0)
	if _clock - float(_last.get(id, -100.0)) < gap:
		return
	_last[id] = _clock
	var priority: int = PRIORITY.get(id, 3)
	var chosen: AudioStreamPlayer = null
	var active := 0
	for voice in _voices:
		if voice.playing:
			active += 1
		elif chosen == null:
			chosen = voice
	if chosen == null:
		# A quiet footstep never cuts off an ultimate or a result fanfare.
		var oldest := _clock
		for voice in _voices:
			if int(voice.get_meta("priority")) <= priority and float(voice.get_meta("started")) < oldest:
				oldest = float(voice.get_meta("started"))
				chosen = voice
	if chosen == null:
		return
	_counter += 1
	chosen.stop()
	chosen.stream = _streams[id]
	chosen.volume_db = float(LEVELS.get(id, -6.0)) + linear_to_db(clampf(intensity, 0.05, 1.6)) - minf(active * 0.30, 3.0)
	# Fixed sequence variation is reproducible and keeps repeated impacts organic.
	chosen.pitch_scale = 1.0 if priority >= 8 else 0.965 + float((_counter * 7) % 9) * 0.009
	chosen.set_meta("priority", priority)
	chosen.set_meta("started", _clock)
	chosen.play()


func set_levels(master: float, effects: float, ambience: float) -> void:
	_master = clampf(master, 0.0, 1.0)
	_effects_level = clampf(effects, 0.0, 1.0)
	_ambience_level = clampf(ambience, 0.0, 1.0)
	if not _ready_done:
		return
	for pair in [[&"StormMaster", _master], [&"StormEffects", _effects_level], [&"StormAmbience", _ambience_level]]:
		var index := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(pair[1], 0.00001)))
		AudioServer.set_bus_mute(index, pair[1] <= 0.00001)


func start_ambience() -> void:
	if not _headless and _ready_done and not _ambience.playing:
		_ambience.play()


func stop_effects() -> void:
	for voice in _voices:
		voice.stop()
	_last.clear()


func _exit_tree() -> void:
	shutdown()
	_voices.clear()
	for i in range(_owned_buses.size() - 1, -1, -1):
		var bus := AudioServer.get_bus_index(_owned_buses[i])
		if bus >= 0:
			AudioServer.remove_bus(bus)
	_owned_buses.clear()


func shutdown() -> void:
	# Call before the final quit, then allow one native audio-buffer interval to
	# drain. This also makes accelerated verification shut down without WAV leaks.
	_ready_done = false
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null
	_streams.clear()


func get_audio_state() -> Dictionary:
	var active := 0
	for voice in _voices:
		active += int(voice.playing)
	return {"loaded_sounds": _streams.size(), "active_voices": active, "voice_limit": VOICE_COUNT, "ambience": _ambience != null and _ambience.playing, "master": _master, "effects": _effects_level, "ambience_level": _ambience_level}
