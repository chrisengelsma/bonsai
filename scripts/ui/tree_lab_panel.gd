extends Control

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")
const LSystemPresets = preload("res://scripts/lab/lsystem_presets.gd")
const LSystemParams = preload("res://scripts/lsystem/lsystem_params.gd")

enum ToolMode { VIEW, PRUNE, PINCH }

signal preset_selected(index: int)
signal apply_pressed(params: LSystemParams)
signal reset_pressed
signal grow_speed_changed(value: float)
signal random_factor_changed(value: float)
signal auxin_changed
signal tool_mode_changed(mode: int)
signal display_changed
signal camera_distance_changed(value: float)
signal grow_step_pressed
signal main_menu_pressed
signal colonization_changed
signal reseed_attractors_pressed
signal foliage_changed

@onready var preset_option: OptionButton = %PresetOption
@onready var axiom_field: LineEdit = %AxiomField
@onready var rules_field: TextEdit = %RulesField
@onready var angle_slider: HSlider = %AngleSlider
@onready var angle_label: Label = %AngleLabel
@onready var segment_slider: HSlider = %SegmentSlider
@onready var segment_label: Label = %SegmentLabel
@onready var growth_slider: HSlider = %GrowthSlider
@onready var growth_label: Label = %GrowthLabel
@onready var gravity_slider: HSlider = %GravitySlider
@onready var gravity_label: Label = %GravityLabel
@onready var depth_slider: HSlider = %DepthSlider
@onready var depth_label: Label = %DepthLabel
@onready var children_slider: HSlider = %ChildrenSlider
@onready var children_label: Label = %ChildrenLabel
@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_label: Label = %SpeedLabel
@onready var random_slider: HSlider = %RandomSlider
@onready var random_label: Label = %RandomLabel
@onready var angle_jitter_slider: HSlider = %AngleJitterSlider
@onready var angle_jitter_label: Label = %AngleJitterLabel
@onready var segment_jitter_slider: HSlider = %SegmentJitterSlider
@onready var segment_jitter_label: Label = %SegmentJitterLabel
@onready var spread_slider: HSlider = %SpreadSlider
@onready var spread_label: Label = %SpreadLabel
@onready var roll_slider: HSlider = %RollSlider
@onready var roll_label: Label = %RollLabel
@onready var skip_slider: HSlider = %SkipSlider
@onready var skip_label: Label = %SkipLabel
@onready var energy_slider: HSlider = %EnergySlider
@onready var energy_label: Label = %EnergyLabel
@onready var dominance_slider: HSlider = %DominanceSlider
@onready var dominance_label: Label = %DominanceLabel
@onready var decay_slider: HSlider = %DecaySlider
@onready var decay_label: Label = %DecayLabel
@onready var strength_slider: HSlider = %StrengthSlider
@onready var strength_label: Label = %StrengthLabel
@onready var deterministic_toggle: CheckButton = %DeterministicToggle
@onready var colonization_toggle: CheckButton = %ColonizationToggle
@onready var volume_preset_option: OptionButton = %VolumePresetOption
@onready var colon_strength_slider: HSlider = %ColonStrengthSlider
@onready var colon_strength_label: Label = %ColonStrengthLabel
@onready var colon_spawn_slider: HSlider = %ColonSpawnSlider
@onready var colon_spawn_label: Label = %ColonSpawnLabel
@onready var colon_influence_slider: HSlider = %ColonInfluenceSlider
@onready var colon_influence_label: Label = %ColonInfluenceLabel
@onready var colon_kill_slider: HSlider = %ColonKillSlider
@onready var colon_kill_label: Label = %ColonKillLabel
@onready var colon_count_slider: HSlider = %ColonCountSlider
@onready var colon_count_label: Label = %ColonCountLabel
@onready var reseed_attractors_button: Button = %ReseedAttractorsButton
@onready var foliage_enabled_toggle: CheckButton = %FoliageEnabledToggle
@onready var foliage_style_option: OptionButton = %FoliageStyleOption
@onready var foliage_placement_option: OptionButton = %FoliagePlacementOption
@onready var foliage_growth_slider: HSlider = %FoliageGrowthSlider
@onready var foliage_growth_label: Label = %FoliageGrowthLabel
@onready var foliage_start_slider: HSlider = %FoliageStartSlider
@onready var foliage_start_label: Label = %FoliageStartLabel
@onready var foliage_sway_slider: HSlider = %FoliageSwaySlider
@onready var foliage_sway_label: Label = %FoliageSwayLabel
@onready var foliage_scale_slider: HSlider = %FoliageScaleSlider
@onready var foliage_scale_label: Label = %FoliageScaleLabel
@onready var wireframe_toggle: CheckButton = %WireframeToggle
@onready var centerlines_toggle: CheckButton = %CenterlinesToggle
@onready var attractor_toggle: CheckButton = %AttractorToggle
@onready var foliage_toggle: CheckButton = %FoliageToggle
@onready var camera_distance_slider: HSlider = %CameraDistanceSlider
@onready var camera_distance_label: Label = %CameraDistanceLabel
@onready var view_button: Button = %ViewButton
@onready var prune_button: Button = %PruneButton
@onready var pinch_button: Button = %PinchButton
@onready var grow_step_button: Button = %GrowStepButton
@onready var apply_button: Button = %ApplyButton
@onready var reset_button: Button = %ResetButton
@onready var main_button: Button = %MainButton
@onready var panel: PanelContainer = %Panel

