extends Node
## Component that owns XP and level-up logic for an entity.
## Depends on: StatsComponent (stat gains on level-up).

const LevelData = preload("res://scripts/data/level_data.gd")

var _stats: Node  # StatsComponent ref

func setup(stats_component: Node) -> void:
	_stats = stats_component

func grant_xp(entity_id: String, amount: int) -> void:
	var data := WorldState.get_entity_data(entity_id)
	var xp: int = data.get("xp", 0) + amount
	var level: int = data.get("level", 1)
	var xp_needed: int = LevelData.xp_to_next_level(level)

	while xp >= xp_needed and level < LevelData.MAX_LEVEL:
		xp -= xp_needed
		level += 1
		# Apply stat gains via StatsComponent
		_stats.max_hp += LevelData.HP_PER_LEVEL
		_stats.hp = _stats.max_hp
		_stats.atk += LevelData.ATK_PER_LEVEL
		_stats.def += LevelData.DEF_PER_LEVEL
		_stats.level = level
		_stats._sync()

		var sp: int = data.get("skill_points", 0) + LevelData.SKILL_POINTS_PER_LEVEL
		WorldState.set_entity_data(entity_id, "skill_points", sp)
		GameEvents.level_up.emit(entity_id, level)
		xp_needed = LevelData.xp_to_next_level(level)

	WorldState.set_entity_data(entity_id, "xp", xp)
	WorldState.set_entity_data(entity_id, "level", level)
	GameEvents.xp_gained.emit(entity_id, amount)
