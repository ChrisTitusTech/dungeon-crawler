class_name DungeonAudio
extends Node

enum Track { DUNGEON, REFUGE, BATTLE }
enum Cue { STEP, CONFIRM, DOOR, ENCOUNTER, HIT, SKILL, GUARD, HEAL, RETREAT, VICTORY, DEFEAT }

const MUSIC := [
	preload("res://assets/audio/stone_paths.wav"),
	preload("res://assets/audio/hearthlight.wav"),
	preload("res://assets/audio/steel_at_the_gate.wav"),
]
const EFFECTS := [
	preload("res://assets/audio/step.wav"), preload("res://assets/audio/confirm.wav"),
	preload("res://assets/audio/door.wav"), preload("res://assets/audio/encounter.wav"),
	preload("res://assets/audio/blade.wav"), preload("res://assets/audio/skill.wav"),
	preload("res://assets/audio/guard.wav"), preload("res://assets/audio/heal.wav"),
	preload("res://assets/audio/retreat.wav"), preload("res://assets/audio/victory.wav"),
	preload("res://assets/audio/defeat.wav"),
]
const SETTINGS := "user://audio-settings.cfg"
const MUSIC_GAIN := 0.48
const EFFECT_GAIN := 0.66

var music_volume: int = 75
var effects_volume: int = 100

var _enabled: bool
var _track: int = -1
var _active: int = 1
var _music: Array[AudioStreamPlayer] = []
var _effects: Array[AudioStreamPlayer] = []
var _weights: Array[float] = [0.0, 0.0]
var _fade: Tween
var _step_pitch: float = 0.97


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	var settings := ConfigFile.new()
	if settings.load(SETTINGS) == OK:
		music_volume = clampi(int(settings.get_value("audio", "music", music_volume)), 0, 100)
		effects_volume = clampi(int(settings.get_value("audio", "effects", effects_volume)), 0, 100)
	for stream: AudioStreamWAV in MUSIC:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	for index: int in 2:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_music.append(player)
	for stream: AudioStream in EFFECTS:
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.max_polyphony = 2
		add_child(player)
		_effects.append(player)


func play_track(track: Track) -> void:
	if not _enabled or _track == track:
		return
	_track = track
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var outgoing: int = _active
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _music[_active]
	incoming.stream = MUSIC[track]
	_set_weight(0.0, _active)
	incoming.play()
	_fade = create_tween().set_parallel()
	_fade.tween_method(_set_weight.bind(_active), 0.0, 1.0, 0.45)
	_fade.tween_method(_set_weight.bind(outgoing), _weights[outgoing], 0.0, 0.45)
	_fade.chain().tween_callback(_music[outgoing].stop)


func play_cue(cue: Cue) -> void:
	if not _enabled or effects_volume == 0:
		return
	var player: AudioStreamPlayer = _effects[cue]
	player.volume_db = _gain_db(EFFECT_GAIN * effects_volume / 100.0)
	if cue == Cue.STEP:
		player.pitch_scale = _step_pitch
		_step_pitch = 1.04 if _step_pitch < 1.0 else 0.97
	player.play()


func cycle_volume(music: bool) -> void:
	if music:
		music_volume = _next_volume(music_volume)
		for index: int in _music.size():
			_set_weight(_weights[index], index)
	else:
		effects_volume = _next_volume(effects_volume)
		for player: AudioStreamPlayer in _effects:
			player.volume_db = _gain_db(EFFECT_GAIN * effects_volume / 100.0)
	if _enabled:
		var settings := ConfigFile.new()
		settings.set_value("audio", "music", music_volume)
		settings.set_value("audio", "effects", effects_volume)
		var error: Error = settings.save(SETTINGS)
		if error != OK:
			push_warning("Could not save audio settings: %s" % error_string(error))


func _set_weight(weight: float, index: int) -> void:
	_weights[index] = weight
	_music[index].volume_db = _gain_db(MUSIC_GAIN * weight * music_volume / 100.0)


func _next_volume(level: int) -> int:
	return 100 if level == 0 else maxi(0, level - 25)


func _gain_db(gain: float) -> float:
	return linear_to_db(maxf(0.0001, gain))
