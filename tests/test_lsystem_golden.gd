extends SceneTree

const Harness = preload("res://tests/lsystem_test_harness.gd")
const LSystemInterpreter = preload("res://scripts/tree/lsystem_interpreter.gd")

func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(_test_binary_split_first_production())
	failures.append_array(_test_classic_upright_first_production())
	failures.append_array(_test_linear_chain_two_productions())
	failures.append_array(_test_interpreter_spawn_counts())
	failures.append_array(_test_symbol_preserved_on_continuation())

	if failures.is_empty():
		print("ALL CHECKS PASSED (L-system golden)")
	else:
		for failure in failures:
			print("FAIL: ", failure)
	quit(1 if not failures.is_empty() else 0)

func _test_binary_split_first_production() -> Array[String]:
	var pattern = Harness.make_pattern(
		"T",
		"T=F[+S][-S]\nS=F",
		90.0,
		0.1,
		4
	)
	var graph = Harness.make_graph(pattern)
	Harness.apply_production_at_root(graph, pattern)

	var failures: Array[String] = []
	var expected := """0|p-1|d0|T|0.000|1.000|0.000|c1,2,3|g0|f1
1|p0|d1|S|0.848|0.530|0.000|c|g1|f0
2|p0|d1|S|-0.848|0.530|0.000|c|g1|f0
3|p0|d0|T|0.000|1.000|0.000|c|g1|f0"""
	if Harness.topology_fingerprint(graph) != expected:
		failures.append("binary split topology mismatch")

	if Harness.count_nodes_at_depth(graph, 1) != 2:
		failures.append("binary split expected 2 depth-1 nodes")
	if graph.nodes[graph.root_id].freeze_length != true:
		failures.append("binary split root should freeze after continuation")
	if graph.nodes[3].lsymbol != "T":
		failures.append("binary split continuation should preserve symbol T")
	return failures

func _test_classic_upright_first_production() -> Array[String]:
	var pattern = Harness.make_pattern(
		"T",
		"T=F[+S][-S][&S]\nS=F[+T][-T][^T]\nF=F",
		28.0,
		0.1,
		5
	)
	var graph = Harness.make_graph(pattern)
	Harness.apply_production_at_root(graph, pattern)

	var failures: Array[String] = []
	if graph.nodes.size() != 5:
		failures.append("classic upright expected 5 nodes after first production, got %d" % graph.nodes.size())
	if Harness.count_nodes_at_depth(graph, 1) != 3:
		failures.append("classic upright expected 3 primary branches")
	if graph.nodes[4].depth != 0:
		failures.append("classic upright continuation should stay at depth 0")
	if graph.nodes[4].lsymbol != "T":
		failures.append("classic upright continuation should keep symbol T")

	var expected := """0|p-1|d0|T|0.000|1.000|0.000|c1,2,3,4|g0|f1
1|p0|d1|S|0.469|0.883|0.000|c|g1|f0
2|p0|d1|S|-0.469|0.883|0.000|c|g1|f0
3|p0|d1|S|0.000|0.883|0.469|c|g1|f0
4|p0|d0|T|0.000|1.000|0.000|c|g1|f0"""
	if Harness.topology_fingerprint(graph) != expected:
		failures.append("classic upright topology mismatch")
	return failures

func _test_linear_chain_two_productions() -> Array[String]:
	var pattern = Harness.make_pattern(
		"A",
		"A=F",
		0.0,
		0.1,
		3
	)
	var graph = Harness.make_graph(pattern)
	Harness.grow_until_productions(graph, pattern, 2)

	var failures: Array[String] = []
	if graph.nodes.size() != 3:
		failures.append("linear chain expected 3 nodes, got %d" % graph.nodes.size())
	if Harness.count_nodes_at_depth(graph, 0) != 3:
		failures.append("linear chain expected 3 depth-0 nodes")
	var tips: Array = Harness.tip_world_positions(graph)
	if tips.size() != 1:
		failures.append("linear chain expected 1 active tip")
	elif tips[0].y < 0.28:
		failures.append("linear chain tip too short: %.3f" % tips[0].y)
	return failures

func _test_interpreter_spawn_counts() -> Array[String]:
	var pattern = Harness.make_pattern(
		"T",
		"T=F[+S][-S][&S]\nS=F",
		45.0,
		0.1,
		5
	)
	var graph = Harness.make_graph(pattern)
	var root_id: int = graph.root_id
	var root = graph.nodes[root_id]
	root.length = 0.1
	root.length_at_last_production = 0.0

	LSystemInterpreter.apply_at_tip(graph, root_id, pattern)

	var failures: Array[String] = []
	if root.children.size() != 4:
		failures.append("interpreter expected 4 children (3 lateral + continuation), got %d" % root.children.size())

	var lateral := 0
	var continuation := 0
	for child_id in root.children:
		var child = graph.nodes[child_id]
		if child.depth == root.depth:
			continuation += 1
		else:
			lateral += 1
	if lateral != 3:
		failures.append("interpreter expected 3 lateral children, got %d" % lateral)
	if continuation != 1:
		failures.append("interpreter expected 1 continuation child, got %d" % continuation)
	return failures

func _test_symbol_preserved_on_continuation() -> Array[String]:
	var pattern = Harness.make_pattern(
		"S",
		"S=FF",
		0.0,
		0.1,
		4
	)
	var graph = Harness.make_graph(pattern)
	var tip_id: int = graph.root_id
	graph.nodes[tip_id].lsymbol = "S"
	graph.nodes[tip_id].length = 0.1
	graph.nodes[tip_id].length_at_last_production = 0.0

	LSystemInterpreter.apply_at_tip(graph, tip_id, pattern)

	var failures: Array[String] = []
	var continuation_id := -1
	for child_id in graph.nodes[tip_id].children:
		if graph.nodes[child_id].depth == graph.nodes[tip_id].depth:
			continuation_id = child_id
	if continuation_id < 0:
		failures.append("continuation child not created")
	elif graph.nodes[continuation_id].lsymbol != "S":
		failures.append("continuation should preserve symbol S, got %s" % graph.nodes[continuation_id].lsymbol)
	return failures
