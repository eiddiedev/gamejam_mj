extends RefCounted

enum Phase { DUSK, NIGHT, DAWN, LOST }

const DUSK_TIME := 58.0
const NIGHT_TIME := 58.0
const NIGHTS := 2

var phase := Phase.DUSK
var night_number := 1
var left := DUSK_TIME
var age := 0.0

func advance(delta: float) -> void:
	age += delta
	left = maxf(0.0, left - delta)

func start_night() -> void:
	phase = Phase.NIGHT
	left = NIGHT_TIME
	age = 0.0

func next_dusk() -> void:
	night_number += 1
	phase = Phase.DUSK
	left = DUSK_TIME
	age = 0.0

func finish(won: bool) -> void:
	phase = Phase.DAWN if won else Phase.LOST
	left = 0.0

func progress() -> float:
	return left / (DUSK_TIME if phase == Phase.DUSK else NIGHT_TIME)
