class_name RootGraph
extends RefCounted

const RootNodeClass = preload("res://scripts/roots/root_node.gd")
const RootGrowthFieldClass = preload("res://scripts/roots/root_growth_field.gd")

signal graph_changed

const MAX_DEPTH := 8
const MAX_ROOT_COUNT := 1800
const PRIMARY_ROOT_COUNT := 72
const BRANCH_POINT_INTERVAL := 4
const BRANCH_CHANCE := 0.62
const SECONDARY_BRANCH_CHANCE := 0.28
const STEP_LENGTH := 0.011
const MIN_SPAWN_SEPARATION_FRAC := 0.1
const SPAWN_ATTEMPTS := 8
const TREE_SPEED_RATIO := 6.0

var nodes: Dictionary = {}
var anchor: Vector3 = Vector3(0.0, 0.36, 0.0)
var next_id: int = 0
var _field
var _rng := RandomNumberGenerator.new()
var _growth_accumulator: float = 0.0
var _spawn_accumulator: float = 0.0
var _spawn_radius: float = 0.45

## Steps per second at speed_mult = 1.0 (very slow filamental growth).
var growth_rate: float = 0.35
## New fibrous roots spawned per second across the base circle.
var spawn_rate: float = 2.8
var thickness_falloff: float = 0.82
var _generation_seed: int = 0


func _init() -> void:
	_rng.randomize()


func setup(
	field,
	root_anchor: Vector3 = Vector3(0.0, 0.36, 0.0),
	spawn_radius: float = -1.0,
	seed: int = -1
) -> void:
	_field = field
	anchor = root_anchor
	_spawn_radius = spawn_radius if spawn_radius > 0.0 else 0.014
	_generation_seed = seed if seed >= 0 else int(_rng.randi())
	_rng.seed = _generation_seed
	clear()


func generate_for_elapsed(elapsed_seconds: float, speed_mult: float = 1.0) -> void:
	clear()
	_rng.seed = _generation_seed
	_growth_accumulator = 0.0
	_spawn_accumulator = 0.0

	if _field == null:
		graph_changed.emit()
		return

	_create_primary_roots()

	if elapsed_seconds <= 0.0:
		graph_changed.emit()
		return

	var remaining: float = elapsed_seconds
	var safety: int = 0
	const MAX_TICKS := 250_000
	const TICK_SECONDS := 1.0 / 30.0

	while remaining > 0.00001 and safety < MAX_TICKS:
		var dt: float = minf(remaining, TICK_SECONDS)
		grow(dt, speed_mult, false)
		remaining -= dt
		safety += 1

	graph_changed.emit()


func set_spawn_radius(spawn_radius: float) -> void:
	if spawn_radius > 0.0:
		_spawn_radius = spawn_radius


func clear() -> void:
	nodes.clear()
	next_id = 0
	_growth_accumulator = 0.0
	_spawn_accumulator = 0.0


func _min_spawn_separation() -> float:
	return maxf(_spawn_radius * MIN_SPAWN_SEPARATION_FRAC, 0.0015)


func _create_primary_roots() -> void:
	for i in range(PRIMARY_ROOT_COUNT):
		var spawn: Dictionary = _stratified_base_spawn(i, PRIMARY_ROOT_COUNT)
		_create_root(-1, spawn.start, spawn.outward, 0.007, 0)


func _stratified_base_spawn(index: int, total: int) -> Dictionary:
	var ring_t: float = (float(index) + _rng.randf()) / float(max(total, 1))
	var yaw: float = TAU * ring_t + _rng.randf_range(-0.18, 0.18)
	var radial: float = sqrt(ring_t) * _spawn_radius
	return _base_spawn_from_polar(yaw, radial)


func _random_base_spawn() -> Dictionary:
	var yaw: float = _rng.randf_range(0.0, TAU)
	var radial: float = sqrt(_rng.randf()) * _spawn_radius
	return _base_spawn_from_polar(yaw, radial)


func _base_spawn_from_polar(yaw: float, radial: float) -> Dictionary:
	var offset: Vector3 = Vector3(cos(yaw) * radial, 0.0, sin(yaw) * radial)
	var start: Vector3 = anchor + offset
	var outward: Vector3 = Vector3(offset.x, 0.0, offset.z)
	if outward.length_squared() < 0.0001:
		outward = Vector3(cos(yaw), 0.0, sin(yaw))
	return {"start": start, "outward": outward.normalized()}


