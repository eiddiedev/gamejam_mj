class_name BattleAudio
extends Node

var ambience: AudioStreamPlayer
var cue: AudioStreamPlayer


func setup() -> void:
	name = "BattleAudio"
	ambience = AudioStreamPlayer.new()
	var wind: AudioStreamWAV = load("res://audio/wind.wav").duplicate()
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind.loop_end = wind.data.size() / 2
	ambience.stream = wind
	ambience.volume_db = -23.0
	add_child(ambience)
	ambience.play()
	cue = AudioStreamPlayer.new()
	cue.volume_db = -16.0
	add_child(cue)


func play_cue(cue_name: String) -> void:
	cue.stream = load("res://audio/%s.wav" % cue_name)
	cue.play()
