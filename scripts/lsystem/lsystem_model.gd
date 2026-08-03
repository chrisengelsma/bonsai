class_name LSystemModel
extends RefCounted

signal changed

const LSystemRules = preload("res://scripts/lsystem/lsystem_rules.gd")
const LSystemTurtle3D = preload("res://scripts/lsystem/lsystem_turtle.gd")

var params: LSystemParams
var rules := LSystemRules.new()
var segments: Array = []
var tips: Array = []
var rng := RandomNumberGenerator.new()

var production_count: int = 0


func setup(new_params: LSystemParams, seed: int = 0) -> void:
	params = new_params.duplicate_params()
	params.clamp_values()
	rules.parse(params.rules_text)
	rng.seed = seed if seed != 0 else randi()
	reset()


func reset() -> void:
	segments.clear()
	tips.clear()
	production_count = 0
	var frame: Dictionary = LSystemTurtle3D.init_frame(Vector3.UP, Vector3.FORWARD)
	_spawn_tip(
		params.seed_position,
		frame.heading,
		frame.left,
		frame.up,
		params.axiom[0],
		0,
		_segment_length_for_tip()
	)
	_emit_changed()


func grow(delta: float, speed_mult: float = 1.0) -> void:
	if not has_active_tips():
		return

	var changed := false
	for tip in tips:
		if not tip.active:
			continue
		if tip.depth >= params.iterations:
			tip.active = false
			_finalize_tip_segment(tip)
			continue
		if tip.axial_productions >= params.iterations:
			tip.active = false
			_finalize_tip_segment(tip)
			continue

		var energy: float = _growth_energy()
		var step: float = params.growth_rate * delta * speed_mult * energy
		if step <= 0.0:
			continue

		var remaining: float = tip.segment_length - tip.length_since_production
		step = minf(step, remaining)
		if step <= 0.0:
			continue

		var from_pos: Vector3 = tip.position
		tip.position += tip.heading * step
		tip.length_since_production += step
		_update_tip_segment(tip, from_pos, tip.position)
		changed = true

		if params.gravity > 0.0 and not params.deterministic:
			var gravity_strength: float = params.gravity * delta
			tip.heading = (tip.heading + Vector3.DOWN * gravity_strength).normalized()
			_rebuild_tip_frame(tip)

	if changed:
		_emit_changed()

	fire_ready_productions()


func fire_ready_productions() -> int:
	var ready: Array = []
	for tip in tips:
		if not tip.active:
			continue
		if tip.depth >= params.iterations:
			tip.active = false
			_finalize_tip_segment(tip)
			continue
		if tip.axial_productions >= params.iterations:
			tip.active = false
			_finalize_tip_segment(tip)
			continue
		if tip.length_since_production >= tip.segment_length - 0.001:
			ready.append(tip)

	if ready.is_empty():
		return 0

	for tip in ready:
		_apply_production(tip)

	_emit_changed()
	return ready.size()


func step_production() -> bool:
	if not has_active_tips():
		return false

	for tip in tips:
		if not tip.active:
			continue
		if tip.depth >= params.iterations:
			tip.active = false
			_finalize_tip_segment(tip)
			continue
		if tip.axial_productions >= params.iterations:
			tip.active = false
			_finalize_tip_segment(tip)
			continue

		var remaining: float = tip.segment_length - tip.length_since_production
		if remaining > 0.001:
			var from_pos: Vector3 = tip.position
			tip.position += tip.heading * remaining
			tip.length_since_production = tip.segment_length
			_update_tip_segment(tip, from_pos, tip.position)

	fire_ready_productions()
	return has_active_tips()


func is_complete() -> bool:
	return not has_active_tips()


func has_active_tips() -> bool:
	for tip in tips:
		if not tip.active:
			continue
		if tip.depth >= params.iterations:
			continue
		if tip.axial_productions >= params.iterations:
			continue
		return true
	return false


func get_bounds_height() -> float:
	var max_y := params.seed_position.y
	for segment in segments:
		max_y = maxf(max_y, float(segment.from.y))
		max_y = maxf(max_y, float(segment.to.y))
	for tip in tips:
		if tip.active:
			max_y = maxf(max_y, tip.position.y)
	return max_y


