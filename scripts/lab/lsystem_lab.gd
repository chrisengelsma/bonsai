extends Node3D

const TreeGraphScript = preload("res://scripts/tree/tree_graph.gd")
const TreeSpeciesScript = preload("res://scripts/catalog/tree_species.gd")
const LSystemPresets = preload("res://scripts/lab/lsystem_presets.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")
const LabGrowthRandom = preload("res://scripts/lab/lab_growth_random.gd")
const RootGraphScript = preload("res://scripts/roots/root_graph.gd")

@onready var renderer: Node3D = $LabTree/TreeRenderer
@onready var root_renderer = $LabTree/Pot/RootRenderer
@onready var pot: Node3D = $LabTree/Pot
@onready var panel: Control = $UI/LSystemLabPanel

var _graph
var _species
var _pattern
var _grow_speed: float = 5.0
var _random_factor: float = 0.0
var _current_preset: int = 0
var _auto_grow: bool = false
var _step_mode: bool = false
var _growth_frozen: bool = false
var _step_tips: Dictionary = {}
var _pending_prune_id: int = -1
var _pending_hit: Vector3 = Vector3.ZERO
var _prune_dialog: ConfirmationDialog
var _root_graph
var _root_growth_seconds: float = 0.0
var _root_generation_seed: int = 0
var _root_field
var _root_anchor: Vector3 = Vector3.ZERO
var _root_spawn_radius: float = 0.014


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
	panel.random_factor_changed.connect(_on_random_factor_changed)
	panel.grow_step_pressed.connect(_on_grow_step_pressed)
	panel.main_menu_pressed.connect(_go_main_menu)
	panel.bark_mode_changed.connect(_on_bark_mode_changed)
	panel.wood_wireframe_changed.connect(_on_wood_wireframe_changed)
	panel.roots_visibility_changed.connect(_on_roots_visibility_changed)

	_setup_prune_dialog()
	renderer.branch_clicked.connect(_on_branch_clicked)

	_sync_renderer_visual_options()
	_apply_preset(0, true)


func _unhandled_input(event: InputEvent) -> void:
	if renderer and renderer.has_method("handle_prune_input"):
		if renderer.handle_prune_input(event):
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _growth_frozen:
		return

	_accumulate_root_growth_time(delta)

	if not _auto_grow or _graph == null or _pattern == null:
		return

	_graph.grow(delta, _pattern, true, _grow_speed, 1.0)
	_update_camera_focus()

	if _graph.get_active_tip_ids().is_empty():
		_finish_growth()
		return

	if _step_mode and _is_step_complete():
		_finish_growth()


func _setup_prune_dialog() -> void:
	_prune_dialog = ConfirmationDialog.new()
	_prune_dialog.title = "Prune branch?"
	_prune_dialog.dialog_text = "Remove all growth past this point and trim the branch here?"
	_prune_dialog.ok_button_text = "Prune"
	_prune_dialog.cancel_button_text = "Cancel"
	_prune_dialog.confirmed.connect(_on_prune_confirmed)
	_prune_dialog.canceled.connect(_on_prune_cancelled)
	add_child(_prune_dialog)


func _update_camera_focus() -> void:
	if _graph == null:
		return
	var orbit_camera: Node3D = get_node_or_null("OrbitCamera")
	if orbit_camera == null:
		return

	var max_height: float = 0.0
	for node_id in _graph.nodes.keys():
		var tip_y: float = _graph.get_world_tip(node_id).y
		max_height = maxf(max_height, tip_y)

	orbit_camera.look_target_height = clampf(max_height * 0.45, 0.2, 4.0)


func _apply_preset(index: int, reset_tree: bool) -> void:
	_current_preset = index
	_pattern = LSystemPresets.load_preset(index)
	GrowthLimits.clamp_pattern(_pattern)
	LabGrowthRandom.apply_to_pattern(_pattern, _random_factor)
	_species.grow_pattern = _pattern
	panel.sync_from_pattern(_pattern, index, _random_factor)
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


