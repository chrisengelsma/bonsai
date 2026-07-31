extends Node3D
class_name TreeRenderer

signal branch_clicked(branch_id: int, hit_position: Vector3)

@export var trunk_material: Material
@export var graft_material: Material
@export var cut_material: Material
@export var radial_segments: int = 10
@export var thickness_visual_scale: float = 1.0
@export var prune_hover_enabled: bool = false
@export var prune_ring_min_radius: float = 0.018

var _graph
var _species
var _segment_pool: Dictionary = {}
var _cap_pool: Dictionary = {}
var _graft_pool: Dictionary = {}
var _pick_areas: Dictionary = {}
var _segments_root: Node3D
var _caps_root: Node3D
var _hover_ring: MeshInstance3D
var _click_start: Vector2 = Vector2.ZERO
var _click_pending: bool = false


func _ready() -> void:
	_segments_root = Node3D.new()
	_segments_root.name = "Segments"
	add_child(_segments_root)
	_caps_root = Node3D.new()
	_caps_root.name = "Caps"
	add_child(_caps_root)
	_hover_ring = _create_hover_ring()


func _process(_delta: float) -> void:
	if not prune_hover_enabled or _graph == null:
		if _hover_ring:
			_hover_ring.visible = false
		return

	var hit: Dictionary = _pick_branch_at_mouse()
	if hit.is_empty():
		_hover_ring.visible = false
		return

	_update_hover_ring(hit.branch_id, hit.position)


func _unhandled_input(event: InputEvent) -> void:
	if not prune_hover_enabled or _graph == null:
		return
	if handle_prune_input(event):
		get_viewport().set_input_as_handled()


func handle_prune_input(event: InputEvent) -> bool:
	if not prune_hover_enabled or _graph == null:
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_start = event.position
			_click_pending = true
			return false
		if not _click_pending:
			return false
		_click_pending = false
		if _click_start.distance_to(event.position) > 18.0:
			return false
		var hit: Dictionary = _pick_branch_at_mouse()
		if hit.is_empty():
			return false
		_update_hover_ring(hit.branch_id, hit.position)
		branch_clicked.emit(hit.branch_id, _prune_hit_on_branch(hit.branch_id, hit.position))
		return true

	if event is InputEventScreenTouch and event.pressed:
		var hit: Dictionary = _pick_branch_at_mouse()
		if hit.is_empty():
			return false
		_update_hover_ring(hit.branch_id, hit.position)
		branch_clicked.emit(hit.branch_id, _prune_hit_on_branch(hit.branch_id, hit.position))
		return true

	return false


func set_prune_hover_enabled(enabled: bool) -> void:
	prune_hover_enabled = enabled
	if not enabled and _hover_ring:
		_hover_ring.visible = false


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
		trunk_material = StandardMaterial3D.new()
		trunk_material.albedo_color = _species.trunk_color if _species else Color(0.55, 0.35, 0.2)
		trunk_material.roughness = 0.94
	if graft_material == null:
		graft_material = trunk_material.duplicate()
		if graft_material is StandardMaterial3D:
			graft_material.albedo_color = Color(0.79, 0.66, 0.42)
	if cut_material == null:
		cut_material = trunk_material.duplicate()
		if cut_material is StandardMaterial3D:
			cut_material.albedo_color = _species.trunk_color.lightened(0.2) if _species else Color(0.7, 0.55, 0.35)


func _apply_species_colors() -> void:
	if _species == null:
		return
	if trunk_material is StandardMaterial3D:
		trunk_material.albedo_color = _species.trunk_color


func rebuild() -> void:
	if _graph == null:
		return

	var live_ids: Dictionary = {}
	for node_id in _graph.nodes.keys():
		live_ids[node_id] = true

	_hide_all_pools()
	_cleanup_stale_pools(live_ids)

	for node_id in _graph.nodes.keys():
		_render_branch(node_id)


func _cleanup_stale_pools(live_ids: Dictionary) -> void:
	for node_id in _segment_pool.keys():
		if not live_ids.has(node_id):
			_segment_pool[node_id].queue_free()
			_segment_pool.erase(node_id)
	for node_id in _cap_pool.keys():
		if not live_ids.has(node_id):
			_cap_pool[node_id].queue_free()
			_cap_pool.erase(node_id)
	for node_id in _graft_pool.keys():
		if not live_ids.has(node_id):
			_graft_pool[node_id].queue_free()
			_graft_pool.erase(node_id)
	for node_id in _pick_areas.keys():
		if not live_ids.has(node_id):
			var area: Area3D = _pick_areas[node_id]
			if is_instance_valid(area):
				area.queue_free()
			_pick_areas.erase(node_id)