func get_seed_position() -> Vector3:
	return params.seed_position


func active_tip_count() -> int:
	var count := 0
	for tip in tips:
		if tip.active:
			count += 1
	return count


func _spawn_tip(
	position: Vector3,
	heading: Vector3,
	left: Vector3,
	up: Vector3,
	symbol: String,
	depth: int,
	segment_length: float,
	axial_productions: int = 0
) -> Dictionary:
	var tip := {
		"position": position,
		"heading": heading.normalized(),
		"left": left.normalized(),
		"up": up.normalized(),
		"symbol": symbol,
		"depth": depth,
		"axial_productions": axial_productions,
		"length_since_production": 0.0,
		"segment_length": segment_length,
		"active": true,
		"open_segment_index": -1,
	}
	tips.append(tip)
	return tip


func _apply_production(tip: Dictionary) -> void:
	_finalize_tip_segment(tip)

	var production: String = rules.get_production(tip.symbol)
	if production.is_empty():
		tip.active = false
		return

	var deterministic: bool = params.deterministic
	var frame: Dictionary = {
		"heading": tip.heading,
		"left": tip.left,
		"up": tip.up,
	}
	var result: Dictionary = LSystemTurtle3D.interpret(
		production,
		frame,
		params,
		null if deterministic else rng
	)

	tip.active = false
	production_count += 1

	var child_count := 0
	for spawn in result.spawns:
		if tip.depth + 1 > params.iterations:
			continue
		if child_count >= params.max_children:
			break
		if not deterministic and params.lateral_skip_chance > 0.0 \
				and rng.randf() < params.lateral_skip_chance:
			continue

		var spawn_frame: Dictionary = LSystemTurtle3D.init_frame(spawn.direction, spawn.up)
		_spawn_tip(
			tip.position,
			spawn_frame.heading,
			spawn_frame.left,
			spawn_frame.up,
			spawn.symbol,
			tip.depth + 1,
			_segment_length_for_tip()
		)
		child_count += 1

	if not result.parent_continues:
		return
	if tip.axial_productions + 1 >= params.iterations:
		return

	var new_dir: Vector3 = result.heading
	if not deterministic:
		new_dir = LSystemTurtle3D.spread_direction(new_dir, params, rng, false)
	var new_up: Vector3 = result.up
	if not deterministic:
		new_up = LSystemTurtle3D.turtle_up_for_spawn(new_dir, result.left, params, rng, false)

	var cont_frame: Dictionary = LSystemTurtle3D.init_frame(new_dir, new_up)
	_spawn_tip(
		tip.position,
		cont_frame.heading,
		cont_frame.left,
		cont_frame.up,
		tip.symbol,
		tip.depth,
		_segment_length_for_tip(),
		tip.axial_productions + 1
	)


func _update_tip_segment(tip: Dictionary, from_pos: Vector3, to_pos: Vector3) -> void:
	if tip.open_segment_index >= 0:
		segments[tip.open_segment_index]["to"] = to_pos
	else:
		segments.append({"from": from_pos, "to": to_pos, "open": true})
		tip.open_segment_index = segments.size() - 1


func _finalize_tip_segment(tip: Dictionary) -> void:
	if tip.open_segment_index < 0:
		return
	if tip.open_segment_index < segments.size():
		segments[tip.open_segment_index].erase("open")
	tip.open_segment_index = -1


func _segment_length_for_tip() -> float:
	var length: float = params.segment_length
	if params.deterministic or params.segment_length_jitter <= 0.0:
		return length
	var jitter: float = rng.randf_range(-params.segment_length_jitter, params.segment_length_jitter)
	return maxf(length * (1.0 + jitter), params.segment_length * 0.5)


func _growth_energy() -> float:
	if params.deterministic or params.growth_energy_variance <= 0.0:
		return 1.0
	return 1.0 + rng.randf_range(-params.growth_energy_variance, params.growth_energy_variance)


func _rebuild_tip_frame(tip: Dictionary) -> void:
	var frame: Dictionary = LSystemTurtle3D.init_frame(tip.heading, tip.up)
	tip.heading = frame.heading
	tip.left = frame.left
	tip.up = frame.up


func _emit_changed() -> void:
	changed.emit()
