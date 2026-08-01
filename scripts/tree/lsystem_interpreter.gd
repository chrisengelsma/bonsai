class_name LSystemInterpreter
extends RefCounted

const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const SpatialGrowth = preload("res://scripts/tree/spatial_growth.gd")

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
	var angle: float = deg_to_rad(pattern.lsystem_angle_deg)
	var heading: Vector3 = tip.direction.normalized()
	var turtle_up: Vector3 = _sanitize_turtle_up(heading, tip.turtle_up)
	var left: Vector3 = turtle_up.cross(heading).normalized()
	turtle_up = heading.cross(left).normalized()

	var stack: Array = []
	var spawns: Array = []
	var parent_continues := false

	var index := 0
	while index < production.length():
		var symbol: String = production[index]
		match symbol:
			"F", "f":
				parent_continues = true
			"+":
				var turn_plus: float = _jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(turtle_up, turn_plus).normalized()
				left = left.rotated(turtle_up, turn_plus).normalized()
			"-":
				var turn_minus: float = -_jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(turtle_up, turn_minus).normalized()
				left = left.rotated(turtle_up, turn_minus).normalized()
			"&":
				var pitch: float = _jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(left, pitch).normalized()
				turtle_up = turtle_up.rotated(left, pitch).normalized()
				left = turtle_up.cross(heading).normalized()
			"^":
				var pitch_up: float = -_jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(left, pitch_up).normalized()
				turtle_up = turtle_up.rotated(left, pitch_up).normalized()
				left = turtle_up.cross(heading).normalized()
			"\\":
				var roll: float = _jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(heading, roll).normalized()
				left = left.rotated(heading, roll).normalized()
				turtle_up = turtle_up.rotated(heading, roll).normalized()
			"/":
				var roll_neg: float = -_jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(heading, roll_neg).normalized()
				left = left.rotated(heading, roll_neg).normalized()
				turtle_up = turtle_up.rotated(heading, roll_neg).normalized()
			"|":
				heading = -heading
				left = -left
			"[":
				if not deterministic:
					var rolled := SpatialGrowth.roll_turtle_frame(
						heading,
						left,
						turtle_up,
						pattern.lateral_roll_spread_deg,
						rng
					)
					heading = rolled.heading
					left = rolled.left
					turtle_up = rolled.up
				stack.append({"heading": heading, "left": left, "up": turtle_up})
			"]":
				if not stack.is_empty():
					var state: Dictionary = stack.pop_back()
					heading = state.heading
					left = state.left
					turtle_up = state.up
			_:
				if _is_module_symbol(symbol):
					var spawn_dir: Vector3 = _spread_direction(heading, pattern, rng, deterministic)
					spawns.append({
						"direction": spawn_dir,
						"lsymbol": symbol,
						"turtle_up": _turtle_up_for_spawn(spawn_dir, left, rng, pattern, deterministic),
					})
		index += 1

	for spawn in spawns:
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

	if parent_continues:
		var new_dir: Vector3 = _spread_direction(heading, pattern, rng, deterministic)
		var new_up: Vector3 = _turtle_up_for_spawn(
			new_dir,
			left,
			rng,
			pattern,
			deterministic
		)
		graph.continue_growth_segment(
			tip_id,
			new_dir,
			new_up,
			_continuing_symbol(production),
			pattern
		)
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
	var angle: float = deg_to_rad(pattern.lsystem_angle_deg)
	var heading: Vector3 = tip.direction.normalized()
	var turtle_up: Vector3 = _sanitize_turtle_up(heading, tip.turtle_up)
	var left: Vector3 = turtle_up.cross(heading).normalized()
	turtle_up = heading.cross(left).normalized()

	var stack: Array = []
	var spawns: Array = []
	var parent_dir: Vector3 = tip.direction.normalized()

	var index := 0
	while index < production.length():
		var symbol: String = production[index]
		match symbol:
			"F", "f":
				pass
			"+":
				var turn_plus: float = _jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(turtle_up, turn_plus).normalized()
				left = left.rotated(turtle_up, turn_plus).normalized()
			"-":
				var turn_minus: float = -_jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(turtle_up, turn_minus).normalized()
				left = left.rotated(turtle_up, turn_minus).normalized()
			"&":
				var pitch: float = _jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(left, pitch).normalized()
				turtle_up = turtle_up.rotated(left, pitch).normalized()
				left = turtle_up.cross(heading).normalized()
			"^":
				var pitch_up: float = -_jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(left, pitch_up).normalized()
				turtle_up = turtle_up.rotated(left, pitch_up).normalized()
				left = turtle_up.cross(heading).normalized()
			"\\":
				var roll: float = _jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(heading, roll).normalized()
				left = left.rotated(heading, roll).normalized()
				turtle_up = turtle_up.rotated(heading, roll).normalized()
			"/":
				var roll_neg: float = -_jittered_angle(angle, pattern, rng, deterministic)
				heading = heading.rotated(heading, roll_neg).normalized()
				left = left.rotated(heading, roll_neg).normalized()
				turtle_up = turtle_up.rotated(heading, roll_neg).normalized()
			"|":
				heading = -heading
				left = -left
			"[":
				if not deterministic:
					var rolled := SpatialGrowth.roll_turtle_frame(
						heading,
						left,
						turtle_up,
						pattern.lateral_roll_spread_deg,
						rng
					)
					heading = rolled.heading
					left = rolled.left
					turtle_up = rolled.up
				stack.append({"heading": heading, "left": left, "up": turtle_up})
			"]":
				if not stack.is_empty():
					var state: Dictionary = stack.pop_back()
					heading = state.heading
					left = state.left
					turtle_up = state.up
			_:
				if _is_module_symbol(symbol) and symbol != "F":
					var spawn_dir: Vector3 = heading.normalized()
					spawns.append({
						"direction": spawn_dir,
						"lsymbol": symbol,
						"turtle_up": _turtle_up_for_spawn(spawn_dir, left, rng, pattern, deterministic),
					})
		index += 1

	var spawned: int = 0
	for spawn in spawns:
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


