extends Node3D
class_name TreeRenderer

signal branch_clicked(branch_id: int, hit_position: Vector3)
signal dead_leaf_clicked(tip_id: int)

const GinsengCaudexMesh = preload("res://scripts/tree/ginseng_caudex_mesh.gd")
const BranchSegment = preload("res://scripts/tree/branch_segment.gd")
const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")
const FoliageMeshBuilder = preload("res://scripts/tree/foliage_mesh_builder.gd")
const FoliageRenderer = preload("res://scripts/tree/foliage_renderer.gd")
const MeshConstants = preload("res://scripts/util/mesh_constants.gd")
const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")

const MAX_VISUAL_RADIUS := 0.12

enum BranchMeshMode { CYLINDERS, DECIMATED_CYLINDERS, SWEPT_TUBE, RING_LOFT }

@export var trunk_material: Material
@export var graft_material: Material
@export var cut_material: Material
@export var radial_segments: int = 10
@export var thickness_visual_scale: float = 1.0
@export var prune_hover_enabled: bool = false
@export var tend_pick_enabled: bool = false
@export var prune_ring_min_radius: float = 0.018
@export var branch_mesh_mode: BranchMeshMode = BranchMeshMode.CYLINDERS
@export var show_wood_wireframe: bool = false
@export var show_centerlines: bool = false
@export var show_attractor_points: bool = false
@export var centerline_color: Color = Color(0.28, 0.82, 1.0, 0.95)
@export var attractor_color: Color = Color(0.35, 0.92, 0.45, 0.9)
@export var guide_ring_spacing: float = 0.045
@export var segment_jitter: float = 0.07
@export var corner_blend_bend_deg: float = 5.0
@export var bark_variation: float = 0.09

const HOVER_TORUS_INNER_RADIUS := 0.35
const HOVER_TORUS_OUTER_RADIUS := 0.5

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
var _dead_leaf_root: Node3D
var _dead_leaf_pool: Dictionary = {}
var _dead_leaf_material: StandardMaterial3D
var _foliage_renderer: FoliageRenderer
var _caudex_mesh: MeshInstance3D
var _caudex_wire_mesh: MeshInstance3D
var _segments_root: Node3D
var _caps_root: Node3D
var _wireframe_root: Node3D
var _centerline_root: Node3D
var _centerline_mesh: MeshInstance3D
var _attractor_root: Node3D
var _attractor_multimesh: MultiMeshInstance3D
var _overlay_root: Node3D
var _hover_ring: MeshInstance3D
var _hover_ring_mesh: TorusMesh
var _wireframe_material: StandardMaterial3D
var _centerline_material: StandardMaterial3D
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
	_centerline_root = Node3D.new()
	_centerline_root.name = "Centerlines"
	add_child(_centerline_root)
	_centerline_mesh = MeshInstance3D.new()
	_centerline_mesh.name = "CenterlineMesh"
	_centerline_root.add_child(_centerline_mesh)
	_attractor_root = Node3D.new()
	_attractor_root.name = "Attractors"
	add_child(_attractor_root)
	_attractor_multimesh = MultiMeshInstance3D.new()
	_attractor_multimesh.name = "AttractorPoints"
	_attractor_root.add_child(_attractor_multimesh)
	var attractor_material := StandardMaterial3D.new()
	attractor_material.albedo_color = attractor_color
	attractor_material.emission_enabled = true
	attractor_material.emission = attractor_color
	attractor_material.emission_energy_multiplier = 0.8
	attractor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_attractor_multimesh.material_override = attractor_material
	_overlay_root = Node3D.new()
	_overlay_root.name = "Overlays"
	add_child(_overlay_root)
	_dead_leaf_root = Node3D.new()
	_dead_leaf_root.name = "DeadLeaves"
	_overlay_root.add_child(_dead_leaf_root)
	_foliage_renderer = FoliageRenderer.new()
	_foliage_renderer.name = "Foliage"
	add_child(_foliage_renderer)
	_caudex_mesh = MeshInstance3D.new()
	_caudex_mesh.name = "CaudexMesh"
	_overlay_root.add_child(_caudex_mesh)
	_caudex_wire_mesh = MeshInstance3D.new()
	_caudex_wire_mesh.name = "CaudexWireframe"
	_overlay_root.add_child(_caudex_wire_mesh)
	_ensure_hover_ring()
	_move_centerlines_to_front()
	_wireframe_material = StandardMaterial3D.new()
	_wireframe_material.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	_wireframe_material.emission_enabled = true
	_wireframe_material.emission = Color(1.0, 1.0, 1.0)
	_wireframe_material.emission_energy_multiplier = 0.6
	_wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wireframe_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _process(_delta: float) -> void:
	if not prune_hover_enabled or _graph == null:
		_set_hover_ring_visible(false)
		return

	_ensure_hover_ring()
	if _hover_ring == null:
		return

	var hit: Dictionary = _pick_branch_at_mouse()
	if hit.is_empty():
		_set_hover_ring_visible(false)
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


