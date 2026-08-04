extends SceneTree

const TreeGraph = preload("res://scripts/tree/tree_graph.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const AxialChain = preload("res://scripts/tree/axial_chain.gd")

const SPECIES_PATHS := [
	"res://resources/species/classic_upright.tres",
	"res://resources/species/ginseng_ficus.tres",
	"res://resources/species/cascade.tres",
	"res://resources/species/juniper.tres",
]

const GROW_STEPS := 600
const GROW_DELTA := 0.05
const GROW_SPEED := 3.0

func _init() -> void:
	var failures: Array[String] = []
	for species_path in SPECIES_PATHS:
		failures.append_array(_run_species_checks(species_path))
	failures.append_array(_check_reactivate_does_not_extend_exhausted_branches())

	if failures.is_empty():
		print("ALL CHECKS PASSED (", SPECIES_PATHS.size(), " species)")
	else:
		for failure in failures:
			print("FAIL: ", failure)
	quit(1 if not failures.is_empty() else 0)

func _run_species_checks(species_path: String) -> Array[String]:
	var failures: Array[String] = []
	var species = load(species_path)
	var pattern = species.grow_pattern
	var graph = TreeGraph.new()
	graph.create_from_species(species)
	var segment_length: float = pattern.lsystem_segment_length

	for _i in range(GROW_STEPS):
		graph.grow(GROW_DELTA, pattern, 1.0, GROW_SPEED, 1.0)

	for node_id in graph.nodes.keys():
		var node = graph.nodes[node_id]
		if node.length <= 0.001:
			continue

		var chain: float = AxialChain.chain_total(graph.nodes, node_id)
		var cap: float = GrowthLimits.max_length_for_depth(node.depth)
		if chain > cap + 0.001:
			failures.append(
				"%s node %d depth %d axial %.3f exceeds cap %.3f" % [
					species.id, node_id, node.depth, chain, cap
				]
			)

		if not node.is_growing_tip or node.freeze_length:
			continue

		var since_production: float = node.length - node.length_at_last_production
		var remaining: float = cap - chain
		var allowed_since_production: float = segment_length + 0.012
		if remaining > 0.0 and remaining < segment_length:
			allowed_since_production = remaining + 0.012

		if since_production > allowed_since_production:
			failures.append(
				"%s tip %d grew %.3f since production (allowed %.3f, remaining %.3f)" % [
					species.id, node_id, since_production, allowed_since_production, remaining
				]
			)

		if remaining < -0.001:
			failures.append(
				"%s tip %d over budget by %.3f" % [species.id, node_id, -remaining]
			)

	return failures

func _check_reactivate_does_not_extend_exhausted_branches() -> Array[String]:
	var failures: Array[String] = []
	var species = load("res://resources/species/classic_upright.tres")
	var pattern = species.grow_pattern
	var graph = TreeGraph.new()
	graph.create_from_species(species)

	for _i in range(GROW_STEPS):
		graph.grow(GROW_DELTA, pattern, 1.0, GROW_SPEED, 1.0)

	var before: float = _max_axial_chain(graph)
	graph.reactivate_seed_tips(pattern)
	for _i in range(120):
		graph.grow(GROW_DELTA, pattern, 1.0, GROW_SPEED, 1.0)

	var after: float = _max_axial_chain(graph)
	if after > before + 0.015:
		failures.append(
			"reactivate extended max axial chain %.3f -> %.3f" % [before, after]
		)
	return failures

func _max_axial_chain(graph) -> float:
	return AxialChain.max_chain(graph.nodes)
