class_name RootSceneController
extends RefCounted

const RootGraphScript = preload("res://scripts/roots/root_graph.gd")

const BOOTSTRAP_SECONDS := 3.0

var root_graph
var growth_seconds: float = 0.0
var generation_seed: int = 0
var field
var anchor: Vector3 = Vector3.ZERO
var spawn_radius: float = 0.014


func configure(pot: Node3D, tree_graph, generation_seed_value: int) -> void:
	growth_seconds = 0.0
	generation_seed = generation_seed_value
	anchor = pot.get_root_anchor() if pot.has_method("get_root_anchor") else Vector3.ZERO
	spawn_radius = _spawn_radius_from_tree(tree_graph)
	if pot.has_method("get_growth_field"):
		field = pot.get_growth_field()
	elif pot.has_method("get_bounds"):
		field = pot.get_bounds()
	else:
		field = null


func accumulate_growth(delta: float, speed_mult: float, should_grow: bool) -> void:
	var grow_delta: float = delta * speed_mult
	growth_seconds += grow_delta * RootGraphScript.TREE_SPEED_RATIO
	if should_grow and root_graph != null:
		root_graph.grow(grow_delta, 1.0)


func invoke_generation(root_renderer) -> void:
	if field == null or root_renderer == null:
		return

	release(root_renderer)

	root_graph = RootGraphScript.new()
	root_graph.setup(field, anchor, spawn_radius, generation_seed)
	var elapsed: float = maxf(growth_seconds, BOOTSTRAP_SECONDS)
	root_graph.generate_for_elapsed(elapsed, 1.0)

	root_renderer.setup(root_graph)
	root_renderer.set_show_roots(true)


func release(root_renderer) -> void:
	if root_graph != null and root_renderer != null:
		root_renderer.setup(null)
	root_graph = null


func sync_tree_anchor(renderer: Node3D, pot: Node3D) -> void:
	if renderer == null or pot == null or not pot.has_method("get_tree_anchor_height"):
		return
	renderer.position.y = pot.get_tree_anchor_height()


static func _spawn_radius_from_tree(tree_graph) -> float:
	if tree_graph and tree_graph.has_method("get_trunk_base_spawn_radius"):
		return tree_graph.get_trunk_base_spawn_radius()
	return 0.014