func set_tend_pick_enabled(enabled: bool) -> void:
	tend_pick_enabled = enabled
	for tip_id in _dead_leaf_pool.keys():
		var area: Area3D = _dead_leaf_pool[tip_id]
		if is_instance_valid(area):
			area.input_ray_pickable = enabled


func set_prune_hover_enabled(enabled: bool) -> void:
	prune_hover_enabled = enabled
	if not enabled:
		_set_hover_ring_visible(false)


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


func set_show_centerlines(enabled: bool) -> void:
	if show_centerlines == enabled:
		return
	show_centerlines = enabled
	rebuild()


func set_show_attractor_points(enabled: bool) -> void:
	if show_attractor_points == enabled:
		return
	show_attractor_points = enabled
	rebuild()


func set_show_foliage(enabled: bool) -> void:
	if _foliage_renderer == null:
		return
	if _foliage_renderer.show_foliage == enabled:
		return
	_foliage_renderer.show_foliage = enabled
	_foliage_renderer.rebuild()


func setup(graph, species) -> void:
	_graph = graph
	_species = species
	_dead_leaf_material = null
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
		var node = _graph.nodes[node_id]
		if node.is_caudex_anchor:
			continue
		_render_branch(node_id)

	if _uses_fork_hubs():
		for node_id in _graph.nodes.keys():
			var node = _graph.nodes[node_id]
			if node.children.is_empty() or _should_skip_fork_hub(node_id):
				continue
			_render_fork_hub(node_id)

	_rebuild_centerlines()
	_rebuild_attractors()
	_rebuild_foliage()
	_rebuild_dead_leaves()
	_rebuild_caudex_mesh()


func _rebuild_attractors() -> void:
	if _attractor_multimesh == null:
		return
	if not show_attractor_points or _graph == null:
		_attractor_multimesh.visible = false
		return
	var field = _graph.get_attractor_field()
	if field == null:
		_attractor_multimesh.visible = false
		return
	var points: Array[Vector3] = field.get_points()
	if points.is_empty():
		_attractor_multimesh.visible = false
		return

	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = points.size()
	for i in range(points.size()):
		var transform := Transform3D(Basis(), points[i])
		multimesh.set_instance_transform(i, transform)
	_attractor_multimesh.multimesh = multimesh
	_attractor_multimesh.visible = true


func _rebuild_centerlines() -> void:
	if _centerline_mesh == null:
		return
	if not show_centerlines or _graph == null:
		_centerline_mesh.mesh = null
		_centerline_mesh.visible = false
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for node_id in _graph.nodes.keys():
		var node = _graph.nodes.get(node_id)
		if node and node.is_caudex_anchor:
			continue
		var seg: Dictionary = BranchSegment.from_graph(_graph, node_id)
		var start: Vector3 = seg.start
		var end: Vector3 = seg.end
		if start.distance_squared_to(end) <= MeshConstants.DIR_EPSILON_SQ:
			continue
		st.add_vertex(start)
		st.add_vertex(end)

	_ensure_centerline_material()
	_centerline_mesh.mesh = st.commit()
	_centerline_mesh.material_override = _centerline_material
	_centerline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_centerline_mesh.visible = true


