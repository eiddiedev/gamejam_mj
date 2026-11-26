class_name BattleViewState
extends RefCounted

var night := false
var night_number := 1
var phase_left := 0.0
var phase_progress := 1.0
var fire_hp := 100.0
var oil := 100.0
var embers := 0
var bone := 0
var spawner_remaining := 0
var live_enemies := 0
var player_hp := 100.0
var player_hp_max := 100.0
var xp := 0
var rank_previous := 0
var rank_target := 14
var night_rank := 1
var kills := 0
var ended := false
var paused := false
var weather_text := ""
var action_hint := ""

var inspect_visible := false
var inspect_selecting := false
var inspect_at := Vector2.ZERO
var inspect_marker := Vector2.ZERO
var inspect_radius := 0.0
var inspect_current := 0.0
var inspect_planned := 0.0
var inspect_title := ""
var inspect_level := 0