func _is_spawn_location_clear(start: Vector3) -> bool:
	if _field != null and not _field.is_free(start):
		return false

	var min_sep_sq: float = _min_spawn_separation()
	min_sep_sq *= min_sep_sq
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if node.depth != 0 or node.points.is_empty():
			continue
		if node.points[0].distance_squared_to(start) < min_sep_sq:
			return false
	return true


func _try_spawn_fibrous_root() -> bool:
	if nodes.size() >= MAX_ROOT_COUNT:
		return false

	for _attempt in range(SPAWN_ATTEMPTS):
		var spawn: Dictionary = _random_base_spawn()
		if not _is_spawn_location_clear(spawn.start):
			continue
		return _create_root(-1, spawn.start, spawn.outward, 0.006, 0) != null
	return false


func _create_root(
	parent_id: int,
	start: Vector3,
	outward_bias: Vector3,
	thickness: float,
	depth: int
):
	if nodes.size() >= MAX_ROOT_COUNT:
		return null

	var node := RootNodeClass.new()
	node.id = next_id
	next_id += 1
	node.parent_id = parent_id
	node.thickness = maxf(thickness, 0.0015)
	node.depth = depth
	node.is_growing_tip = true
	node.outward_bias = outward_bias.normalized()
	node.squirm_phase = _rng.randf_range(0.0, TAU)
	node.points_since_branch = 0
	node.points = _seed_root_points(start, outward_bias)
	nodes[node.id] = node

	if parent_id >= 0 and nodes.has(parent_id):
		nodes[parent_id].children.append(node.id)
		nodes[parent_id].is_growing_tip = false

	return node


func _seed_root_points(start: Vector3, outward_bias: Vector3) -> Array:
	var points: Array = [start]
	var step_dir: Vector3 = _blend_growth_direction(outward_bias, start.y, 0.0).normalized()
	var pos: Vector3 = start
	for _i in range(2):
		var step: Dictionary = _field.find_step_around(pos, step_dir, STEP_LENGTH) if _field else {}
		if step.is_empty():
			pos += step_dir * STEP_LENGTH
		else:
			var allowed: float = float(step.get("length", 0.0))
			if allowed <= 0.0001:
				break
			pos = step.get("tip", pos)
			step_dir = step.get("direction", step_dir)
		if points[-1].distance_squared_to(pos) < 0.000001:
			break
		points.append(pos)
		if bool(step.get("blocked", false)):
			step_dir = _bounce_direction(step_dir, step.get("tip", pos), step)
	return points


func grow(delta: float, speed_mult: float = 1.0, emit_changed: bool = true) -> void:
	if _field == null:
		return

	var changed: bool = false

	_spawn_accumulator += spawn_rate * delta * speed_mult
	var spawn_budget: int = int(_spawn_accumulator)
	if spawn_budget > 0:
		_spawn_accumulator -= float(spawn_budget)
		for _i in range(spawn_budget):
			if _try_spawn_fibrous_root():
				changed = true

	if nodes.is_empty():
		if changed and emit_changed:
			graph_changed.emit()
		return

	_growth_accumulator += growth_rate * delta * speed_mult
	var step_budget: int = int(_growth_accumulator)
	if step_budget <= 0:
		if changed and emit_changed:
			graph_changed.emit()
		return
	_growth_accumulator -= float(step_budget)

	for _i in range(step_budget):
		var tips: Array = _get_active_tip_ids()
		if tips.is_empty():
			break
		for node_id in tips:
			if _append_step(node_id):
				changed = true

	if changed and emit_changed:
		graph_changed.emit()


func _append_step(node_id: int) -> bool:
	var node = nodes[node_id]
	if not node.is_growing_tip or node.points.is_empty():
		return false

	var tip_pos: Vector3 = node.tip()
	var preferred_dir: Vector3 = _squirm_direction(node, tip_pos)
	var step: Dictionary = _field.find_step_around(tip_pos, preferred_dir, STEP_LENGTH)
	var allowed: float = float(step.get("length", 0.0))
	if allowed <= 0.0001:
		if _try_surface_bounce(node, tip_pos, preferred_dir):
			return true
		node.is_growing_tip = false
		return true

	var next_pos: Vector3 = step.get("tip", tip_pos)
	if tip_pos.distance_squared_to(next_pos) < 0.000001:
		if _try_surface_bounce(node, tip_pos, preferred_dir):
			return true
		node.is_growing_tip = false
		return true

	node.points.append(next_pos)
	node.points_since_branch += 1

	if bool(step.get("blocked", false)):
		_apply_surface_bounce(node, preferred_dir, next_pos, step)

	if node.depth < MAX_DEPTH \
			and node.points_since_branch >= BRANCH_POINT_INTERVAL \
			and _rng.randf() < BRANCH_CHANCE:
		_try_branch(node_id, false)
		if node.depth < MAX_DEPTH - 1 and _rng.randf() < SECONDARY_BRANCH_CHANCE:
			_try_branch(node_id, true)

	return true


