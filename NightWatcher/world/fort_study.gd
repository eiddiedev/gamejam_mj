extends RefCounted

const ROOT_SHADER = preload("res://world/study_root.gdshader")
const PAGE_ORIGIN := Vector2(425, 108)
const PAGE_SIZE := Vector2i(571, 410)
const PENCIL := Color(1, 0, 0)
const FIRE_PENCIL := Color(0, 1, 0)
const MOSS := Color(0, 0, 1)

static func make_marks() -> ImageTexture:
	var page := Image.create_empty(PAGE_SIZE.x, PAGE_SIZE.y, false, Image.FORMAT_RGB8)
	# The marks are composed for the original orthographic play view.
	stroke(page, [Vector2(705,264), Vector2(717,265), Vector2(729,260), Vector2(741,258),
		Vector2(752,263), Vector2(769,268), Vector2(779,273), Vector2(792,278)], 1.75, PENCIL)
	stroke(page, [Vector2(800,279), Vector2(817,281), Vector2(826,285), Vector2(829,291),
		Vector2(839,302), Vector2(847,309), Vector2(861,321), Vector2(870,330)], 1.8, PENCIL)
	stroke(page, [Vector2(875,338), Vector2(880,350), Vector2(889,359), Vector2(896,372),
		Vector2(902,386), Vector2(903,392), Vector2(908,398)], 1.55, PENCIL)
	stroke(page, [Vector2(911,408), Vector2(913,420), Vector2(924,425), Vector2(941,424)], 1.40, PENCIL)
	stroke(page, [Vector2(714,286), Vector2(724,285), Vector2(729,291), Vector2(741,290)], 1.1, PENCIL)
	stroke(page, [Vector2(745,285), Vector2(756,288), Vector2(765,295), Vector2(780,300),
		Vector2(784,307), Vector2(794,310)], 1.18, PENCIL)
	stroke(page, [Vector2(814,302), Vector2(811,311), Vector2(820,316), Vector2(831,319)], 1.22, PENCIL)
	stroke(page, [Vector2(844,327), Vector2(850,333), Vector2(856,332), Vector2(860,339)], 1.08, PENCIL)
	stroke(page, [Vector2(799,253), Vector2(803,258), Vector2(801,263), Vector2(807,267)], 1.07, PENCIL)
	stroke(page, [Vector2(919,375), Vector2(923,380), Vector2(932,382), Vector2(936,387)], 1.12, PENCIL)
	stroke(page, [Vector2(731,261), Vector2(738,260), Vector2(747,262), Vector2(754,266)], 1.62, FIRE_PENCIL)
	stroke(page, [Vector2(763,267), Vector2(773,272), Vector2(788,277), Vector2(797,279),
		Vector2(805,279)], 1.85, FIRE_PENCIL)
	stroke(page, [Vector2(819,284), Vector2(827,289), Vector2(829,296), Vector2(839,306),
		Vector2(845,310)], 1.85, FIRE_PENCIL)
	stroke(page, [Vector2(853,317), Vector2(860,322), Vector2(864,328), Vector2(867,331)], 1.34, FIRE_PENCIL)
	# A continuous rim and just a few fan joints carry the arch silhouette.
	stroke(page, [Vector2(699,165), Vector2(712,161), Vector2(728,156), Vector2(741,155),
		Vector2(752,155), Vector2(761,158), Vector2(773,159), Vector2(789,166), Vector2(796,174)], 1.32, PENCIL)
	stroke(page, [Vector2(714,136), Vector2(714,144), Vector2(720,151), Vector2(721,157)], 1.02, PENCIL)
	stroke(page, [Vector2(744,121), Vector2(741,131), Vector2(743,139), Vector2(742,153)], 1.07, PENCIL)
	stroke(page, [Vector2(773,124), Vector2(771,135), Vector2(767,147), Vector2(767,152)], 1.03, PENCIL)
	stroke(page, [Vector2(794,181), Vector2(795,193), Vector2(794,204), Vector2(796,211),
		Vector2(795,223)], 1.25, PENCIL)
	stroke(page, [Vector2(797,211), Vector2(802,209), Vector2(810,209)], 0.90, PENCIL)
	# Low bark fibers fork and then disappear into the root's shadow.
	stroke(page, [Vector2(460,405), Vector2(468,418), Vector2(475,432), Vector2(477,441),
		Vector2(484,454), Vector2(494,466), Vector2(506,472)], 1.92, PENCIL)
	stroke(page, [Vector2(475,431), Vector2(486,440), Vector2(493,451), Vector2(502,459),
		Vector2(520,465), Vector2(537,475), Vector2(551,481)], 1.55, PENCIL)
	stroke(page, [Vector2(490,401), Vector2(495,415), Vector2(503,427), Vector2(516,438),
		Vector2(530,437), Vector2(543,433)], 1.37, PENCIL)
	stroke(page, [Vector2(499,442), Vector2(506,445), Vector2(513,441), Vector2(515,436)], 1.15, PENCIL)
	# Dry moss marks tucked into the masonry, with visible stone between them.
	stroke(page, [Vector2(755,299), Vector2(759,298), Vector2(764,301), Vector2(771,301),
		Vector2(775,304)], 4.60, MOSS)
	stroke(page, [Vector2(870,349), Vector2(869,353), Vector2(873,356), Vector2(879,365)], 5.10, MOSS)
	stroke(page, [Vector2(802,217), Vector2(807,217), Vector2(805,221), Vector2(811,227)], 4.30, MOSS)
	return ImageTexture.create_from_image(page)

static func apply_marks(material: ShaderMaterial, marks: ImageTexture) -> void:
	material.set_shader_parameter("marks", marks)
	material.set_shader_parameter("marks_bounds", Vector4(PAGE_ORIGIN.x, PAGE_ORIGIN.y, PAGE_SIZE.x, PAGE_SIZE.y))

static func stroke(page: Image, path: Array[Vector2], width: float, channel: Color) -> void:
	for index in range(path.size() - 1):
		var start := path[index] - PAGE_ORIGIN
		var end := path[index + 1] - PAGE_ORIGIN
		var travel := end - start
		var margin := Vector2.ONE * (width + 1.0)
		var first := Vector2i((start.min(end) - margin).floor()).max(Vector2i.ZERO)
		var last := Vector2i((start.max(end) + margin).ceil()).min(PAGE_SIZE - Vector2i.ONE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var at := Vector2(x, y) + Vector2(0.5, 0.5)
				var t := clampf((at - start).dot(travel) / travel.length_squared(), 0.0, 1.0)
				var progress := (index + t) / float(path.size() - 1)
				var taper := smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.86, 1.0, progress))
				var pressure := 0.75 + 0.25 * sin(progress * 15.4 + width) ** 2
				var radius := width * 0.5 * lerpf(0.34, 1.0, taper) * pressure
				var coverage := 1.0 - smoothstep(radius - 0.42, radius + 0.52, at.distance_to(start + travel * t))
				var old := page.get_pixel(x, y)
				page.set_pixel(x, y, Color(maxf(old.r, channel.r * coverage),
					maxf(old.g, channel.g * coverage), maxf(old.b, channel.b * coverage)))
