extends RefCounted


const PLATFORM_COUNT := 5
const ABILITY_INTERVAL := 4.0
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


static func ability_name(ability_id: String) -> String:
	match ability_id:
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