func _squirm_direction(node, tip_pos: Vector3) -> Vector3:
	var outward: Vector3 = node.outward_bias
	if outward.length_squared() < 0.0001:
		outward = Vector3(tip_pos.x - anchor.x, 0.0, tip_pos.z - anchor.z)
	if outward.length_squared() < 0.0001:
		outward = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	outward = outward.normalized()

	var downward: Vector3 = Vector3.DOWN
	var base_dir: Vector3 = _blend_growth_direction(outward, tip_pos.y, node.depth)
	if node.growth_heading.length_squared() > 0.0001:
		base_dir = (node.growth_heading * 0.72 + base_dir * 0.28).normalized()
		node.growth_heading = node.growth_heading.lerp(Vector3.ZERO, 0.06)

	var prev_dir: Vector3 = base_dir
	if node.points.size() >= 2:
		prev_dir = (node.points[-1] - node.points[-2]).normalized()

	var point_i: int = node.points.size()
	var wave: float = sin(float(point_i) * 0.62 + node.squirm_phase) * 0.22
	var curl_axis: Vector3 = prev_dir.cross(outward)
	if curl_axis.length_squared() < 0.0001:
		curl_axis = Vector3.UP
	var curled: Vector3 = prev_dir.rotated(curl_axis.normalized(), wave)

	var gnarl: Vector3 = Vector3(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-0.08, 0.12),
		_rng.randf_range(-1.0, 1.0)
	) * 0.14

	var dir: Vector3 = curled * 0.42 + base_dir * 0.58 + gnarl
	if dir.length_squared() < 0.0001:
		return base_dir
	return dir.normalized()


func _try_surface_bounce(node, tip_pos: Vector3, incoming_dir: Vector3) -> bool:
	var normal: Vector3 = _field.collision_normal_at(tip_pos)
	if normal.length_squared() <= 0.0001:
		return false
	_apply_surface_bounce(node, incoming_dir, tip_pos, {"normal": normal})
	return true


func _apply_surface_bounce(node, incoming_dir: Vector3, hit_pos: Vector3, step: Dictionary) -> void:
	var normal: Vector3 = step.get("normal", Vector3.ZERO)
	if normal.length_squared() <= 0.0001 and _field != null:
		normal = _field.collision_normal_at(hit_pos)
	if normal.length_squared() <= 0.0001:
		return

	var reflected: Vector3 = _bounce_direction(incoming_dir, hit_pos, step)
	node.growth_heading = reflected
	node.outward_bias = Vector3(reflected.x, 0.0, reflected.z)
	if node.outward_bias.length_squared() > 0.0001:
		node.outward_bias = node.outward_bias.normalized()
	node.squirm_phase += _rng.randf_range(0.35, 1.2)


func _bounce_direction(incoming_dir: Vector3, hit_pos: Vector3, step: Dictionary) -> Vector3:
	var normal: Vector3 = step.get("normal", Vector3.ZERO)
	if normal.length_squared() <= 0.0001 and _field != null:
		normal = _field.collision_normal_at(hit_pos)
	if normal.length_squared() <= 0.0001:
		return incoming_dir.normalized()

	if normal.dot(Vector3.UP) > 0.65:
		var slide: Vector3 = Vector3(incoming_dir.x, 0.0, incoming_dir.z)
		if slide.length_squared() <= 0.0001:
			slide = Vector3(normal.x, 0.0, normal.z)
		if slide.length_squared() <= 0.0001:
			slide = Vector3(1.0, 0.0, 0.0)
		return slide.normalized()

	var reflected: Vector3 = incoming_dir - 2.0 * incoming_dir.dot(normal) * normal
	if reflected.length_squared() <= 0.0001:
		return incoming_dir.normalized()
	return reflected.normalized()


