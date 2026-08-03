extends SceneTree

const LSystemModel = preload("res://scripts/lsystem/lsystem_model.gd")
const LSystemParams = preload("res://scripts/lsystem/lsystem_params.gd")

func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(_test_single_seed_at_origin())
	failures.append_array(_test_parallel_binary_split())
	failures.append_array(_test_linear_chain())
	failures.append_array(_test_segments_connect_to_seed())

	if failures.is_empty():
		print("ALL CHECKS PASSED (L-system model)")
	else:
		for failure in failures:
			print("FAIL: ", failure)
	quit(1 if not failures.is_empty() else 0)


func _make_params(
	axiom: String,
	rules: String,
	angle: float = 28.0,
	segment_length: float = 0.1,
	max_depth: int = 5
) -> LSystemParams:
	var params := LSystemParams.new()
	params.axiom = axiom
	params.rules_text = rules
	params.angle_deg = angle
	params.segment_length = segment_length
	params.iterations = max_depth
	params.max_children = 4
	params.deterministic = true
	params.clamp_values()
	return params


func _make_model(params, seed: int = 12345):
	var model = LSystemModel.new()
	model.setup(params, seed)
	return model


func _grow_to_completion(model) -> void:
	var safety := 0
	while not model.is_complete() and safety < 8000:
		safety += 1
		model.grow(0.05, 8.0)


func _grow_one_production(model) -> void:
	var safety := 0
	var start_count: int = model.production_count
	while model.production_count == start_count and safety < 500:
		safety += 1
		model.grow(0.05, 8.0)
		if model.is_complete():
			return


func _test_single_seed_at_origin() -> Array[String]:
	var params = _make_params("A", "A=F", 0.0, 0.1, 3)
	var model = _make_model(params)
	_grow_one_production(model)

	var failures: Array[String] = []
	if model.get_seed_position() != Vector3.ZERO:
		failures.append("seed should be at origin")
	if model.segments.is_empty():
		failures.append("expected at least one segment")
	elif model.segments[0].from != Vector3.ZERO:
		failures.append("first segment should start at seed")
	return failures


func _test_parallel_binary_split() -> Array[String]:
	var params = _make_params("T", "T=F[+S][-S]\nS=F", 90.0, 0.1, 4)
	var model = _make_model(params)
	_grow_one_production(model)

	var failures: Array[String] = []
	if model.production_count != 1:
		failures.append("expected 1 production, got %d" % model.production_count)
	if model.active_tip_count() != 3:
		failures.append("expected 3 active tips after split, got %d" % model.active_tip_count())
	return failures


func _test_linear_chain() -> Array[String]:
	var params = _make_params("A", "A=F", 0.0, 0.1, 4)
	var model = _make_model(params)
	_grow_to_completion(model)

	var failures: Array[String] = []
	if model.segments.size() < 3:
		failures.append("linear chain expected multiple segments, got %d" % model.segments.size())
	elif model.segments[0].from != Vector3.ZERO:
		failures.append("linear chain should start at seed")
	elif model.segments[model.segments.size() - 1].to.y < 0.25:
		failures.append("linear chain too short: %.3f" % model.segments[model.segments.size() - 1].to.y)
	return failures


func _test_segments_connect_to_seed() -> Array[String]:
	var params = _make_params("T", "T=F[+S][-S]\nS=F", 45.0, 0.1, 3)
	var model = _make_model(params)
	_grow_to_completion(model)

	var failures: Array[String] = []
	var nodes: Dictionary = {Vector3.ZERO: true}
	for segment in model.segments:
		var start: Vector3 = segment.from
		var end: Vector3 = segment.to
		if not _is_near_existing_node(nodes, start):
			failures.append("dangling segment start at %s" % start)
		nodes[end] = true

	if model.segments.is_empty():
		failures.append("expected connected skeleton segments")
	return failures


func _is_near_existing_node(nodes: Dictionary, point: Vector3, epsilon: float = 0.02) -> bool:
	for node in nodes.keys():
		if node.distance_to(point) <= epsilon:
			return true
	return false
