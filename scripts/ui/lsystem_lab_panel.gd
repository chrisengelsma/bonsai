extends Control

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")
const LSystemPresets = preload("res://scripts/lab/lsystem_presets.gd")

signal preset_selected(index: int)
signal apply_pressed(params: Dictionary)
signal reset_tree_pressed
signal grow_speed_changed(value: float)
signal main_menu_pressed

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
@onready var apply_button: Button = %ApplyButton
@onready var reset_button: Button = %ResetButton
@onready var main_button: Button = %MainButton
@onready var panel: PanelContainer = %Panel

var _syncing: bool = false


func _ready() -> void:
	_populate_presets()

	preset_option.item_selected.connect(_on_preset_selected)
	angle_slider.value_changed.connect(_on_angle_changed)
	segment_slider.value_changed.connect(_on_segment_changed)
	growth_slider.value_changed.connect(_on_growth_changed)
	gravity_slider.value_changed.connect(_on_gravity_changed)
	depth_slider.value_changed.connect(_on_depth_changed)
	children_slider.value_changed.connect(_on_children_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	apply_button.pressed.connect(_emit_apply)
	reset_button.pressed.connect(func(): reset_tree_pressed.emit())
	main_button.pressed.connect(func(): main_menu_pressed.emit())

	get_viewport().size_changed.connect(_apply_mobile_layout)
	_apply_mobile_layout()


func _populate_presets() -> void:
	preset_option.clear()
	for name in LSystemPresets.get_names():
		preset_option.add_item(name)


func sync_from_pattern(pattern, preset_index: int) -> void:
	_syncing = true
	if preset_index >= 0 and preset_index < preset_option.item_count:
		preset_option.select(preset_index)
	axiom_field.text = pattern.lsystem_axiom
	rules_field.text = pattern.lsystem_rules_text
	angle_slider.value = pattern.lsystem_angle_deg
	segment_slider.value = pattern.lsystem_segment_length
	growth_slider.value = pattern.tip_growth_rate
	gravity_slider.value = pattern.gravity_curve
	depth_slider.value = pattern.max_branch_depth
	children_slider.value = pattern.max_children_per_node
	_update_labels()
	_syncing = false


func _collect_params() -> Dictionary:
	return {
		"axiom": axiom_field.text.strip_edges(),
		"rules": rules_field.text,
		"angle": angle_slider.value,
		"segment_length": segment_slider.value,
		"growth_rate": growth_slider.value,
		"gravity": gravity_slider.value,
		"max_depth": int(depth_slider.value),
		"max_children": int(children_slider.value),
	}


func _emit_apply() -> void:
	apply_pressed.emit(_collect_params())


func _on_preset_selected(index: int) -> void:
	if _syncing:
		return
	preset_selected.emit(index)


func _on_angle_changed(value: float) -> void:
	angle_label.text = "Branch angle: %.0f°" % value


func _on_segment_changed(value: float) -> void:
	segment_label.text = "Segment length: %.2f" % value


func _on_growth_changed(value: float) -> void:
	growth_label.text = "Tip growth rate: %.3f" % value


func _on_gravity_changed(value: float) -> void:
	gravity_label.text = "Gravity curve: %.2f" % value


func _on_depth_changed(value: float) -> void:
	depth_label.text = "Max depth: %d" % int(value)


func _on_children_changed(value: float) -> void:
	children_label.text = "Max children: %d" % int(value)


func _on_speed_changed(value: float) -> void:
	speed_label.text = "Preview speed: %.1fx" % value
	grow_speed_changed.emit(value)


func _update_labels() -> void:
	_on_angle_changed(angle_slider.value)
	_on_segment_changed(segment_slider.value)
	_on_growth_changed(growth_slider.value)
	_on_gravity_changed(gravity_slider.value)
	_on_depth_changed(depth_slider.value)
	_on_children_changed(children_slider.value)
	_on_speed_changed(speed_slider.value)


func _apply_mobile_layout() -> void:
	var insets: Dictionary = MobileUtils.get_safe_insets(get_viewport())
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_width: float = clampf(viewport_size.x - insets.left - insets.right - 24.0, 300.0, 440.0)
	panel.custom_minimum_size.x = panel_width
	offset_left = insets.left + 8.0
	offset_top = insets.top + 8.0
	offset_right = -(insets.right + 8.0)
	offset_bottom = -(insets.bottom + 8.0)

	if MobileUtils.is_mobile():
		apply_button.custom_minimum_size.y = 48.0
		reset_button.custom_minimum_size.y = 48.0
		main_button.custom_minimum_size.y = 48.0
	else:
		apply_button.custom_minimum_size = Vector2.ZERO
		reset_button.custom_minimum_size = Vector2.ZERO
		main_button.custom_minimum_size = Vector2.ZERO
