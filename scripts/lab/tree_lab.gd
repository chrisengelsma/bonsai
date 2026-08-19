extends Node3D

const TreeGraph = preload("res://scripts/tree/tree_graph.gd")
const LSystemParams = preload("res://scripts/lsystem/lsystem_params.gd")
const LSystemPresets = preload("res://scripts/lab/lsystem_presets.gd")

@onready var renderer: Node3D = $LabTree/TreeRenderer
@onready var panel: Control = $UI/TreeLabPanel

var _graph := TreeGraph.new()
var _pattern: GrowPattern
var _params: LSystemParams
var _species
var _grow_speed: float = 3.0
var _random_factor: float = 0.0
var _current_preset: int = 0
var _auto_grow: bool = true
var _tool_mode: int = 0


func _ready() -> void:
	_species = LSystemPresets.species_for_preset(0)

	panel.preset_selected.connect(_on_preset_selected)
	panel.apply_pressed.connect(_on_apply_pressed)
	panel.reset_pressed.connect(_on_reset_pressed)
	panel.grow_speed_changed.connect(_on_grow_speed_changed)
	panel.random_factor_changed.connect(_on_random_factor_changed)
	panel.auxin_changed.connect(_on_auxin_changed)
	panel.tool_mode_changed.connect(_on_tool_mode_changed)
	panel.display_changed.connect(_on_display_changed)
	panel.foliage_changed.connect(_on_foliage_changed)
	panel.camera_distance_changed.connect(_on_camera_distance_changed)
	panel.grow_step_pressed.connect(_on_grow_step_pressed)
	panel.main_menu_pressed.connect(_go_main_menu)
	panel.leaf_lab_pressed.connect(_go_leaf_lab)
	panel.colonization_changed.connect(_on_colonization_changed)
	panel.reseed_attractors_pressed.connect(_on_reseed_attractors_pressed)
	panel.caudex_arc_count_changed.connect(_on_caudex_arc_count_changed)
	panel.caudex_height_changed.connect(_on_caudex_height_changed)
	panel.caudex_spread_changed.connect(_on_caudex_spread_changed)

	if not _graph.graph_changed.is_connected(_on_graph_changed):
		_graph.graph_changed.connect(_on_graph_changed)

	renderer.setup(_graph, _species)
	renderer.branch_clicked.connect(_on_branch_clicked)
	_apply_display_settings()
	_sync_camera_panel()
	_apply_preset(0, true)


func _process(delta: float) -> void:
	if not _auto_grow or _params == null:
		return
	_graph.grow(delta, _pattern, 1.0, _grow_speed, 1.0)
	_update_camera_focus()


func _on_graph_changed() -> void:
	if renderer != null:
		renderer.rebuild()


func _apply_preset(index: int, reset_tree: bool) -> void:
	_current_preset = index
	_species = LSystemPresets.species_for_preset(index)
	_pattern = LSystemPresets.pattern_for_preset(index).duplicate()
	_params = LSystemPresets.load_preset(index)
	if _species == null or _params == null or _pattern == null:
		push_error("Tree Lab failed to load preset %d" % index)
		return
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	panel.sync_from_params(_params, index, _random_factor, _pattern)
	renderer.setup(_graph, _species)
	_apply_renderer_mesh_mode_for_preset(index)
	_apply_display_settings()
	if reset_tree:
		_reset_tree()


func _sync_pattern_from_params() -> void:
	if _params == null:
		return
	_params.apply_to_grow_pattern(_pattern)
	GrowthLimits.clamp_pattern(_pattern)


func _apply_foliage_from_params() -> void:
	if _params == null or _species == null:
		return
	_params.apply_foliage_to_preset(_species.foliage)
	_params.apply_foliage_timing_to_pattern(_pattern)


func _apply_random_factor() -> void:
	if _params == null:
		return
	_params.apply_random_factor(_random_factor)


func _on_preset_selected(index: int) -> void:
	_apply_preset(index, true)


func _on_apply_pressed(params: LSystemParams) -> void:
	_params = params.duplicate_params()
	_apply_random_factor()
	_params.clamp_values()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	panel.sync_from_params(_params, _current_preset, _random_factor, _pattern)
	_reset_tree()


func _on_reset_pressed() -> void:
	_reset_tree()


func _on_grow_speed_changed(value: float) -> void:
	_grow_speed = GrowthLimits.clamp_lab_grow_speed(value)


func _on_random_factor_changed(value: float) -> void:
	_random_factor = value
	if _params == null:
		return
	_params = panel.collect_params()
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	panel.sync_from_params(_params, _current_preset, _random_factor, _pattern)


func _on_auxin_changed() -> void:
	_params = panel.collect_params()
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()


func _on_foliage_changed() -> void:
	_params = panel.collect_params()
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	renderer.setup(_graph, _species)
	renderer.rebuild()


func _on_tool_mode_changed(mode: int) -> void:
	_tool_mode = mode
	var prune_hover: bool = mode != panel.ToolMode.VIEW
	if renderer.has_method("set_prune_hover_enabled"):
		renderer.set_prune_hover_enabled(prune_hover)


func _on_display_changed() -> void:
	_apply_display_settings()


func _on_camera_distance_changed(value: float) -> void:
	var orbit_camera: Node3D = get_node_or_null("OrbitCamera")
	if orbit_camera != null and orbit_camera.has_method("set_camera_distance"):
		orbit_camera.set_camera_distance(value)


