extends RefCounted

enum Kind { BATTLE, ELITE, CAMP, ALTAR, EVENT, BOSS }

const ZONES := ["陨王遗谷", "蚀沙古台", "枯木环堡", "黑曜长墙"]
const KIND_NAMES := ["守夜", "精英守夜", "余烬营地", "铸誓祭坛", "夜话奇遇", "永夜先驱"]
const KIND_DETAILS := [
	"黄昏搜集补给、修缮营地。入夜提灯迎敌。熬到黎明可改字铸誓。",
	"更强的怪潮将涌向火种。胜利可获得遗物与一次铸誓。",
	"添柴补回四十点篝火基准火势，或免费升级一张建筑蓝图。",
	"在三枚石碑中择一改字铸誓。可花三十余烬刷新一次。",
	"断路旁留有一段夜话。你的抉择将影响下次守夜。",
	"守住极北的火种，击败永夜先驱。胜利后可带着构筑踏入下一轮。",
]
const KIND_ACTIONS := ["进入守夜", "挑战精英", "前往营地", "走近祭坛", "查探夜话", "登上长墙"]

# Authored locations in the 1200 × 896 overview art. Random only changes the
# encounters and connections, so sites remain attached to the continent.
const SITES := [
	{ "zone": 0, "at": [Vector2(241, 754)], "types": [Kind.BATTLE] },
	{ "zone": 0, "at": [Vector2(153, 539), Vector2(305, 535), Vector2(403, 620)], "types": [Kind.CAMP, Kind.ALTAR, Kind.EVENT] },
	{ "zone": 1, "at": [Vector2(320, 327), Vector2(495, 414)], "types": [Kind.BATTLE, Kind.ELITE] },
	{ "zone": 1, "at": [Vector2(492, 539), Vector2(633, 493), Vector2(720, 384)], "types": [Kind.CAMP, Kind.ALTAR, Kind.EVENT] },
	{ "zone": 2, "at": [Vector2(792, 598), Vector2(973, 637)], "types": [Kind.BATTLE, Kind.ELITE] },
	{ "zone": 2, "at": [Vector2(790, 454), Vector2(935, 470), Vector2(1040, 518)], "types": [Kind.CAMP, Kind.ALTAR, Kind.EVENT] },
	{ "zone": 3, "at": [Vector2(649, 232), Vector2(866, 259)], "types": [Kind.BATTLE, Kind.ELITE] },
	{ "zone": 3, "at": [Vector2(434, 167), Vector2(665, 145), Vector2(886, 141)], "types": [Kind.CAMP, Kind.ALTAR, Kind.EVENT] },
	{ "zone": 3, "at": [Vector2(578, 66)], "types": [Kind.BOSS] },
]

static func generate(seed_value: int, cycle: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ (cycle * 891091)
	var first_event := rng.randi_range(0, 1)
	var result: Array[Dictionary] = []
	var previous: Array[Dictionary] = []
	for depth in range(SITES.size()):
		var row: Dictionary = SITES[depth]
		var types: Array = row.types.duplicate()
		for index in range(types.size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var swap: int = types[index]
			types[index] = types[other]
			types[other] = swap
		var next: Array[Dictionary] = []
		for track in range(row.at.size()):
			var at: Vector2 = row.at[track]
			if row.at.size() > 1:
				at += Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
			var node := {
				"id": depth * 10 + track, "depth": depth, "zone": row.zone, "kind": types[track],
				"position": at, "event": (floori(depth / 2.0) + first_event) % 2, "next": [],
			}
			next.append(node)
			result.append(node)
		_link(previous, next, rng)
		previous = next
	return result

static func _link(previous: Array[Dictionary], next: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	if previous.is_empty():
		return
	if previous.size() == 1 or next.size() == 1:
		for parent in previous:
			for child in next:
				parent.next.append(child.id)
		return
	# Every site gets a parent and each parent keeps at least one onward choice.
	# One of the neighboring connections shuffles with the route seed.
	var wide := rng.randi_range(0, previous.size() - 1)
	for index in range(previous.size()):
		var first := roundi(float(index) * (next.size() - 1) / (previous.size() - 1))
		previous[index].next.append(next[first].id)
		if index == wide or next.size() > previous.size():
			var second := clampi(first + (1 if index % 2 == 0 else -1), 0, next.size() - 1)
			if second != first:
				previous[index].next.append(next[second].id)
