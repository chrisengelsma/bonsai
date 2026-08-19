extends Node3D
class_name FoliageRenderer

const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")
const FoliageMeshBuilder = preload("res://scripts/tree/foliage_mesh_builder.gd")
const FoliagePlacer = preload("res://scripts/tree/foliage_placer.gd")

const LEAF_SWAY_SHADER := preload("res://shaders/leaf_sway.gdshader")

var _graph
var _species
var _preset: FoliagePreset
var _multimesh_instance: MultiMeshInstance3D
var _material: ShaderMaterial
var _mesh_style: int = -1
var _instance_registry: Dictionary = {}
var show_foliage: bool = true


func _ready() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "LiveFoliage"
	add_child(_multimesh_instance)


func setup(graph, species) -> void:
	set_context(graph, species)
	rebuild()


func set_context(graph, species) -> void:
	_graph = graph
	_species = species
	_preset = FoliagePreset.resolve(species)


func rebuild() -> void:
	_instance_registry.clear()
	if _multimesh_instance == null:
		return
	if not show_foliage:
		_clear_mesh()
		return
	if _graph == null or _preset == null or _preset.mesh_style == FoliagePreset.MeshStyle.NONE:
		_clear_mesh()
		return

	var placements: Array = FoliagePlacer.collect_placements(_graph, _preset, _species)
	if placements.is_empty():
		_clear_mesh()
		return

	_ensure_material()
	_ensure_multimesh(placements.size())

	for i in range(placements.size()):
		var placement: Dictionary = placements[i]
		_multimesh_instance.multimesh.set_instance_transform(i, placement.transform)
		_multimesh_instance.multimesh.set_instance_custom_data(i, placement.custom)
		_instance_registry[i] = {
			"tip_id": placement.tip_id,
			"slot": placement.slot,
		}

	_multimesh_instance.visible = true


func get_instance_registry() -> Dictionary:
	return _instance_registry


func _process(_delta: float) -> void:
	_update_wind_uniforms()


func _clear_mesh() -> void:
	if _multimesh_instance == null:
		return
	if _multimesh_instance.multimesh != null:
		_multimesh_instance.multimesh.instance_count = 0
	_multimesh_instance.visible = false


func _ensure_material() -> void:
	if _material != null and _mesh_style == _preset.mesh_style:
		_apply_preset_to_material()
		return

	_material = ShaderMaterial.new()
	_material.shader = LEAF_SWAY_SHADER
	_mesh_style = _preset.mesh_style
	_multimesh_instance.material_override = _material
	_apply_preset_to_material()


func _apply_preset_to_material() -> void:
	if _material == null or _preset == null:
		return
	_material.set_shader_parameter("foliage_color", _resolve_albedo_color())
	_material.set_shader_parameter("sway_amount", _preset.sway_amount)
	_material.set_shader_parameter("sway_speed", _preset.sway_speed)
	_material.set_shader_parameter("underside_darken", _preset.underside_darken)
	_material.set_shader_parameter("petiole_length", _petiole_length_for_style(_preset.mesh_style))


func _resolve_albedo_color() -> Color:
	if _species != null and "foliage_color" in _species:
		return _species.foliage_color
	if _preset != null:
		return _preset.albedo_color
	return Color(0.42, 0.56, 0.44)


func _petiole_length_for_style(style: int) -> float:
	match style:
		FoliagePreset.MeshStyle.BROADLEAF:
			return 0.009
		FoliagePreset.MeshStyle.NEEDLE:
			return 0.004
		FoliagePreset.MeshStyle.SCALE:
			return 0.003
		FoliagePreset.MeshStyle.CLUSTER:
			return 0.02
		_:
			return 0.009


func _update_wind_uniforms() -> void:
	if _material == null or _preset == null:
		return
	var wind = _get_foliage_wind()
	if wind == null:
		return
	var sensitivity: float = _preset.tilt_sensitivity
	_material.set_shader_parameter("wind_tilt", wind.wind_tilt * sensitivity)
	_material.set_shader_parameter("wind_strength", wind.wind_strength * sensitivity)


func _get_foliage_wind():
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("FoliageWind")


func _ensure_multimesh(instance_count: int) -> void:
	var mesh := FoliageMeshBuilder.get_mesh(_preset.mesh_style, _preset)
	var multimesh: MultiMesh = _multimesh_instance.multimesh
	if multimesh == null or multimesh.mesh != mesh:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		_multimesh_instance.multimesh = multimesh

	if multimesh.instance_count != instance_count:
		multimesh.instance_count = instance_count
