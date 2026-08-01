extends Node3D
class_name TreeRenderer

signal branch_clicked(branch_id: int, hit_position: Vector3)

const BranchMeshBuilder = preload("res://scripts/tree/branch_mesh_builder.gd")

enum BranchMeshMode { CYLINDERS, DECIMATED_CYLINDERS, SWEPT_TUBE, RING_LOFT }

@export var trunk_material: Material
@export var graft_material: Material
@export var cut_material: Material
@export var radial_segments: int = 10
@export var thickness_visual_scale: float = 1.0
@export var prune_hover_enabled: bool = false
@export var prune_ring_min_radius: float = 0.018
@export var branch_mesh_mode: BranchMeshMode = BranchMeshMode.CYLINDERS
@export var show_wood_wireframe: bool = false
@export var guide_ring_spacing: float = 0.045
@export var segment_jitter: float = 0.07
@export var corner_blend_bend_deg: float = 5.0
@export var bark_variation: float = 0.09

var _graph
var _species
var _segment_pool: Dictionary = {}
var _chain_pool: Dictionary = {}
var _blend_pool: Dictionary = {}
var _cap_pool: Dictionary = {}
var _graft_pool: Dictionary = {}
var _wireframe_pool: Dictionary = {}
var _hub_pool: Dictionary = {}
var _pick_areas: Dictionary = {}
var _segments_root: Node3D
var _caps_root: Node3D
var _wireframe_root: Node3D
var _hover_ring: MeshInstance3D
var _wireframe_material: StandardMaterial3D
var _click_start: Vector2 = Vector2.ZERO
var _click_pending: bool = false


func _ready() -> void:
	_segments_root = Node3D.new()
	_segments_root.name = "Segments"
	add_child(_segments_root)
	_caps_root = Node3D.new()
	_caps_root.name = "Caps"
	add_child(_caps_root)
	_wireframe_root = Node3D.new()
	_wireframe_root.name = "WoodWireframe"
	add_child(_wireframe_root)
	_hover_ring = _create_hover_ring()
	_wireframe_material = StandardMaterial3D.new()
	_wireframe_material.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	_wireframe_material.emission_enabled = true
	_wireframe_material.emission = Color(1.0, 1.0, 1.0)
	_wireframe_material.emission_energy_multiplier = 0.6
	_wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wireframe_material.cull_mode = BaseMaterial3D.CULL_DISABLED


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


func set_branch_mesh_mode(mode: BranchMeshMode) -> void:
	if branch_mesh_mode == mode:
		return
	branch_mesh_mode = mode
	rebuild()


func set_show_wood_wireframe(enabled: bool) -> void:
	if show_wood_wireframe == enabled:
		return
	show_wood_wireframe = enabled
	rebuild()


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

	_clear_wireframes()

	if _uses_profile_guides():
		_graph.prepare_all_profiles_for_render()

	var live_ids: Dictionary = {}
	for node_id in _graph.nodes.keys():
		live_ids[node_id] = true

	_hide_all_pools()
	_cleanup_stale_pools(live_ids)

	for node_id in _graph.nodes.keys():
		_render_branch(node_id)

	if _uses_fork_hubs():
		for node_id in _graph.nodes.keys():
			var node = _graph.nodes[node_id]
			if not node.children.is_empty():
				_render_fork_hub(node_id)


