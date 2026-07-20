extends RefCounted


const PLATFORM_COUNT := 5
const ABILITY_INTERVAL := 4.0
const FLOOR_TEN_ABILITY_INTERVAL := 2.75
const SLOW_PER_BROKEN_PLATFORM := 0.12
const INTIMIDATION_DAMAGE_PENALTY := 0.30
const INTIMIDATION_ACTIONS := 3
const HEAVY_ATTACK_DAMAGE := 110.0
const CARAPACE_REDUCTION := 0.70

const ABILITY_CYCLE: Array[String] = [
	"slow",
	"intimidation",
	"heavy_attack",
	"defense",
]
const FLOOR_TEN_ABILITY_CYCLE: Array[String] = [
	"reverse_loop",
	"intimidation",
	"heavy_attack",
	"defense",
	"slow",
]



static func ability_cycle(floor_number: int) -> Array[String]:
	if floor_number == 10:
		return FLOOR_TEN_ABILITY_CYCLE
	return ABILITY_CYCLE


static func ability_interval(floor_number: int) -> float:
	if floor_number == 10:
		return FLOOR_TEN_ABILITY_INTERVAL
	return ABILITY_INTERVAL


static func ability_name(ability_id: String) -> String:
	match ability_id:
		"reverse_loop":
			return "逆序刻印"
		"slow":
			return "迟缓·碎裂地板"
		"intimidation":
			return "恫吓"
		"heavy_attack":
			return "势大力沉"
		"defense":
			return "外骨骼硬化"
		_:
			return "未知技能"
