extends Node

const Route = preload("res://scripts/campaign/Route.gd")
const TOWERS := { "brazier": "烽火盆", "ballista": "骨弩台", "barricade": "誓言路障", "oil": "火油槽" }
const RELICS := {
	"守火铜环": "每场胜利后额外补回十二点基准火势。",
	"巡夜油芯": "每场守夜开始前补充十六点提灯油。",
	"骨匠契印": "每场胜利额外收获十份骨材。",
	"极北余辉": "每场胜利额外收获十点余烬。",
}

var cycle := 1
var embers := 68
var bone := 38
var oaths: Array[String] = []
var blueprints: Dictionary = {}
var relics: Array[String] = []
var fire_start := 100.0
var oil_start := 100.0
var ally := false
var speed_bonus := 0.0
var nodes: Array[Dictionary] = []
var visited: Array[int] = []
var current_node := -1
var active_node := -1
var victories := 0
var battle_reserve: Dictionary = {}

func start_new() -> void:
	cycle = 1
	embers = 68
	bone = 38
	oaths.clear()
	blueprints.clear()
	relics.clear()
	_reset_route()

func start_next_cycle() -> void:
	cycle += 1
	embers = maxi(embers, 68)
	bone = maxi(bone, 38)
	_reset_route()

func _reset_route() -> void:
	nodes = Route.generate(cycle)
	visited.clear()
	current_node = -1
	active_node = -1
	victories = 0
	battle_reserve.clear()
	fire_start = 100.0
	oil_start = 100.0
	ally = false
	speed_bonus = 0.0

func get_node_data(id: int) -> Dictionary:
	for node in nodes:
		if node.id == id:
			return node
	return {}

func available_nodes() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if active_node >= 0 or nodes.is_empty():
		return available
	if current_node < 0:
		available.append(nodes[0])
	else:
		for id in get_node_data(current_node).next:
			available.append(get_node_data(id))
	return available

func begin_node(id: int) -> bool:
	for node in available_nodes():
		if node.id == id:
			active_node = id
			return true
	return false

func complete_node() -> void:
	if active_node >= 0:
		current_node = active_node
		visited.append(active_node)
		active_node = -1

func prepare_battle() -> void:
	battle_reserve = { "embers": embers, "bone": bone, "oil": oil_start }
	if relics.has("巡夜油芯"):
		oil_start = minf(100.0, oil_start + 16.0)

func abandon_node() -> void:
	if not battle_reserve.is_empty():
		embers = battle_reserve.embers
		bone = battle_reserve.bone
		oil_start = battle_reserve.oil
		battle_reserve.clear()
	active_node = -1

func settle_battle(health: float, elite: bool) -> String:
	battle_reserve.clear()
	var repair := 12.0 if relics.has("守火铜环") else 0.0
	fire_start = clampf(health + repair, 30.0, 100.0)
	oil_start = 100.0
	ally = false
	speed_bonus = 0.0
	embers += (30 if elite else 20) + (10 if relics.has("极北余辉") else 0)
	bone += (20 if elite else 12) + (10 if relics.has("骨匠契印") else 0)
	victories += 1
	if not elite:
		return ""
	var remaining := RELICS.keys().filter(func(id): return not relics.has(id))
	if remaining.is_empty():
		return ""
	var gained: String = remaining[0]
	relics.append(gained)
	return gained

func spend_embers(amount: int) -> bool:
	if amount < 0 or embers < amount:
		return false
	embers -= amount
	return true

func add_oath(id: String) -> void:
	if not id.is_empty() and not oaths.has(id):
		oaths.append(id)

func rest_fire() -> void:
	fire_start = minf(100.0, fire_start + 40.0)

func upgrade_blueprint(tower: String) -> bool:
	if not TOWERS.has(tower):
		return false
	var level: int = blueprints.get(tower, 1)
	if level >= 3:
		return false
	blueprints[tower] = level + 1
	return true