func _hide_all_pools() -> void:
	for key in _segment_pool.keys():
		_segment_pool[key].visible = false
	for key in _cap_pool.keys():
		_cap_pool[key].visible = false
	for key in _graft_pool.keys():
		_graft_pool[key].visible = false


func _render_branch(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= 0.001:
		return

	var start: Vector3 = _graph.get_joint(node_id)
	var end: Vector3 = _graph.get_world_tip(node_id)
	var direction: Vector3 = (end - start).normalized()
	var height: float = maxf(start.distance_to(end), 0.02)

	var bottom_radius: float = _get_base_radius(node_id) * thickness_visual_scale
	var top_radius: float = _get_tip_radius(node_id) * thickness_visual_scale

	var mesh_instance := _get_segment(node_id)
	mesh_instance.visible = true
	mesh_instance.mesh = _build_cylinder(height, bottom_radius, top_radius)
	_orient_segment(mesh_instance, start, direction, height)
	mesh_instance.material_override = graft_material if node.is_graft else trunk_material

	if node.is_graft:
		var graft_marker := _get_graft_marker(node_id)
		graft_marker.visible = true
		graft_marker.position = start

	if node.cut_timestamp >= 0.0:
		var cap := _get_cap(node_id)
		cap.visible = true
		cap.mesh = _build_cylinder(
			top_radius * 0.35,
			top_radius,
			top_radius * 0.15
		)
		_orient_segment(cap, end - direction * (top_radius * 0.175), direction, top_radius * 0.35)
		cap.material_override = cut_material

	_update_pick_area(node_id, start, end, node.thickness * thickness_visual_scale)


func _build_cylinder(height: float, bottom_radius: float, top_radius: float) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.height = maxf(height, 0.02)
	cylinder.bottom_radius = maxf(bottom_radius, 0.003)
	cylinder.top_radius = maxf(top_radius, 0.003)
	cylinder.radial_segments = maxi(radial_segments, 6)
	return cylinder


func _get_base_radius(node_id: int) -> float:
	return _graph.get_radius_at_dist(node_id, 0.0)


func _get_tip_radius(node_id: int) -> float:
	var node = _graph.nodes[node_id]
	return _graph.get_radius_at_dist(node_id, node.length)


func _get_radius_at_along(node_id: int, along: float) -> float:
	return _graph.get_radius_at_dist(node_id, along) * thickness_visual_scale


func _create_hover_ring() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PruneHoverRing"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.12, 0.08)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.08, 0.05)
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = material
	mesh_instance.visible = false
	add_child(mesh_instance)
	return mesh_instance


func _update_hover_ring(branch_id: int, local_hit: Vector3) -> void:
	var start: Vector3 = _graph.get_joint(branch_id)
	var end: Vector3 = _graph.get_world_tip(branch_id)
	var branch_dir: Vector3 = (end - start).normalized()
	var length: float = start.distance_to(end)
	var along: float = clampf((local_hit - start).dot(branch_dir), 0.02, length)
	var center: Vector3 = start + branch_dir * along
	var branch_radius: float = _get_radius_at_along(branch_id, along)
	var ring_radius: float = maxf(branch_radius * 1.5, prune_ring_min_radius)

	var tube_radius: float = maxf(ring_radius * 0.08, 0.002)
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(ring_radius - tube_radius, 0.001)
	torus.outer_radius = ring_radius + tube_radius
	torus.rings = 20
	torus.ring_segments = maxi(radial_segments, 12)

	_hover_ring.mesh = torus
	_hover_ring.visible = true
	_orient_ring(_hover_ring, center, branch_dir)


func _prune_hit_on_branch(branch_id: int, local_hit: Vector3) -> Vector3:
	var start: Vector3 = _graph.get_joint(branch_id)
	var end: Vector3 = _graph.get_world_tip(branch_id)
	var branch_dir: Vector3 = (end - start).normalized()
	var length: float = start.distance_to(end)
	var along: float = clampf((local_hit - start).dot(branch_dir), 0.02, length)
	return start + branch_dir * along


func _orient_ring(mesh_instance: MeshInstance3D, center: Vector3, branch_dir: Vector3) -> void:
	branch_dir = branch_dir.normalized()
	if branch_dir.length_squared() <= 0.0001:
		return

	mesh_instance.position = center

	# TorusMesh lies in the XZ plane with its hole along local Y.
	# Align local Y to the branch centerline so the ring is perpendicular to it.
	var ref_up: Vector3 = Vector3.UP
	if absf(branch_dir.dot(ref_up)) > 0.98:
		ref_up = Vector3.FORWARD

	var x_axis: Vector3 = ref_up.cross(branch_dir).normalized()
	var z_axis: Vector3 = branch_dir.cross(x_axis).normalized()
	mesh_instance.basis = Basis(x_axis, branch_dir, z_axis)


func _pick_branch_at_mouse() -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or _graph == null:
		return {}

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin_global: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir_global: Vector3 = camera.project_ray_normal(mouse_pos)
	var to_local: Transform3D = global_transform.affine_inverse()
	var ray_origin: Vector3 = to_local * ray_origin_global
	var ray_dir: Vector3 = (to_local.basis * ray_dir_global).normalized()

	var best_t_ray: float = INF
	var best_hit: Dictionary = {}

	for node_id in _graph.nodes.keys():
		var node = _graph.nodes[node_id]
		if node.length <= 0.001:
			continue

		var start: Vector3 = _graph.get_joint(node_id)
		var end: Vector3 = _graph.get_world_tip(node_id)
		var pick_radius: float = maxf(
			_get_base_radius(node_id),
			_get_tip_radius(node_id)
		) * thickness_visual_scale * 1.6
		pick_radius = maxf(pick_radius, 0.02)

		var segment_hit: Dictionary = _raycast_branch_segment(
			ray_origin,
			ray_dir,
			start,
			end,
			pick_radius
		)
		if segment_hit.is_empty():
			continue

		var t_ray: float = segment_hit.t_ray
		if t_ray < best_t_ray:
			best_t_ray = t_ray
			best_hit = {
				"branch_id": node_id,
				"position": segment_hit.position,
			}

	return best_hit


func _raycast_branch_segment(
	ray_origin: Vector3,
	ray_dir: Vector3,
	seg_start: Vector3,
	seg_end: Vector3,
	radius: float
) -> Dictionary:
	var axis: Vector3 = seg_end - seg_start
	var axis_len: float = axis.length()
	if axis_len <= 0.001:
		return {}

	var axis_dir: Vector3 = axis / axis_len
	var w0: Vector3 = ray_origin - seg_start
	var a: float = ray_dir.dot(ray_dir)
	var b: float = ray_dir.dot(axis_dir)
	var c: float = axis_dir.dot(axis_dir)
	var d: float = ray_dir.dot(w0)
	var e: float = axis_dir.dot(w0)
	var denom: float = a * c - b * b

	var t_ray: float
	var t_axis: float
	if absf(denom) < 0.0001:
		t_ray = 0.0
		t_axis = e / c
	else:
		t_ray = (b * e - c * d) / denom
		t_axis = (a * e - b * d) / denom

	if t_ray < 0.0:
		return {}

	t_axis = clampf(t_axis, 0.0, axis_len)
	var point_on_ray: Vector3 = ray_origin + ray_dir * t_ray
	var point_on_axis: Vector3 = seg_start + axis_dir * t_axis
	if point_on_ray.distance_squared_to(point_on_axis) > radius * radius:
		return {}

	return {
		"t_ray": t_ray,
		"position": point_on_axis,
	}


func _orient_segment(mesh_instance: MeshInstance3D, start: Vector3, direction: Vector3, height: float) -> void:
	if direction.length_squared() <= 0.0001:
		return
	mesh_instance.position = start + direction * (height * 0.5)
	var up: Vector3 = Vector3.UP
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.FORWARD
	mesh_instance.basis = Basis.looking_at(direction, up)
	mesh_instance.rotate_object_local(Vector3.RIGHT, -PI * 0.5)


func _get_segment(node_id: int) -> MeshInstance3D:
	if not _segment_pool.has(node_id):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Segment_%d" % node_id
		_segments_root.add_child(mesh_instance)
		_segment_pool[node_id] = mesh_instance
	return _segment_pool[node_id]


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
		area.input_ray_pickable = true
		area.collision_layer = 1
		area.collision_mask = 0
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
		area.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	var collision_shape: CollisionShape3D = area.get_node("Collision")
	var capsule: CapsuleShape3D = collision_shape.shape
	capsule.radius = maxf(thickness, 0.02)
	capsule.height = maxf(height, 0.04)


func _on_branch_input_event(
	_camera: Node,
	event: InputEvent,
	event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	branch_id: int
) -> void:
	if prune_hover_enabled:
		return

	var local_hit: Vector3 = global_transform.affine_inverse() * event_position
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		branch_clicked.emit(branch_id, local_hit)
	if event is InputEventScreenTouch and event.pressed:
		branch_clicked.emit(branch_id, local_hit)


func play_happy_bounce() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.03, 0.97, 1.03), 0.15)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
