extends RefCounted

const Relic = preload("res://scripts/model/ObsidianRelic.gd")
const STONE := Color("#535866")
const DARK := Color("#454655")
const SNOW := Color("#aab8c4")
const FROST := Color("#7f92a4")
const ICED := Color("#72798c")

static func build(world) -> void:
	for index in range(18):
		var at := Vector2(index*44.0-15, 25.0+sin(index*0.72)*32.0)
		var height: float = world.random.randf_range(1.7, 3.5)
		world.ellipsoid(world.from_floor(at,height*0.46),
			Vector3(world.random.randf_range(0.92,1.59),height,world.random.randf_range(0.90,1.57)),
			world.weathered(DARK,0.088), 7,5)
		world.ellipsoid(world.from_floor(at+Vector2(-7,5),height*1.09),Vector3(0.57,height*0.41,0.51),
			world.weathered(FROST,0.046),7,5)
	for index in range(12):
		var y := index*45.0 + 35
		var x: float = 757 - sin(index*0.8)*23.0
		var height: float = world.random.randf_range(0.75,2.19)
		world.ellipsoid(world.at(x,y,height*0.27),Vector3(0.67,height,1.0),
			world.weathered(STONE,0.09),7,6)
		world.stone(x,y+5,25,26,0.08,world.weathered(SNOW,0.08),0.2,height*1.06)
	wall_walk(world)
	Relic.build(world)
	for index in range(37):
		var at := Vector2(world.random.randf_range(33,696),world.random.randf_range(83,463))
		if world.route_distance(at) < 15.0 or world.slot_distance(at) < 18.0:
			continue
		var width: float = world.random.randf_range(10,31)
		world.ring_patch(at,Vector2(width,width*0.63),0.024,world.weathered(SNOW,0.08),9)
		if index%3==0:
			world.ellipsoid(world.from_floor(at,0.10),Vector3(0.39,0.31,0.35),
				world.weathered(ICED,0.10),7,5)

static func wall_walk(world) -> void:
	var wall := [Vector2(233,119),Vector2(286,146),Vector2(338,176),Vector2(395,213),Vector2(454,241)]
	world.wall(wall,2.61,STONE,31.0)
	world.wall([Vector2(377,302),Vector2(411,325),Vector2(440,334)],1.24,STONE,24.0)
	world.wall([Vector2(475,317),Vector2(517,325),Vector2(570,299),Vector2(602,288)],1.80,STONE,29.0)
	world.wall([Vector2(673,227),Vector2(711,247),Vector2(727,271)],1.59,STONE,25.0)
	world.wall([Vector2(513,139),Vector2(546,160),Vector2(588,157),Vector2(620,143)],1.40,ICED,23.0)
	world.arch(Vector2(460,270),37.0,2.15,ICED,0.34)
	world.arch(Vector2(615,146),22.0,1.86,ICED,-0.53)
	turret(world,Vector2(458,227),2.61)
	turret(world,Vector2(574,138),2.95)
	world.steps(Vector2(714,93),Vector2(675,155),28.0,0.52,10,ICED)
	world.steps(Vector2(655,306),Vector2(630,250),34.0,0.25,8,ICED)

static func turret(world, at: Vector2, height: float) -> void:
	for row in range(8):
		var y := height*row/8.0
		world.stone(at.x,at.y,27.5,28.2,height/8.0,world.weathered(STONE,0.047),0.09,y)
	world.stone(at.x,at.y,33.0,34,0.18,ICED,0.09,height)
	for dx in [-12,12]:
		for dy in [-12,12]:
			world.stone(at.x+dx,at.y+dy,7,7,0.36,STONE,0.09,height+0.16)