func _rebuild_caudex_mesh() -> void:
	if _caudex_mesh == null or _graph == null:
		return
	if not _graph.has_caudex:
		_caudex_mesh.visible = false
		if _caudex_wire_mesh:
			_caudex_wire_mesh.visible = false
		return

	var top_radius: float = 0.012
	if _graph.nodes.has(_graph.root_id):
		for child_id in _graph.nodes[_graph.root_id].children:
			var child = _graph.nodes.get(child_id)
			if child and not child.is_caudex_anchor:
				top_radius = child.base_thickness + child.cambium_thickness
				break

	var mesh: ArrayMesh = GinsengCaudexMesh.build(
		_graph.caudex_arc_count,
		_graph.caudex_height,
		_graph.caudex_bulk_radius,
		top_radius,
	)
	_caudex_mesh.mesh = mesh
	_ensure_materials()
	_caudex_mesh.material_override = trunk_material
	_caudex_mesh.visible = mesh != null

	if _caudex_wire_mesh:
		var wire: ArrayMesh = GinsengCaudexMesh.build_wireframe(
			_graph.caudex_arc_count,
			_graph.caudex_height,
			_graph.caudex_bulk_radius,
			top_radius,
		)
		_caudex_wire_mesh.mesh = wire
		_ensure_centerline_material()
		_caudex_wire_mesh.material_override = _centerline_material
		_caudex_wire_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_caudex_wire_mesh.visible = show_centerlines and wire != null


func _move_centerlines_to_front() -> void:
	if _centerline_root == null:
		return
	move_child(_centerline_root, get_child_count() - 1)
	if _overlay_root != null:
		move_child(_overlay_root, get_child_count() - 1)


func _ensure_centerline_material() -> void:
	if _centerline_material == null:
		_centerline_material = StandardMaterial3D.new()
		_centerline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_centerline_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_centerline_material.no_depth_test = true
		_centerline_material.render_priority = 100
	_centerline_material.albedo_color = centerline_color
	_centerline_material.emission_enabled = true
	_centerline_material.emission = centerline_color
	_centerline_material.emission_energy_multiplier = 0.85


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
	for tip_id in _dead_leaf_pool.keys():
		var should_keep: bool = live_ids.has(tip_id) \
			and _graph.nodes.has(tip_id) \
			and _graph.nodes[tip_id].has_dead_leaf
		if not should_keep:
			var dead_area: Area3D = _dead_leaf_pool[tip_id]
			if is_instance_valid(dead_area):
				dead_area.queue_free()
			_dead_leaf_pool.erase(tip_id)


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
	var node = _graph.nodes[node_id]
	if node.is_caudex_anchor:
		return
	match branch_mesh_mode:
		BranchMeshMode.DECIMATED_CYLINDERS:
			_render_branch_decimated(node_id)
		BranchMeshMode.SWEPT_TUBE, BranchMeshMode.RING_LOFT:
			_render_branch_skinned(node_id)
		_:
			_render_branch_cylinder(node_id)


func _branch_segment(node_id: int) -> Dictionary:
	return BranchSegment.from_graph(_graph, node_id)


