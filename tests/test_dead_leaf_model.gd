extends SceneTree

const DeadLeafModel = preload("res://scripts/tree/dead_leaf_model.gd")
const TreeGraph = preload("res://scripts/tree/tree_graph.gd")
const GrowPattern = preload("res://scripts/tree/grow_pattern.gd")


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(_test_spawn_cap_and_tend())
	failures.append_array(_test_spawn_requires_foliage_system())
	failures.append_array(_test_spawn_requires_mature_foliage())

	if failures.is_empty():
		print("ALL CHECKS PASSED (dead leaf model)")
	else:
		for failure in failures:
			print("FAIL: ", failure)
	quit(1 if not failures.is_empty() else 0)


func _make_pattern(foliage_style: String = "cluster") -> GrowPattern:
	var pattern := GrowPattern.new()
	pattern.foliage_style = foliage_style
	pattern.foliage_start_length = 0.05
	pattern.foliage_growth_rate = 0.5
	return pattern


func _make_graph_with_tip(foliage_amount: float, has_dead_leaf: bool = false) -> TreeGraph:
	var species = load("res://resources/species/classic_upright.tres")
	var graph := TreeGraph.new()
	graph.create_from_species(species)
	var tip_id: int = graph.root_id
	var tip = graph.nodes[tip_id]
	tip.foliage_amount = foliage_amount
	tip.has_dead_leaf = has_dead_leaf
	tip.length = 0.2
	return graph


func _make_graph_from_species() -> TreeGraph:
	var species = load("res://resources/species/classic_upright.tres")
	var graph := TreeGraph.new()
	graph.create_from_species(species)
	return graph


func _test_spawn_cap_and_tend() -> Array[String]:
	var failures: Array[String] = []
	var graph := _make_graph_from_species()
	var pattern := _make_pattern()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for node_id in graph.nodes.keys():
		var node = graph.nodes[node_id]
		node.foliage_amount = 1.0
		node.length = 0.2

	for _i in range(500):
		DeadLeafModel.try_spawn_dead_leaf(graph, pattern, 20.0, rng)

	if DeadLeafModel.count_dead_leaves(graph) > DeadLeafModel.MAX_DEAD_LEAVES:
		failures.append("dead leaf count should respect cap")

	var dead_ids: Array = DeadLeafModel.get_dead_leaf_tip_ids(graph)
	if dead_ids.is_empty():
		failures.append("expected at least one dead leaf after forced spawn attempts")

	if not dead_ids.is_empty():
		var tip_id: int = int(dead_ids[0])
		if not DeadLeafModel.tend_leaf(graph, tip_id):
			failures.append("tend_leaf should succeed on dead leaf tip")
		if graph.nodes[tip_id].has_dead_leaf:
			failures.append("tend_leaf should clear has_dead_leaf")
		if DeadLeafModel.tend_leaf(graph, tip_id):
			failures.append("tend_leaf should fail on already tended tip")

	return failures


func _test_spawn_requires_foliage_system() -> Array[String]:
	var failures: Array[String] = []
	var graph := _make_graph_with_tip(1.0)
	graph.species = null
	var pattern := _make_pattern("none")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	for _i in range(50):
		DeadLeafModel.try_spawn_dead_leaf(graph, pattern, 1.0, rng)

	if DeadLeafModel.count_dead_leaves(graph) != 0:
		failures.append("dead leaves should not spawn when foliage_style is none")
	return failures


func _test_spawn_requires_mature_foliage() -> Array[String]:
	var failures: Array[String] = []
	var graph := _make_graph_with_tip(0.2)
	var pattern := _make_pattern()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11

	for _i in range(50):
		DeadLeafModel.try_spawn_dead_leaf(graph, pattern, 1.0, rng)

	if DeadLeafModel.count_dead_leaves(graph) != 0:
		failures.append("dead leaves should not spawn on immature foliage")
	return failures
