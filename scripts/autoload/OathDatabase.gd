extends Node

const OathDef = preload("res://scripts/data/OathData.gd")
const COMMON := "common"
const RARE := "rare"
const EPIC := "epic"

const OATHS := {
	"SWORE": {"base": "SWORD", "letter": 4, "rarity": EPIC, "title": "金色誓约",
		"effect": "剑刃命中时，220 范围内的防御塔获得 35% 攻速与 20% 暴击率，持续 4 秒。"},
	"CAMP": {"base": "LAMP", "letter": 0, "rarity": RARE, "title": "提灯营地",
		"effect": "原地站立 1.5 秒后，开启的提灯光照半径翻倍，并修复附近的防御塔和路障。"},
	"STOP": {"base": "STEP", "letter": 2, "rarity": RARE, "title": "残影信标",
		"effect": "冲刺在起点留下残影，使 140 范围内的敌人定身 2.5 秒。"},
	"NEAR": {"base": "FEAR", "letter": 0, "rarity": COMMON, "title": "孤身赴暗",
		"effect": "离中央篝火越远，近战伤害与移动速度越高，最多增加 60%。"},
	"MIGHT": {"base": "LIGHT", "letter": 0, "rarity": EPIC, "title": "光焰威能",
		"effect": "所有光源都会灼烧照亮的敌人，伤害随光强增加。"},
	"FIGHT": {"base": "LIGHT", "letter": 0, "rarity": RARE, "title": "沸腾战意",
		"effect": "受光照的防御塔攻击间隔缩短 25%，暴击时额外获得 1 点余烬。"},
	"SHARK": {"base": "SPARK", "letter": 1, "rarity": RARE, "title": "噬暗火灵",
		"effect": "烽火盆熄灭或火油燃尽时，释放 5 道追踪火灵扑向最近的敌人。"},
	"ASK": {"base": "ASH", "letter": 2, "rarity": COMMON, "title": "余烬祈愿",
		"effect": "消耗余烬为篝火添火或修复建筑时，重置技能冷却并触发全图齐射。"},
	"WILL": {"base": "WALL", "letter": 1, "rarity": EPIC, "title": "不屈壁垒",
		"effect": "路障损毁时化为无敌光墙，继续阻敌 5 秒。每座路障每晚触发一次。"},
	"BOND": {"base": "BONE", "letter": 3, "rarity": EPIC, "title": "金色羁绊",
		"effect": "260 范围内的建筑以金色光链相连。光链照亮、减速并电击途经的敌人。"},
	"WRAP": {"base": "TRAP", "letter": 0, "rarity": RARE, "title": "焦土荆棘",
		"effect": "引燃火油会使范围内的敌人定身 3 秒，期间受到的火焰伤害翻倍。"},
	"POWER": {"base": "TOWER", "letter": 0, "rarity": RARE, "title": "破晓穿甲炮",
		"effect": "骨弩静候满 3 秒后，下一射造成 350% 的范围爆炸伤害。"},
	"GOLD": {"base": "COLD", "letter": 0, "rarity": EPIC, "title": "余烬之金",
		"effect": "深夜后半段、暴风雪或迷雾期间，击杀掉落的余烬和骨材翻倍。"},
	"MARK": {"base": "DARK", "letter": 0, "rarity": RARE, "title": "破暗印记",
		"effect": "敌人从阴影踏入光照时被标记，5 秒内受到的所有伤害增加 40%。"},
	"DUST": {"base": "RUST", "letter": 0, "rarity": COMMON, "title": "铁锈尘爆",
		"effect": "敌人死亡时炸出腐蚀尘雾，伤害周围敌人并传染燃烧。"},
	"FAST": {"base": "LAST", "letter": 0, "rarity": EPIC, "title": "绝境疾风",
		"effect": "篝火低于 30 时，守夜人与防御塔攻速翻倍，守夜人移速翻倍，每次击杀回火 1 点。"},
}

var oath_defs: Dictionary[String, OathDef] = {}


func _init() -> void:
	for id: String in OATHS:
		var entry: Dictionary = OATHS[id]
		oath_defs[id] = OathDef.create(id, entry["base"], entry["letter"], entry["rarity"], entry["title"], entry["effect"])


func get_oath_data(id: String) -> OathDef:
	return oath_defs[id] if oath_defs.has(id) else null


func get_oath(id: String) -> Dictionary:
	var data := get_oath_data(id)
	return data.to_dict() if data != null else {}

func has_oath(owned: Array, id: String) -> bool:
	return id in owned

func epic_unowned(owned: Array) -> Array[String]:
	var choices: Array[String] = []
	for id: String in OATHS:
		if OATHS[id]["rarity"] == EPIC and not has_oath(owned, id):
			choices.append(id)
	return choices

