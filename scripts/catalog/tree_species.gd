class_name TreeSpecies
extends Resource

const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")

@export var id: String = ""
@export var display_name: String = ""
@export var grow_pattern: Resource
@export var foliage: FoliagePreset
@export var trunk_color: Color = Color(0.55, 0.35, 0.2)
@export var foliage_color: Color = Color(0.42, 0.56, 0.44)
@export var basal_form: String = "standard"
@export var starter_graph: Dictionary = {}
