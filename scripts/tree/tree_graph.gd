class_name TreeGraph
extends RefCounted

const BranchNodeClass = preload("res://scripts/tree/branch_node.gd")
const LSystemInterpreter = preload("res://scripts/tree/lsystem_interpreter.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const SpatialGrowth = preload("res://scripts/tree/spatial_growth.gd")
const BranchMeshBuilder = preload("res://scripts/tree/branch_mesh_builder.gd")

signal graph_changed

var nodes: Dictionary = {}
var root_id: int = -1
var next_id: int = 0
var species_id: String = ""
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func clear() -> void:
	nodes.clear()
	root_id = -1
	next_id = 0


func create_from_species(species) -> void:
	clear()
	species_id = species.id
	if species.starter_graph.is_empty():
		_create_default_starter(species)
	else:
		from_dict(species.starter_graph)


func _create_default_starter(species) -> void:
	var pattern = species.grow_pattern
	var root = _create_node(-1, Vector3.UP, pattern.trunk_thickness, 0)
	root.length = 0.04
	root.is_growing_tip = true
	root.lsymbol = pattern.lsystem_axiom if pattern.use_lsystem else "T"
	var root_spin: float = _rng.randf_range(0.0, TAU)
	root.turtle_up = Vector3.FORWARD.rotated(Vector3.UP, root_spin).normalized()
	root.growth_energy = _roll_growth_energy(pattern)
	root_id = root.id


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
	_enforce_active_tip_budget()
	var over_height: bool = _is_over_height_limit()

	var now = Time.get_ticks_msec() / 1000.0
	_process_regrowth(now, pattern, delta)

	var tip_ids = _get_active_tip_ids()
	for tip_id in tip_ids:
		var tip = nodes[tip_id]
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

		if pattern.gravity_curve != 0.0:
			var gravity = Vector3(0.0, -pattern.gravity_curve * delta, 0.0)
			tip.direction = (tip.direction + gravity).normalized()

		if tip.length >= pattern.foliage_start_length:
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
	turtle_up: Vector3 = Vector3.FORWARD
):
	var parent = nodes[parent_id]
	if not GrowthLimits.can_add_node(nodes.size()):
		return null
	if parent.children.size() >= pattern.max_children_per_node:
		return null
	if parent.depth >= pattern.max_branch_depth:
		return null

	var thickness: float = parent.thickness * pattern.thickness_falloff
	if thickness < pattern.branch_thickness:
		thickness = pattern.branch_thickness

	var child = _create_node(parent_id, direction, thickness, parent.depth + 1)
	child.base_thickness = thickness
	child.length = 0.02
	child.is_growing_tip = true
	child.lsymbol = lsymbol
	child.length_at_last_production = child.length
	child.turtle_up = turtle_up.normalized()
	child.growth_energy = _roll_growth_energy(pattern)
	parent.is_growing_tip = false
	return child


func _bud_child_random(parent_id: int, pattern) -> void:
	var parent = nodes[parent_id]
	var angle_deg = _rng.randf_range(pattern.branch_angle_range.x, pattern.branch_angle_range.y)
	if _rng.randf() > 0.5:
		angle_deg = -angle_deg
	var axis = parent.direction.cross(Vector3.UP)
	if axis.length_squared() < 0.001:
		axis = Vector3.RIGHT
	var child_dir = parent.direction.rotated(axis.normalized(), deg_to_rad(angle_deg)).normalized()
	bud_lsystem_child(parent_id, child_dir, "S", pattern)


func _init_branch_profile(node) -> void:
	if not node.ring_samples.is_empty() and not node.locked_wobble.is_empty():
		return

	node.base_thickness = node.thickness
	node.cambium_thickness = 0.0
	node.locked_wobble = BranchMeshBuilder.generate_locked_wobble(node.id, 10, 0.11)
	node.last_ring_sample_dist = 0.0
	node.last_profile_direction = node.direction.normalized()
	node.ring_samples = [
		{
			"dist": 0.0,
			"dir": node.last_profile_direction,
			"r": node.thickness,
		},
		{
			"dist": maxf(node.length, 0.02),
			"dir": node.last_profile_direction,
			"r": node.thickness * 0.94,
		},
	]