func _cleanup_stale_pools(live_ids: Dictionary) -> void:
	for node_id in _segment_pool.keys():
		if not live_ids.has(node_id):
			_segment_pool[node_id].queue_free()
			_segment_pool.erase(node_id)
	for chain_key in _chain_pool.keys():
		var chain_node_id: int = int(chain_key.split(":")[0])
		if not live_ids.has(chain_node_id):
			_chain_pool[chain_key].queue_free()
			_chain_pool.erase(chain_key)
	for blend_key in _blend_pool.keys():
		var blend_node_id: int = int(blend_key.split(":")[0])
		if not live_ids.has(blend_node_id):
			_blend_pool[blend_key].queue_free()
			_blend_pool.erase(blend_key)
	for wire_key in _wireframe_pool.keys():
		var wire_node_id: int = int(str(wire_key).split(":")[0])
		if not live_ids.has(wire_node_id):
			_wireframe_pool[wire_key].queue_free()
			_wireframe_pool.erase(wire_key)
	for node_id in _hub_pool.keys():
		if not live_ids.has(node_id):
			_hub_pool[node_id].queue_free()
			_hub_pool.erase(node_id)
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
	for key in _chain_pool.keys():
		_chain_pool[key].visible = false
	for key in _blend_pool.keys():
		_blend_pool[key].visible = false
	for key in _wireframe_pool.keys():
		_wireframe_pool[key].visible = false
	for key in _hub_pool.keys():
		_hub_pool[key].visible = false
	for key in _cap_pool.keys():
		_cap_pool[key].visible = false
	for key in _graft_pool.keys():
		_graft_pool[key].visible = false


func _clear_wireframes() -> void:
	for key in _wireframe_pool.keys():
		var mesh_instance: MeshInstance3D = _wireframe_pool[key]
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	_wireframe_pool.clear()


func _render_branch(node_id: int) -> void:
	match branch_mesh_mode:
		BranchMeshMode.DECIMATED_CYLINDERS:
			_render_branch_decimated(node_id)
		BranchMeshMode.SWEPT_TUBE, BranchMeshMode.RING_LOFT:
			_render_branch_skinned(node_id)
		_:
			_render_branch_cylinder(node_id)


func _render_branch_cylinder(node_id: int) -> void:
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
		_render_cut_cap(node_id, end, direction)
	else:
		_render_tip_disc_cap(node_id, end, direction)

	_update_pick_area(node_id, start, end, node.thickness * thickness_visual_scale)
	if show_wood_wireframe:
		_render_wireframe_cylinder(node_id, start, direction, height, bottom_radius, top_radius)
	_prune_wireframe_pool(node_id, 0, 0, true)