func _render_branch_cylinder(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= MeshConstants.DIST_EPSILON:
		return

	var seg := _branch_segment(node_id)
	var start: Vector3 = seg.start
	var end: Vector3 = seg.end
	var direction: Vector3 = seg.direction
	var height: float = seg.length

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

	_update_pick_area(
		node_id,
		start,
		end,
		maxf(_get_base_radius(node_id), _get_tip_radius(node_id)) * thickness_visual_scale
	)
	if show_wood_wireframe:
		_render_wireframe_cylinder(node_id, start, direction, height, bottom_radius, top_radius)
	_prune_wireframe_pool(node_id, 0, 0, true)


func _render_branch_decimated(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= MeshConstants.DIST_EPSILON:
		return

	var seg := _branch_segment(node_id)
	var start: Vector3 = seg.start
	var end: Vector3 = seg.end
	var direction: Vector3 = seg.direction
	var height: float = seg.length

	var guide_samples: Array = _graph.get_bark_guide_samples(node_id, guide_ring_spacing)
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
	var include_fork_blend := false
	for child_id in node.children:
		if _graph.nodes[child_id].depth > node.depth:
			include_fork_blend = true
			break

	var blend_specs: Array = BranchMeshBuilder.build_corner_blend_specs(
		guide_samples,
		start,
		node.id,
		corner_blend_bend_deg,
		segment_jitter,
		include_fork_blend,
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

	_update_pick_area(
		node_id,
		start,
		end,
		maxf(_get_base_radius(node_id), _get_tip_radius(node_id)) * thickness_visual_scale
	)
	_prune_branch_chain_pool(node_id, cylinder_specs.size(), blend_specs.size())
	var wire_chain_count: int = cylinder_specs.size() if show_wood_wireframe else 0
	var wire_blend_count: int = blend_specs.size() if show_wood_wireframe else 0
	_prune_wireframe_pool(node_id, wire_chain_count, wire_blend_count, false)


func _render_branch_skinned(node_id: int) -> void:
	var node = _graph.nodes[node_id]
	if node.length <= MeshConstants.DIST_EPSILON:
		return

	var seg := _branch_segment(node_id)
	var start: Vector3 = seg.start
	var end: Vector3 = seg.end
	var direction: Vector3 = seg.direction
	var height: float = seg.length

	var guide_samples: Array = _graph.get_bark_guide_samples(node_id, guide_ring_spacing)
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

	_update_pick_area(
		node_id,
		start,
		end,
		maxf(_get_base_radius(node_id), _get_tip_radius(node_id)) * thickness_visual_scale
	)
	_prune_branch_chain_pool(node_id, 0, 0)
	_prune_wireframe_pool(node_id, 0, 0, false)


func _render_fork_hub(parent_id: int) -> void:
	var parent = _graph.nodes[parent_id]
	var hub_center: Vector3 = _graph.get_world_tip(parent_id)
	var parent_dir: Vector3 = parent.last_profile_direction
	if parent_dir.length_squared() <= 0.0001:
		parent_dir = parent.direction
	parent_dir = parent_dir.normalized()

	var parent_r: float = clampf(
		_get_tip_radius(parent_id) * thickness_visual_scale,
		MeshConstants.MIN_BRANCH_RADIUS,
		MAX_VISUAL_RADIUS
	)
	var child_specs: Array = []
	for child_id in parent.children:
		var child = _graph.nodes[child_id]
		var child_r: float = _get_base_radius(child_id) * thickness_visual_scale
		if child.profile_joint_radius >= 0.0:
			child_r = clampf(
				child.profile_joint_radius * thickness_visual_scale,
				MeshConstants.MIN_BRANCH_RADIUS,
				MAX_VISUAL_RADIUS
			)
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


func _should_skip_fork_hub(parent_id: int) -> bool:
	if _graph == null or not _graph.nodes.has(parent_id):
		return false
	for child_id in _graph.nodes[parent_id].children:
		if not _graph.nodes.has(child_id):
			continue
		if _graph.nodes[child_id].is_basal_leg:
			return true
	return false


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
	cylinder.height = maxf(height, MeshConstants.MIN_BRANCH_HEIGHT)
	cylinder.bottom_radius = clampf(
		maxf(bottom_radius, MeshConstants.MIN_BRANCH_RADIUS),
		MeshConstants.MIN_BRANCH_RADIUS,
		MAX_VISUAL_RADIUS
	)
	cylinder.top_radius = clampf(
		maxf(top_radius, MeshConstants.MIN_BRANCH_RADIUS),
		MeshConstants.MIN_BRANCH_RADIUS,
		MAX_VISUAL_RADIUS
	)
	cylinder.radial_segments = maxi(radial_segments, 6)
	return cylinder


func _get_base_radius(node_id: int) -> float:
	return _graph.get_radius_at_dist(node_id, 0.0)


func _get_tip_radius(node_id: int) -> float:
	var node = _graph.nodes[node_id]
	return _graph.get_radius_at_dist(node_id, node.length)


func _get_radius_at_along(node_id: int, along: float) -> float:
	return _graph.get_radius_at_dist(node_id, along) * thickness_visual_scale


func _set_hover_ring_visible(visible: bool) -> void:
	_ensure_hover_ring()
	if _hover_ring != null and is_instance_valid(_hover_ring):
		_hover_ring.visible = visible


func _ensure_hover_ring() -> void:
	if not is_inside_tree():
		return
	if _hover_ring != null and is_instance_valid(_hover_ring):
		return

	if _overlay_root == null or not is_instance_valid(_overlay_root):
		_overlay_root = get_node_or_null("Overlays") as Node3D
		if _overlay_root == null:
			_overlay_root = Node3D.new()
			_overlay_root.name = "Overlays"
			add_child(_overlay_root)

	var existing: Node = _overlay_root.get_node_or_null("PruneHoverRing")
	if existing == null:
		existing = get_node_or_null("PruneHoverRing")
	if existing is MeshInstance3D and is_instance_valid(existing):
		if existing.get_parent() != _overlay_root:
			existing.reparent(_overlay_root)
		_hover_ring = existing
		_hover_ring_mesh = _hover_ring.mesh as TorusMesh
		if _hover_ring_mesh == null:
			_hover_ring_mesh = _build_hover_torus_mesh()
			_hover_ring.mesh = _hover_ring_mesh
		return

	_hover_ring = _create_hover_ring()
	if _hover_ring == null or _overlay_root == null or not is_instance_valid(_overlay_root):
		return
	_overlay_root.add_child(_hover_ring)


func _build_hover_torus_mesh() -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = HOVER_TORUS_INNER_RADIUS
	torus.outer_radius = HOVER_TORUS_OUTER_RADIUS
	torus.rings = 16
	torus.ring_segments = 24
	return torus


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
	material.render_priority = 100
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = material
	mesh_instance.visible = false
	_hover_ring_mesh = _build_hover_torus_mesh()
	mesh_instance.mesh = _hover_ring_mesh
	return mesh_instance


func _hover_ring_scale(branch_radius: float) -> float:
	var ring_radius: float = maxf(branch_radius * 1.5, prune_ring_min_radius)
	var mean_torus_radius: float = (HOVER_TORUS_INNER_RADIUS + HOVER_TORUS_OUTER_RADIUS) * 0.5
	return ring_radius / mean_torus_radius


func _update_hover_ring(branch_id: int, local_hit: Vector3) -> void:
	_ensure_hover_ring()
	if _hover_ring == null:
		return

	var seg := _branch_segment(branch_id)
	var span: float = seg.start.distance_to(seg.end)
	if span <= MeshConstants.DIST_EPSILON or seg.direction.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		_set_hover_ring_visible(false)
		return

	var branch_dir: Vector3 = seg.direction
	var min_along: float = minf(0.02, span * 0.5)
	var along: float = clampf((local_hit - seg.start).dot(branch_dir), min_along, span)
	var center: Vector3 = seg.start + branch_dir * along
	if not local_hit.is_finite() or not center.is_finite():
		_set_hover_ring_visible(false)
		return

	var branch_radius: float = maxf(
		_get_radius_at_along(branch_id, along),
		MeshConstants.MIN_BRANCH_RADIUS * thickness_visual_scale
	)
	if not is_finite(branch_radius):
		_set_hover_ring_visible(false)
		return

	var ring_scale: float = _hover_ring_scale(branch_radius)
	if ring_scale <= 0.0 or not is_finite(ring_scale):
		_set_hover_ring_visible(false)
		return

	_set_hover_ring_visible(true)
	_orient_ring(_hover_ring, center, branch_dir, ring_scale)


func _prune_hit_on_branch(branch_id: int, local_hit: Vector3) -> Vector3:
	return BranchSegment.prune_hit_along(_graph, branch_id, local_hit)


func _orient_ring(
	mesh_instance: MeshInstance3D,
	center: Vector3,
	branch_dir: Vector3,
	uniform_scale: float = 1.0
) -> void:
	if not center.is_finite() or not branch_dir.is_finite() or not is_finite(uniform_scale):
		return
	if uniform_scale <= 0.0 or uniform_scale > 4.0:
		return
	if branch_dir.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		return

	var orientation := Vector3Frame.basis_along_direction(branch_dir)
	if not _basis_is_finite(orientation):
		return

	mesh_instance.position = center
	mesh_instance.basis = orientation
	mesh_instance.scale = Vector3.ONE * uniform_scale


func _orient_segment(mesh_instance: MeshInstance3D, start: Vector3, direction: Vector3, height: float) -> void:
	if not start.is_finite() or not direction.is_finite() or not is_finite(height):
		return
	if direction.length_squared() <= MeshConstants.DIR_EPSILON_SQ or height <= MeshConstants.DIST_EPSILON:
		return
	Vector3Frame.orient_cylinder_mesh(mesh_instance, start, direction, height)


func _basis_is_finite(basis: Basis) -> bool:
	return basis.x.is_finite() and basis.y.is_finite() and basis.z.is_finite()


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
		t_axis = clampf(e / c, 0.0, axis_len)
		var closest_on_axis: Vector3 = seg_start + axis_dir * t_axis
		t_ray = ray_dir.dot(closest_on_axis - ray_origin)
	else:
		t_ray = (b * e - c * d) / denom
		t_axis = (a * e - b * d) / denom

	if t_ray < 0.01:
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
	if direction.length_squared() > MeshConstants.DIR_EPSILON_SQ:
		area.basis = Vector3Frame.basis_along_direction(direction)
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


func _rebuild_foliage() -> void:
	if _foliage_renderer == null:
		return
	_foliage_renderer.set_context(_graph, _species)
	_foliage_renderer.rebuild()


func _rebuild_dead_leaves() -> void:
	if _graph == null or _dead_leaf_root == null:
		return

	var live_dead: Dictionary = {}
	for tip_id in _graph.get_dead_leaf_tip_ids():
		live_dead[int(tip_id)] = true
		_update_dead_leaf_marker(int(tip_id))

	for tip_id in _dead_leaf_pool.keys():
		if not live_dead.has(tip_id):
			var stale_area: Area3D = _dead_leaf_pool[tip_id]
			if is_instance_valid(stale_area):
				stale_area.queue_free()
			_dead_leaf_pool.erase(tip_id)


func _ensure_dead_leaf_material() -> void:
	if _dead_leaf_material != null:
		return
	var preset: FoliagePreset = FoliagePreset.resolve(_species)
	_dead_leaf_material = StandardMaterial3D.new()
	_dead_leaf_material.albedo_color = preset.dead_leaf_color if preset else Color(0.42, 0.28, 0.14)
	_dead_leaf_material.roughness = 0.95
	_dead_leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _update_dead_leaf_marker(tip_id: int) -> void:
	var preset: FoliagePreset = FoliagePreset.resolve(_species)
	_ensure_dead_leaf_material()
	var tip_pos: Vector3 = _graph.get_world_tip(tip_id)
	var node = _graph.nodes[tip_id]
	var branch_dir: Vector3 = node.direction.normalized()
	var offset: Vector3 = branch_dir * 0.018
	var marker_pos: Vector3 = tip_pos + offset

	var area: Area3D
	if _dead_leaf_pool.has(tip_id):
		area = _dead_leaf_pool[tip_id]
	else:
		area = Area3D.new()
		area.name = "DeadLeaf_%d" % tip_id
		area.collision_layer = 1
		area.collision_mask = 0
		area.input_ray_pickable = tend_pick_enabled
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "LeafMesh"
		mesh_instance.mesh = FoliageMeshBuilder.get_dead_leaf_mesh(preset)
		mesh_instance.material_override = _dead_leaf_material
		var droop: float = (preset.droop_deg if preset else 15.0) + (preset.dead_leaf_droop_extra_deg if preset else 25.0)
		mesh_instance.rotation_degrees = Vector3(-droop, 15.0, 0.0)
		var leaf_scale: float = preset.dead_leaf_scale if preset else 0.9
		mesh_instance.scale = Vector3.ONE * leaf_scale
		area.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.04
		collision.shape = shape
		area.add_child(collision)
		area.input_event.connect(_on_dead_leaf_input_event.bind(tip_id))
		_dead_leaf_root.add_child(area)
		_dead_leaf_pool[tip_id] = area

	area.position = marker_pos
	area.visible = true


func _on_dead_leaf_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	tip_id: int
) -> void:
	if not tend_pick_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		dead_leaf_clicked.emit(tip_id)
	if event is InputEventScreenTouch and event.pressed:
		dead_leaf_clicked.emit(tip_id)


func play_happy_bounce() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.03, 0.97, 1.03), 0.15)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