func _try_branch(parent_id: int, alternate: bool) -> void:
	var parent = nodes[parent_id]
	parent.points_since_branch = 0

	var tip_pos: Vector3 = parent.tip()
	var parent_outward: Vector3 = parent.outward_bias
	var axis: Vector3 = Vector3.UP
	var sign: float = 1.0 if _rng.randf() > 0.5 else -1.0
	if alternate:
		sign *= -1.0
	var spread: float = 24.0 if alternate else 34.0
	var branch_bias: Vector3 = parent_outward.rotated(
		axis,
		deg_to_rad(spread * sign + _rng.randf_range(-10.0, 10.0))
	)
	branch_bias = (branch_bias + Vector3.DOWN * 0.12).normalized()

	var probe: Dictionary = _field.find_step_around(tip_pos, branch_bias, STEP_LENGTH * 2.0)
	if float(probe.get("length", 0.0)) < STEP_LENGTH * 0.45:
		return

	var child_thickness: float = parent.thickness * thickness_falloff
	_create_root(parent_id, tip_pos, branch_bias, child_thickness, parent.depth + 1)


func get_joint(node_id: int) -> Vector3:
	if not nodes.has(node_id):
		return anchor
	var node = nodes[node_id]
	if node.points.is_empty():
		return anchor
	return node.points[0]


func get_tip(node_id: int) -> Vector3:
	if not nodes.has(node_id):
		return anchor
	return nodes[node_id].tip()


func _get_active_tip_ids() -> Array:
	var tips: Array = []
	for node_id in nodes.keys():
		if nodes[node_id].is_growing_tip:
			tips.append(node_id)
	return tips


func has_tip_extension() -> bool:
	return _growth_accumulator > 0.001


func get_render_points(node) -> PackedVector3Array:
	var points := PackedVector3Array()
	for point in node.points:
		if point is Vector3:
			points.append(point)

	if node.is_growing_tip and points.size() > 0:
		var extension: float = _growth_accumulator * STEP_LENGTH
		if extension > 0.00001:
			points.append(points[points.size() - 1] + _tip_preview_direction(node) * extension)
	return points


func _tip_preview_direction(node) -> Vector3:
	if node.growth_heading.length_squared() > 0.0001:
		return node.growth_heading.normalized()
	if node.points.size() >= 2:
		return (node.points[-1] - node.points[-2]).normalized()
	var tip_y: float = node.points[-1].y if node.points.size() > 0 else anchor.y
	return _blend_growth_direction(node.outward_bias, tip_y, node.depth)


func _blend_growth_direction(outward: Vector3, tip_y: float, depth: int) -> Vector3:
	var outward_horiz: Vector3 = Vector3(outward.x, 0.0, outward.z)
	if outward_horiz.length_squared() < 0.0001:
		outward_horiz = Vector3(1.0, 0.0, 0.0)
	else:
		outward_horiz = outward_horiz.normalized()

	var depth_below: float = 0.0
	if anchor.y > 0.0001:
		depth_below = clampf((anchor.y - tip_y) / anchor.y, 0.0, 1.0)

	var shallow_boost: float = (1.0 - depth_below) * 0.22
	var lateral_weight: float = clampf(0.62 + shallow_boost - float(depth) * 0.03, 0.45, 0.82)
	var down_weight: float = 1.0 - lateral_weight
	return (Vector3.DOWN * down_weight + outward_horiz * lateral_weight).normalized()


func to_dict() -> Dictionary:
	var node_dict: Dictionary = {}
	for node_id in nodes.keys():
		node_dict[str(node_id)] = nodes[node_id].to_dict()
	return {
		"anchor": [anchor.x, anchor.y, anchor.z],
		"next_id": next_id,
		"spawn_radius": _spawn_radius,
		"generation_seed": _generation_seed,
		"nodes": node_dict,
	}


func from_dict(data: Dictionary, field) -> void:
	clear()
	_field = field
	var anchor_data: Array = data.get("anchor", [0.0, 0.36, 0.0])
	anchor = Vector3(float(anchor_data[0]), float(anchor_data[1]), float(anchor_data[2]))
	_spawn_radius = float(data.get("spawn_radius", 0.014))
	_generation_seed = int(data.get("generation_seed", 0))
	if _generation_seed != 0:
		_rng.seed = _generation_seed
	next_id = int(data.get("next_id", 0))
	var node_dict: Dictionary = data.get("nodes", {})
	for key in node_dict.keys():
		var node = RootNodeClass.from_dict(node_dict[key])
		nodes[node.id] = node