func _render_branch_decimated(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= 0.001:
		return

	var start: Vector3 = _graph.get_joint(node_id)
	var end: Vector3 = _graph.get_world_tip(node_id)
	var direction: Vector3 = (end - start).normalized()
	var height: float = maxf(start.distance_to(end), 0.02)

	var guide_samples: Array = _scale_sample_radii(
		_graph.get_bark_guide_samples(node_id, guide_ring_spacing)
	)
	if guide_samples.size() < 2:
		_render_branch_cylinder(node_id)
		return

	var cylinder_specs: Array = BranchMeshBuilder.build_decimated_cylinder_specs(
		guide_samples,
		start,
		node.id,
		segment_jitter,
		direction
	)
	var blend_specs: Array = BranchMeshBuilder.build_corner_blend_specs(
		guide_samples,
		start,
		node.id,
		corner_blend_bend_deg,
		segment_jitter,
		not node.children.is_empty(),
		direction
	)

	var material: Material = graft_material if node.is_graft else trunk_material
	for i in range(cylinder_specs.size()):
		var spec: Dictionary = cylinder_specs[i]
		var chain_key: String = "%d:c:%d" % [node_id, i]
		var mesh_instance := _get_chain_segment(chain_key)
		mesh_instance.visible = true
		var seg_start: Vector3 = spec.get("start", start)
		var seg_end: Vector3 = spec.get("end", end)
		var seg_dir: Vector3 = (seg_end - seg_start).normalized()
		var seg_height: float = seg_start.distance_to(seg_end)
		mesh_instance.mesh = _build_cylinder(
			seg_height,
			float(spec.get("bottom_r", 0.01)) * thickness_visual_scale,
			float(spec.get("top_r", 0.01)) * thickness_visual_scale
		)
		_orient_segment(mesh_instance, seg_start, seg_dir, seg_height)
		mesh_instance.material_override = material

	for i in range(blend_specs.size()):
		var spec: Dictionary = blend_specs[i]
		var blend_key: String = "%d:b:%d" % [node_id, i]
		var blend_mesh := _get_blend_sphere(blend_key)
		blend_mesh.visible = true
		var radius: float = float(spec.get("radius", 0.01)) * thickness_visual_scale
		var sphere := SphereMesh.new()
		sphere.radius = maxf(radius, 0.003)
		sphere.height = radius * 2.0
		sphere.radial_segments = maxi(radial_segments, 8)
		sphere.rings = maxi(radial_segments / 2, 6)
		blend_mesh.mesh = sphere
		blend_mesh.position = spec.get("center", start)
		blend_mesh.basis = Basis.IDENTITY
		blend_mesh.material_override = material

	if show_wood_wireframe:
		_render_wireframe_decimated(
			node_id,
			cylinder_specs,
			blend_specs
		)

	if node.is_graft:
		var graft_marker := _get_graft_marker(node_id)
		graft_marker.visible = true
		graft_marker.position = start

	if node.cut_timestamp >= 0.0:
		_render_cut_cap(node_id, end, direction)
	else:
		_render_tip_disc_cap(node_id, end, direction)

	_update_pick_area(node_id, start, end, node.thickness * thickness_visual_scale)
	_prune_branch_chain_pool(node_id, cylinder_specs.size(), blend_specs.size())
	var wire_chain_count: int = cylinder_specs.size() if show_wood_wireframe else 0
	var wire_blend_count: int = blend_specs.size() if show_wood_wireframe else 0
	_prune_wireframe_pool(node_id, wire_chain_count, wire_blend_count, false)


func _render_branch_skinned(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= 0.001:
		return

	var start: Vector3 = _graph.get_joint(node_id)
	var end: Vector3 = _graph.get_world_tip(node_id)
	var direction: Vector3 = (end - start).normalized()
	var height: float = maxf(start.distance_to(end), 0.02)

	var guide_samples: Array = _scale_sample_radii(
		_graph.get_bark_guide_samples(node_id, guide_ring_spacing)
	)
	if guide_samples.size() < 2:
		_render_branch_cylinder(node_id)
		return

	var wobble: Array = BranchMeshBuilder.generate_locked_wobble(
		node.id,
		radial_segments,
		bark_variation
	)
	var densify: bool = branch_mesh_mode == BranchMeshMode.RING_LOFT
	var bark_meshes: Dictionary = BranchMeshBuilder.build_bark_branch_meshes(
		guide_samples,
		wobble,
		radial_segments,
		densify,
		node.length,
		direction,
		guide_ring_spacing
	)
	var branch_mesh: ArrayMesh = bark_meshes.get("surface")

	if branch_mesh == null:
		_render_branch_cylinder(node_id)
		return

	var mesh_instance := _get_segment(node_id)
	mesh_instance.visible = true
	mesh_instance.mesh = branch_mesh
	mesh_instance.position = start
	mesh_instance.basis = Basis.IDENTITY
	mesh_instance.material_override = graft_material if node.is_graft else trunk_material

	if show_wood_wireframe:
		_render_bark_wireframe(node_id, bark_meshes.get("wireframe"), start)

	if node.is_graft:
		var graft_marker := _get_graft_marker(node_id)
		graft_marker.visible = true
		graft_marker.position = start

	if node.cut_timestamp >= 0.0:
		_render_cut_cap(node_id, end, direction)

	_update_pick_area(node_id, start, end, node.thickness * thickness_visual_scale)
	_prune_branch_chain_pool(node_id, 0, 0)
	_prune_wireframe_pool(node_id, 0, 0, false)


func _render_fork_hub(parent_id: int) -> void:
	var parent = _graph.nodes[parent_id]
	var hub_center: Vector3 = _graph.get_world_tip(parent_id)
	var parent_dir: Vector3 = parent.last_profile_direction
	if parent_dir.length_squared() <= 0.0001:
		parent_dir = parent.direction
	parent_dir = parent_dir.normalized()

	var parent_r: float = _get_tip_radius(parent_id)
	var child_specs: Array = []
	for child_id in parent.children:
		var child = _graph.nodes[child_id]
		var child_r: float = _get_base_radius(child_id)
		if child.profile_joint_radius >= 0.0:
			child_r = child.profile_joint_radius * thickness_visual_scale
		child_specs.append({
			"dir": child.direction.normalized(),
			"r": child_r,
		})

	var hub_mesh: ArrayMesh = BranchMeshBuilder.build_fork_hub(
		hub_center,
		parent_dir,
		parent_r,
		child_specs,
		radial_segments
	)
	if hub_mesh == null:
		return

	var hub_instance := _get_fork_hub(parent_id)
	hub_instance.visible = true
	hub_instance.mesh = hub_mesh
	hub_instance.position = Vector3.ZERO
	hub_instance.basis = Basis.IDENTITY
	hub_instance.material_override = graft_material if parent.is_graft else trunk_material


func _uses_profile_guides() -> bool:
	return branch_mesh_mode != BranchMeshMode.CYLINDERS


func _uses_fork_hubs() -> bool:
	return branch_mesh_mode == BranchMeshMode.SWEPT_TUBE \
		or branch_mesh_mode == BranchMeshMode.RING_LOFT


func _get_fork_hub(parent_id: int) -> MeshInstance3D:
	if not _hub_pool.has(parent_id):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "ForkHub_%d" % parent_id
		_segments_root.add_child(mesh_instance)
		_hub_pool[parent_id] = mesh_instance
	return _hub_pool[parent_id]


func _render_bark_wireframe(node_id: int, wire_mesh: ArrayMesh, start: Vector3) -> void:
	if wire_mesh == null:
		return
	var wire_key: String = "%d:bark" % node_id
	var mesh_instance := _get_wireframe(wire_key)
	mesh_instance.visible = true
	mesh_instance.mesh = wire_mesh
	mesh_instance.position = start
	mesh_instance.basis = Basis.IDENTITY
	mesh_instance.material_override = _wireframe_material


func _render_wireframe_cylinder(
	node_id: int,
	start: Vector3,
	direction: Vector3,
	height: float,
	bottom_radius: float,
	top_radius: float
) -> void:
	var wire_key: String = "%d:main" % node_id
	var mesh_instance := _get_wireframe(wire_key)
	mesh_instance.visible = true
	mesh_instance.mesh = BranchMeshBuilder.build_cylinder_wireframe(
		height,
		bottom_radius,
		top_radius,
		radial_segments
	)
	_orient_segment(mesh_instance, start, direction, height)
	mesh_instance.material_override = _wireframe_material


func _render_wireframe_decimated(
	node_id: int,
	cylinder_specs: Array,
	blend_specs: Array
) -> void:
	for i in range(cylinder_specs.size()):
		var spec: Dictionary = cylinder_specs[i]
		var wire_key: String = "%d:c:%d" % [node_id, i]
		var mesh_instance := _get_wireframe(wire_key)
		mesh_instance.visible = true
		var seg_start: Vector3 = spec.get("start", Vector3.ZERO)
		var seg_end: Vector3 = spec.get("end", Vector3.ZERO)
		var seg_dir: Vector3 = (seg_end - seg_start).normalized()
		var seg_height: float = seg_start.distance_to(seg_end)
		mesh_instance.mesh = BranchMeshBuilder.build_cylinder_wireframe(
			seg_height,
			float(spec.get("bottom_r", 0.01)) * thickness_visual_scale,
			float(spec.get("top_r", 0.01)) * thickness_visual_scale,
			radial_segments
		)
		_orient_segment(mesh_instance, seg_start, seg_dir, seg_height)
		mesh_instance.material_override = _wireframe_material

	for i in range(blend_specs.size()):
		var spec: Dictionary = blend_specs[i]
		var wire_key: String = "%d:b:%d" % [node_id, i]
		var mesh_instance := _get_wireframe(wire_key)
		mesh_instance.visible = true
		var radius: float = float(spec.get("radius", 0.01)) * thickness_visual_scale
		mesh_instance.mesh = BranchMeshBuilder.build_sphere_wireframe(
			maxf(radius, 0.003),
			maxi(radial_segments, 8)
		)
		mesh_instance.position = spec.get("center", Vector3.ZERO)
		mesh_instance.basis = Basis.IDENTITY
		mesh_instance.material_override = _wireframe_material


func _get_wireframe(wire_key: String) -> MeshInstance3D:
	if not _wireframe_pool.has(wire_key):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Wire_%s" % wire_key
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wireframe_root.add_child(mesh_instance)
		_wireframe_pool[wire_key] = mesh_instance
	return _wireframe_pool[wire_key]


func _prune_wireframe_pool(
	node_id: int,
	chain_count: int,
	blend_count: int,
	keep_main: bool
) -> void:
	var main_key: String = "%d:main" % node_id
	if not keep_main and _wireframe_pool.has(main_key):
		_wireframe_pool[main_key].queue_free()
		_wireframe_pool.erase(main_key)

	var bark_key: String = "%d:bark" % node_id
	if _wireframe_pool.has(bark_key) and (keep_main or chain_count > 0):
		_wireframe_pool[bark_key].queue_free()
		_wireframe_pool.erase(bark_key)

	var chain_prefix: String = "%d:c:" % node_id
	for key in _wireframe_pool.keys():
		if not str(key).begins_with(chain_prefix):
			continue
		var index: int = int(str(key).get_slice(":", 2))
		if index >= chain_count:
			_wireframe_pool[key].queue_free()
			_wireframe_pool.erase(key)

	var blend_prefix: String = "%d:b:" % node_id
	for key in _wireframe_pool.keys():
		if not str(key).begins_with(blend_prefix):
			continue
		var index: int = int(str(key).get_slice(":", 2))
		if index >= blend_count:
			_wireframe_pool[key].queue_free()
			_wireframe_pool.erase(key)


func _prune_branch_chain_pool(node_id: int, chain_count: int, blend_count: int) -> void:
	var chain_prefix: String = "%d:c:" % node_id
	for key in _chain_pool.keys():
		if not str(key).begins_with(chain_prefix):
			continue
		var index: int = int(str(key).get_slice(":", 2))
		if index >= chain_count:
			_chain_pool[key].queue_free()
			_chain_pool.erase(key)

	var blend_prefix: String = "%d:b:" % node_id
	for key in _blend_pool.keys():
		if not str(key).begins_with(blend_prefix):
			continue
		var index: int = int(str(key).get_slice(":", 2))
		if index >= blend_count:
			_blend_pool[key].queue_free()
			_blend_pool.erase(key)


func _scale_sample_radii(samples: Array) -> Array:
	var scaled: Array = []
	for sample in samples:
		if sample is Dictionary:
			scaled.append({
				"dist": float(sample.get("dist", 0.0)),
				"dir": sample.get("dir", Vector3.UP),
				"r": float(sample.get("r", 0.02)) * thickness_visual_scale,
			})
	return scaled


func _get_chain_segment(chain_key: String) -> MeshInstance3D:
	if not _chain_pool.has(chain_key):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Chain_%s" % chain_key
		_segments_root.add_child(mesh_instance)
		_chain_pool[chain_key] = mesh_instance
	return _chain_pool[chain_key]


func _get_blend_sphere(blend_key: String) -> MeshInstance3D:
	if not _blend_pool.has(blend_key):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Blend_%s" % blend_key
		_segments_root.add_child(mesh_instance)
		_blend_pool[blend_key] = mesh_instance
	return _blend_pool[blend_key]


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


func _render_cut_cap(node_id: int, end: Vector3, direction: Vector3) -> void:
	var top_radius: float = _get_tip_radius(node_id) * thickness_visual_scale
	var cap := _get_cap(node_id)
	cap.visible = true
	cap.mesh = _build_cylinder(
		top_radius * 0.35,
		top_radius,
		top_radius * 0.15
	)
	_orient_segment(cap, end - direction * (top_radius * 0.175), direction, top_radius * 0.35)
	cap.material_override = cut_material


func _render_tip_disc_cap(node_id: int, end: Vector3, direction: Vector3) -> void:
	var node = _graph.nodes[node_id]
	var cap_radius: float = _get_tip_radius(node_id) * thickness_visual_scale
	var cap := _get_cap(node_id)
	cap.visible = true
	cap.mesh = BranchMeshBuilder.build_disc_cap_mesh(
		cap_radius,
		direction,
		radial_segments
	)
	cap.position = end
	cap.basis = Basis.IDENTITY
	cap.material_override = graft_material if node.is_graft else trunk_material


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
