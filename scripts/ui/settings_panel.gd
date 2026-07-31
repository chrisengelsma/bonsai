extends Control

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")

signal closed

@onready var panel: PanelContainer = %Panel
@onready var backdrop: ColorRect = $Backdrop
@onready var grow_speed_slider: HSlider = %GrowSpeedSlider
@onready var grow_speed_label: Label = %GrowSpeedLabel
@onready var music_check: CheckBox = %MusicCheck
@onready var ambience_check: CheckBox = %AmbienceCheck
@onready var species_option: OptionButton = %SpeciesOption
@onready var reset_button: Button = %ResetButton
@onready var lab_button: Button = %LabButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	grow_speed_slider.min_value = 0.1
	grow_speed_slider.max_value = 8.0
	grow_speed_slider.step = 0.1
	grow_speed_slider.value = GameState.grow_speed_multiplier
	_update_grow_speed_label(GameState.grow_speed_multiplier)

	grow_speed_slider.value_changed.connect(_on_grow_speed_changed)
	music_check.toggled.connect(_on_music_toggled)
	ambience_check.toggled.connect(_on_ambience_toggled)
	reset_button.pressed.connect(_on_reset_pressed)
	lab_button.pressed.connect(_on_lab_pressed)
	close_button.pressed.connect(_close)
	species_option.item_selected.connect(_on_species_selected)

	music_check.button_pressed = GameState.music_enabled
	ambience_check.button_pressed = GameState.ambience_enabled
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	get_viewport().size_changed.connect(_apply_mobile_layout)
	_populate_species()
	_apply_mobile_layout()


var _populating_species: bool = false


func _populate_species() -> void:
	_populating_species = true
	species_option.clear()
	var seeds := CatalogRegistry.get_all_seeds()
	for i in seeds.size():
		species_option.add_item(seeds[i].display_name, i)
		if GameState.species and seeds[i].species and seeds[i].species.id == GameState.species.id:
			species_option.select(i)
	_populating_species = false


func open() -> void:
	visible = true
	grow_speed_slider.value = GameState.grow_speed_multiplier
	_apply_mobile_layout()


func _apply_mobile_layout() -> void:
	var insets: Dictionary = MobileUtils.get_safe_insets(get_viewport())
	var width: float = get_viewport_rect().size.x - insets.left - insets.right - 32.0
	panel.custom_minimum_size.x = clampf(width, 280.0, 420.0)
	panel.get_parent().offset_left = insets.left
	panel.get_parent().offset_top = insets.top
	panel.get_parent().offset_right = -insets.right
	panel.get_parent().offset_bottom = -insets.bottom

	if MobileUtils.is_mobile():
		close_button.custom_minimum_size.y = 52.0
		reset_button.custom_minimum_size.y = 52.0
		lab_button.custom_minimum_size.y = 52.0
		grow_speed_slider.custom_minimum_size.y = 40.0
	else:
		close_button.custom_minimum_size = Vector2.ZERO
		reset_button.custom_minimum_size = Vector2.ZERO
		lab_button.custom_minimum_size = Vector2.ZERO
		grow_speed_slider.custom_minimum_size = Vector2.ZERO


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_close()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _close() -> void:
	visible = false
	closed.emit()


func _on_grow_speed_changed(value: float) -> void:
	GameState.set_grow_speed_multiplier(value)
	_update_grow_speed_label(value)
	SaveManager.save_game(GameState.build_save_data())


func _update_grow_speed_label(value: float) -> void:
	grow_speed_label.text = "Growth speed: %.1fx" % value


func _on_music_toggled(enabled: bool) -> void:
	GameState.music_enabled = enabled
	AudioManager.set_bus_mute("Music", not enabled)
	SaveManager.save_game(GameState.build_save_data())


func _on_ambience_toggled(enabled: bool) -> void:
	GameState.ambience_enabled = enabled
	AudioManager.set_bus_mute("Ambience", not enabled)
	SaveManager.save_game(GameState.build_save_data())


func _on_reset_pressed() -> void:
	GameState.reset_progress()
	SaveManager.save_game(GameState.build_save_data())
	GameState.graph_changed.emit()
	_close()


func _on_lab_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/lab/LSystemLab.tscn")


func _on_species_selected(index: int) -> void:
	if _populating_species:
		return
	var seeds := CatalogRegistry.get_all_seeds()
	if index < 0 or index >= seeds.size():
		return
	var seed = seeds[index]
	if GameState.species and seed.species and seed.species.id == GameState.species.id:
		return
	GameState.reset_progress(seed.id)
	SaveManager.save_game(GameState.build_save_data())
	GameState.graph_changed.emit()
