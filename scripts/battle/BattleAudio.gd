class_name BattleAudio
extends Node

const POOL_SIZE := 6
const DRONE_RATE := 22050
const DRONE_SECONDS := 8.0
const PITCH_CYCLE := [1.0, 0.96, 1.04, 0.98, 1.03, 0.95]
const CUE_GAIN_DB := {
	"wood": -15.0,
	"wall": -14.0,
	"fuel": -15.0,
	"burn": -14.0,
	"hit": -16.0,
	"moth": -15.0,
	"shadow": -15.0,
	"wave": -13.0,
	"dusk": -14.0,
	"dawn": -12.0,
	"lost": -12.0,
}
const PITCHED_CUES := ["wood", "wall", "fuel", "burn", "hit", "moth", "shadow"]
const CUE_COOLDOWN_MS := 45

var ambience: AudioStreamPlayer
var drone: AudioStreamPlayer
var cue: AudioStreamPlayer
var cue_pool: Array[AudioStreamPlayer] = []
var stream_cache: Dictionary[String, AudioStream] = {}
var last_played_ms: Dictionary[String, int] = {}
var pool_cursor := 0
var pitch_cursor := 0
var target_wind_db := -24.0
var target_wind_pitch := 0.98
var target_drone_db := -34.0
var target_drone_pitch := 1.0


func setup() -> void:
	name = "BattleAudio"
	ambience = AudioStreamPlayer.new()
	var wind: AudioStreamWAV = load("res://audio/wind.wav").duplicate()
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind.loop_end = wind.data.size() / 2
	ambience.stream = wind
	ambience.volume_db = target_wind_db
	ambience.pitch_scale = target_wind_pitch
	add_child(ambience)
	ambience.play()

	drone = AudioStreamPlayer.new()
	drone.stream = build_vigil_drone()
	drone.volume_db = target_drone_db
	drone.pitch_scale = target_drone_pitch
	add_child(drone)
	drone.play()

	cue_pool.clear()
	for index in range(POOL_SIZE):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -16.0
		add_child(voice)
		cue_pool.append(voice)
	cue = cue_pool[0]


func play_cue(cue_name: String) -> void:
	if cue_pool.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	if cue_name in PITCHED_CUES and now_ms - int(last_played_ms.get(cue_name, -999)) < CUE_COOLDOWN_MS:
		return
	last_played_ms[cue_name] = now_ms
	var stream := resolve_stream(cue_name)
	if stream == null:
		return
	var voice := acquire_voice()
	voice.stream = stream
	voice.volume_db = float(CUE_GAIN_DB.get(cue_name, -16.0))
	if cue_name in PITCHED_CUES:
		voice.pitch_scale = float(PITCH_CYCLE[pitch_cursor % PITCH_CYCLE.size()])
		pitch_cursor += 1
	else:
		voice.pitch_scale = 1.0
	voice.play()


func update_atmosphere(is_night: bool, harsh_weather: bool, is_boss: bool, fire_ratio: float, ducked: bool) -> void:
	var wind_db := -19.5 if is_night else -24.0
	var wind_pitch := 0.92 if is_night else 0.98
	if harsh_weather:
		wind_db += 4.5
		wind_pitch = 1.08
	var drone_db := -23.0 if is_night else -34.0
	var drone_pitch := 1.0
	if is_night and (is_boss or fire_ratio < 0.30):
		drone_db = -18.5
		drone_pitch = 0.95
	if ducked:
		wind_db -= 8.0
		drone_db -= 8.0
	target_wind_db = wind_db
	target_wind_pitch = wind_pitch
	target_drone_db = drone_db
	target_drone_pitch = drone_pitch
	if is_instance_valid(ambience):
		ambience.volume_db = lerpf(ambience.volume_db, target_wind_db, 0.14)
		ambience.pitch_scale = lerpf(ambience.pitch_scale, target_wind_pitch, 0.14)
	if is_instance_valid(drone):
		drone.volume_db = lerpf(drone.volume_db, target_drone_db, 0.12)
		drone.pitch_scale = lerpf(drone.pitch_scale, target_drone_pitch, 0.12)


func stop_all() -> void:
	for voice in cue_pool:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	for bed in [ambience, drone]:
		if is_instance_valid(bed):
			bed.stop()
			bed.stream = null


func _exit_tree() -> void:
	stop_all()


func resolve_stream(cue_name: String) -> AudioStream:
	if stream_cache.has(cue_name):
		return stream_cache[cue_name]
	var path := "res://audio/%s.wav" % cue_name
	if not ResourceLoader.exists(path):
		return null
	var loaded := load(path) as AudioStream
	if loaded != null:
		stream_cache[cue_name] = loaded
	return loaded


func acquire_voice() -> AudioStreamPlayer:
	for offset in range(cue_pool.size()):
		var index := (pool_cursor + offset) % cue_pool.size()
		if not cue_pool[index].playing:
			pool_cursor = (index + 1) % cue_pool.size()
			return cue_pool[index]
	var fallback := cue_pool[pool_cursor]
	pool_cursor = (pool_cursor + 1) % cue_pool.size()
	return fallback


func build_vigil_drone() -> AudioStreamWAV:
	var count := roundi(DRONE_RATE * DRONE_SECONDS)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = DRONE_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for sample in range(count):
		var t := float(sample) / float(DRONE_RATE)
		var breath := 0.72 + 0.28 * sin(TAU * 0.125 * t)
		var pulse := 0.85 + 0.15 * sin(TAU * 0.375 * t + 1.1)
		var root := sin(TAU * 73.5 * t) * 0.42
		var fifth := sin(TAU * 110.0 * t + 0.4) * 0.26
		var octave := sin(TAU * 147.0 * t + 0.9) * 0.14 * pulse
		var minor_third := sin(TAU * 174.5 * t + 1.7) * 0.08 * (0.5 + 0.5 * sin(TAU * 0.25 * t))
		var value := (root + fifth + octave + minor_third) * breath * 0.48
		bytes.encode_s16(sample * 2, roundi(clampf(value, -0.85, 0.85) * 32767.0))
	stream.data = bytes
	return stream