static func _jittered_angle(base_angle: float, pattern, rng: RandomNumberGenerator, deterministic: bool) -> float:
	if deterministic or pattern.angle_jitter_deg <= 0.0 or rng == null:
		return base_angle
	var jitter: float = deg_to_rad(rng.randf_range(-pattern.angle_jitter_deg, pattern.angle_jitter_deg))
	return base_angle + jitter


static func _spread_direction(
	direction: Vector3,
	pattern,
	rng: RandomNumberGenerator,
	deterministic: bool
) -> Vector3:
	if deterministic or pattern.spatial_spread_deg <= 0.0:
		return direction.normalized()
	var spread: float = pattern.spatial_spread_deg
	if pattern.angle_jitter_deg > 0.0:
		spread = maxf(spread, pattern.angle_jitter_deg * 0.65)
	return SpatialGrowth.spread_direction(direction, spread, rng)


static func _turtle_up_for_spawn(
	direction: Vector3,
	left: Vector3,
	rng: RandomNumberGenerator,
	pattern,
	deterministic: bool
) -> Vector3:
	if deterministic:
		return direction.cross(left).normalized()
	return SpatialGrowth.random_turtle_up(
		direction,
		rng,
		pattern.lateral_roll_spread_deg
	)


static func _sanitize_turtle_up(heading: Vector3, hint: Vector3) -> Vector3:
	var up_hint: Vector3 = hint.normalized()
	if up_hint.length_squared() < 0.0001 or absf(heading.normalized().dot(up_hint)) > 0.98:
		up_hint = Vector3.FORWARD
		if absf(heading.normalized().dot(up_hint)) > 0.98:
			up_hint = Vector3.RIGHT
	return up_hint


static func _continuing_symbol(production: String) -> String:
	for i in production.length():
		var symbol := production[i]
		if symbol == "F" or symbol == "f":
			return "F"
		if _is_module_symbol(symbol):
			break
	return "F"


static func _is_module_symbol(symbol: String) -> bool:
	if symbol.length() != 1:
		return false
	var code := symbol.unicode_at(0)
	return code >= 65 and code <= 90
