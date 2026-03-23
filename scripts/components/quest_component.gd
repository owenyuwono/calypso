extends BaseComponent
class_name QuestComponent
## Component that owns quest progress state for an entity.
## Tracks active quests, completed quests, and arbitrary condition flags.
## Auto-updates kill/gather objectives from GameEvents signals.

const QuestDatabase = preload("res://scripts/data/quest_database.gd")

var _active: Dictionary = {}     # quest_id → {progress: {objective_idx: count}}
var _completed: Array = []       # completed quest_ids
var _flags: Dictionary = {}      # arbitrary bool flags for conditions


func _ready() -> void:
	GameEvents.item_looted.connect(_on_item_looted)
	GameEvents.entity_died.connect(_on_entity_died)


# --- Public API ---

func accept_quest(quest_id: String) -> bool:
	## Validate, check prerequisites, initialize progress, emit quest_accepted.
	## Returns true on success.
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return false

	if not can_accept_quest(quest_id):
		return false

	# Initialize progress for all objectives at count 0
	var progress: Dictionary = {}
	for i in quest.objectives.size():
		progress[i] = 0
	_active[quest_id] = {"progress": progress}

	GameEvents.quest_accepted.emit(_get_entity_id(), quest_id)
	return true


func update_objective_progress(quest_id: String, objective_idx: int, amount: int = 1) -> void:
	## Increment progress for one objective, clamp to target, emit update signal.
	if not _active.has(quest_id):
		return
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return
	if objective_idx < 0 or objective_idx >= quest.objectives.size():
		return

	var target: int = quest.objectives[objective_idx].get("count", 1)
	var progress: Dictionary = _active[quest_id]["progress"]
	progress[objective_idx] = mini(progress.get(objective_idx, 0) + amount, target)

	GameEvents.quest_objective_updated.emit(_get_entity_id(), quest_id, objective_idx, progress[objective_idx])


func try_complete_quest(quest_id: String) -> Dictionary:
	## If all objectives are met, remove from active, add to completed, return rewards.
	## Returns empty dict if not completable.
	if not is_quest_completable(quest_id):
		return {}

	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	_active.erase(quest_id)
	_completed.append(quest_id)

	var rewards: Dictionary = quest.get("rewards", {})
	GameEvents.quest_completed.emit(_get_entity_id(), quest_id, rewards)
	return rewards


func is_quest_active(quest_id: String) -> bool:
	return _active.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return _completed.has(quest_id)


func is_quest_completable(quest_id: String) -> bool:
	## True if quest is active and all objectives are at their target count.
	if not _active.has(quest_id):
		return false
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return false
	var progress: Dictionary = _active[quest_id]["progress"]
	for i in quest.objectives.size():
		var obj: Dictionary = quest.objectives[i]
		var target: int = obj.get("count", 1)
		if progress.get(i, 0) < target:
			return false
	return true


func get_progress(quest_id: String, objective_idx: int) -> int:
	if not _active.has(quest_id):
		return 0
	return _active[quest_id]["progress"].get(objective_idx, 0)


func get_active_quests() -> Dictionary:
	return _active


func get_completed_quests() -> Array:
	return _completed


func set_flag(flag_name: String) -> void:
	_flags[flag_name] = true


func has_flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)


func can_accept_quest(quest_id: String) -> bool:
	## Check prerequisites without side effects.
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return false

	# Already active — only allow if repeatable
	if _active.has(quest_id):
		return quest.get("repeatable", false)

	# Already completed — only allow if repeatable
	if _completed.has(quest_id):
		return quest.get("repeatable", false)

	# Check prerequisite quests
	for prereq_id in quest.get("prerequisite_quests", []):
		if not _completed.has(prereq_id):
			return false

	# Check prerequisite flags
	for flag_name in quest.get("prerequisite_flags", []):
		if not _flags.get(flag_name, false):
			return false

	return true


func check_condition(condition: String) -> bool:
	## Parse a condition string and evaluate it.
	## Supported forms:
	##   "quest:quest_id:not_started"  — not active and not completed
	##   "quest:quest_id:active"       — is_quest_active
	##   "quest:quest_id:completed"    — is_quest_completed
	##   "quest:quest_id:completable"  — all objectives done, not yet turned in
	##   "flag:flag_name"              — has_flag
	var parts: Array = condition.split(":")
	if parts.size() < 2:
		return false

	var kind: String = parts[0]

	if kind == "flag":
		return has_flag(parts[1])

	if kind == "quest" and parts.size() >= 3:
		var quest_id: String = parts[1]
		var state: String = parts[2]
		match state:
			"not_started":
				return not is_quest_active(quest_id) and not is_quest_completed(quest_id)
			"active":
				return is_quest_active(quest_id)
			"completed":
				return is_quest_completed(quest_id)
			"completable":
				return is_quest_completable(quest_id)

	return false


# --- GameEvents handlers ---

func _on_item_looted(entity_id: String, item_id: String, _count: int) -> void:
	if entity_id != _get_entity_id():
		return
	for quest_id in _active:
		var quest: Dictionary = QuestDatabase.get_quest(quest_id)
		for i in quest.objectives.size():
			var obj: Dictionary = quest.objectives[i]
			if obj.type == "gather" and obj.item == item_id:
				update_objective_progress(quest_id, i, 1)


func _on_entity_died(entity_id: String, _killer_id: String) -> void:
	var data: Dictionary = WorldState.get_entity_data(entity_id)
	var monster_type: String = data.get("monster_type", "")
	if monster_type.is_empty():
		return
	for quest_id in _active:
		var quest: Dictionary = QuestDatabase.get_quest(quest_id)
		for i in quest.objectives.size():
			var obj: Dictionary = quest.objectives[i]
			if obj.type == "kill" and obj.monster_type == monster_type:
				update_objective_progress(quest_id, i, 1)