var _syncing: bool = false
var _tool_mode: int = ToolMode.VIEW


func _ready() -> void:
	_populate_presets()
	_populate_volume_presets()
	_populate_foliage_options()

	preset_option.item_selected.connect(_on_preset_selected)
	angle_slider.value_changed.connect(_on_angle_changed)
	segment_slider.value_changed.connect(_on_segment_changed)
	growth_slider.value_changed.connect(_on_growth_changed)
	gravity_slider.value_changed.connect(_on_gravity_changed)
	depth_slider.value_changed.connect(_on_depth_changed)
	children_slider.value_changed.connect(_on_children_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	random_slider.value_changed.connect(_on_random_changed)
	angle_jitter_slider.value_changed.connect(_on_angle_jitter_changed)
	segment_jitter_slider.value_changed.connect(_on_segment_jitter_changed)
	spread_slider.value_changed.connect(_on_spread_changed)
	roll_slider.value_changed.connect(_on_roll_changed)
	skip_slider.value_changed.connect(_on_skip_changed)
	energy_slider.value_changed.connect(_on_energy_changed)
	dominance_slider.value_changed.connect(_on_auxin_changed)
	decay_slider.value_changed.connect(_on_auxin_changed)
	strength_slider.value_changed.connect(_on_auxin_changed)
	deterministic_toggle.toggled.connect(_on_deterministic_toggled)
	colonization_toggle.toggled.connect(_on_colonization_changed)
	volume_preset_option.item_selected.connect(_on_colonization_changed_index)
	colon_strength_slider.value_changed.connect(_on_colon_strength_changed)
	colon_spawn_slider.value_changed.connect(_on_colon_spawn_changed)
	colon_influence_slider.value_changed.connect(_on_colon_influence_changed)
	colon_kill_slider.value_changed.connect(_on_colon_kill_changed)
	colon_count_slider.value_changed.connect(_on_colon_count_changed)
	reseed_attractors_button.pressed.connect(func(): reseed_attractors_pressed.emit())
	foliage_enabled_toggle.toggled.connect(_on_foliage_changed)
	foliage_style_option.item_selected.connect(_on_foliage_changed_index)
	foliage_placement_option.item_selected.connect(_on_foliage_changed_index)
	foliage_growth_slider.value_changed.connect(_on_foliage_growth_changed)
	foliage_start_slider.value_changed.connect(_on_foliage_start_changed)
	foliage_sway_slider.value_changed.connect(_on_foliage_sway_changed)
	foliage_scale_slider.value_changed.connect(_on_foliage_scale_changed)
	wireframe_toggle.toggled.connect(_on_display_changed)
	centerlines_toggle.toggled.connect(_on_display_changed)
	attractor_toggle.toggled.connect(_on_display_changed)
	camera_distance_slider.value_changed.connect(_on_camera_distance_changed)
	view_button.pressed.connect(func(): _set_tool_mode(ToolMode.VIEW))
	prune_button.pressed.connect(func(): _set_tool_mode(ToolMode.PRUNE))
	pinch_button.pressed.connect(func(): _set_tool_mode(ToolMode.PINCH))
	grow_step_button.pressed.connect(func(): grow_step_pressed.emit())
	apply_button.pressed.connect(_emit_apply)
	reset_button.pressed.connect(func(): reset_pressed.emit())
	main_button.pressed.connect(func(): main_menu_pressed.emit())

	get_viewport().size_changed.connect(_apply_mobile_layout)
	_apply_mobile_layout()
	_set_tool_mode(ToolMode.VIEW)


func _populate_presets() -> void:
	preset_option.clear()
	for name in LSystemPresets.get_names():
		preset_option.add_item(name)


func _populate_volume_presets() -> void:
	volume_preset_option.clear()
	for name in LSystemPresets.get_volume_preset_names():
		volume_preset_option.add_item(name)


func _populate_foliage_options() -> void:
	foliage_style_option.clear()
	for name in ["Cluster", "Broadleaf", "Needle", "Scale"]:
		foliage_style_option.add_item(name)
	foliage_placement_option.clear()
	for name in ["Tip only", "Segment scatter", "Fascicle along twig"]:
		foliage_placement_option.add_item(name)


func sync_from_params(params: LSystemParams, preset_index: int, random_factor: float = 0.0) -> void:
	if params == null:
		return
	_syncing = true
	if preset_index >= 0 and preset_index < preset_option.item_count:
		preset_option.select(preset_index)
	axiom_field.text = params.axiom
	rules_field.text = params.rules_text
	angle_slider.value = params.angle_deg
	segment_slider.value = params.segment_length
	growth_slider.value = params.growth_rate
	gravity_slider.value = params.gravity
	depth_slider.value = params.iterations
	children_slider.value = params.max_children
	random_slider.value = random_factor
	angle_jitter_slider.value = params.angle_jitter_deg
	segment_jitter_slider.value = params.segment_length_jitter
	spread_slider.value = params.spatial_spread_deg
	roll_slider.value = params.lateral_roll_spread_deg
	skip_slider.value = params.lateral_skip_chance
	energy_slider.value = params.growth_energy_variance
	dominance_slider.value = params.apical_dominance
	decay_slider.value = params.auxin_decay
	strength_slider.value = params.auxin_source_strength
	deterministic_toggle.button_pressed = params.deterministic
	_sync_colonization_from_params(params)
	_sync_foliage_from_params(params)
	set_grow_step_enabled(true)
	set_grow_step_growing(false)
	_update_labels()
	_syncing = false


func set_grow_step_enabled(enabled: bool) -> void:
	grow_step_button.disabled = not enabled


func set_grow_step_growing(growing: bool) -> void:
	if growing:
		grow_step_button.disabled = true
		grow_step_button.text = "Growing…"
	else:
		grow_step_button.text = "Grow Step"


func get_tool_mode() -> int:
	return _tool_mode


func get_grow_speed() -> float:
	return speed_slider.value


func show_wireframe() -> bool:
	return wireframe_toggle.button_pressed


func show_centerlines() -> bool:
	return centerlines_toggle.button_pressed


func show_attractors() -> bool:
	return attractor_toggle.button_pressed


func show_foliage() -> bool:
	return foliage_toggle.button_pressed


func sync_camera_distance(distance: float, min_distance: float, max_distance: float) -> void:
	_syncing = true
	camera_distance_slider.min_value = min_distance
	camera_distance_slider.max_value = max_distance
	camera_distance_slider.value = clampf(distance, min_distance, max_distance)
	_on_camera_distance_changed(camera_distance_slider.value)
	_syncing = false


func collect_params() -> LSystemParams:
	var params := LSystemParams.new()
	params.axiom = axiom_field.text.strip_edges()
	params.rules_text = rules_field.text
	params.angle_deg = angle_slider.value
	params.segment_length = segment_slider.value
	params.growth_rate = growth_slider.value
	params.gravity = gravity_slider.value
	params.iterations = int(depth_slider.value)
	params.max_children = int(children_slider.value)
	params.angle_jitter_deg = angle_jitter_slider.value
	params.segment_length_jitter = segment_jitter_slider.value
	params.spatial_spread_deg = spread_slider.value
	params.lateral_roll_spread_deg = roll_slider.value
	params.lateral_skip_chance = skip_slider.value
	params.growth_energy_variance = energy_slider.value
	params.apical_dominance = dominance_slider.value
	params.auxin_decay = decay_slider.value
	params.auxin_source_strength = strength_slider.value
	params.deterministic = deterministic_toggle.button_pressed
	_apply_colonization_to_params(params)
	_apply_foliage_to_params(params)
	params.clamp_values()
	return params


func _apply_colonization_to_params(params: LSystemParams) -> void:
	params.use_space_colonization = colonization_toggle.button_pressed
	params.colonization_strength = colon_strength_slider.value
	params.colonization_spawn_strength = colon_spawn_slider.value
	params.colonization_influence_radius = colon_influence_slider.value
	params.colonization_kill_distance = colon_kill_slider.value
	params.colonization_point_count = int(colon_count_slider.value)
	if volume_preset_option.selected >= 0:
		params.colonization_volume_preset = volume_preset_option.get_item_text(volume_preset_option.selected)


func _apply_foliage_to_params(params: LSystemParams) -> void:
	params.foliage_enabled = foliage_enabled_toggle.button_pressed
	params.foliage_mesh_style = foliage_style_option.selected + 1
	params.foliage_placement = foliage_placement_option.selected
	params.foliage_growth_rate = foliage_growth_slider.value
	params.foliage_start_length = foliage_start_slider.value
	params.foliage_sway_amount = foliage_sway_slider.value
	params.foliage_scale = foliage_scale_slider.value


func _sync_foliage_from_params(params: LSystemParams) -> void:
	foliage_enabled_toggle.button_pressed = params.foliage_enabled
	if params.foliage_mesh_style >= 1 and params.foliage_mesh_style - 1 < foliage_style_option.item_count:
		foliage_style_option.select(params.foliage_mesh_style - 1)
	if params.foliage_placement >= 0 and params.foliage_placement < foliage_placement_option.item_count:
		foliage_placement_option.select(params.foliage_placement)
	foliage_growth_slider.value = params.foliage_growth_rate
	foliage_start_slider.value = params.foliage_start_length
	foliage_sway_slider.value = params.foliage_sway_amount
	foliage_scale_slider.value = params.foliage_scale
	_on_foliage_growth_changed(foliage_growth_slider.value)
	_on_foliage_start_changed(foliage_start_slider.value)
	_on_foliage_sway_changed(foliage_sway_slider.value)
	_on_foliage_scale_changed(foliage_scale_slider.value)
	_update_foliage_controls_enabled()


func _sync_colonization_from_params(params: LSystemParams) -> void:
	colonization_toggle.button_pressed = params.use_space_colonization
	colon_strength_slider.value = params.colonization_strength
	colon_spawn_slider.value = params.colonization_spawn_strength
	colon_influence_slider.value = params.colonization_influence_radius
	colon_kill_slider.value = params.colonization_kill_distance
	colon_count_slider.value = params.colonization_point_count
	var preset_index: int = _volume_preset_index_for_name(params.colonization_volume_preset)
	if preset_index >= 0:
		volume_preset_option.select(preset_index)
	_on_colon_strength_changed(colon_strength_slider.value)
	_on_colon_spawn_changed(colon_spawn_slider.value)
	_on_colon_influence_changed(colon_influence_slider.value)
	_on_colon_kill_changed(colon_kill_slider.value)
	_on_colon_count_changed(colon_count_slider.value)


func _volume_preset_index_for_name(preset_name: String) -> int:
	var target: String = preset_name.strip_edges()
	for i in range(volume_preset_option.item_count):
		if volume_preset_option.get_item_text(i) == target:
			return i
	return -1


func get_random_factor() -> float:
	return random_slider.value


func _emit_apply() -> void:
	apply_pressed.emit(collect_params())


func _set_tool_mode(mode: int) -> void:
	_tool_mode = mode
	view_button.button_pressed = mode == ToolMode.VIEW
	prune_button.button_pressed = mode == ToolMode.PRUNE
	pinch_button.button_pressed = mode == ToolMode.PINCH
	tool_mode_changed.emit(mode)


func _on_preset_selected(index: int) -> void:
	if _syncing:
		return
	preset_selected.emit(index)


func _on_display_changed(_enabled: bool = false) -> void:
	display_changed.emit()


func _on_foliage_changed(_enabled: bool = false) -> void:
	_update_foliage_controls_enabled()
	if not _syncing:
		foliage_changed.emit()


func _on_foliage_changed_index(_index: int = 0) -> void:
	if not _syncing:
		foliage_changed.emit()


func _on_foliage_growth_changed(value: float) -> void:
	foliage_growth_label.text = "Foliage growth: %.2f" % value
	if not _syncing:
		foliage_changed.emit()


func _on_foliage_start_changed(value: float) -> void:
	foliage_start_label.text = "Foliage start: %.2f" % value
	if not _syncing:
		foliage_changed.emit()


func _on_foliage_sway_changed(value: float) -> void:
	foliage_sway_label.text = "Foliage sway: %.3f" % value
	if not _syncing:
		foliage_changed.emit()


func _on_foliage_scale_changed(value: float) -> void:
	foliage_scale_label.text = "Foliage scale: %.2f" % value
	if not _syncing:
		foliage_changed.emit()


func _update_foliage_controls_enabled() -> void:
	var enabled: bool = foliage_enabled_toggle.button_pressed
	foliage_style_option.disabled = not enabled
	foliage_placement_option.disabled = not enabled
	foliage_growth_slider.editable = enabled
	foliage_start_slider.editable = enabled
	foliage_sway_slider.editable = enabled
	foliage_scale_slider.editable = enabled


func _on_camera_distance_changed(value: float) -> void:
	camera_distance_label.text = "Camera distance: %.1f" % value
	if not _syncing:
		camera_distance_changed.emit(value)


func _on_auxin_changed(_value: float = 0.0) -> void:
	_on_dominance_changed(dominance_slider.value)
	_on_decay_changed(decay_slider.value)
	_on_strength_changed(strength_slider.value)
	if not _syncing:
		auxin_changed.emit()


func _on_angle_changed(value: float) -> void:
	angle_label.text = "Turn angle: %.0f°" % value


func _on_segment_changed(value: float) -> void:
	segment_label.text = "Segment length: %.2f" % value


func _on_growth_changed(value: float) -> void:
	growth_label.text = "Growth rate: %.3f" % value


func _on_gravity_changed(value: float) -> void:
	gravity_label.text = "Gravity: %.2f" % value


func _on_depth_changed(value: float) -> void:
	depth_label.text = "Max depth: %d" % int(value)


func _on_children_changed(value: float) -> void:
	children_label.text = "Max children: %d" % int(value)


func _on_speed_changed(value: float) -> void:
	speed_label.text = "Growth speed: %.1fx" % value
	grow_speed_changed.emit(value)


func _on_random_changed(value: float) -> void:
	random_label.text = "Random preset: %.0f%%" % (value * 100.0)
	if not _syncing:
		random_factor_changed.emit(value)


func _on_angle_jitter_changed(value: float) -> void:
	angle_jitter_label.text = "Angle jitter: %.0f°" % value


func _on_segment_jitter_changed(value: float) -> void:
	segment_jitter_label.text = "Length jitter: %.0f%%" % (value * 100.0)


func _on_spread_changed(value: float) -> void:
	spread_label.text = "Spatial spread: %.0f°" % value


func _on_roll_changed(value: float) -> void:
	roll_label.text = "Branch roll: %.0f°" % value


func _on_skip_changed(value: float) -> void:
	skip_label.text = "Skip chance: %.0f%%" % (value * 100.0)


func _on_energy_changed(value: float) -> void:
	energy_label.text = "Energy variance: %.0f%%" % (value * 100.0)


func _on_dominance_changed(value: float) -> void:
	dominance_label.text = "Apical dominance: %.0f%%" % (value * 100.0)


func _on_decay_changed(value: float) -> void:
	decay_label.text = "Auxin decay: %.0f%%" % (value * 100.0)


func _on_strength_changed(value: float) -> void:
	strength_label.text = "Auxin strength: %.1f" % value


func _on_deterministic_toggled(enabled: bool) -> void:
	deterministic_toggle.text = "Deterministic growth" if enabled else "Stochastic growth"


func _on_colonization_changed(_enabled: bool = false) -> void:
	if not _syncing:
		colonization_changed.emit()


func _on_colonization_changed_index(_index: int = 0) -> void:
	if not _syncing:
		colonization_changed.emit()


func _on_colon_strength_changed(value: float) -> void:
	colon_strength_label.text = "Tip strength: %.2f" % value
	if not _syncing:
		colonization_changed.emit()


func _on_colon_spawn_changed(value: float) -> void:
	colon_spawn_label.text = "Spawn strength: %.2f" % value
	if not _syncing:
		colonization_changed.emit()


func _on_colon_influence_changed(value: float) -> void:
	colon_influence_label.text = "Influence radius: %.2f" % value
	if not _syncing:
		colonization_changed.emit()


func _on_colon_kill_changed(value: float) -> void:
	colon_kill_label.text = "Kill distance: %.2f" % value
	if not _syncing:
		colonization_changed.emit()


func _on_colon_count_changed(value: float) -> void:
	colon_count_label.text = "Attractor count: %d" % int(value)
	if not _syncing:
		colonization_changed.emit()


func _update_labels() -> void:
	_on_angle_changed(angle_slider.value)
	_on_segment_changed(segment_slider.value)
	_on_growth_changed(growth_slider.value)
	_on_gravity_changed(gravity_slider.value)
	_on_depth_changed(depth_slider.value)
	_on_children_changed(children_slider.value)
	_on_speed_changed(speed_slider.value)
	_on_random_changed(random_slider.value)
	_on_angle_jitter_changed(angle_jitter_slider.value)
	_on_segment_jitter_changed(segment_jitter_slider.value)
	_on_spread_changed(spread_slider.value)
	_on_roll_changed(roll_slider.value)
	_on_skip_changed(skip_slider.value)
	_on_energy_changed(energy_slider.value)
	_on_dominance_changed(dominance_slider.value)
	_on_decay_changed(decay_slider.value)
	_on_strength_changed(strength_slider.value)
	_on_deterministic_toggled(deterministic_toggle.button_pressed)
	_on_colon_strength_changed(colon_strength_slider.value)
	_on_colon_spawn_changed(colon_spawn_slider.value)
	_on_colon_influence_changed(colon_influence_slider.value)
	_on_colon_kill_changed(colon_kill_slider.value)
	_on_colon_count_changed(colon_count_slider.value)
	_on_foliage_growth_changed(foliage_growth_slider.value)
	_on_foliage_start_changed(foliage_start_slider.value)
	_on_foliage_sway_changed(foliage_sway_slider.value)
	_on_foliage_scale_changed(foliage_scale_slider.value)


func _apply_mobile_layout() -> void:
	var insets: Dictionary = MobileUtils.get_safe_insets(get_viewport())
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_width: float = clampf(
		400.0,
		300.0,
		minf(460.0, viewport_size.x - insets.left - insets.right - 16.0)
	)

	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = insets.left
	panel.offset_top = insets.top
	panel.offset_right = panel_width
	panel.offset_bottom = -insets.bottom
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	if MobileUtils.is_mobile():
		grow_step_button.custom_minimum_size.y = 48.0
		apply_button.custom_minimum_size.y = 48.0
		reset_button.custom_minimum_size.y = 48.0
		main_button.custom_minimum_size.y = 48.0
		view_button.custom_minimum_size.y = 44.0
		prune_button.custom_minimum_size.y = 44.0
		pinch_button.custom_minimum_size.y = 44.0
	else:
		grow_step_button.custom_minimum_size = Vector2.ZERO
		apply_button.custom_minimum_size = Vector2.ZERO
		reset_button.custom_minimum_size = Vector2.ZERO
		main_button.custom_minimum_size = Vector2.ZERO
		view_button.custom_minimum_size = Vector2.ZERO
		prune_button.custom_minimum_size = Vector2.ZERO
		pinch_button.custom_minimum_size = Vector2.ZERO
