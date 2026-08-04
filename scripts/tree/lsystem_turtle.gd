class_name LSystemTurtle
extends RefCounted

const SpatialGrowth = preload("res://scripts/tree/spatial_growth.gd")
const LSystemSymbols = preload("res://scripts/tree/lsystem_symbols.gd")
const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")

enum Mode { GROW, PRUNE_SEED }


static func interpret_production(
	production: String,
	frame: Dictionary,
	pattern,
	rng: RandomNumberGenerator,
	deterministic: bool,
	mode: Mode,
	colonization_context: Dictionary = {}
) -> Dictionary:
	var heading: Vector3 = frame.heading
	var left: Vector3 = frame.left
	var turtle_up: Vector3 = frame.up
	var angle: float = deg_to_rad(pattern.lsystem_angle_deg)
	var stack: Array = []
	var spawns: Array = []
	var parent_continues := false

	var index := 0
	while index < production.length():
		var symbol: String = production[index]
		match symbol:
			"F", "f":
				if mode == Mode.GROW:
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
				if mode == Mode.GROW and LSystemSymbols.is_module_symbol(symbol):
					var spawn_dir: Vector3 = spread_direction(heading, pattern, rng, deterministic)
					spawn_dir = _blend_colonization_direction(
						spawn_dir,
						colonization_context,
						pattern
					)
					spawns.append({
						"direction": spawn_dir,
						"lsymbol": symbol,
						"turtle_up": turtle_up_for_spawn(spawn_dir, left, rng, pattern, deterministic),
					})
				elif mode == Mode.PRUNE_SEED and LSystemSymbols.is_lateral_module(symbol):
					var spawn_dir: Vector3 = heading.normalized()
					spawns.append({
						"direction": spawn_dir,
						"lsymbol": symbol,
						"turtle_up": turtle_up_for_spawn(spawn_dir, left, rng, pattern, deterministic),
					})
		index += 1

	return {
		"heading": heading,
		"left": left,
		"up": turtle_up,
		"spawns": spawns,
		"parent_continues": parent_continues,
	}


static func init_frame(heading: Vector3, turtle_up_hint: Vector3) -> Dictionary:
	return Vector3Frame.init_turtle_frame(heading, turtle_up_hint)


static func _jittered_angle(base_angle: float, pattern, rng: RandomNumberGenerator, deterministic: bool) -> float:
	if deterministic or pattern.angle_jitter_deg <= 0.0 or rng == null:
		return base_angle
	var jitter: float = deg_to_rad(rng.randf_range(-pattern.angle_jitter_deg, pattern.angle_jitter_deg))
	return base_angle + jitter


static func spread_direction(
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


static func turtle_up_for_spawn(
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


static func _blend_colonization_direction(
	direction: Vector3,
	colonization_context: Dictionary,
	pattern
) -> Vector3:
	if not pattern.use_space_colonization:
		return direction.normalized()
	var field = colonization_context.get("field")
	if field == null:
		return direction.normalized()
	var spawn_origin: Vector3 = colonization_context.get("spawn_origin", Vector3.ZERO)
	var attract_dir: Vector3 = field.attraction_at_position(spawn_origin)
	if attract_dir.length_squared() <= 0.0001:
		return direction.normalized()
	var blend: float = clampf(pattern.colonization_spawn_strength, 0.0, 1.0)
	return (direction.normalized() + attract_dir * blend).normalized()
