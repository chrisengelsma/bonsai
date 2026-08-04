class_name LSystemTestHarness
extends RefCounted

const TreeGraph = preload("res://scripts/tree/tree_graph.gd")
const GrowPattern = preload("res://scripts/tree/grow_pattern.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const LSystemInterpreter = preload("res://scripts/tree/lsystem_interpreter.gd")


static func make_pattern(
	axiom: String,
	rules_text: String,
	angle_deg: float = 28.0,
	segment_length: float = 0.1,
	max_depth: int = 4
) -> GrowPattern:
	var pattern := GrowPattern.new()
	pattern.lsystem_axiom = axiom
	pattern.lsystem_rules_text = rules_text
	pattern.lsystem_angle_deg = angle_deg
	pattern.lsystem_segment_length = segment_length
	pattern.max_branch_depth = max_depth
	pattern.max_children_per_node = 4
	pattern.deterministic_growth = true
	pattern.use_lsystem = true
	pattern.angle_jitter_deg = 0.0
	pattern.spatial_spread_deg = 0.0
	pattern.segment_length_jitter = 0.0
	pattern.lateral_skip_chance = 0.0
	pattern.growth_energy_variance = 0.0
	pattern.gravity_curve = 0.0
	pattern.tip_growth_rate = 0.05
	pattern.trunk_thickness = 0.02
	pattern.branch_thickness = 0.01
	pattern.invalidate_rules_cache()
	GrowthLimits.clamp_pattern(pattern)
	return pattern


static func make_graph(pattern: GrowPattern, rng_seed: int = 12345) -> TreeGraph:
	var graph := TreeGraph.new()
	graph.get_rng().seed = rng_seed
	var species = load("res://resources/species/classic_upright.tres")
	species.grow_pattern = pattern
	graph.create_from_species(species)
	return graph


static func grow_until_productions(graph: TreeGraph, pattern: GrowPattern, production_count: int) -> void:
	var fired := 0
	var safety := 0
	while fired < production_count and safety < 5000:
		safety += 1
		var before := _production_fingerprint(graph)
		graph.grow(0.02, pattern, 1.0, 4.0, 1.0)
		var after := _production_fingerprint(graph)
		if after != before:
			fired += 1


static func apply_production_at_root(graph: TreeGraph, pattern: GrowPattern) -> void:
	var tip_id: int = graph.root_id
	var tip = graph.nodes[tip_id]
	tip.length = pattern.lsystem_segment_length
	tip.length_at_last_production = 0.0
	LSystemInterpreter.apply_at_tip(graph, tip_id, pattern)


static func topology_fingerprint(graph: TreeGraph) -> String:
	var ids: Array = graph.nodes.keys()
	ids.sort()
	var parts: PackedStringArray = []
	for node_id in ids:
		var node = graph.nodes[node_id]
		var child_ids: Array = node.children.duplicate()
		child_ids.sort()
		parts.append(
			"%d|p%d|d%d|%s|%.3f|%.3f|%.3f|c%s|g%d|f%d" % [
				node_id,
				node.parent_id,
				node.depth,
				node.lsymbol,
				node.direction.x,
				node.direction.y,
				node.direction.z,
				",".join(child_ids.map(func(id: int) -> String: return str(id))),
				1 if node.is_growing_tip else 0,
				1 if node.freeze_length else 0,
			]
		)
	return "\n".join(parts)


static func tip_world_positions(graph: TreeGraph) -> Array:
	var positions: Array = []
	for tip_id in graph.get_active_tip_ids():
		var tip = graph.get_world_tip(tip_id)
		positions.append(Vector3(
			snappedf(tip.x, 0.001),
			snappedf(tip.y, 0.001),
			snappedf(tip.z, 0.001)
		))
	positions.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		if a.x != b.x:
			return a.x < b.x
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z
	)
	return positions


static func count_nodes_at_depth(graph: TreeGraph, depth: int) -> int:
	var count := 0
	for node_id in graph.nodes.keys():
		if graph.nodes[node_id].depth == depth:
			count += 1
	return count


static func _production_fingerprint(graph: TreeGraph) -> String:
	var parts: PackedStringArray = []
	for node_id in graph.nodes.keys():
		var node = graph.nodes[node_id]
		parts.append("%d:%.4f:%d" % [node_id, node.length_at_last_production, node.children.size()])
	parts.sort()
	return "|".join(parts)
