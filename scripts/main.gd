extends Node3D

@onready var bonsai_tree: Node3D = $BonsaiTree
@onready var orbit_camera: Node3D = $OrbitCamera
@onready var hud: Control = $UI/GameHUD
@onready var settings: Control = $UI/SettingsPanel

var _save_timer: float = 0.0


func _ready() -> void:
	hud.water_pressed.connect(_on_water_pressed)
	hud.settings_pressed.connect(_on_settings_pressed)
	hud.tool_mode_selected.connect(_on_tool_mode_selected)

	GameState.watering_started.connect(_on_watering_started)
	GameState.watering_finished.connect(_on_watering_finished)
	GameState.moisture_changed.connect(_on_moisture_changed)

	if bonsai_tree.has_node("TreeEditor"):
		hud.set_tool_mode(GameState.tool_mode)
		_on_tool_mode_selected(GameState.tool_mode)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		SaveManager.save_game(GameState.build_save_data())
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if bonsai_tree.has_method("set_soil_moisture"):
			bonsai_tree.set_soil_moisture(GameState.moisture)


func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer >= 5.0:
		_save_timer = 0.0
		SaveManager.save_game(GameState.build_save_data())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("water"):
		_on_water_pressed()
	if event.is_action_pressed("open_settings"):
		settings.open()
	if event.is_action_pressed("tool_view"):
		_on_tool_mode_selected(0)
	if event.is_action_pressed("tool_prune"):
		_on_tool_mode_selected(1)
	if event.is_action_pressed("tool_graft"):
		_on_tool_mode_selected(2)


func _on_water_pressed() -> void:
	if GameState.request_water():
		pass


func _on_watering_started() -> void:
	if bonsai_tree.has_node("TreeEditor"):
		bonsai_tree.get_node("TreeEditor").set_enabled(false)


func _on_watering_finished() -> void:
	if bonsai_tree.has_node("TreeEditor"):
		bonsai_tree.get_node("TreeEditor").set_enabled(true)
	if bonsai_tree.has_method("set_soil_moisture"):
		bonsai_tree.set_soil_moisture(GameState.moisture)
	if bonsai_tree.has_method("play_happy_bounce"):
		bonsai_tree.play_happy_bounce()
	SaveManager.save_game(GameState.build_save_data())


func _on_moisture_changed(value: float) -> void:
	if bonsai_tree.has_method("set_soil_moisture"):
		bonsai_tree.set_soil_moisture(value)


func _on_settings_pressed() -> void:
	settings.open()


func _on_tool_mode_selected(mode: int) -> void:
	GameState.tool_mode = mode
	hud.set_tool_mode(mode)
	if bonsai_tree.has_node("TreeEditor"):
		bonsai_tree.get_node("TreeEditor").set_tool_mode(mode)