func draw_oaths(owned: Array, force_id := "", previous: Array = []) -> Array[String]:
	var picks: Array[String] = []
	if OATHS.has(force_id) and not has_oath(owned, force_id):
		picks.append(force_id)
	var fresh: Array[String] = []
	var rest: Array[String] = []
	for id: String in OATHS:
		if id in owned or id in picks:
			continue
		if id in previous:
			rest.append(id)
		else:
			fresh.append(id)
	for pool in [fresh, rest]:
		for id: String in pool:
			if picks.size() >= 3:
				break
			picks.append(id)
	return picks

func player_modifiers(owned: Array, distance_to_fire: float, fire_hp: float) -> Dictionary:
	var range_bonus := clampf(distance_to_fire / 450.0, 0.0, 1.0) * 0.60 if has_oath(owned, "NEAR") else 0.0
	var haste := 2.0 if fast_active(owned, fire_hp) else 1.0
	return {"move": (1.0 + range_bonus) * haste, "melee": 1.0 + range_bonus, "attack_speed": haste}

func tower_modifiers(owned: Array, lit: bool, sworn: bool, idle: float, fire_hp: float) -> Dictionary:
	var interval := 0.75 if lit and has_oath(owned, "FIGHT") else 1.0
	var speed := (1.35 if sworn else 1.0) * (2.0 if fast_active(owned, fire_hp) else 1.0)
	return {"attack_speed": speed, "attack_interval": interval, "crit": 0.20 if sworn else 0.0,
		"power": 3.50 if idle >= 3.0 and has_oath(owned, "POWER") else 1.0}

func lantern_modifiers(owned: Array, still: float) -> Dictionary:
	var active := still >= 1.5 and has_oath(owned, "CAMP")
	return {"radius": 2.0 if active else 1.0, "repair": 7.0 if active else 0.0}

func on_player_slash(owned: Array) -> Dictionary:
	return {"radius": 220.0, "seconds": 4.0, "attack_speed": 1.35, "crit": 0.20} if has_oath(owned, "SWORE") else {}

func on_dash(owned: Array) -> Dictionary:
	return {"radius": 140.0, "seconds": 2.5} if has_oath(owned, "STOP") else {}

func light_damage(owned: Array, strength: float) -> float:
	return 8.0 * maxf(0.0, strength) if has_oath(owned, "MIGHT") else 0.0

func on_tower_attack(owned: Array, lit: bool, critical: bool) -> Dictionary:
	var ember_reward := 1 if lit and critical and has_oath(owned, "FIGHT") else 0
	return {"embers": ember_reward}

func on_light_gone(owned: Array) -> Dictionary:
	return {"count": 5, "damage": 18.0, "radius": 320.0} if has_oath(owned, "SHARK") else {}

func on_ember_spend(owned: Array, reason: String) -> Dictionary:
	if reason in ["fuel", "repair"] and has_oath(owned, "ASK"):
		return {"reset_skills": true, "salvo": true}
	return {}

func on_barricade_break(owned: Array, used_this_night: bool) -> Dictionary:
	return {"seconds": 5.0} if has_oath(owned, "WILL") and not used_this_night else {}

func bond_modifiers(owned: Array) -> Dictionary:
	return {"range": 260.0, "width": 17.0, "dps": 6.5, "slow": 0.23} if has_oath(owned, "BOND") else {}

func on_oil_ignite(owned: Array) -> Dictionary:
	return {"seconds": 3.0, "fire_scale": 2.0} if has_oath(owned, "WRAP") else {}

func on_enemy_lit(owned: Array, previously_lit: bool, currently_lit: bool) -> Dictionary:
	if not previously_lit and currently_lit and has_oath(owned, "MARK"):
		return {"seconds": 5.0, "damage_scale": 1.40}
	return {}

func damage_modifier(marked: bool, wrapped: bool, flame: bool) -> float:
	var exposure := 1.40 if marked else 1.0
	var oil := 2.0 if wrapped and flame else 1.0
	return exposure * oil

func on_enemy_killed(owned: Array, fire_hp: float, night_fraction: float, harsh_weather: bool,
		was_burning := false) -> Dictionary:
	var gilded := has_oath(owned, "GOLD") and (night_fraction >= 0.5 or harsh_weather)
	var dust := {}
	if has_oath(owned, "DUST"):
		dust = {"radius": 56.0, "damage": 18.0, "burn_seconds": 2.4 if was_burning else 0.0}
	return {"loot_scale": 2 if gilded else 1, "fire_heal": 1.0 if fast_active(owned, fire_hp) else 0.0,
		"dust": dust}

func fast_active(owned: Array, fire_hp: float) -> bool:
	return fire_hp > 0.0 and fire_hp < 30.0 and has_oath(owned, "FAST")
