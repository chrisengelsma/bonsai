class_name TreeGraph
extends RefCounted

const BranchNodeClass = preload("res://scripts/tree/branch_node.gd")
const LSystemInterpreter = preload("res://scripts/tree/lsystem_interpreter.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const SpatialGrowth = preload("res://scripts/tree/spatial_growth.gd")

const JOINT_COLLAR_LENGTH_FRAC := 0.38
const FORK_TAPER_MIN_LENGTH := 0.038
const FORK_TAPER_LENGTH_FRAC := 0.24

signal graph_changed

var nodes: Dictionary = {}
var root_id: int = -1
var next_id: int = 0
var species_id: String = ""
var _thickness_falloff: float = 0.72
var _rng := RandomNumberGenerator.new()
var _allow_prune_spawn: bool = false

const PATH_RADIUS_DECAY := 2.05


func _init() -> void:
	_rng.randomize()


func clear() -> void:
	nodes.clear()
	root_id = -1
	next_id = 0


func create_from_species(species) -> void:
	clear()
	species_id = species.id
	if species.grow_pattern:
		_thickness_falloff = species.grow_pattern.thickness_falloff
	if species.starter_graph.is_empty():
		_create_default_starter(species)
	else:
		from_dict(species.starter_graph)


func _create_default_starter(species) -> void:
	var pattern = species.grow_pattern
	var root_thickness: float = pattern.trunk_thickness
	if species.id == "ginseng_ficus":
		root_thickness *= 1.15

	var root = _create_node(-1, Vector3.UP, root_thickness, 0)
	root.length = 0.09 if species.id == "ginseng_ficus" else 0.04
	root.base_thickness = root_thickness
	if species.id == "ginseng_ficus":
		root.cambium_thickness = pattern.trunk_thickness * 0.06
		root.thickness = root.base_thickness + root.cambium_thickness
		root.ring_samples.clear()
		root.locked_wobble.clear()
		_init_branch_profile(root)
	root.is_growing_tip = true
	root.lsymbol = pattern.lsystem_axiom if pattern.use_lsystem else "T"
	if pattern.deterministic_growth:
		root.turtle_up = Vector3.FORWARD
	else:
		var root_spin: float = _rng.randf_range(0.0, TAU)
		root.turtle_up = Vector3.FORWARD.rotated(Vector3.UP, root_spin).normalized()
	root.growth_energy = _roll_growth_energy(pattern)
	root.stochastic_direction = not pattern.deterministic_growth
	root_id = root.id


func get_trunk_base_spawn_radius() -> float:
	if not nodes.has(root_id):
		return 0.014
	var root = nodes[root_id]
	return clampf(root.thickness * 1.75, 0.008, 0.05)


func _create_node(parent_id: int, direction: Vector3, thickness: float, depth: int):
	var node = BranchNodeClass.new()
	node.id = next_id
	next_id += 1
	node.parent_id = parent_id
	node.direction = direction.normalized()
	node.thickness = thickness
	node.depth = depth
	node.growth_energy = 1.0
	nodes[node.id] = node
	if parent_id >= 0 and nodes.has(parent_id):
		nodes[parent_id].children.append(node.id)
	_init_branch_profile(node)
	return node


func grow(delta: float, pattern, moisture_ok: bool, speed_mult: float, soil_mult: float) -> void:
	if not moisture_ok:
		return

	GrowthLimits.clamp_pattern(pattern)
	_thickness_falloff = pattern.thickness_falloff
	_enforce_active_tip_budget()
	var over_height: bool = _is_over_height_limit()

	var now = Time.get_ticks_msec() / 1000.0
	_process_regrowth(now, pattern, delta)

	var tip_ids = _get_active_tip_ids()
	for tip_id in tip_ids:
		var tip = nodes[tip_id]
		if tip.freeze_length:
			continue
		if over_height:
			tip.is_growing_tip = false
			continue

		var max_length: float = GrowthLimits.max_length_for_depth(tip.depth)
		if tip.length >= max_length:
			tip.is_growing_tip = false
			continue

		tip.age += delta
		var growth_amount: float = pattern.tip_growth_rate * delta * speed_mult * soil_mult * tip.growth_energy
		tip.length = minf(tip.length + growth_amount, max_length)

		if pattern.gravity_curve != 0.0 and tip.stochastic_direction:
			var gravity = Vector3(0.0, -pattern.gravity_curve * delta, 0.0)
			tip.direction = (tip.direction + gravity).normalized()

		if pattern.foliage_style != "none" and tip.length >= pattern.foliage_start_length:
			tip.foliage_amount = minf(1.0, tip.foliage_amount + pattern.foliage_growth_rate * delta)

		_accumulate_cambium_on_path(tip_id, delta, pattern)
		_update_branch_profile(tip, pattern)

		var segment_length: float = _segment_length_for_tip(tip, pattern)
		if tip.length - tip.length_at_last_production >= segment_length:
			if pattern.use_lsystem:
				LSystemInterpreter.apply_at_tip(self, tip_id, pattern)
			elif _should_random_bud(tip, pattern, delta):
				_bud_child_random(tip_id, pattern)
			tip.next_segment_length = -1.0

	graph_changed.emit()


func _should_random_bud(tip, pattern, delta: float) -> bool:
	if tip.depth >= pattern.max_branch_depth:
		return false
	if tip.children.size() >= pattern.max_children_per_node:
		return false
	var chance: float = pattern.branch_split_chance * delta
	if pattern.apical_dominance > 0.5:
		chance *= 1.0 - pattern.apical_dominance * 0.5
	return _rng.randf() < chance


func _process_regrowth(now: float, pattern, delta: float) -> void:
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if node.cut_timestamp < 0.0:
			continue
		if now - node.cut_timestamp < pattern.regrowth_delay:
			continue
		if node.is_growing_tip:
			continue
		if _rng.randf() < pattern.regrowth_chance * delta:
			if not GrowthLimits.can_add_node(nodes.size()):
				continue
			var spread_deg: float = pattern.lsystem_angle_deg + pattern.spatial_spread_deg
			var new_dir: Vector3 = SpatialGrowth.spread_direction(node.direction, spread_deg, _rng)
			var child = bud_lsystem_child(
				node_id,
				new_dir,
				_lateral_regrowth_symbol(pattern),
				pattern
			)
			if child:
				node.cut_timestamp = -1.0
				node.is_growing_tip = false


func _lateral_regrowth_symbol(pattern) -> String:
	var rules = pattern.get_lsystem_rules()
	if rules.has("S"):
		return "S"
	if rules.has("B"):
		return "B"
	return pattern.lsystem_axiom


func bud_lsystem_child(
	parent_id: int,
	direction: Vector3,
	lsymbol: String,
	pattern,
	turtle_up: Vector3 = Vector3.FORWARD,
	stochastic_direction: bool = true
):
	var parent = nodes[parent_id]
	if not _allow_prune_spawn and not GrowthLimits.can_add_node(nodes.size()):
		return null
	if parent.children.size() >= pattern.max_children_per_node:
		return null
	if parent.depth + 1 > pattern.max_branch_depth:
		return null

	var thickness: float = _parent_tip_radius(parent_id) * pattern.thickness_falloff
	if parent.prune_cut_radius <= 0.0 and thickness < pattern.branch_thickness:
		thickness = pattern.branch_thickness

	var child = _create_node(parent_id, direction, thickness, parent.depth + 1)
	child.base_thickness = thickness
	child.length = maxf(pattern.lsystem_segment_length * 0.32, 0.042)
	child.is_growing_tip = true
	child.lsymbol = lsymbol
	child.length_at_last_production = child.length
	child.turtle_up = turtle_up.normalized()
	child.growth_energy = _roll_growth_energy(pattern)
	child.stochastic_direction = stochastic_direction
	parent.is_growing_tip = false
	_setup_child_joint_profile(parent, child)
	return child


func continue_growth_segment(
	parent_id: int,
	direction: Vector3,
	turtle_up: Vector3,
	lsymbol: String,
	pattern
) -> void:
	if not nodes.has(parent_id):
		return
	if not GrowthLimits.can_add_node(nodes.size()):
		return

	var parent = nodes[parent_id]
	parent.is_growing_tip = false
	parent.freeze_length = true
	_extend_tip_sample(parent)

	var thickness: float = _parent_tip_radius(parent_id)
	var child = _create_node(parent_id, direction, thickness, parent.depth)
	child.base_thickness = thickness
	child.length = maxf(pattern.lsystem_segment_length * 0.32, 0.042)
	child.is_growing_tip = true
	child.lsymbol = lsymbol
	child.length_at_last_production = child.length
	child.turtle_up = turtle_up.normalized()
	child.growth_energy = _roll_growth_energy(pattern)
	child.stochastic_direction = parent.stochastic_direction
	_setup_axial_continuation_profile(parent, child)


func _setup_axial_continuation_profile(parent, child) -> void:
	ensure_profile_render_ready(parent)
	_update_parent_fork_profile(parent)

	var child_dir: Vector3 = child.direction.normalized()
	child.profile_frame_right = Vector3.ZERO
	child.profile_joint_radius = get_radius_at_dist(parent.id, parent.length)
	child.locked_wobble = parent.locked_wobble.duplicate()
	child.last_profile_direction = child_dir
	child.last_ring_sample_dist = 0.0

	var tip_dist: float = maxf(child.length, 0.02)
	child.ring_samples = [
		{
			"dist": 0.0,
			"dir": child_dir,
		},
		{
			"dist": tip_dist,
			"dir": child_dir,
		},
	]


func _bud_child_random(parent_id: int, pattern) -> bool:
	var parent = nodes[parent_id]
	var angle_deg = _rng.randf_range(pattern.branch_angle_range.x, pattern.branch_angle_range.y)
	if _rng.randf() > 0.5:
		angle_deg = -angle_deg
	var axis = parent.direction.cross(Vector3.UP)
	if axis.length_squared() < 0.001:
		axis = Vector3.RIGHT
	var child_dir = parent.direction.rotated(axis.normalized(), deg_to_rad(angle_deg)).normalized()
	return bud_lsystem_child(parent_id, child_dir, "S", pattern) != null


func _init_branch_profile(node) -> void:
	if not node.ring_samples.is_empty():
		if node.last_profile_direction.length_squared() <= 0.0001:
			node.last_profile_direction = node.direction.normalized()
		if node.base_thickness <= 0.0:
			node.base_thickness = node.thickness
		return

	node.base_thickness = node.thickness
	node.cambium_thickness = 0.0
	node.locked_wobble = []
	node.last_ring_sample_dist = 0.0
	node.last_profile_direction = node.direction.normalized()
	node.profile_joint_radius = -1.0
	node.profile_frame_right = Vector3.ZERO
	node.ring_samples = [
		{
			"dist": 0.0,
			"dir": node.last_profile_direction,
		},
		{
			"dist": maxf(node.length, 0.02),
			"dir": node.last_profile_direction,
		},
	]


func _setup_child_joint_profile(parent, child) -> void:
	ensure_profile_render_ready(parent)
	_update_parent_fork_profile(parent)

	var exit_dir: Vector3 = parent.last_profile_direction.normalized()
	var exit_right: Vector3 = Vector3.ZERO
	var child_dir: Vector3 = child.direction.normalized()
	var fork_angle: float = exit_dir.angle_to(child_dir)

	child.profile_frame_right = exit_right
	child.profile_joint_radius = get_radius_at_dist(parent.id, parent.length)
	child.locked_wobble = parent.locked_wobble.duplicate()
	child.last_profile_direction = child_dir

	var collar_len: float = _joint_collar_length(child)
	if fork_angle > deg_to_rad(10.0):
		collar_len = minf(collar_len, maxf(child.length * 0.2, 0.003))

	var tip_dist: float = maxf(child.length, collar_len + 0.012)
	child.last_ring_sample_dist = collar_len if fork_angle <= deg_to_rad(10.0) else 0.0

	var samples: Array = []
	if fork_angle <= deg_to_rad(10.0):
		var bend_steps: int = 3 if child.length < 0.12 else 5
		for step_i in range(bend_steps + 1):
			var blend_t: float = float(step_i) / float(bend_steps)
			samples.append({
				"dist": collar_len * blend_t,
				"dir": exit_dir.slerp(child_dir, blend_t).normalized(),
			})
	else:
		samples.append({
			"dist": 0.0,
			"dir": child_dir,
		})
		if collar_len > 0.002:
			samples.append({
				"dist": collar_len,
				"dir": child_dir,
			})

	var last_dist: float = float(samples[-1].get("dist", 0.0))
	if tip_dist > last_dist + 0.001:
		samples.append({
			"dist": tip_dist,
			"dir": child_dir,
		})
	elif absf(tip_dist - last_dist) <= 0.001:
		samples[-1]["dist"] = tip_dist

	child.ring_samples = samples


func _joint_collar_length(node) -> float:
	var branch_length: float = maxf(node.length, 0.01)
	var desired: float = maxf(branch_length * JOINT_COLLAR_LENGTH_FRAC, 0.004)
	return minf(desired, branch_length * 0.68)


func _fork_taper_length(node) -> float:
	return maxf(node.length * FORK_TAPER_LENGTH_FRAC, FORK_TAPER_MIN_LENGTH)


func _fork_tip_radius(parent) -> float:
	var fork_radius: float = 0.0
	for child_id in parent.children:
		var child = nodes[child_id]
		var child_core: float = child.base_thickness + child.cambium_thickness
		fork_radius = maxf(fork_radius, child_core * 0.96)
	var parent_core: float = parent.base_thickness + parent.cambium_thickness
	if fork_radius <= 0.0:
		return parent_core * 0.9
	return clampf(fork_radius, parent_core * 0.5, parent_core * 0.98)


func _update_parent_fork_profile(parent) -> void:
	if parent.children.is_empty():
		return

	ensure_profile_render_ready(parent)
	var fork_len: float = _fork_taper_length(parent)
	var fork_start: float = maxf(parent.length - fork_len, 0.0)
	_ensure_sample_at_dist(parent, fork_start, parent.last_profile_direction)
	_extend_tip_sample(parent)
	_refresh_ring_sample_radii(parent)

	var tip_radius: float = get_radius_at_dist(parent.id, parent.length)
	for child_id in parent.children:
		var child = nodes[child_id]
		child.profile_joint_radius = tip_radius


func _ensure_sample_at_dist(node, dist: float, direction: Vector3) -> void:
	for sample in node.ring_samples:
		if sample is Dictionary and absf(float(sample.get("dist", -1.0)) - dist) < 0.001:
			return
	_append_frozen_sample(node, dist, direction)


func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func get_radius_at_dist(node_id: int, dist: float) -> float:
	if not nodes.has(node_id):
		return 0.02
	return _radius_at_dist(nodes[node_id], dist)


func _path_distance_from_root(node_id: int, dist_along: float) -> float:
	var total: float = maxf(dist_along, 0.0)
	var current_id: int = node_id
	while nodes.has(current_id):
		var node = nodes[current_id]
		if node.parent_id < 0:
			break
		var parent = nodes[node.parent_id]
		total += maxf(parent.length, 0.02)
		current_id = node.parent_id
	return total


func _root_core_radius() -> float:
	if not nodes.has(root_id):
		return 0.02
	var root = nodes[root_id]
	return maxf(root.base_thickness + root.cambium_thickness, 0.008)


func _segment_base_radius(node) -> float:
	var core_radius: float = node.base_thickness + node.cambium_thickness
	var min_radius: float = maxf(core_radius * 0.38, 0.0035)

	var path_from_root: float = _path_distance_from_root(node.id, 0.0)
	var trunk_radius: float = _root_core_radius()
	var path_radius: float = trunk_radius * exp(-path_from_root * PATH_RADIUS_DECAY)
	path_radius *= pow(_thickness_falloff, float(node.depth) * 0.42)
	path_radius = maxf(path_radius, min_radius)

	var base_radius: float = maxf(core_radius, path_radius)
	if node.profile_joint_radius > 0.0:
		base_radius = maxf(base_radius, node.profile_joint_radius)
	return base_radius


func _segment_tip_radius(node, base_radius: float) -> float:
	var core_radius: float = node.base_thickness + node.cambium_thickness
	var min_radius: float = maxf(core_radius * 0.38, 0.0035)
	var tip_radius: float = maxf(core_radius * 0.72, min_radius)
	return minf(tip_radius, base_radius * 0.92)


func _radius_at_dist(node, dist: float) -> float:
	var length: float = maxf(node.length, 0.02)
	var local_t: float = clampf(dist / length, 0.0, 1.0)

	if node.prune_cut_radius > 0.0:
		var joint_radius: float = _segment_base_radius(node)
		var cut_radius: float = minf(node.prune_cut_radius, joint_radius)
		return lerpf(joint_radius, cut_radius, _smoothstep(pow(local_t, 0.9)))

	var base_radius: float = _segment_base_radius(node)
	var tip_radius: float = _segment_tip_radius(node, base_radius)
	var radius: float = lerpf(base_radius, tip_radius, _smoothstep(pow(local_t, 0.9)))

	if not node.children.is_empty():
		var fork_len: float = minf(_fork_taper_length(node), length * 0.85)
		var fork_start: float = maxf(length - fork_len, 0.0)
		if dist >= fork_start:
			var fork_t: float = clampf(
				(dist - fork_start) / maxf(fork_len, 0.001),
				0.0,
				1.0
			)
			var fork_radius: float = minf(_fork_tip_radius(node), base_radius * 0.88)
			radius = lerpf(radius, fork_radius, _smoothstep(fork_t) * 0.45)

	return maxf(radius, maxf(base_radius * 0.35, 0.0035))


func _append_frozen_sample(node, dist: float, direction: Vector3) -> void:
	var frozen_dir: Vector3 = direction.normalized()
	if not node.ring_samples.is_empty():
		var last_sample: Dictionary = node.ring_samples[-1]
		var last_dist: float = float(last_sample.get("dist", -1.0))
		var last_dir: Vector3 = last_sample.get("dir", Vector3.UP)
		if absf(last_dist - dist) < 0.001 and last_dir.angle_to(frozen_dir) < deg_to_rad(0.5):
			return

	node.ring_samples.append({
		"dist": dist,
		"dir": frozen_dir,
	})


func _extend_tip_sample(node) -> void:
	if node.ring_samples.is_empty():
		return

	var tip_dist: float = maxf(node.length, 0.02)
	var last_sample: Dictionary = node.ring_samples[-1]
	var last_dist: float = float(last_sample.get("dist", 0.0))
	var tip_dir: Vector3 = node.last_profile_direction
	if tip_dir.length_squared() <= 0.0001:
		tip_dir = node.direction
	tip_dir = tip_dir.normalized()
	if node.direction.length_squared() > 0.0001:
		tip_dir = node.direction.normalized()

	if absf(last_dist - tip_dist) < 0.001 and last_sample.get("dir", Vector3.UP).angle_to(tip_dir) < deg_to_rad(0.5):
		return

	_append_frozen_sample(node, tip_dist, tip_dir)
	node.last_profile_direction = tip_dir


func _update_branch_profile(node, pattern) -> void:
	if node.ring_samples.is_empty():
		_init_branch_profile(node)

	var spacing: float = maxf(pattern.ring_sample_spacing, 0.015)
	while node.last_ring_sample_dist + spacing <= node.length - 0.001:
		node.last_ring_sample_dist += spacing
		_append_frozen_sample(node, node.last_ring_sample_dist, node.last_profile_direction)

	var direction_changed: bool = node.last_profile_direction.angle_to(node.direction) > deg_to_rad(2.5)
	if direction_changed:
		_append_frozen_sample(node, node.length, node.last_profile_direction)
		node.last_profile_direction = node.direction.normalized()
		node.last_ring_sample_dist = node.length
		_append_frozen_sample(node, node.length, node.last_profile_direction)
	else:
		_extend_tip_sample(node)


func ensure_profile_render_ready(node) -> void:
	if node.ring_samples.is_empty():
		_init_branch_profile(node)
	elif node.ring_samples.size() < 2:
		_append_frozen_sample(node, maxf(node.length, 0.02), node.last_profile_direction)
	else:
		_extend_tip_sample(node)


func prepare_all_profiles_for_render() -> void:
	for node_id in nodes.keys():
		ensure_profile_render_ready(nodes[node_id])
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if not node.children.is_empty():
			_update_parent_fork_profile(node)
		_refresh_ring_sample_radii(node)


func get_bark_guide_samples(node_id: int, guide_spacing: float, angle_keep_deg: float = 8.0) -> Array:
	if not nodes.has(node_id):
		return []
	var node = nodes[node_id]
	ensure_profile_render_ready(node)
	var guides: Array = decimate_ring_samples(node.ring_samples, guide_spacing, angle_keep_deg)
	return _samples_with_radii(node_id, guides)


static func decimate_ring_samples(samples: Array, min_spacing: float, angle_keep_deg: float = 8.0) -> Array:
	if samples.size() <= 2:
		return samples.duplicate()

	var angle_keep: float = deg_to_rad(angle_keep_deg)
	var kept: Array = [samples[0].duplicate()]
	for i in range(1, samples.size() - 1):
		var sample: Dictionary = samples[i]
		var prev: Dictionary = kept[-1]
		var dist_gap: float = float(sample.get("dist", 0.0)) - float(prev.get("dist", 0.0))
		var prev_dir: Vector3 = prev.get("dir", Vector3.UP)
		var sample_dir: Vector3 = sample.get("dir", Vector3.UP)
		var bend: float = prev_dir.angle_to(sample_dir)
		if dist_gap >= min_spacing or bend >= angle_keep:
			kept.append(sample.duplicate())

	var last: Dictionary = samples[-1]
	var tail: Dictionary = kept[-1]
	if float(last.get("dist", 0.0)) - float(tail.get("dist", 0.0)) > 0.001:
		kept.append(last.duplicate())
	elif kept.size() == 1:
		kept.append(last.duplicate())
	else:
		kept[-1] = last.duplicate()
	return kept


func _samples_with_radii(node_id: int, samples: Array) -> Array:
	var result: Array = []
	for sample in samples:
		if sample is Dictionary:
			var dist: float = float(sample.get("dist", 0.0))
			result.append({
				"dist": dist,
				"dir": sample.get("dir", Vector3.UP),
				"r": get_radius_at_dist(node_id, dist),
			})
	return result


func _accumulate_cambium_on_path(node_id: int, delta: float, pattern) -> void:
	var current_id: int = node_id
	while nodes.has(current_id):
		var node = nodes[current_id]
		var rate: float = pattern.cambium_growth_rate * delta * node.growth_energy
		if node.depth == 0:
			rate *= 1.45
		else:
			rate *= pow(pattern.thickness_falloff, float(node.depth) * 0.42)

		node.cambium_thickness += rate
		node.thickness = minf(
			node.base_thickness + node.cambium_thickness,
			_max_radius_for_node(node, pattern)
		)

		if node.parent_id < 0:
			break
		current_id = node.parent_id


func _max_radius_for_node(node, pattern) -> float:
	var target: float = pattern.trunk_thickness if node.depth == 0 else pattern.branch_thickness
	return target * (1.0 + node.age * 0.05) + node.cambium_thickness * 0.35


func _refresh_ring_sample_radii(node) -> void:
	for sample in node.ring_samples:
		if sample is Dictionary:
			var dist: float = float(sample.get("dist", 0.0))
			sample["r"] = get_radius_at_dist(node.id, dist)


func cut_branch(branch_id: int) -> bool:
	if not nodes.has(branch_id) or branch_id == root_id:
		return false

	var parent_id: int = nodes[branch_id].parent_id
	_remove_subtree(branch_id)

	if parent_id >= 0 and nodes.has(parent_id):
		var parent = nodes[parent_id]
		parent.is_growing_tip = false
		parent.cut_timestamp = Time.get_ticks_msec() / 1000.0

	adapt_after_edit()
	graph_changed.emit()
	return true


func _parent_tip_radius(parent_id: int) -> float:
	if not nodes.has(parent_id):
		return 0.01
	var parent = nodes[parent_id]
	if parent.prune_cut_radius > 0.0:
		return parent.prune_cut_radius
	return get_radius_at_dist(parent_id, parent.length)


func _truncate_branch_profile(node, cut_dist: float) -> void:
	ensure_profile_render_ready(node)

	var trimmed: Array = []
	for sample in node.ring_samples:
		if sample is Dictionary and float(sample.get("dist", 0.0)) <= cut_dist + 0.001:
			trimmed.append(sample)

	if trimmed.is_empty():
		trimmed.append({
			"dist": 0.0,
			"dir": node.last_profile_direction,
		})

	var last_dist: float = float(trimmed[-1].get("dist", 0.0))
	if cut_dist > last_dist + 0.001:
		trimmed.append({
			"dist": cut_dist,
			"dir": node.last_profile_direction,
		})
	else:
		trimmed[-1]["dist"] = cut_dist

	node.ring_samples = trimmed
	node.last_ring_sample_dist = cut_dist
	node.last_profile_direction = node.direction.normalized()


func prune_at_point(branch_id: int, local_hit: Vector3, sole_seed: bool = false) -> bool:
	if not nodes.has(branch_id):
		return false

	var node = nodes[branch_id]
	var start: Vector3 = get_joint(branch_id)
	var end: Vector3 = get_world_tip(branch_id)
	var branch_dir: Vector3 = (end - start).normalized()
	if branch_dir.length_squared() <= 0.0001:
		branch_dir = node.direction.normalized()

	var axis_length: float = start.distance_to(end)
	var along: float = (local_hit - start).dot(branch_dir)
	along = clampf(along, 0.02, maxf(axis_length, 0.02))

	for child_id in node.children.duplicate():
		_remove_subtree(child_id)
	node.children.clear()

	node.length = along
	ensure_profile_render_ready(node)
	var base_radius: float = get_radius_at_dist(branch_id, 0.0)
	var cut_radius: float = get_radius_at_dist(branch_id, along)

	node.freeze_length = true
	node.prune_seed_pending = true
	node.prune_cut_radius = cut_radius
	node.base_thickness = base_radius
	node.thickness = base_radius
	node.cambium_thickness = 0.0
	node.cut_timestamp = -1.0
	node.length_at_last_production = node.length
	node.next_segment_length = -1.0
	node.foliage_amount = 0.0
	node.is_growing_tip = false

	_truncate_branch_profile(node, along)

	if sole_seed:
		for node_id in nodes.keys():
			nodes[node_id].is_growing_tip = false

	graph_changed.emit()
	return true


func sprout_prune_seeds(pattern) -> int:
	GrowthLimits.clamp_pattern(pattern)
	_thickness_falloff = pattern.thickness_falloff
	_allow_prune_spawn = true

	var spawned_total: int = 0
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if not node.prune_seed_pending:
			continue
		if node.depth + 1 > pattern.max_branch_depth:
			node.prune_seed_pending = false
			continue

		var spawned: int = 0
		if pattern.use_lsystem:
			spawned = LSystemInterpreter.apply_prune_seed(self, node_id, pattern)
			if spawned == 0:
				spawned = _bud_prune_fallback(node_id, pattern)
		elif _should_random_bud(node, pattern, 1.0):
			if _bud_child_random(node_id, pattern):
				spawned = 1
		else:
			spawned = _bud_prune_fallback(node_id, pattern)

		node.prune_seed_pending = false
		spawned_total += spawned

	_allow_prune_spawn = false
	if spawned_total > 0:
		graph_changed.emit()
	return spawned_total


func has_pending_prune_seeds(pattern) -> bool:
	GrowthLimits.clamp_pattern(pattern)
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if node.prune_seed_pending and node.depth + 1 <= pattern.max_branch_depth:
			return true
	return false


func _bud_prune_fallback(parent_id: int, pattern) -> int:
	if not nodes.has(parent_id):
		return 0

	var parent = nodes[parent_id]
	var symbol: String = _lateral_prune_symbol(parent.lsymbol, pattern)
	var axis: Vector3 = parent.direction.cross(Vector3.UP)
	if axis.length_squared() < 0.001:
		axis = Vector3.RIGHT
	axis = axis.normalized()

	var spawned: int = 0
	var angle_rad: float = deg_to_rad(pattern.lsystem_angle_deg)
	for sign in [-1.0, 1.0]:
		if parent.children.size() >= pattern.max_children_per_node:
			break
		var dir: Vector3 = parent.direction.rotated(axis, angle_rad * sign).normalized()
		if bud_lsystem_child(parent_id, dir, symbol, pattern, parent.turtle_up, false) != null:
			spawned += 1
	return spawned


func _lateral_prune_symbol(parent_symbol: String, pattern) -> String:
	var production: String = pattern.get_production(parent_symbol)
	for i in production.length():
		var symbol: String = production[i]
		if symbol.length() != 1:
			continue
		var code: int = symbol.unicode_at(0)
		if code >= 65 and code <= 90 and symbol != "F":
			return symbol
	return _lateral_regrowth_symbol(pattern)


func advance_lab_step(pattern, speed_mult: float = 1.0) -> void:
	GrowthLimits.clamp_pattern(pattern)
	_thickness_falloff = pattern.thickness_falloff

	for tip_id in _get_active_tip_ids():
		var tip = nodes[tip_id]
		if tip.depth >= pattern.max_branch_depth:
			tip.is_growing_tip = false
			continue

		var max_length: float = GrowthLimits.max_length_for_depth(tip.depth)
		var segment_length: float = _segment_length_for_tip(tip, pattern)
		var since_production: float = tip.length - tip.length_at_last_production
		var growth_needed: float = maxf(segment_length - since_production, segment_length * 0.25)
		tip.length = minf(tip.length + growth_needed * speed_mult, max_length)

		if pattern.gravity_curve != 0.0 and tip.stochastic_direction:
			var gravity := Vector3(0.0, -pattern.gravity_curve * 0.05, 0.0)
			tip.direction = (tip.direction + gravity).normalized()

		_accumulate_cambium_on_path(tip_id, 0.05, pattern)
		_update_branch_profile(tip, pattern)

		if tip.length - tip.length_at_last_production >= segment_length * 0.98:
			if pattern.use_lsystem:
				LSystemInterpreter.apply_at_tip(self, tip_id, pattern)
			elif _should_random_bud(tip, pattern, 1.0):
				_bud_child_random(tip_id, pattern)
			tip.next_segment_length = -1.0

	graph_changed.emit()


func has_growable_seed_tips(pattern) -> bool:
	if has_pending_prune_seeds(pattern):
		return true
	GrowthLimits.clamp_pattern(pattern)
	for node_id in nodes.keys():
		if _is_growable_seed(nodes[node_id], pattern):
			return true
	return false


func reactivate_seed_tips(pattern) -> int:
	GrowthLimits.clamp_pattern(pattern)
	var activated: int = 0
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if not _is_growable_seed(node, pattern):
			continue
		if not node.is_growing_tip:
			node.is_growing_tip = true
			activated += 1
	if activated > 0:
		graph_changed.emit()
	return activated


func _is_growable_seed(node, pattern) -> bool:
	if node.freeze_length:
		return false
	if node.cut_timestamp >= 0.0:
		return false
	if not node.children.is_empty():
		return false
	if node.depth >= pattern.max_branch_depth:
		return false
	if node.length >= GrowthLimits.max_length_for_depth(node.depth):
		return false
	return true


func graft(donor_root_id: int, host_id: int, _hit_position: Vector3 = Vector3.ZERO) -> bool:
	if donor_root_id == host_id or donor_root_id == root_id:
		return false
	if not nodes.has(donor_root_id) or not nodes.has(host_id):
		return false
	if _is_ancestor(donor_root_id, host_id):
		return false

	var donor = nodes[donor_root_id]
	var old_parent_id = donor.parent_id
	if old_parent_id >= 0 and nodes.has(old_parent_id):
		nodes[old_parent_id].children.erase(donor_root_id)

	var host = nodes[host_id]
	donor.parent_id = host_id
	host.children.append(donor_root_id)

	var blended = (host.direction + donor.direction).normalized()
	donor.direction = blended
	donor.is_graft = true
	donor.is_growing_tip = true
	donor.depth = host.depth + 1
	_update_subtree_depths(donor_root_id)
	_setup_child_joint_profile(host, donor)

	adapt_after_edit()
	graph_changed.emit()
	return true


func _is_ancestor(ancestor_id: int, node_id: int) -> bool:
	var current = node_id
	while nodes.has(current):
		if current == ancestor_id:
			return true
		current = nodes[current].parent_id
	return false


func _update_subtree_depths(node_id: int) -> void:
	if not nodes.has(node_id):
		return
	var node = nodes[node_id]
	if node.parent_id >= 0:
		node.depth = nodes[node.parent_id].depth + 1
	for child_id in node.children:
		_update_subtree_depths(child_id)


func _remove_subtree(node_id: int) -> void:
	if not nodes.has(node_id):
		return
	var node = nodes[node_id]
	var children_copy = node.children.duplicate()
	for child_id in children_copy:
		_remove_subtree(child_id)
	if node.parent_id >= 0 and nodes.has(node.parent_id):
		nodes[node.parent_id].children.erase(node_id)
	nodes.erase(node_id)


func adapt_after_edit() -> void:
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if node.children.is_empty() and not node.is_growing_tip and node.cut_timestamp < 0.0:
			node.is_growing_tip = true


func get_joint(node_id: int) -> Vector3:
	var node = nodes[node_id]
	if node.parent_id < 0:
		return Vector3.ZERO
	var parent = nodes[node.parent_id]
	var parent_start: Vector3 = get_joint(node.parent_id)
	return parent_start + parent.direction.normalized() * parent.length


func get_world_tip(node_id: int) -> Vector3:
	var node = nodes[node_id]
	var start: Vector3 = get_joint(node_id)
	return start + node.direction.normalized() * node.length


func get_maturity_label() -> String:
	var branch_count = nodes.size()
	var max_depth = 0
	for node_id in nodes.keys():
		max_depth = maxi(max_depth, nodes[node_id].depth)
	if max_depth <= 1 and branch_count <= 2:
		return "Sprout"
	if max_depth <= 3 and branch_count <= 12:
		return "Young"
	return "Mature"


func get_active_tip_ids() -> Array:
	return _get_active_tip_ids()


func _get_active_tip_ids() -> Array:
	var tips: Array = []
	for node_id in nodes.keys():
		var node = nodes[node_id]
		if node.is_growing_tip:
			tips.append(node_id)
	return tips


func _enforce_active_tip_budget() -> void:
	var tips: Array = _get_active_tip_ids()
	if tips.size() <= GrowthLimits.MAX_ACTIVE_TIPS:
		return

	tips.sort_custom(func(a: int, b: int) -> bool:
		var node_a = nodes[a]
		var node_b = nodes[b]
		if node_a.depth != node_b.depth:
			return node_a.depth > node_b.depth
		return a > b
	)

	for i in range(GrowthLimits.MAX_ACTIVE_TIPS, tips.size()):
		nodes[tips[i]].is_growing_tip = false


func _is_over_height_limit() -> bool:
	return get_tree_height() >= GrowthLimits.MAX_TREE_HEIGHT


func get_tree_height() -> float:
	var max_height: float = 0.0
	for node_id in nodes.keys():
		max_height = maxf(max_height, get_world_tip(node_id).y)
	return max_height


func get_rng() -> RandomNumberGenerator:
	return _rng


func _segment_length_for_tip(tip, pattern) -> float:
	if tip.next_segment_length > 0.0:
		return tip.next_segment_length

	var base_length: float = pattern.lsystem_segment_length if pattern.use_lsystem else pattern.foliage_start_length * 2.0
	if tip.stochastic_direction and not pattern.deterministic_growth and pattern.segment_length_jitter > 0.0:
		var spread: float = pattern.segment_length_jitter
		base_length *= _rng.randf_range(1.0 - spread, 1.0 + spread)

	tip.next_segment_length = base_length
	return base_length


func _roll_growth_energy(pattern) -> float:
	if pattern.deterministic_growth or pattern.growth_energy_variance <= 0.0:
		return 1.0
	var spread: float = pattern.growth_energy_variance
	return clampf(_rng.randf_range(1.0 - spread, 1.0 + spread), 0.55, 1.45)


func to_dict() -> Dictionary:
	var node_dict = {}
	for node_id in nodes.keys():
		node_dict[str(node_id)] = nodes[node_id].to_dict()
	return {
		"species_id": species_id,
		"root_id": root_id,
		"next_id": next_id,
		"nodes": node_dict,
	}


func from_dict(data: Dictionary) -> void:
	clear()
	species_id = str(data.get("species_id", ""))
	root_id = int(data.get("root_id", -1))
	next_id = int(data.get("next_id", 0))
	var node_dict: Dictionary = data.get("nodes", {})
	for key in node_dict.keys():
		var node = BranchNodeClass.from_dict(node_dict[key])
		nodes[node.id] = node
		if node.ring_samples.is_empty():
			_init_branch_profile(node)
		else:
			_refresh_ring_sample_radii(node)
