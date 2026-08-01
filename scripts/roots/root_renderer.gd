extends Node3D
class_name RootRenderer

@export var line_color: Color = Color(1.0, 0.12, 0.08, 1.0)
@export var line_radius: float = 0.00085
@export var smooth_samples_per_segment: int = 3

const MIN_SEGMENT_LENGTH := 0.00008
const MAX_SEGMENT_LENGTH := 0.05

var show_roots: bool = true

var _graph
var _multimesh_instance: MultiMeshInstance3D
var _line_template: CylinderMesh
var _material: StandardMaterial3D
var _cached_segment_count: int = 0


func _ready() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "RootLines"
	add_child(_multimesh_instance)
	_ensure_material()
	_ensure_line_template()
	_apply_visibility()


func setup(graph) -> void:
	if _graph != null and _graph.graph_changed.is_connected(_on_graph_changed):
		_graph.graph_changed.disconnect(_on_graph_changed)

	_graph = graph
	_cached_segment_count = 0
	_ensure_material()
	_ensure_line_template()

	if _graph != null:
		_graph.graph_changed.connect(_on_graph_changed)

	if show_roots and _graph != null:
		_rebuild_mesh()
	else:
		_clear_mesh()


func set_show_roots(enabled: bool) -> void:
	if show_roots == enabled:
		_apply_visibility()
		return

	show_roots = enabled
	_apply_visibility()

	if show_roots and _graph != null:
		_rebuild_mesh()
	elif not show_roots:
		_clear_mesh()


func _apply_visibility() -> void:
	if _multimesh_instance == null:
		return
	_multimesh_instance.visible = show_roots and _cached_segment_count > 0


func _on_graph_changed() -> void:
	if show_roots and _graph != null:
		_rebuild_mesh()


func _clear_mesh() -> void:
	if _multimesh_instance == null:
		return
	if _multimesh_instance.multimesh != null:
		_multimesh_instance.multimesh.instance_count = 0
	_multimesh_instance.visible = false
	_cached_segment_count = 0


func _ensure_material() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
	_material.albedo_color = line_color
	_material.emission_enabled = true
	_material.emission = line_color
	_material.emission_energy_multiplier = 1.25
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _ensure_line_template() -> void:
	if _line_template == null:
		_line_template = CylinderMesh.new()
		_line_template.top_radius = 0.5
		_line_template.bottom_radius = 0.5
		_line_template.height = 1.0
		_line_template.radial_segments = 8
		_line_template.rings = 1


func _rebuild_mesh() -> void:
	if _graph == null or not show_roots:
		_clear_mesh()
		return

	var segments: Array = []
	for node_id in _graph.nodes.keys():
		var node = _graph.nodes[node_id]
		var points: PackedVector3Array = _graph.get_render_points(node)
		if points.size() < 2:
			continue
		var smooth_points: PackedVector3Array = _smooth_polyline(points)
		for i in range(smooth_points.size() - 1):
			var start: Vector3 = smooth_points[i]
			var end: Vector3 = smooth_points[i + 1]
			if _is_valid_segment(start, end):
				segments.append([start, end])

	var segment_count: int = segments.size()
	if segment_count <= 0:
		_clear_mesh()
		return

	var multimesh: MultiMesh = _multimesh_instance.multimesh
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = false
		multimesh.mesh = _line_template
		_multimesh_instance.multimesh = multimesh

	if multimesh.instance_count != segment_count:
		multimesh.instance_count = segment_count
	_cached_segment_count = segment_count

	for i in range(segment_count):
		var segment: Array = segments[i]
		multimesh.set_instance_transform(i, _segment_transform(segment[0], segment[1]))

	_multimesh_instance.material_override = _material
	_multimesh_instance.visible = true


func _is_valid_segment(start: Vector3, end: Vector3) -> bool:
	var length: float = start.distance_to(end)
	return length >= MIN_SEGMENT_LENGTH and length <= MAX_SEGMENT_LENGTH


func _smooth_polyline(points: PackedVector3Array) -> PackedVector3Array:
	if points.size() < 2:
		return points

	var samples: int = maxi(smooth_samples_per_segment, 2)
	var smooth := PackedVector3Array()
	for i in range(points.size() - 1):
		var start: Vector3 = points[i]
		var end: Vector3 = points[i + 1]
		for step in range(samples):
			var t: float = float(step) / float(samples)
			smooth.append(start.lerp(end, t))
	smooth.append(points[points.size() - 1])
	return smooth


func _segment_transform(start: Vector3, end: Vector3) -> Transform3D:
	var delta: Vector3 = end - start
	var length: float = delta.length()
	if length <= MIN_SEGMENT_LENGTH:
		return Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), start)

	var direction: Vector3 = delta / length
	var up: Vector3 = Vector3.UP
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.FORWARD

	var basis: Basis = Basis.looking_at(direction, up)
	basis = basis * Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
	var radius_scale: float = line_radius * 2.0
	basis = basis.scaled(Vector3(radius_scale, length, radius_scale))
	return Transform3D(basis, start + direction * (length * 0.5))
