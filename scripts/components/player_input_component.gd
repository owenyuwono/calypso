extends Node
## Thin input adapter for the player skill system.
## Handles hotbar slot → skill_id resolution only.
## Delegates all skill execution to SkillsComponent.

var _player: Node3D = null
var _skills_comp: Node = null


func setup(player: Node3D, skills_comp: Node) -> void:
	_player = player
	_skills_comp = skills_comp


## Try to use the skill assigned to the given hotbar slot index (0-based).
## Skills fire immediately in the player's facing direction — no target required.
func try_use_hotbar_slot(slot: int) -> void:
	var hotbar: Array = _skills_comp.get_hotbar()
	if slot < 0 or slot >= hotbar.size():
		return
	var skill_id: String = hotbar[slot]
	if skill_id.is_empty():
		return
	if _skills_comp.is_on_cooldown(skill_id):
		return
	_skills_comp.begin_skill_use(skill_id)


## Cancel any pending skill hit state.
func cancel_pending() -> void:
	if _skills_comp:
		_skills_comp.cancel_pending()
