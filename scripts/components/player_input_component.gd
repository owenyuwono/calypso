extends Node
## Thin input adapter for the player skill system.
## Handles hotbar slot → skill_id resolution and chase-to-range movement.
## Delegates all skill execution to SkillsComponent.

var _player: Node3D = null
var _skills_comp: Node = null

## Delegates to SkillsComponent.is_skill_pending()
var pending_skill_hit: bool:
	get: return _skills_comp.is_skill_pending() if _skills_comp else false


func setup(player: Node3D, skills_comp: Node) -> void:
	_player = player
	_skills_comp = skills_comp


## Try to use the skill assigned to the given hotbar slot index (0-based).
func try_use_hotbar_slot(slot: int) -> void:
	var hotbar: Array = _skills_comp.get_hotbar()
	if slot < 0 or slot >= hotbar.size():
		return
	var skill_id: String = hotbar[slot]
	if skill_id.is_empty():
		return
	if _skills_comp.is_on_cooldown(skill_id):
		return
	var target_id: String = _player._attack_target
	if target_id.is_empty():
		return
	_skills_comp.begin_skill_use(skill_id, target_id)


## Handles player-specific chase-to-range movement for a pending skill hit.
## When in range, ticks the pending hit via SkillsComponent.
## Returns true if the player is moving (chasing out-of-range target).
func process_skill_hit(delta: float, attack_range: float) -> bool:
	var attack_target: String = _player._attack_target
	var target_node: Node3D = WorldState.get_entity(attack_target)
	if not target_node or not is_instance_valid(target_node) or not WorldState.is_alive(attack_target):
		_player._cancel_attack()
		return false

	var dist: float = _player.global_position.distance_to(target_node.global_position)
	if dist > attack_range:
		var nav_agent: Node = _player.nav_agent
		nav_agent.target_position = target_node.global_position
		if not nav_agent.is_navigation_finished():
			var next_pos: Vector3 = nav_agent.get_next_path_position()
			var dir: Vector3 = (next_pos - _player.global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.01:
				dir = dir.normalized()
				_player.velocity.x = dir.x * _player.SPEED
				_player.velocity.z = dir.z * _player.SPEED
				_player._visuals.face_direction(dir)
				_player._visuals.play_anim("Running_A")
		return true

	# In range — stop moving, face target, tick the skill hit
	_player.velocity.x = 0.0
	_player.velocity.z = 0.0
	var to_target: Vector3 = (target_node.global_position - _player.global_position)
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		_player._visuals.face_direction(to_target.normalized())

	_skills_comp.tick_pending_hit(delta)
	return false


## Cancel any pending skill hit state.
func cancel_pending() -> void:
	if _skills_comp:
		_skills_comp.cancel_pending()
