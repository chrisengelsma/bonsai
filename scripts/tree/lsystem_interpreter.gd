class_name LSystemInterpreter
extends RefCounted

const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const LSystemTurtle = preload("res://scripts/tree/lsystem_turtle.gd")
const AuxinModel = preload("res://scripts/tree/auxin_model.gd")


## Interprets one L-system production at a growing apex using 3D turtle graphics.
## Uses heading + left + up vectors so +/- branch correctly from vertical trunks.


static func apply_at_tip(graph, tip_id: int, pattern) -> void:
	if not graph.nodes.has(tip_id):
		return

	var tip = graph.nodes[tip_id]
	var production: String = pattern.get_production(tip.lsymbol)
	if production.is_empty():
		return

	var deterministic: bool = pattern.deterministic_growth or not tip.stochastic_direction
	var rng: RandomNumberGenerator = graph.get_rng() if not deterministic else null
	var frame: Dictionary = LSystemTurtle.init_frame(tip.direction, tip.turtle_up)
	var colonization_context: Dictionary = {}
	if pattern.use_space_colonization and graph.get_attractor_field() != null:
		colonization_context = {
			"field": graph.get_attractor_field(),
			"spawn_origin": graph.get_world_tip(tip_id),
		}
	var result: Dictionary = LSystemTurtle.interpret_production(
		production,
		frame,
		pattern,
		rng,
		deterministic,
		LSystemTurtle.Mode.GROW,
		colonization_context
	)

	for spawn in AuxinModel.filter_lateral_spawns(graph, tip_id, result.spawns, pattern, rng):
		if tip.depth >= pattern.max_branch_depth:
			continue
		if tip.children.size() >= pattern.max_children_per_node:
			continue
		if not GrowthLimits.can_add_node(graph.nodes.size()):
			break
		if pattern.lateral_skip_chance > 0.0 and not deterministic and rng.randf() < pattern.lateral_skip_chance:
			continue
		graph.bud_lsystem_child(
			tip_id,
			spawn.direction,
			spawn.lsymbol,
			pattern,
			spawn.turtle_up,
			tip.stochastic_direction
		)

	tip.length_at_last_production = tip.length

	if result.parent_continues:
		if tip.depth >= pattern.max_branch_depth:
			tip.is_growing_tip = false
		else:
			var new_dir: Vector3 = LSystemTurtle.spread_direction(
				result.heading,
				pattern,
				rng,
				deterministic
			)
			var new_up: Vector3 = LSystemTurtle.turtle_up_for_spawn(
				new_dir,
				result.left,
				rng,
				pattern,
				deterministic
			)
			if not graph.continue_growth_segment(
				tip_id,
				new_dir,
				new_up,
				tip.lsymbol,
				pattern
			):
				tip.is_growing_tip = false
	else:
		tip.is_growing_tip = false


## Like apply_at_tip, but for a prune cut: spawn only lateral child branches.
## F/f advance the turtle but never spawn — the cut segment stays fixed length.
static func apply_prune_seed(graph, tip_id: int, pattern) -> int:
	if not graph.nodes.has(tip_id):
		return 0

	var tip = graph.nodes[tip_id]
	var production: String = pattern.get_production(tip.lsymbol)
	if production.is_empty():
		return 0

	var deterministic: bool = true
	var rng: RandomNumberGenerator = null
	var frame: Dictionary = LSystemTurtle.init_frame(tip.direction, tip.turtle_up)
	var parent_dir: Vector3 = tip.direction.normalized()
	var result: Dictionary = LSystemTurtle.interpret_production(
		production,
		frame,
		pattern,
		rng,
		deterministic,
		LSystemTurtle.Mode.PRUNE_SEED
	)

	var spawned: int = 0
	for spawn in AuxinModel.filter_prune_spawns(graph, tip_id, result.spawns, pattern, rng):
		if tip.depth + 1 > pattern.max_branch_depth:
			continue
		if tip.children.size() >= pattern.max_children_per_node:
			continue
		if spawn.direction.normalized().dot(parent_dir) > 0.9:
			continue
		if not graph._allow_prune_spawn and not GrowthLimits.can_add_node(graph.nodes.size()):
			break
		if pattern.lateral_skip_chance > 0.0 and not deterministic and rng.randf() < pattern.lateral_skip_chance:
			continue
		var child = graph.bud_lsystem_child(
			tip_id,
			spawn.direction,
			spawn.lsymbol,
			pattern,
			spawn.turtle_up,
			false
		)
		if child != null:
			spawned += 1

	tip.length_at_last_production = tip.length
	tip.is_growing_tip = false
	tip.freeze_length = true
	return spawned
