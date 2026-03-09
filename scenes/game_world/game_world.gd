extends Node3D
## Game world — registers locations/objects and sets up NPC test behaviors.

func _ready() -> void:
	# Register location markers with WorldState
	for marker in $LocationMarkers.get_children():
		WorldState.register_location(marker.name, marker.global_position)

	# Register world objects (forge and well overlays)
	_register_world_objects()

	# Ensure CSG meshes are computed before baking navmesh
	var nav_region := $NavigationRegion3D
	nav_region.bake_finished.connect(_on_navmesh_baked)
	# parsed_geometry_type is set in the .tscn resource to BOTH for CSG compatibility
	# Defer bake to next physics frame so CSG shapes finish generating collision
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav_region.bake_navigation_mesh()

func _on_navmesh_baked() -> void:
	var nav_mesh: NavigationMesh = $NavigationRegion3D.navigation_mesh
	var poly_count: int = nav_mesh.get_polygon_count()
	print("[NavMesh] Bake finished — %d polygons" % poly_count)
	if poly_count == 0:
		push_warning("[NavMesh] WARNING: Navmesh is EMPTY! CSG geometry may not have been parsed.")
	_setup_npc_test_actions()

func _register_world_objects() -> void:
	# Register the forge as an interactable object
	var forge_node: Node3D = $NavigationRegion3D/Blacksmith/Forge
	if forge_node:
		WorldState.register_entity("forge", forge_node, {
			"type": "object",
			"name": "Forge",
		})

	# Register the well as an interactable object
	var well_node: Node3D = $NavigationRegion3D/Well
	if well_node:
		WorldState.register_entity("well", well_node, {
			"type": "object",
			"name": "Well",
		})

func _setup_npc_test_actions() -> void:
	# Gareth: Walk to forge, use it, walk to town square, talk to Finn
	var gareth: Node3D = $NPCs/Gareth
	if gareth:
		gareth.get_node("NPCBrain").set_test_actions([
			{"action": "move_to", "target": "BlacksmithArea", "thinking": "I should head to my smithy"},
			{"action": "use_object", "target": "forge", "thinking": "Time to fire up the forge"},
			{"action": "move_to", "target": "TownSquare", "thinking": "Let me check the town square"},
			{"action": "talk_to", "target": "finn", "dialogue": "Oi Finn, got any iron to trade?", "thinking": "Finn might have materials"},
			{"action": "move_to", "target": "ForestEdge", "thinking": "Maybe I can find ore myself"},
			{"action": "move_to", "target": "BlacksmithArea", "thinking": "Back to work"},
		])

	# Elara: Walk to forest, pick herbs, check well, talk to Gareth
	var elara: Node3D = $NPCs/Elara
	if elara:
		elara.get_node("NPCBrain").set_test_actions([
			{"action": "move_to", "target": "ForestEdge", "thinking": "The forest should have herbs this time of year"},
			{"action": "pick_up", "target": "herbs_1", "thinking": "These healing herbs look fresh"},
			{"action": "move_to", "target": "WellArea", "thinking": "I should check if the well water is clean"},
			{"action": "use_object", "target": "well", "thinking": "Let me draw some water"},
			{"action": "move_to", "target": "TownSquare", "thinking": "Time to head back to the village"},
			{"action": "talk_to", "target": "gareth", "dialogue": "Gareth, are you feeling well? I have some herbs if you need.", "thinking": "Gareth works too hard"},
		])

	# Finn: Walk around market, talk to people, try to trade
	var finn: Node3D = $NPCs/Finn
	if finn:
		finn.get_node("NPCBrain").set_test_actions([
			{"action": "move_to", "target": "MarketArea", "thinking": "Let me set up my stall"},
			{"action": "pick_up", "target": "cloth_bundle", "thinking": "This cloth could fetch a good price"},
			{"action": "move_to", "target": "TownSquare", "thinking": "More foot traffic in the square"},
			{"action": "talk_to", "target": "elara", "dialogue": "Elara! Have you heard the latest? A merchant caravan was spotted near the mountains!", "thinking": "Elara always likes to hear news"},
			{"action": "move_to", "target": "BlacksmithArea", "thinking": "Gareth might need supplies"},
			{"action": "talk_to", "target": "gareth", "dialogue": "Gareth, my friend! I have fine cloth and news from the road. Interested in a trade?", "thinking": "A good merchant visits all his customers"},
		])
