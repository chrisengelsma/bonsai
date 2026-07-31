extends Node3D
class_name TreeRenderer

const BranchMeshBuilder = preload("res://scripts/tree/branch_mesh_builder.gd")

signal branch_clicked(branch_id: int)

@export var trunk_material: Material
@export var foliage_material: StandardMaterial3D
@export var graft_material: Material
@export var cut_material: Material
@export var radial_segments: int = 10
@export var ring_count: int = 3
@export var bark_variation: float = 0.11
@export var thickness_visual_scale: float = 1.18

var _graph
var _species
var _segment_pool: Dictionary = {}
var _foliage_pool: Dictionary = {}
var _cap_pool: Dictionary = {}
var _graft_pool: Dictionary = {}
var _collar_pool: Dictionary = {}
var _pick_areas: Dictionary = {}
var _segments_root: Node3D
var _foliage_root: Node3D
var _caps_root: Node3D


func _ready() -> void:
	_segments_root = Node3D.new()
	_segments_root.name = "Segments"
	add_child(_segments_root)
	_foliage_root = Node3D.new()
	_foliage_root.name = "Foliage"
	add_child(_foliage_root)
	_caps_root = Node3D.new()
	_caps_root.name = "Caps"
	add_child(_caps_root)


func setup(graph, species) -> void:
	_graph = graph
	_species = species
	_ensure_materials()
	_apply_species_colors()
	if _graph:
		if not _graph.graph_changed.is_connected(rebuild):
			_graph.graph_changed.connect(rebuild)
	rebuild()


func _ensure_materials() -> void:
	if trunk_material == null:
		var bark_shader := load("res://shaders/bark.gdshader") as Shader
		if bark_shader:
			var bark_mat := ShaderMaterial.new()
			bark_mat.shader = bark_shader
			bark_mat.set_shader_parameter("bark_color", _species.trunk_color if _species else Color(0.55, 0.35, 0.2))
			trunk_material = bark_mat
		else:
			trunk_material = StandardMaterial3D.new()
			trunk_material.albedo_color = _species.trunk_color if _species else Color(0.55, 0.35, 0.2)
			trunk_material.roughness = 0.94
	if foliage_material == null:
		foliage_material = StandardMaterial3D.new()
		foliage_material.albedo_color = _species.foliage_color if _species else Color(0.42, 0.56, 0.44)
	if graft_material == null:
		graft_material = trunk_material.duplicate()
		if graft_material is StandardMaterial3D:
			graft_material.albedo_color = Color(0.79, 0.66, 0.42)
		elif graft_material is ShaderMaterial:
			graft_material.set_shader_parameter("bark_color", Color(0.79, 0.66, 0.42))
	if cut_material == null:
		cut_material = trunk_material.duplicate()
		if cut_material is StandardMaterial3D:
			cut_material.albedo_color = _species.trunk_color.lightened(0.2) if _species else Color(0.7, 0.55, 0.35)
		elif cut_material is ShaderMaterial:
			cut_material.set_shader_parameter("bark_color", _species.trunk_color.lightened(0.2) if _species else Color(0.7, 0.55, 0.35))


func _apply_species_colors() -> void:
	if _species == null:
		return
	if trunk_material is ShaderMaterial:
		trunk_material.set_shader_parameter("bark_color", _species.trunk_color)
	elif trunk_material is StandardMaterial3D:
		trunk_material.albedo_color = _species.trunk_color
	if foliage_material:
		foliage_material.albedo_color = _species.foliage_color


func rebuild() -> void:
	if _graph == null:
		return
	_hide_all_pools()
	for node_id in _graph.nodes.keys():
		_render_branch(node_id)


func _hide_all_pools() -> void:
	for key in _segment_pool.keys():
		_segment_pool[key].visible = false
	for key in _foliage_pool.keys():
		_foliage_pool[key].visible = false
	for key in _cap_pool.keys():
		_cap_pool[key].visible = false
	for key in _graft_pool.keys():
		_graft_pool[key].visible = false
	for key in _collar_pool.keys():
		_collar_pool[key].visible = false


