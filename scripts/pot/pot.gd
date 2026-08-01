extends Node3D

const PotBoundsClass = preload("res://scripts/pot/pot_bounds.gd")
const GrowthBarrierClass = preload("res://scripts/roots/growth_barrier.gd")
const RootGrowthFieldClass = preload("res://scripts/roots/root_growth_field.gd")

@export var bowl_floor_y: float = 0.0
@export var bowl_top_radius: float = 1.32
@export var bowl_bottom_radius: float = 1.08
@export var bowl_height: float = 0.36
@export var bowl_wall_thickness: float = 0.24
@export var root_anchor_height: float = 0.36
@export var root_growth_ceiling_y: float = 0.36
@export var barrier_padding: float = 0.012

@onready var _pot_mesh: MeshInstance3D = $PotMesh
@onready var _rocks_root: Node3D = $Rocks
@onready var _decoration_anchor: Node3D = $DecorationAnchor


func _ready() -> void:
	_sync_anchors()
	_apply_bowl_material()
	_apply_rock_materials()


func get_bounds():
	return PotBoundsClass.from_pot_mesh(
		bowl_floor_y,
		root_growth_ceiling_y,
		bowl_top_radius,
		bowl_bottom_radius,
		bowl_wall_thickness
	)


func get_growth_field():
	return RootGrowthFieldClass.create(get_bounds(), get_growth_barriers())


func get_growth_barriers() -> Array:
	var barriers: Array = []
	if _rocks_root == null:
		return barriers
	for child in _rocks_root.get_children():
		if child is MeshInstance3D:
			barriers.append(GrowthBarrierClass.from_mesh_instance(child, barrier_padding))
	return barriers


func get_tree_anchor_height() -> float:
	return bowl_height


func get_root_anchor() -> Vector3:
	return Vector3(0.0, get_tree_anchor_height(), 0.0)


func _sync_anchors() -> void:
	if _decoration_anchor != null:
		_decoration_anchor.position.y = get_tree_anchor_height()


func _apply_bowl_material() -> void:
	if _pot_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.77, 0.55, 0.42, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.55
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	_pot_mesh.material_override = material


func _apply_rock_materials() -> void:
	if _rocks_root == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.46, 0.43, 1.0)
	material.roughness = 0.88
	for child in _rocks_root.get_children():
		if child is MeshInstance3D:
			child.material_override = material
