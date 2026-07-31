extends Node3D

const TreeGraphScript = preload("res://scripts/tree/tree_graph.gd")
const TreeSpeciesScript = preload("res://scripts/catalog/tree_species.gd")
const LSystemPresets = preload("res://scripts/lab/lsystem_presets.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")

@onready var renderer: Node3D = $LabTree/TreeRenderer
@onready var panel: Control = $UI/LSystemLabPanel
@onready var orbit_camera: Node3D = $OrbitCamera

var _graph
var _species
var _pattern
var _grow_speed: float = 5.0
var _current_preset: int = 0


func _ready() -> void:
	_species = TreeSpeciesScript.new()
	_species.id = "lab"
	_species.display_name = "L-System Lab"
	_species.trunk_color = Color(0.55, 0.35, 0.2)
	_species.foliage_color = Color(0.42, 0.56, 0.44)

	panel.preset_selected.connect(_on_preset_selected)
	panel.apply_pressed.connect(_on_apply_pressed)
	panel.reset_tree_pressed.connect(_on_reset_tree_pressed)
	panel.grow_speed_changed.connect(_on_grow_speed_changed)
	panel.main_menu_pressed.connect(_go_main_menu)

	_apply_preset(0, true)


func _process(delta: float) -> void:
	if _graph and _pattern:
		_graph.grow(delta, _pattern, true, _grow_speed, 1.0)
		_update_camera_focus()


func _update_camera_focus() -> void:
	if _graph == null or orbit_camera == null:
		return

	var max_height: float = 0.0
	for node_id in _graph.nodes.keys():
		var tip_y: float = _graph.get_world_tip(node_id).y
		max_height = maxf(max_height, tip_y)

	if orbit_camera:
		orbit_camera.look_target_height = clampf(max_height * 0.45, 0.2, 4.0)


func _apply_preset(index: int, reset_tree: bool) -> void:
	_current_preset = index
	_pattern = LSystemPresets.load_preset(index)
	GrowthLimits.clamp_pattern(_pattern)
	_species.grow_pattern = _pattern
	panel.sync_from_pattern(_pattern, index)
	if reset_tree:
		_reset_tree()


func _on_preset_selected(index: int) -> void:
	_apply_preset(index, true)


func _on_apply_pressed(params: Dictionary) -> void:
	_apply_params(params)
	_reset_tree()


func _on_reset_tree_pressed() -> void:
	_reset_tree()


func _on_grow_speed_changed(value: float) -> void:
	_grow_speed = GrowthLimits.clamp_lab_grow_speed(value)


func _apply_params(params: Dictionary) -> void:
	_pattern.lsystem_axiom = str(params.get("axiom", "T"))
	_pattern.lsystem_rules_text = str(params.get("rules", ""))
	_pattern.lsystem_angle_deg = float(params.get("angle", 28.0))
	_pattern.lsystem_segment_length = float(params.get("segment_length", 0.1))
	_pattern.tip_growth_rate = float(params.get("growth_rate", 0.03))
	_pattern.gravity_curve = float(params.get("gravity", 0.0))
	_pattern.max_branch_depth = int(params.get("max_depth", 5))
	_pattern.max_children_per_node = int(params.get("max_children", 2))
	GrowthLimits.clamp_pattern(_pattern)
	_pattern.invalidate_rules_cache()
	_species.grow_pattern = _pattern


func _reset_tree() -> void:
	if _graph and _graph.graph_changed.is_connected(_on_graph_changed):
		_graph.graph_changed.disconnect(_on_graph_changed)

	_graph = TreeGraphScript.new()
	_graph.graph_changed.connect(_on_graph_changed)
	_graph.create_from_species(_species)
	renderer.setup(_graph, _species)


func _on_graph_changed() -> void:
	if renderer:
		renderer.rebuild()


func _go_main_menu() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")