func _on_random_factor_changed(value: float) -> void:
	_random_factor = value
	if _pattern:
		LabGrowthRandom.apply_to_pattern(_pattern, _random_factor)
		_species.grow_pattern = _pattern


func _on_bark_mode_changed(mode_index: int) -> void:
	if renderer == null:
		return
	match mode_index:
		1:
			renderer.set_branch_mesh_mode(renderer.BranchMeshMode.DECIMATED_CYLINDERS)
		2:
			renderer.set_branch_mesh_mode(renderer.BranchMeshMode.SWEPT_TUBE)
		3:
			renderer.set_branch_mesh_mode(renderer.BranchMeshMode.RING_LOFT)
		_:
			renderer.set_branch_mesh_mode(renderer.BranchMeshMode.CYLINDERS)


func _on_wood_wireframe_changed(enabled: bool) -> void:
	if renderer:
		renderer.set_show_wood_wireframe(enabled)


func _on_roots_visibility_changed(enabled: bool) -> void:
	if enabled:
		_invoke_root_generation()
	else:
		_release_root_graph()
		if root_renderer:
			root_renderer.set_show_roots(false)


func _sync_renderer_visual_options() -> void:
	if renderer == null or panel == null:
		return
	panel.bark_mode_option.select(renderer.branch_mesh_mode)
	panel.wood_wireframe_toggle.button_pressed = renderer.show_wood_wireframe
	if panel.roots_toggle != null:
		panel.roots_toggle.button_pressed = root_renderer.show_roots if root_renderer else true


func _on_grow_step_pressed() -> void:
	if _graph == null or _pattern == null or _growth_frozen or _auto_grow:
		return

	_reseed_growth()
	_graph.sprout_prune_seeds(_pattern)
	_graph.reactivate_seed_tips(_pattern)
	if _graph.get_active_tip_ids().is_empty():
		_update_grow_step_button()
		return

	_begin_step()
	_step_mode = true
	_auto_grow = true
	panel.set_grow_step_growing(true)


func _reseed_growth() -> void:
	_graph.get_rng().randomize()
	LabGrowthRandom.apply_to_pattern(_pattern, _random_factor)
	_species.grow_pattern = _pattern


func _begin_step() -> void:
	_step_tips.clear()
	for tip_id in _graph.get_active_tip_ids():
		var tip = _graph.nodes[tip_id]
		_step_tips[tip_id] = tip.length_at_last_production


func _is_step_complete() -> bool:
	for tip_id in _step_tips.keys():
		if not _graph.nodes.has(tip_id):
			continue

		var tip = _graph.nodes[tip_id]
		var start_prod: float = _step_tips[tip_id]
		if not tip.is_growing_tip:
			continue
		if tip.depth >= _pattern.max_branch_depth:
			continue
		if tip.length_at_last_production <= start_prod + 0.0001:
			return false

	return true


func _start_full_growth() -> void:
	_step_mode = false
	_step_tips.clear()
	_auto_grow = not _graph.get_active_tip_ids().is_empty()
	panel.set_grow_step_growing(_auto_grow)
	_update_grow_step_button()


func _finish_growth() -> void:
	_auto_grow = false
	_step_mode = false
	_step_tips.clear()
	panel.set_grow_step_growing(false)
	_update_grow_step_button()


func _update_grow_step_button() -> void:
	if _graph == null or _pattern == null:
		return
	panel.set_grow_step_enabled(not _auto_grow and _graph.has_growable_seed_tips(_pattern))


