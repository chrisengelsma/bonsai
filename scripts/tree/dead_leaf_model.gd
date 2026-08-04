class_name DeadLeafModel
extends RefCounted

const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")

## Rare dead-leaf spawning and tending — cozy care, not physiology simulation.

const MAX_DEAD_LEAVES := 3
const FOLIAGE_MATURE_THRESHOLD := 0.85
const SPAWN_RATE_PER_SECOND := 0.00035


static func has_foliage_system(species, pattern = null) -> bool:
	return FoliagePreset.has_foliage_growth(species, pattern)


static func count_dead_leaves(graph) -> int:
	var count: int = 0
	for node_id in graph.nodes.keys():
		var node = graph.nodes[node_id]
		if node.has_dead_leaf:
			count += 1
	return count


static func can_spawn_dead_leaf(graph, pattern) -> bool:
	if not has_foliage_system(graph.species if graph != null else null, pattern):
		return false
	return count_dead_leaves(graph) < MAX_DEAD_LEAVES


static func eligible_spawn_tips(graph, pattern) -> Array:
	var tips: Array = []
	if not has_foliage_system(graph.species if graph != null else null, pattern):
		return tips
	for tip_id in graph._get_active_tip_ids():
		if not graph.nodes.has(tip_id):
			continue
		var tip = graph.nodes[tip_id]
		if tip.has_dead_leaf:
			continue
		if tip.foliage_amount < FOLIAGE_MATURE_THRESHOLD:
			continue
		tips.append(tip_id)
	return tips


static func try_spawn_dead_leaf(graph, pattern, delta: float, rng: RandomNumberGenerator) -> bool:
	if delta <= 0.0 or rng == null:
		return false
	if not can_spawn_dead_leaf(graph, pattern):
		return false
	var eligible: Array = eligible_spawn_tips(graph, pattern)
	if eligible.is_empty():
		return false
	if rng.randf() >= SPAWN_RATE_PER_SECOND * delta:
		return false
	var tip_id: int = int(eligible[rng.randi_range(0, eligible.size() - 1)])
	graph.nodes[tip_id].has_dead_leaf = true
	return true


static func tend_leaf(graph, tip_id: int) -> bool:
	if not graph.nodes.has(tip_id):
		return false
	var node = graph.nodes[tip_id]
	if not node.has_dead_leaf:
		return false
	node.has_dead_leaf = false
	return true


static func get_dead_leaf_tip_ids(graph) -> Array:
	var ids: Array = []
	for node_id in graph.nodes.keys():
		var node = graph.nodes[node_id]
		if node.has_dead_leaf:
			ids.append(node_id)
	return ids
