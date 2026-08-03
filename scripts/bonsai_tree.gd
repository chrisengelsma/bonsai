extends Node3D

const TreeEditorScript = preload("res://scripts/tree/tree_editor.gd")
const RootSceneController = preload("res://scripts/roots/root_scene_controller.gd")

@onready var pot: Node3D = $Pot
@onready var renderer: Node3D = $TreeRenderer
@onready var root_renderer = $Pot/RootRenderer

var tree_editor
var _species
var _roots := RootSceneController.new()


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

	_roots.sync_tree_anchor(renderer, pot)
	_roots.release(root_renderer)
	_roots.configure(pot, GameState.tree_graph, _make_root_seed())

	root_renderer.setup(null)
	if GameState.show_roots:
		_roots.invoke_generation(root_renderer)
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
	var grow_delta: float = delta * tree_speed
	_roots.accumulate_growth(
		grow_delta,
		1.0,
		GameState.show_roots and _roots.root_graph != null
	)


func _invoke_root_generation() -> void:
	_roots.invoke_generation(root_renderer)


func _release_root_graph() -> void:
	_roots.release(root_renderer)


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