func _apply_params(params: Dictionary) -> void:
	_pattern.lsystem_axiom = str(params.get("axiom", "T"))
	_pattern.lsystem_rules_text = str(params.get("rules", ""))
	_pattern.lsystem_angle_deg = float(params.get("angle", 28.0))
	_pattern.lsystem_segment_length = float(params.get("segment_length", 0.1))
	_pattern.tip_growth_rate = float(params.get("growth_rate", 0.03))
	_pattern.gravity_curve = float(params.get("gravity", 0.0))
	_pattern.max_branch_depth = int(params.get("max_depth", 5))
	_pattern.max_children_per_node = int(params.get("max_children", 2))
	_random_factor = float(params.get("random_factor", 0.0))
	GrowthLimits.clamp_pattern(_pattern)
	LabGrowthRandom.apply_to_pattern(_pattern, _random_factor)
	_pattern.invalidate_rules_cache()
	_species.grow_pattern = _pattern


func _reset_tree() -> void:
	if _graph and _graph.graph_changed.is_connected(_on_graph_changed):
		_graph.graph_changed.disconnect(_on_graph_changed)

	_growth_frozen = false
	_pending_prune_id = -1
	_auto_grow = false
	_step_mode = false
	_step_tips.clear()

	_graph = TreeGraphScript.new()
	_graph.graph_changed.connect(_on_graph_changed)
	_graph.create_from_species(_species)
	_graph.get_rng().randomize()
	renderer.setup(_graph, _species)
	_configure_roots()
	_start_full_growth()


func _configure_roots() -> void:
	if root_renderer == null or pot == null:
		return

	_sync_tree_anchor()
	_release_root_graph()

	_root_growth_seconds = 0.0
	_root_generation_seed = int(hash("lab_roots"))
	_root_anchor = pot.get_root_anchor()
	_root_spawn_radius = _get_root_spawn_radius()
	if pot.has_method("get_growth_field"):
		_root_field = pot.get_growth_field()
	elif pot.has_method("get_bounds"):
		_root_field = pot.get_bounds()
	else:
		_root_field = null

	root_renderer.setup(null)
	if panel != null and panel.roots_toggle.button_pressed:
		_invoke_root_generation()
	else:
		root_renderer.set_show_roots(false)


func _accumulate_root_growth_time(delta: float) -> void:
	_root_growth_seconds += delta * _grow_speed * RootGraphScript.TREE_SPEED_RATIO


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
	if panel != null and panel.roots_toggle.button_pressed:
		_invoke_root_generation()
	else:
		_release_root_graph()
		if root_renderer:
			root_renderer.set_show_roots(false)


func _get_root_spawn_radius() -> float:
	if _graph and _graph.has_method("get_trunk_base_spawn_radius"):
		return _graph.get_trunk_base_spawn_radius()
	return 0.014


func _sync_tree_anchor() -> void:
	if renderer == null or pot == null or not pot.has_method("get_tree_anchor_height"):
		return
	renderer.position.y = pot.get_tree_anchor_height()


func _on_graph_changed() -> void:
	if renderer:
		renderer.rebuild()


func _on_branch_clicked(branch_id: int, hit_position: Vector3) -> void:
	if _growth_frozen or _graph == null or _prune_dialog == null:
		return
	if not _prune_dialog.is_inside_tree():
		return

	_pending_prune_id = branch_id
	_pending_hit = hit_position
	_pause_for_prune()
	_prune_dialog.popup_centered()


func _on_prune_confirmed() -> void:
	var branch_id: int = _pending_prune_id
	var hit: Vector3 = _pending_hit
	_clear_prune_pending()

	if branch_id >= 0 and _graph:
		_graph.prune_at_point(branch_id, hit, true)
		if renderer:
			renderer.rebuild()
		_finish_growth()

	_unfreeze_growth()


func _on_prune_cancelled() -> void:
	_clear_prune_pending()
	_unfreeze_growth()


func _clear_prune_pending() -> void:
	_pending_prune_id = -1
	_pending_hit = Vector3.ZERO


func _pause_for_prune() -> void:
	_growth_frozen = true
	renderer.set_prune_hover_enabled(false)


func _unfreeze_growth() -> void:
	_growth_frozen = false
	renderer.set_prune_hover_enabled(true)
	_start_full_growth()


func _go_main_menu() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")