func _render_branch(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= 0.001:
		return

	_graph.ensure_profile_render_ready(node)

	var start: Vector3 = _graph.get_joint(node_id)
	var tip_offset: Vector3 = BranchMeshBuilder.get_profile_tip_offset(node.ring_samples)
	if tip_offset.length_squared() <= 0.0001:
		tip_offset = node.direction * node.length
	var end: Vector3 = start + tip_offset

	var bottom_radius: float = _get_base_radius(node_id) * thickness_visual_scale
	var top_radius: float = _get_tip_radius(node_id) * thickness_visual_scale

	var mesh_instance := _get_segment(node_id)
	mesh_instance.visible = true
	var profile_mesh: ArrayMesh = BranchMeshBuilder.build_solid_branch(
		node.ring_samples,
		node.locked_wobble,
		radial_segments,
		node.length
	)

	if profile_mesh != null:
		mesh_instance.mesh = profile_mesh
		mesh_instance.position = start
		mesh_instance.basis = Basis.IDENTITY
	else:
		var direction: Vector3 = (end - start).normalized()
		var height: float = start.distance_to(end)
		mesh_instance.mesh = BranchMeshBuilder.build_tapered_segment(
			height,
			bottom_radius,
			top_radius,
			radial_segments,
			ring_count,
			bark_variation,
			node_id
		)
		mesh_instance.position = start + direction * (height * 0.5)
		_orient_segment(mesh_instance, start, direction, height)

	if node.is_graft:
		mesh_instance.material_override = graft_material
		var graft_marker := _get_graft_marker(node_id)
		graft_marker.visible = true
		graft_marker.position = start
	else:
		mesh_instance.material_override = trunk_material

	if node.cut_timestamp >= 0.0:
		var cap := _get_cap(node_id)
		cap.visible = true
		cap.position = end
		var direction: Vector3 = (end - start).normalized()
		var height: float = maxf(start.distance_to(end), top_radius * 0.35)
		cap.mesh = BranchMeshBuilder.build_tapered_segment(
			top_radius * 0.35,
			top_radius,
			top_radius * 0.15,
			maxi(6, radial_segments - 2),
			1,
			bark_variation * 0.5,
			node_id + 9173
		)
		_orient_segment(cap, end - direction * (top_radius * 0.175), direction, top_radius * 0.35)
		cap.material_override = cut_material

	if node.foliage_amount > 0.05:
		var foliage := _get_foliage(node_id)
		foliage.visible = true
		foliage.position = end
		var foliage_scale: float = 0.05 + node.foliage_amount * 0.1
		foliage.scale = Vector3.ONE * foliage_scale
		if node.graft_species_id != "":
			var mat := foliage_material.duplicate()
			mat.albedo_color = mat.albedo_color.lerp(Color(0.5, 0.65, 0.5), 0.3)
			foliage.material_override = mat
		else:
			foliage.material_override = foliage_material

	_update_pick_area(node_id, start, end, node.thickness * thickness_visual_scale)


func _get_base_radius(node_id: int) -> float:
	var node = _graph.nodes[node_id]
	return maxf(node.thickness, 0.008)


func _get_tip_radius(node_id: int) -> float:
	var node = _graph.nodes[node_id]
	if node.children.is_empty():
		return node.thickness * 0.74

	var largest_child: float = 0.0
	for child_id in node.children:
		largest_child = maxf(largest_child, _graph.nodes[child_id].thickness)
	return maxf(node.thickness * 0.86, largest_child * 1.04)


func _orient_segment(mesh_instance: MeshInstance3D, start: Vector3, direction: Vector3, height: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	mesh_instance.position = start + direction * (height * 0.5)
	var up: Vector3 = Vector3.UP
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.FORWARD
	mesh_instance.basis = Basis.looking_at(direction, up)
	mesh_instance.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _orient_collar(mesh_instance: MeshInstance3D, direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		return
	var up: Vector3 = Vector3.UP
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.FORWARD
	mesh_instance.basis = Basis.looking_at(direction, up)
	mesh_instance.rotate_object_local(Vector3.RIGHT, PI * 0.5)


func _get_segment(node_id: int) -> MeshInstance3D:
	if not _segment_pool.has(node_id):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Segment_%d" % node_id
		_segments_root.add_child(mesh_instance)
		_segment_pool[node_id] = mesh_instance
	return _segment_pool[node_id]


func _get_collar(node_id: int) -> MeshInstance3D:
	if not _collar_pool.has(node_id):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.material_override = trunk_material
		mesh_instance.name = "Collar_%d" % node_id
		_segments_root.add_child(mesh_instance)
		_collar_pool[node_id] = mesh_instance
	return _collar_pool[node_id]


func _get_foliage(node_id: int) -> MeshInstance3D:
	if not _foliage_pool.has(node_id):
		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 8
		sphere.rings = 6
		mesh_instance.mesh = sphere
		mesh_instance.name = "Foliage_%d" % node_id
		_foliage_root.add_child(mesh_instance)
		_foliage_pool[node_id] = mesh_instance
	return _foliage_pool[node_id]


func _get_cap(node_id: int) -> MeshInstance3D:
	if not _cap_pool.has(node_id):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Cap_%d" % node_id
		_caps_root.add_child(mesh_instance)
		_cap_pool[node_id] = mesh_instance
	return _cap_pool[node_id]


func _get_graft_marker(node_id: int) -> MeshInstance3D:
	if not _graft_pool.has(node_id):
		var mesh_instance := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.3
		torus.outer_radius = 0.5
		torus.rings = 8
		mesh_instance.mesh = torus
		mesh_instance.material_override = graft_material
		mesh_instance.name = "Graft_%d" % node_id
		_caps_root.add_child(mesh_instance)
		_graft_pool[node_id] = mesh_instance
	return _graft_pool[node_id]


func _update_pick_area(node_id: int, start: Vector3, end: Vector3, thickness: float) -> void:
	var area: Area3D
	if _pick_areas.has(node_id):
		area = _pick_areas[node_id]
	else:
		area = Area3D.new()
		area.name = "Pick_%d" % node_id
		var collision := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		collision.name = "Collision"
		collision.shape = shape
		area.add_child(collision)
		area.input_event.connect(_on_branch_input_event.bind(node_id))
		add_child(area)
		_pick_areas[node_id] = area

	var midpoint := (start + end) * 0.5
	var direction := (end - start).normalized()
	var height := start.distance_to(end)
	area.position = midpoint
	if direction.length_squared() > 0.0001:
		var up: Vector3 = Vector3.UP
		if absf(direction.dot(up)) > 0.98:
			up = Vector3.FORWARD
		area.basis = Basis.looking_at(direction, up)
		area.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var collision_shape: CollisionShape3D = area.get_node("Collision")
	var capsule: CapsuleShape3D = collision_shape.shape
	capsule.radius = maxf(thickness, 0.02)
	capsule.height = maxf(height, 0.04)


func _on_branch_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, branch_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		branch_clicked.emit(branch_id)
	if event is InputEventScreenTouch and event.pressed:
		branch_clicked.emit(branch_id)


func play_happy_bounce() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.03, 0.97, 1.03), 0.15)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
