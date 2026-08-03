class_name LSystemTurtle3D
extends RefCounted

const SpatialGrowth = preload("res://scripts/tree/spatial_growth.gd")
const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")


static func init_frame(heading: Vector3, up_hint: Vector3 = Vector3.UP) -> Dictionary:
	return Vector3Frame.init_turtle_frame(heading, up_hint)


static func interpret(
	production: String,
	frame: Dictionary,
	params: LSystemParams,
	rng: RandomNumberGenerator
) -> Dictionary:
	var heading: Vector3 = frame.heading
	var left: Vector3 = frame.left
	var turtle_up: Vector3 = frame.up
	var angle: float = deg_to_rad(params.angle_deg)
	var stack: Array = []
	var spawns: Array = []
	var parent_continues := false
	var deterministic: bool = params.deterministic or rng == null

	var index := 0
	while index < production.length():
		var symbol: String = production[index]
		match symbol:
			"F", "f":
				parent_continues = true
			"+":
				var turn_plus: float = _jittered_angle(angle, params, rng, deterministic)
				heading = heading.rotated(turtle_up, turn_plus).normalized()
				left = left.rotated(turtle_up, turn_plus).normalized()
			"-":
				var turn_minus: float = -_jittered_angle(angle, params, rng, deterministic)
				heading = heading.rotated(turtle_up, turn_minus).normalized()
				left = left.rotated(turtle_up, turn_minus).normalized()
			"&":
				var pitch: float = _jittered_angle(angle, params, rng, deterministic)
				heading = heading.rotated(left, pitch).normalized()
				turtle_up = turtle_up.rotated(left, pitch).normalized()
				left = turtle_up.cross(heading).normalized()
			"^":
				var pitch_up: float = -_jittered_angle(angle, params, rng, deterministic)
				heading = heading.rotated(left, pitch_up).normalized()
				turtle_up = turtle_up.rotated(left, pitch_up).normalized()
				left = turtle_up.cross(heading).normalized()
			"\\":
				var roll: float = _jittered_angle(angle, params, rng, deterministic)
				heading = heading.rotated(heading, roll).normalized()
				left = left.rotated(heading, roll).normalized()
				turtle_up = turtle_up.rotated(heading, roll).normalized()
			"/":
				var roll_neg: float = -_jittered_angle(angle, params, rng, deterministic)
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
						params.lateral_roll_spread_deg,
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
				if _is_lateral_module(symbol):
					var spawn_dir: Vector3 = spread_direction(heading, params, rng, deterministic)
					spawns.append({
						"direction": spawn_dir,
						"symbol": symbol,
						"up": turtle_up_for_spawn(spawn_dir, left, params, rng, deterministic),
					})
		index += 1

	return {
		"heading": heading,
		"left": left,
		"up": turtle_up,
		"spawns": spawns,
		"parent_continues": parent_continues,
	}


static func _is_module_symbol(symbol: String) -> bool:
	if symbol.length() != 1:
		return false
	var code: int = symbol.unicode_at(0)
	return code >= 65 and code <= 90


static func _is_lateral_module(symbol: String) -> bool:
	return _is_module_symbol(symbol) and symbol != "F"


static func _jittered_angle(
	base_angle: float,
	params: LSystemParams,
	rng: RandomNumberGenerator,
	deterministic: bool
) -> float:
	if deterministic or params.angle_jitter_deg <= 0.0 or rng == null:
		return base_angle
	var jitter: float = deg_to_rad(rng.randf_range(-params.angle_jitter_deg, params.angle_jitter_deg))
	return base_angle + jitter


static func spread_direction(
	direction: Vector3,
	params: LSystemParams,
	rng: RandomNumberGenerator,
	deterministic: bool
) -> Vector3:
	if deterministic or params.spatial_spread_deg <= 0.0 or rng == null:
		return direction.normalized()
	var spread: float = params.spatial_spread_deg
	if params.angle_jitter_deg > 0.0:
		spread = maxf(spread, params.angle_jitter_deg * 0.65)
	return SpatialGrowth.spread_direction(direction, spread, rng)


static func turtle_up_for_spawn(
	direction: Vector3,
	left: Vector3,
	params: LSystemParams,
	rng: RandomNumberGenerator,
	deterministic: bool
) -> Vector3:
	if deterministic:
		return direction.cross(left).normalized()
	return SpatialGrowth.random_turtle_up(direction, rng, params.lateral_roll_spread_deg)