func _sync_camera_panel() -> void:
	var orbit_camera: Node3D = get_node_or_null("OrbitCamera")
	if orbit_camera == null:
		return
	panel.sync_camera_distance(
		orbit_camera.get_camera_distance(),
		orbit_camera.min_distance,
		orbit_camera.max_distance
	)
	if not orbit_camera.distance_changed.is_connected(_on_orbit_distance_changed):
		orbit_camera.distance_changed.connect(_on_orbit_distance_changed)


func _on_orbit_distance_changed(value: float) -> void:
	var orbit_camera: Node3D = get_node_or_null("OrbitCamera")
	if orbit_camera == null:
		return
	panel.sync_camera_distance(value, orbit_camera.min_distance, orbit_camera.max_distance)


func _apply_display_settings() -> void:
	if renderer.has_method("set_show_wood_wireframe"):
		renderer.set_show_wood_wireframe(panel.show_wireframe())
	if renderer.has_method("set_show_centerlines"):
		renderer.set_show_centerlines(panel.show_centerlines())
	if renderer.has_method("set_show_attractor_points"):
		renderer.set_show_attractor_points(panel.show_attractors())
	if renderer.has_method("set_show_foliage"):
		renderer.set_show_foliage(panel.show_foliage())


func _apply_renderer_mesh_mode_for_preset(index: int) -> void:
	if not renderer.has_method("set_branch_mesh_mode"):
		return
	renderer.set_branch_mesh_mode(TreeRenderer.BranchMeshMode.DECIMATED_CYLINDERS)


func _on_caudex_arc_count_changed(value: int) -> void:
	if _pattern == null:
		return
	_pattern.basal_arc_count = clampi(value, 1, 4)
	_reset_tree()


func _on_caudex_height_changed(value: float) -> void:
	if _pattern == null:
		return
	_pattern.caudex_max_height = value
	GrowthLimits.clamp_pattern(_pattern)
	_reset_tree()


func _on_caudex_spread_changed(value: float) -> void:
	if _pattern == null:
		return
	_pattern.basal_radius_mult = value
	GrowthLimits.clamp_pattern(_pattern)
	_reset_tree()


func _on_colonization_changed() -> void:
	_params = panel.collect_params()
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	_graph.init_attractors_from_preset(_pattern)
	renderer.rebuild()


func _on_reseed_attractors_pressed() -> void:
	_params = panel.collect_params()
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	_graph.reseed_attractors_from_preset(_pattern)
	renderer.rebuild()


func _on_branch_clicked(branch_id: int, hit_position: Vector3) -> void:
	if branch_id == _graph.root_id:
		return

	var changed: bool = false
	match _tool_mode:
		panel.ToolMode.PRUNE:
			if _graph.prune_at_point(branch_id, hit_position):
				_graph._update_auxin(_pattern)
				_graph.sprout_prune_seeds(_pattern)
				changed = true
		panel.ToolMode.PINCH:
			if _is_near_tip(branch_id, hit_position):
				if _graph.pinch_tip(branch_id):
					_graph._update_auxin(_pattern)
					_graph.sprout_prune_seeds(_pattern)
					changed = true
			elif _graph.prune_at_point(branch_id, hit_position):
				_graph._update_auxin(_pattern)
				_graph.sprout_prune_seeds(_pattern)
				changed = true

	if changed:
		renderer.rebuild()
		_update_camera_focus()


func _is_near_tip(branch_id: int, hit_position: Vector3) -> bool:
	var node = _graph.nodes[branch_id]
	var start: Vector3 = _graph.get_joint(branch_id)
	var end: Vector3 = _graph.get_world_tip(branch_id)
	var axis: Vector3 = (end - start).normalized()
	if axis.length_squared() <= 0.0001:
		return true
	var along: float = (hit_position - start).dot(axis)
	return along >= node.length * 0.72


func _on_grow_step_pressed() -> void:
	if _params == null:
		return
	_auto_grow = false
	_graph.advance_lab_step(_pattern, _grow_speed)
	if _graph.has_pending_prune_seeds(_pattern):
		_graph.sprout_prune_seeds(_pattern)
	renderer.rebuild()
	_update_camera_focus()
	panel.set_grow_step_enabled(true)
	panel.set_grow_step_growing(false)


func _reset_tree() -> void:
	_auto_grow = true
	_params = panel.collect_params()
	_apply_random_factor()
	_sync_pattern_from_params()
	_apply_foliage_from_params()
	_graph.create_from_lab_pattern(_species, _pattern)
	_graph._update_auxin(_pattern)
	renderer.setup(_graph, _species)
	renderer.rebuild()
	_update_camera_focus()
	panel.set_grow_step_enabled(true)
	panel.set_grow_step_growing(false)


func _update_camera_focus() -> void:
	var orbit_camera: Node3D = get_node_or_null("OrbitCamera")
	if orbit_camera == null:
		return
	var max_height: float = _graph.get_tree_height()
	orbit_camera.look_target_height = clampf(max_height * 0.45, 0.2, 4.0)


func _go_main_menu() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")


func _go_leaf_lab() -> void:
	get_tree().change_scene_to_file("res://scenes/lab/LeafLab.tscn")
