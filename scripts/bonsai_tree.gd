extends Node3D

const TreeEditorScript = preload("res://scripts/tree/tree_editor.gd")

@onready var pot: Node3D = $Pot
@onready var renderer: Node3D = $TreeRenderer

var tree_editor
var _species


func _ready() -> void:
	tree_editor = TreeEditorScript.new()
	tree_editor.name = "TreeEditor"
	add_child(tree_editor)

	GameState.species_changed.connect(_on_species_changed)
	GameState.graph_changed.connect(_on_graph_changed)

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
