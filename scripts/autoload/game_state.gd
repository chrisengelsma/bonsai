extends Node

const TreeGraphScript = preload("res://scripts/tree/tree_graph.gd")
const GameConfigScript = preload("res://scripts/game_config.gd")
const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")

signal moisture_changed(value: float)
signal growth_status_changed(is_growing: bool)
signal maturity_changed(label: String)
signal graph_changed
signal grow_speed_changed(value: float)
signal watering_started
signal watering_finished
signal species_changed(species)
signal settings_changed

var config
var species
var tree_graph
var moisture: float = 0.5
var grow_speed_multiplier: float = 1.0
var music_enabled: bool = true
var ambience_enabled: bool = true
var camera_yaw: float = 0.0
var camera_pitch: float = -10.0
var camera_distance: float = 3.0
var tool_mode: int = 0

var _is_watering: bool = false
var _water_cooldown: float = 0.0
var _is_growing: bool = false


func _ready() -> void:
	config = load("res://resources/game_config.tres")
	if config == null:
		config = GameConfigScript.new()


func _process(delta: float) -> void:
	if _water_cooldown > 0.0:
		_water_cooldown = maxf(0.0, _water_cooldown - delta)

	var soil = CatalogRegistry.get_equipped_soil()
	var decay_mult: float = soil.moisture_decay_mult if soil else 1.0
	moisture = maxf(0.0, moisture - config.moisture_decay_per_second * decay_mult * delta)
	moisture_changed.emit(moisture)

	var moisture_ok: bool = moisture >= config.growth_threshold
	if moisture_ok and tree_graph and species and not _is_watering:
		var soil_mult: float = soil.growth_mult if soil else 1.0
		tree_graph.grow(delta, species.grow_pattern, true, grow_speed_multiplier, soil_mult)
		_set_growing(true)
		maturity_changed.emit(tree_graph.get_maturity_label())
	else:
		_set_growing(false)


func _set_growing(value: bool) -> void:
	if _is_growing != value:
		_is_growing = value
		growth_status_changed.emit(value)


func initialize_new_tree(seed_id: String = "seed_classic_upright") -> void:
	var seed = CatalogRegistry.get_seed(seed_id)
	if seed == null or seed.species == null:
		push_error("GameState: missing seed %s" % seed_id)
		return
	species = seed.species
	GrowthLimits.clamp_pattern(species.grow_pattern if species else null)
	tree_graph = TreeGraphScript.new()
	if seed.starter_graph_override.is_empty():
		tree_graph.create_from_species(species)
	else:
		tree_graph.from_dict(seed.starter_graph_override)
		tree_graph.species_id = species.id
	moisture = config.default_moisture
	species_changed.emit(species)
	graph_changed.emit()
	maturity_changed.emit(tree_graph.get_maturity_label())


func load_from_save(data: Dictionary) -> void:
	var species_id := str(data.get("species_id", "classic_upright"))
	species = CatalogRegistry.get_species(species_id)
	if species == null:
		initialize_new_tree()
		return

	tree_graph = TreeGraphScript.new()
	var graph_data: Dictionary = data.get("tree_graph", {})
	if graph_data.is_empty():
		tree_graph.create_from_species(species)
	else:
		tree_graph.from_dict(graph_data)

	moisture = float(data.get("moisture", config.default_moisture))
	grow_speed_multiplier = float(data.get("grow_speed_multiplier", 1.0))
	music_enabled = bool(data.get("music_enabled", true))
	ambience_enabled = bool(data.get("ambience_enabled", true))
	camera_yaw = float(data.get("camera_yaw", 0.0))
	camera_pitch = float(data.get("camera_pitch", -10.0))
	camera_distance = float(data.get("camera_distance", 3.0))
	tool_mode = int(data.get("tool_mode", 0))

	var soil_id := str(data.get("soil_id", "soil_default"))
	CatalogRegistry.set_equipped_soil_id(soil_id)

	var owned: Array = data.get("owned_catalog_ids", [])
	if not owned.is_empty():
		CatalogRegistry.set_owned_ids(owned)

	_apply_offline_progress(data)
	species_changed.emit(species)
	graph_changed.emit()
	maturity_changed.emit(tree_graph.get_maturity_label())
	grow_speed_changed.emit(grow_speed_multiplier)


func _apply_offline_progress(data: Dictionary) -> void:
	var saved_time := int(data.get("timestamp", 0))
	if saved_time <= 0:
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed := minf(float(now - saved_time), config.offline_progress_cap_seconds)
	if elapsed <= 0.0:
		return

	var soil = CatalogRegistry.get_equipped_soil()
	var decay_mult: float = soil.moisture_decay_mult if soil else 1.0
	moisture = maxf(0.0, moisture - config.moisture_decay_per_second * decay_mult * elapsed)

	if moisture >= config.growth_threshold and tree_graph and species:
		var soil_mult: float = soil.growth_mult if soil else 1.0
		tree_graph.grow(elapsed, species.grow_pattern, true, grow_speed_multiplier, soil_mult)


func build_save_data() -> Dictionary:
	var graph_data := {}
	if tree_graph:
		graph_data = tree_graph.to_dict()
	return {
		"species_id": species.id if species else "classic_upright",
		"soil_id": CatalogRegistry.get_equipped_soil_id(),
		"tree_graph": graph_data,
		"moisture": moisture,
		"grow_speed_multiplier": grow_speed_multiplier,
		"owned_catalog_ids": CatalogRegistry.get_owned_ids(),
		"placed_decorations": [],
		"music_enabled": music_enabled,
		"ambience_enabled": ambience_enabled,
		"camera_yaw": camera_yaw,
		"camera_pitch": camera_pitch,
		"camera_distance": camera_distance,
		"tool_mode": tool_mode,
	}


func request_water() -> bool:
	if _is_watering or _water_cooldown > 0.0:
		return false
	_is_watering = true
	watering_started.emit()
	return true


func complete_watering() -> void:
	moisture = minf(1.0, moisture + config.moisture_water_boost)
	moisture_changed.emit(moisture)
	_is_watering = false
	_water_cooldown = config.watering_cooldown_seconds
	watering_finished.emit()
	AudioManager.play_sfx("growth")


func set_grow_speed_multiplier(value: float) -> void:
	grow_speed_multiplier = GrowthLimits.clamp_game_grow_speed(value)
	grow_speed_changed.emit(grow_speed_multiplier)


func is_watering() -> bool:
	return _is_watering


func can_water() -> bool:
	return not _is_watering and _water_cooldown <= 0.0


func reset_progress(seed_id: String = "seed_classic_upright") -> void:
	initialize_new_tree(seed_id)
	moisture = config.default_moisture
	grow_speed_multiplier = 1.0
