class_name NpcTraitHelpers
## Algorithmic helpers for NPC trait data. References NpcTraits for all data constants.
const NpcTraits = preload("res://scripts/data/npc_traits.gd")

static func pick_mood(profile_name: String) -> Dictionary:
	var profile := NpcTraits.get_profile(profile_name)
	if profile.is_empty():
		return NpcTraits.MOODS[0]
	var weighted: Array = []
	for mood in NpcTraits.MOODS:
		var score: float = 1.0
		var w: Dictionary = mood["weights"]
		for trait_name in w:
			score += profile.get(trait_name, 0.5) * w[trait_name]
		weighted.append({"mood": mood, "score": maxf(score, 0.1)})
	var total: float = 0.0
	for entry in weighted:
		total += entry["score"]
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for entry in weighted:
		cumulative += entry["score"]
		if roll <= cumulative:
			return entry["mood"]
	return NpcTraits.MOODS[0]

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
