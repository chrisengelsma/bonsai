class_name AuxinModel
extends RefCounted

## Auxin flows from active tips toward the root and suppresses lateral buds.
## Pruning or pinching removes the apex source, releasing competition below.


static func recompute(graph, pattern) -> void:
	graph._auxin_levels.clear()
	if not pattern.use_auxin:
		return

	var decay: float = clampf(pattern.auxin_decay, 0.2, 0.95)
	var source: float = maxf(pattern.auxin_source_strength, 0.05)

	for tip_id in graph._get_active_tip_ids():
		var strength: float = source
		var current_id: int = tip_id
		var hops: int = 0
		while graph.nodes.has(current_id):
			var existing: float = float(graph._auxin_levels.get(current_id, 0.0))
			graph._auxin_levels[current_id] = existing + strength
			var node = graph.nodes[current_id]
			if node.parent_id < 0:
				break
			hops += 1
			strength *= decay
			current_id = node.parent_id


static func tip_growth_multiplier(graph, tip_id: int, pattern) -> float:
	if not pattern.use_auxin or not graph.nodes.has(tip_id):
		return 1.0

	var tip = graph.nodes[tip_id]
	var upstream_auxin: float = _upstream_auxin_for_laterals(graph, tip_id)
	var inhibition: float = clampf(upstream_auxin * pattern.apical_dominance, 0.0, 1.0)
	var is_lateral: bool = _is_lateral_tip(graph, tip)
	var suppression: float = 0.82 if is_lateral else 0.18
	return clampf(1.0 - inhibition * suppression, 0.08, 1.0)


static func filter_lateral_spawns(graph, parent_id: int, spawns: Array, pattern, rng) -> Array:
	if not pattern.use_auxin or spawns.is_empty():
		return spawns

	var slots: int = _lateral_slots(graph, parent_id, spawns.size(), pattern)
	return _pick_spawns(spawns, slots, rng)


static func filter_prune_spawns(graph, parent_id: int, spawns: Array, pattern, rng) -> Array:
	if spawns.is_empty():
		return spawns

	if not pattern.use_auxin:
		return spawns

	# After a cut the apex source is gone — release more buds, but still compete.
	var slots: int = maxi(1, spawns.size())
	var upstream_auxin: float = _upstream_auxin_for_laterals(graph, parent_id)
	var inhibition: float = clampf(upstream_auxin * pattern.apical_dominance * 0.35, 0.0, 1.0)
	slots = maxi(1, roundi(lerpf(float(spawns.size()), float(slots), 1.0 - inhibition)))
	return _pick_spawns(spawns, slots, rng)


static func _upstream_auxin_for_laterals(graph, apex_id: int) -> float:
	if not graph.nodes.has(apex_id):
		return 0.0
	var apex = graph.nodes[apex_id]
	if apex.parent_id < 0:
		return 0.0
	return float(graph._auxin_levels.get(apex.parent_id, 0.0))


static func _is_lateral_tip(graph, tip) -> bool:
	if tip.parent_id < 0 or not graph.nodes.has(tip.parent_id):
		return false
	var parent = graph.nodes[tip.parent_id]
	return tip.depth > parent.depth


static func _lateral_slots(graph, parent_id: int, spawn_count: int, pattern) -> int:
	var upstream_auxin: float = _upstream_auxin_for_laterals(graph, parent_id)
	var inhibition: float = clampf(upstream_auxin * pattern.apical_dominance, 0.0, 1.0)
	var open_ratio: float = 1.0 - inhibition
	return clampi(roundi(open_ratio * float(spawn_count)), 0, spawn_count)


static func _pick_spawns(spawns: Array, slots: int, rng) -> Array:
	if slots >= spawns.size():
		return spawns.duplicate()

	var ranked: Array = []
	for i in range(spawns.size()):
		ranked.append({
			"spawn": spawns[i],
			"vigor": _spawn_vigor(i, rng),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.vigor) > float(b.vigor)
	)

	var selected: Array = []
	for i in range(mini(slots, ranked.size())):
		selected.append(ranked[i].spawn)
	return selected


static func _spawn_vigor(index: int, rng) -> float:
	if rng != null:
		return rng.randf()
	return 0.35 + 0.65 * float((index * 73 + 17) % 100) / 100.0
