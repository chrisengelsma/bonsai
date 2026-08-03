extends Node3D
class_name LSystemSkeletonRenderer

const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")
const MeshConstants = preload("res://scripts/util/mesh_constants.gd")

@export var line_color: Color = Color(0.55, 0.35, 0.2, 1.0)
@export var line_width: float = 0.004
@export var seed_color: Color = Color(0.95, 0.12, 0.08, 1.0)
@export var seed_radius: float = 0.012

var _line_mesh_instance: MeshInstance3D
var _multimesh_instance: MultiMeshInstance3D
var _line_template: CylinderMesh
var _seed_mesh: MeshInstance3D
var _seed_sphere: SphereMesh
var _material: StandardMaterial3D
var _seed_material: StandardMaterial3D
var _render_cylinders: bool = false


func _ready() -> void:
	_line_template = _make_line_template()
	_seed_sphere = SphereMesh.new()
	_seed_sphere.radius = seed_radius
	_seed_sphere.height = seed_radius * 2.0
	_seed_sphere.radial_segments = 8
	_seed_sphere.rings = 6

	_line_mesh_instance = MeshInstance3D.new()
	_line_mesh_instance.name = "SkeletonLines"
	add_child(_line_mesh_instance)

	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "SkeletonCylinders"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _line_template
	_multimesh_instance.multimesh = multimesh
	add_child(_multimesh_instance)

	_seed_mesh = MeshInstance3D.new()
	_seed_mesh.name = "Seed"
	add_child(_seed_mesh)

	_ensure_materials()


func clear() -> void:
	_line_mesh_instance.mesh = null
	_line_mesh_instance.visible = false
	if _multimesh_instance.multimesh != null:
		_multimesh_instance.multimesh.instance_count = 0
	_multimesh_instance.visible = false
	_seed_mesh.visible = false


func set_segments(
	segments: Array,
	color: Color = line_color,
	width: float = line_width,
	seed_position: Vector3 = Vector3.ZERO,
	render_cylinders: bool = false
) -> void:
	line_color = color
	line_width = width
	_render_cylinders = render_cylinders
	_ensure_materials()
	_material.albedo_color = line_color
	_show_seed(seed_position)

	var valid_segments: Array = _filter_valid_segments(segments)
	if valid_segments.is_empty():
		clear()
		_show_seed(seed_position)
		return

	if _render_cylinders:
		_set_cylinder_segments(valid_segments)
	else:
		_set_line_segments(valid_segments)


func _set_line_segments(segments: Array) -> void:
	_multimesh_instance.visible = false
	if _multimesh_instance.multimesh != null:
		_multimesh_instance.multimesh.instance_count = 0

	_line_mesh_instance.mesh = _build_line_mesh(segments)
	_line_mesh_instance.material_override = _material
	_line_mesh_instance.visible = true


func _set_cylinder_segments(segments: Array) -> void:
	_line_mesh_instance.mesh = null
	_line_mesh_instance.visible = false

	var multimesh: MultiMesh = _multimesh_instance.multimesh
	var count: int = segments.size()
	if multimesh.instance_count != count:
		multimesh.instance_count = count

	var radius_scale: float = maxf(line_width, 0.001) * 2.0
	for i in range(count):
		var segment: Dictionary = segments[i]
		var start: Vector3 = segment.get("from", Vector3.ZERO)
		var end: Vector3 = segment.get("to", Vector3.ZERO)
		multimesh.set_instance_transform(
			i,
			Vector3Frame.cylinder_transform(start, end, radius_scale)
		)

	_multimesh_instance.material_override = _material
	_multimesh_instance.visible = true


func _build_line_mesh(segments: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for segment in segments:
		var start: Vector3 = segment.get("from", Vector3.ZERO)
		var end: Vector3 = segment.get("to", Vector3.ZERO)
		st.add_vertex(start)
		st.add_vertex(end)
	return st.commit()


func _filter_valid_segments(segments: Array) -> Array:
	var valid: Array = []
	for segment in segments:
		if segment is not Dictionary:
			continue
		var start: Vector3 = segment.get("from", Vector3.ZERO)
		var end: Vector3 = segment.get("to", Vector3.ZERO)
		if start.distance_squared_to(end) > MeshConstants.DIR_EPSILON_SQ:
			valid.append(segment)
	return valid


func _show_seed(seed_position: Vector3) -> void:
	_seed_material.albedo_color = seed_color
	_seed_mesh.mesh = _seed_sphere
	_seed_mesh.position = seed_position
	_seed_mesh.material_override = _seed_material
	_seed_mesh.visible = true


func _ensure_materials() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
	_material.albedo_color = line_color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if _seed_material == null:
		_seed_material = StandardMaterial3D.new()
	_seed_material.albedo_color = seed_color
	_seed_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


static func _make_line_template() -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 5
	cylinder.rings = 1
	return cylinder
