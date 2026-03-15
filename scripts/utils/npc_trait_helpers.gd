class_name NpcTraitHelpers
## Algorithmic helpers for NPC trait data. References NpcTraits for all data constants.
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

static func get_trait_summary(id: String) -> String:
	var profile := NpcTraits.PROFILES.get(id, {}) as Dictionary
	if profile.is_empty():
		return ""
	var labels: Array = []
	var boldness: float = profile.get("boldness", 0.5)
	for entry in NpcTraits.BOLDNESS_LABELS:
		if boldness <= entry[0]:
			labels.append(entry[1])
			break
	var sociability: float = profile.get("sociability", 0.5)
	for entry in NpcTraits.SOCIABILITY_LABELS:
		if sociability <= entry[0]:
			labels.append(entry[1])
			break
	return ", ".join(labels)
