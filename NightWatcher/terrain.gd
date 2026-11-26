extends RefCounted

const CANVAS_SIZE := Vector2(600, 750)
const FIRE := Vector2(354, 402)
const START := Vector2(358, 449)
const STASHES := [Vector2(329, 213), Vector2(419, 208), Vector2(565, 448),
	Vector2(405, 600), Vector2(243, 454), Vector2(378, 431)]
const GATES := [Vector2(335, 279), Vector2(521, 444), Vector2(390, 548)]
const GATE_ANGLES := [-0.22, 1.16, -0.26]

# Courtyard and approach paths use the same map coordinates as the drawn scenery.
static var playable: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(306,277), Vector2(355,276), Vector2(391,292), Vector2(426,309),
		Vector2(465,340), Vector2(486,377), Vector2(503,417), Vector2(520,431), Vector2(539,446),
		Vector2(503,463), Vector2(480,470), Vector2(462,511), Vector2(429,527), Vector2(418,545),
		Vector2(392,559), Vector2(368,544), Vector2(332,535), Vector2(268,525), Vector2(238,505),
		Vector2(213,481), Vector2(195,449), Vector2(219,420), Vector2(222,386), Vector2(192,356),
		Vector2(207,334), Vector2(250,313), Vector2(291,302)]),
	PackedVector2Array([Vector2(294,291), Vector2(315,259), Vector2(305,236), Vector2(291,207),
		Vector2(319,185), Vector2(346,177), Vector2(368,139), Vector2(395,131), Vector2(412,157),
		Vector2(394,182), Vector2(389,202), Vector2(441,190), Vector2(466,201), Vector2(474,221),
		Vector2(443,235), Vector2(407,231), Vector2(375,222), Vector2(354,234), Vector2(355,262),
		Vector2(359,291)]),
	PackedVector2Array([Vector2(488,438), Vector2(519,432), Vector2(547,430), Vector2(569,421),
		Vector2(597,415), Vector2(597,456), Vector2(576,466), Vector2(550,474), Vector2(520,469),
		Vector2(494,463)]),
	PackedVector2Array([Vector2(359,518), Vector2(405,517), Vector2(423,548), Vector2(417,564),
		Vector2(428,590), Vector2(419,625), Vector2(438,654), Vector2(463,673), Vector2(479,699),
		Vector2(445,708), Vector2(417,680), Vector2(386,664), Vector2(372,637), Vector2(369,602),
		Vector2(357,579), Vector2(352,546)])
]

const WALL_RUNS := [
	[Vector2(311,270), Vector2(260,280), Vector2(210,304), Vector2(167,341),
		Vector2(143,386), Vector2(144,440), Vector2(169,491), Vector2(215,532),
		Vector2(269,558), Vector2(315,567), Vector2(365,559)],
	[Vector2(360,268), Vector2(409,281), Vector2(458,307), Vector2(501,344),
		Vector2(526,382), Vector2(535,423)],
	[Vector2(535,467), Vector2(514,500), Vector2(475,531), Vector2(412,553)],
]

const TRUNK := Vector2(168, 407)

static var static_occluders: Array[PackedVector2Array] = make_occluders()

static func make_occluders() -> Array[PackedVector2Array]:
	var blockers: Array[PackedVector2Array] = []
	for run in WALL_RUNS:
		for index in range(run.size() - 1):
			var a: Vector2 = run[index]
			var b: Vector2 = run[index + 1]
			var side := a.direction_to(b).orthogonal() * 7.4
			blockers.append(PackedVector2Array([a + side, b + side, b - side, a - side]))
	blockers.append(PackedVector2Array([Vector2(145,385), Vector2(178,385), Vector2(200,416),
		Vector2(214,436), Vector2(177,438), Vector2(147,424)]))
	return blockers

static func walkable(point: Vector2) -> bool:
	for region in static_occluders:
		if Geometry2D.is_point_in_polygon(point, region):
			return false
	for region in playable:
		if Geometry2D.is_point_in_polygon(point, region):
			return true
	return false

static func route(index: int, variant: int) -> PackedVector2Array:
	var shift := float(variant % 3 - 1) * 6.0
	match index:
		0:
			return PackedVector2Array([Vector2(385 + shift, 148), Vector2(361 + shift, 183),
				Vector2(332 + shift, 213), Vector2(337 + shift, 249), GATES[0],
				FIRE + Vector2(-6 + shift * 0.35, -13)])
		1:
			return PackedVector2Array([Vector2(594, 445 + shift), Vector2(561, 450 + shift),
				GATES[1], FIRE + Vector2(13, 4 + shift * 0.35)])
		_:
			return PackedVector2Array([Vector2(434 + shift, 671), Vector2(397 + shift, 618),
				Vector2(391 + shift, 580), GATES[2], FIRE + Vector2(4 + shift * 0.35, 13)])
