extends Node3D

const TreeEditorScript = preload("res://scripts/tree/tree_editor.gd")
const RootGraphScript = preload("res://scripts/roots/root_graph.gd")

@onready var pot: Node3D = $Pot
@onready var renderer: Node3D = $TreeRenderer
@onready var root_renderer = $Pot/RootRenderer

var tree_editor
var _species
var _root_graph
var _root_growth_seconds: float = 0.0
var _root_generation_seed: int = 0
var _root_field
var _root_anchor: Vector3 = Vector3.ZERO
var _root_spawn_radius: float = 0.014


func _ready() -> void:
	tree_editor = TreeEditorScript.new()
	tree_editor.name = "TreeEditor"
	add_child(tree_editor)

	GameState.species_changed.connect(_on_species_changed)
	GameState.graph_changed.connect(_on_graph_changed)
	GameState.roots_visibility_changed.connect(_on_roots_visibility_changed)

	if tree_editor:
		tree_editor.branch_selected.connect(_on_branch_edited)

	SaveManager.clear_save()
	GameState.initialize_new_tree()
	_apply_state()


func _apply_state() -> void:
	if GameState.species:
		_on_species_changed(GameState.species)


func _on_species_changed(new_species) -> void:
	_species = new_species
	if GameState.tree_graph:
		renderer.setup(GameState.tree_graph, _species)
		tree_editor.setup(GameState.tree_graph, renderer)
	_configure_roots()


func _configure_roots() -> void:
	if root_renderer == null or pot == null:
		return

	_sync_tree_anchor()
	_release_root_graph()

	_root_growth_seconds = 0.0
	_root_generation_seed = _make_root_seed()
	_root_anchor = pot.get_root_anchor()
	_root_spawn_radius = _get_root_spawn_radius()
	if pot.has_method("get_growth_field"):
		_root_field = pot.get_growth_field()
	elif pot.has_method("get_bounds"):
		_root_field = pot.get_bounds()
	else:
		_root_field = null

	root_renderer.setup(null)
	if GameState.show_roots:
		_invoke_root_generation()
	else:
		root_renderer.set_show_roots(false)


func _accumulate_root_growth_time(delta: float) -> void:
	if GameState.config == null or GameState.tree_graph == null or GameState.is_watering():
		return
	if GameState.moisture < GameState.config.growth_threshold:
		return

	var soil = CatalogRegistry.get_equipped_soil()
	var soil_mult: float = soil.growth_mult if soil else 1.0
	var tree_speed: float = GameState.grow_speed_multiplier * soil_mult
	_root_growth_seconds += delta * tree_speed * RootGraphScript.TREE_SPEED_RATIO


func _invoke_root_generation() -> void:
	if _root_field == null or root_renderer == null:
		return

	_release_root_graph()

	_root_graph = RootGraphScript.new()
	_root_graph.setup(_root_field, _root_anchor, _root_spawn_radius, _root_generation_seed)
	_root_graph.generate_for_elapsed(_root_growth_seconds, 1.0)

	root_renderer.setup(_root_graph)
	root_renderer.set_show_roots(true)


func _release_root_graph() -> void:
	if _root_graph != null and root_renderer != null:
		root_renderer.setup(null)
	_root_graph = null


func _apply_roots_visibility() -> void:
	if GameState.show_roots:
		_invoke_root_generation()
	else:
		_release_root_graph()
		if root_renderer:
			root_renderer.set_show_roots(false)


func _on_roots_visibility_changed(enabled: bool) -> void:
	if enabled:
		_invoke_root_generation()
	else:
		_release_root_graph()
		if root_renderer:
			root_renderer.set_show_roots(false)


func _make_root_seed() -> int:
	if GameState.species:
		return int(hash(GameState.species.id))
	return randi()


func _get_root_spawn_radius() -> float:
	if GameState.tree_graph and GameState.tree_graph.has_method("get_trunk_base_spawn_radius"):
		return GameState.tree_graph.get_trunk_base_spawn_radius()
	return 0.014


func _sync_tree_anchor() -> void:
	if renderer == null or pot == null or not pot.has_method("get_tree_anchor_height"):
		return
	renderer.position.y = pot.get_tree_anchor_height()


func _process(delta: float) -> void:
	_accumulate_root_growth_time(delta)


func _on_graph_changed() -> void:
	if GameState.tree_graph and _species and renderer:
		renderer.rebuild()


func set_soil_moisture(value: float) -> void:
	var soil := pot.get_node_or_null("Soil")
	if soil and soil.has_method("set_moisture"):
		soil.set_moisture(value)


func play_happy_bounce() -> void:
	if renderer and renderer.has_method("play_happy_bounce"):
		renderer.play_happy_bounce()


func _on_branch_edited(_branch_id: int) -> void:
	SaveManager.save_game(GameState.build_save_data())
	if renderer:
		renderer.rebuild()
