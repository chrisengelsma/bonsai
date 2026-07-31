extends Control

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")

signal water_pressed
signal settings_pressed
signal tool_mode_selected(mode: int)

@onready var top_bar: HBoxContainer = $TopBar
@onready var bottom_bar: VBoxContainer = $BottomBar
@onready var hint_label: Label = $BottomBar/HintLabel
@onready var title_label: Label = %TitleLabel
@onready var species_label: Label = %SpeciesLabel
@onready var maturity_label: Label = %MaturityLabel
@onready var moisture_bar: ProgressBar = %MoistureBar
@onready var growth_indicator: Label = %GrowthIndicator
@onready var water_button: Button = %WaterButton
@onready var settings_button: Button = %SettingsButton
@onready var view_button: Button = %ViewButton
@onready var prune_button: Button = %PruneButton
@onready var graft_button: Button = %GraftButton

const MOBILE_BUTTON_HEIGHT := 52.0
const MOBILE_WATER_WIDTH := 220.0


func _ready() -> void:
	water_button.pressed.connect(func(): water_pressed.emit())
	settings_button.pressed.connect(func(): settings_pressed.emit())
	view_button.pressed.connect(func(): tool_mode_selected.emit(0))
	prune_button.pressed.connect(func(): tool_mode_selected.emit(1))
	graft_button.pressed.connect(func(): tool_mode_selected.emit(2))

	GameState.moisture_changed.connect(_on_moisture_changed)
	GameState.growth_status_changed.connect(_on_growth_status_changed)
	GameState.maturity_changed.connect(_on_maturity_changed)
	GameState.species_changed.connect(_on_species_changed)
	GameState.watering_started.connect(_on_watering_started)
	GameState.watering_finished.connect(_on_watering_finished)

	get_viewport().size_changed.connect(_apply_mobile_layout)
	_apply_mobile_layout()

	_on_moisture_changed(GameState.moisture)
	_on_growth_status_changed(false)


func _apply_mobile_layout() -> void:
	var insets: Dictionary = MobileUtils.get_safe_insets(get_viewport())
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = MobileUtils.is_portrait(viewport_size)
	var mobile: bool = MobileUtils.is_mobile()

	top_bar.offset_left = 16.0 + insets.left
	top_bar.offset_top = 16.0 + insets.top
	top_bar.offset_right = -16.0 - insets.right

	bottom_bar.offset_left = 16.0 + insets.left
	bottom_bar.offset_right = -16.0 - insets.right
	bottom_bar.offset_bottom = -16.0 - insets.bottom

	if mobile:
		hint_label.text = "Swipe to turn • Pinch to zoom" if portrait else "Drag to turn • Pinch to zoom"
		water_button.custom_minimum_size = Vector2(MOBILE_WATER_WIDTH, MOBILE_BUTTON_HEIGHT)
		settings_button.custom_minimum_size = Vector2(96.0, MOBILE_BUTTON_HEIGHT)
		for button in [view_button, prune_button, graft_button]:
			button.custom_minimum_size = Vector2(88.0, MOBILE_BUTTON_HEIGHT)
		bottom_bar.offset_top = -188.0 - insets.bottom
	else:
		hint_label.text = "Drag to turn • Scroll to zoom"
		water_button.custom_minimum_size = Vector2(180.0, 44.0)
		settings_button.custom_minimum_size = Vector2.ZERO
		for button in [view_button, prune_button, graft_button]:
			button.custom_minimum_size = Vector2.ZERO
		bottom_bar.offset_top = -140.0

	if portrait and mobile:
		top_bar.offset_bottom = 112.0 + insets.top
		species_label.visible = false
	else:
		top_bar.offset_bottom = 96.0 + insets.top
		species_label.visible = true


func _on_moisture_changed(value: float) -> void:
	moisture_bar.value = value * 100.0
	if value < GameState.config.growth_threshold:
		moisture_bar.modulate = Color(1.0, 0.75, 0.65)
	else:
		moisture_bar.modulate = Color.WHITE


func _on_growth_status_changed(is_growing: bool) -> void:
	growth_indicator.text = "Growing" if is_growing else "Needs water"
	growth_indicator.modulate = Color.WHITE


func _on_maturity_changed(label_text: String) -> void:
	maturity_label.text = label_text


func _on_species_changed(species) -> void:
	species_label.text = species.display_name if species else ""


func _on_watering_started() -> void:
	water_button.disabled = true


func _on_watering_finished() -> void:
	water_button.disabled = not GameState.can_water()


func _process(_delta: float) -> void:
	if not water_button.disabled and not GameState.can_water():
		water_button.disabled = true
	elif water_button.disabled and GameState.can_water() and not GameState.is_watering():
		water_button.disabled = false


func set_tool_mode(mode: int) -> void:
	view_button.button_pressed = mode == 0
	prune_button.button_pressed = mode == 1
	graft_button.button_pressed = mode == 2

	if MobileUtils.is_mobile() and mode != 0:
		hint_label.text = "Tap branches • Switch to View to turn"
	elif MobileUtils.is_mobile():
		hint_label.text = "Swipe to turn • Pinch to zoom"
