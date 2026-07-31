extends Node

const CatalogScript = preload("res://scripts/catalog/game_catalog.gd")

const CATALOG_PATH := "res://resources/catalog/default_catalog.tres"

var _catalog
var _owned_ids: Array[String] = []
var _equipped_soil_id: String = "soil_default"


func _ready() -> void:
	_catalog = load(CATALOG_PATH)
	_init_free_ownership()


func _init_free_ownership() -> void:
	_owned_ids.clear()
	if _catalog == null:
		return
	for seed in _catalog.seeds:
		if seed.unlock_type == "free":
			_owned_ids.append(seed.id)
	for soil in _catalog.soils:
		if soil.unlock_type == "free":
			_owned_ids.append(soil.id)


func set_owned_ids(ids: Array) -> void:
	_owned_ids.clear()
	for id in ids:
		_owned_ids.append(str(id))
	_init_free_ownership()


func get_owned_ids() -> Array[String]:
	return _owned_ids.duplicate()


func is_owned(id: String) -> bool:
	return _owned_ids.has(id)


func get_seed(id: String):
	if _catalog == null:
		return null
	for seed in _catalog.seeds:
		if seed.id == id:
			return seed
	return null


func get_species(species_id: String):
	if _catalog == null:
		return null
	for seed in _catalog.seeds:
		if seed.species and seed.species.id == species_id:
			return seed.species
	return null


func get_soil(id: String):
	if _catalog == null:
		return null
	for soil in _catalog.soils:
		if soil.id == id:
			return soil
	return null


func get_equipped_soil():
	var soil = get_soil(_equipped_soil_id)
	if soil:
		return soil
	if _catalog and not _catalog.soils.is_empty():
		return _catalog.soils[0]
	return null


func set_equipped_soil_id(id: String) -> void:
	_equipped_soil_id = id


func get_equipped_soil_id() -> String:
	return _equipped_soil_id


func get_all_seeds() -> Array:
	if _catalog:
		return _catalog.seeds
	return []


func purchase(id: String) -> void:
	if is_owned(id):
		return
	print("CatalogRegistry: IAP not implemented for ", id)