func _radius_at_dist(node, dist: float) -> float:
	var length: float = maxf(node.length, 0.02)
	var t: float = clampf(dist / length, 0.0, 1.0)
	var total_radius: float = node.base_thickness + node.cambium_thickness
	return total_radius * lerpf(0.84, 1.0, t)


func _append_frozen_sample(node, dist: float, direction: Vector3) -> void:
	var frozen_dir: Vector3 = direction.normalized()
	if not node.ring_samples.is_empty():
		var last_sample: Dictionary = node.ring_samples[-1]
		var last_dist: float = float(last_sample.get("dist", -1.0))
		var last_dir: Vector3 = last_sample.get("dir", Vector3.UP)
		if absf(last_dist - dist) < 0.001 and last_dir.angle_to(frozen_dir) < deg_to_rad(0.5):
			last_sample["r"] = _radius_at_dist(node, dist)
			return

	node.ring_samples.append({
		"dist": dist,
		"dir": frozen_dir,
		"r": _radius_at_dist(node, dist),
	})


func _extend_tip_sample(node) -> void:
	if node.ring_samples.is_empty():
		return

	var tip_dist: float = maxf(node.length, 0.02)
	var last_sample: Dictionary = node.ring_samples[-1]
	var last_dist: float = float(last_sample.get("dist", 0.0))
	var last_dir: Vector3 = last_sample.get("dir", Vector3.UP)

	if absf(last_dist - tip_dist) < 0.001 and last_dir.angle_to(node.last_profile_direction) < deg_to_rad(0.5):
		last_sample["r"] = _radius_at_dist(node, tip_dist)
		return

	_append_frozen_sample(node, tip_dist, node.last_profile_direction)


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
		_append_frozen_sample(node, node.length, node.last_profile_direction)
	else:
		_extend_tip_sample(node)

	_refresh_ring_sample_radii(node)


func ensure_profile_render_ready(node) -> void:
	if node.ring_samples.is_empty() or node.locked_wobble.is_empty():
		_init_branch_profile(node)
	elif node.ring_samples.size() < 2:
		_append_frozen_sample(node, maxf(node.length, 0.02), node.last_profile_direction)
	else:
		_extend_tip_sample(node)
	_refresh_ring_sample_radii(node)


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
		_refresh_ring_sample_radii(node)

		if node.parent_id < 0:
			break
		current_id = node.parent_id


func _max_radius_for_node(node, pattern) -> float:
	var target: float = pattern.trunk_thickness if node.depth == 0 else pattern.branch_thickness
	return target * (1.0 + node.age * 0.05) + node.cambium_thickness * 0.35


func _refresh_ring_sample_radii(node) -> void:
	var total_radius: float = node.base_thickness + node.cambium_thickness
	var length: float = maxf(node.length, 0.02)
	for sample in node.ring_samples:
		if sample is Dictionary:
			var t: float = float(sample.get("dist", 0.0)) / length
			sample["r"] = total_radius * lerpf(0.84, 1.0, t)


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
	if parent.ring_samples.size() >= 2:
		return parent_start + BranchMeshBuilder.get_profile_tip_offset(parent.ring_samples)
	return parent_start + parent.direction * parent.length


func get_world_tip(node_id: int) -> Vector3:
	var node = nodes[node_id]
	var start: Vector3 = get_joint(node_id)
	if node.ring_samples.size() >= 2:
		return start + BranchMeshBuilder.get_profile_tip_offset(node.ring_samples)
	return start + node.direction * node.length


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
	if pattern.segment_length_jitter > 0.0:
		var spread: float = pattern.segment_length_jitter
		base_length *= _rng.randf_range(1.0 - spread, 1.0 + spread)

	tip.next_segment_length = base_length
	return base_length


func _roll_growth_energy(pattern) -> float:
	if pattern.growth_energy_variance <= 0.0:
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
