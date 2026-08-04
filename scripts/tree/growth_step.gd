class_name GrowthStep
extends RefCounted

const LSystemInterpreter = preload("res://scripts/tree/lsystem_interpreter.gd")
const AxialChain = preload("res://scripts/tree/axial_chain.gd")
const MeshConstants = preload("res://scripts/util/mesh_constants.gd")
const DeadLeafModel = preload("res://scripts/tree/dead_leaf_model.gd")
const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")


static func process_active_tips(graph, pattern, options: Dictionary) -> void:
	var mode: String = str(options.get("mode", "continuous"))
	var over_height: bool = bool(options.get("over_height", false))
	var delta: float = float(options.get("delta", 0.0))
	var speed_mult: float = float(options.get("speed_mult", 1.0))
	var soil_mult: float = float(options.get("soil_mult", 1.0))
	var moisture_factor: float = float(options.get("moisture_factor", 1.0))
	var cambium_delta: float = float(options.get("cambium_delta", delta))

	for tip_id in graph._get_active_tip_ids():
		var tip = graph.nodes[tip_id]
		if tip.freeze_length:
			continue
		if over_height:
			tip.is_growing_tip = false
			continue
		if tip.depth >= pattern.max_branch_depth and mode == "lab_step":
			tip.is_growing_tip = false
			continue

		var remaining: float = AxialChain.remaining_budget(graph.nodes, tip_id)
		if remaining <= MeshConstants.DIST_EPSILON:
			tip.is_growing_tip = false
			continue

		var segment_length: float = graph._segment_length_for_tip(tip, pattern)
		var segment_cap: float = tip.length_at_last_production + segment_length
		var max_length: float = minf(tip.length + remaining, segment_cap)

		if mode == "lab_step":
			var since_production: float = tip.length - tip.length_at_last_production
			var growth_needed: float = maxf(segment_length - since_production, segment_length * 0.25)
			var lab_mult: float = graph.get_tip_growth_multiplier(tip_id, pattern) if pattern.use_auxin else 1.0
			tip.length = minf(tip.length + growth_needed * speed_mult * lab_mult, max_length)
		else:
			if tip.length >= max_length:
				tip.is_growing_tip = false
				continue
			tip.age += delta
			var growth_amount: float = pattern.tip_growth_rate * delta * speed_mult * soil_mult * moisture_factor * tip.growth_energy
			if pattern.use_auxin:
				growth_amount *= graph.get_tip_growth_multiplier(tip_id, pattern)
			tip.length = minf(tip.length + growth_amount, max_length)

		if pattern.gravity_curve != 0.0 and tip.stochastic_direction:
			var gravity_strength: float = pattern.gravity_curve * (0.05 if mode == "lab_step" else delta)
			var gravity := Vector3(0.0, -gravity_strength, 0.0)
			tip.direction = (tip.direction + gravity).normalized()

		if pattern.use_space_colonization:
			var field = options.get("attractor_field")
			if field != null:
				var tip_pos: Vector3 = graph.get_world_tip(tip_id)
				var attract_dir: Vector3 = field.attraction_direction_for_tip(tip_id, tip_pos, graph)
				if attract_dir.length_squared() > 0.0001:
					var colon_strength: float = pattern.colonization_strength * (0.05 if mode == "lab_step" else delta)
					tip.direction = (tip.direction + attract_dir * colon_strength).normalized()
				field.consume_near(tip_pos, pattern.colonization_kill_distance)

		if mode == "continuous" and FoliagePreset.has_foliage_growth(graph.species if graph != null else null, pattern) and tip.length >= pattern.foliage_start_length:
			tip.foliage_amount = minf(1.0, tip.foliage_amount + pattern.foliage_growth_rate * delta)
			DeadLeafModel.try_spawn_dead_leaf(graph, pattern, delta, graph._rng)
		elif mode == "lab_step" and FoliagePreset.has_foliage_growth(graph.species if graph != null else null, pattern) and tip.length >= pattern.foliage_start_length:
			tip.foliage_amount = minf(1.0, tip.foliage_amount + pattern.foliage_growth_rate * 0.2)

		graph._accumulate_cambium_on_path(tip_id, cambium_delta * moisture_factor, pattern)
		graph._update_branch_profile(tip, pattern)

		var production_threshold: float = segment_length
		if mode == "lab_step":
			production_threshold = segment_length * 0.98
		if tip.length - tip.length_at_last_production >= production_threshold:
			if pattern.use_lsystem:
				LSystemInterpreter.apply_at_tip(graph, tip_id, pattern)
			elif graph._should_random_bud(tip, pattern, 1.0 if mode == "lab_step" else delta):
				graph._bud_child_random(tip_id, pattern)
			tip.next_segment_length = -1.0
