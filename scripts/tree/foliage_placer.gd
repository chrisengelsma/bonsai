class_name FoliagePlacer
extends RefCounted

const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")
const FoliageGrowthPath = preload("res://scripts/tree/foliage_growth_path.gd")
const MeshConstants = preload("res://scripts/util/mesh_constants.gd")
const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")

const CLUSTER_RADIUS_SCALE := 0.055


static func collect_placements(graph, preset: FoliagePreset, species) -> Array:
	if graph == null or preset == null:
		return []

	var placements: Array = []
	for node_id in graph.nodes.keys():
		var node = graph.nodes[node_id]
		if node.foliage_amount <= 0.001:
			continue
		if not FoliageGrowthPath.is_eligible_branch(node, preset):
			continue
		_collect_for_terminal(int(node_id), node, graph, preset, placements)
	return placements


static func _collect_for_terminal(
	tip_id: int,
	tip,
	graph,
	preset: FoliagePreset,
	placements: Array
) -> void:
	var all_anchors: Array = FoliageGrowthPath.build_world_anchors(graph, tip_id, preset)
	var anchors: Array = _resolve_placement_anchors(all_anchors, tip.foliage_amount, preset)

	for slot in range(anchors.size()):
		var anchor: Dictionary = anchors[slot]
		var tangent: Vector3 = anchor.get("tangent", Vector3.UP)
		if tangent.length_squared() < MeshConstants.DIR_EPSILON_SQ:
			tangent = tip.direction.normalized()

		var scale: float = _instance_scale(preset, tip_id, slot, tip.foliage_amount)
		var droop: float = preset.droop_deg + _droop_jitter(tip_id, slot)
		var spin: float = _hash01(tip_id, slot, 29)
		var fascicle_index: int = int(anchor.get("fascicle_index", slot))
		var transform := build_transform(
			preset,
			anchor.get("position", Vector3.ZERO),
			tangent,
			tip.turtle_up,
			scale,
			droop,
			spin,
			fascicle_index
		)
		placements.append({
			"tip_id": tip_id,
			"slot": slot,
			"transform": transform,
			"custom": _build_instance_custom(preset, tip_id, slot, tip.foliage_amount),
		})


static func _resolve_placement_anchors(
	all_anchors: Array,
	foliage_amount: float,
	preset: FoliagePreset
) -> Array:
	if all_anchors.is_empty():
		return []

	match preset.placement:
		FoliagePreset.Placement.TIP_ONLY:
			return _tip_only_anchors(all_anchors, foliage_amount, preset)
		FoliagePreset.Placement.SEGMENT_SCATTER:
			return _scatter_anchors(all_anchors, foliage_amount, preset)
		_:
			return FoliageGrowthPath.select_mature_anchors(all_anchors, foliage_amount)


static func _tip_only_anchors(
	all_anchors: Array,
	foliage_amount: float,
	preset: FoliagePreset
) -> Array:
	var instance_count: int = _instance_count_for_tip(preset, foliage_amount)
	if instance_count <= 0:
		return []

	var tip_anchor: Dictionary = all_anchors[-1]
	var tangent: Vector3 = tip_anchor.get("tangent", Vector3.UP).normalized()
	var anchors: Array = []
	for slot in range(instance_count):
		var inset: float = 0.004 + 0.003 * float(slot)
		var anchor: Dictionary = tip_anchor.duplicate()
		anchor["position"] = tip_anchor.get("position", Vector3.ZERO) - tangent * inset
		anchor["fascicle_index"] = slot
		anchors.append(anchor)
	return anchors


static func _scatter_anchors(
	all_anchors: Array,
	foliage_amount: float,
	preset: FoliagePreset
) -> Array:
	var mature: Array = FoliageGrowthPath.select_mature_anchors(all_anchors, foliage_amount)
	var target_count: int = maxi(preset.segment_scatter_count, _instance_count_for_tip(preset, foliage_amount))
	if mature.size() >= target_count:
		return mature

	if all_anchors.size() <= target_count:
		return all_anchors

	return all_anchors.slice(all_anchors.size() - target_count, all_anchors.size())


static func build_transform(
	preset: FoliagePreset,
	position: Vector3,
	tangent: Vector3,
	turtle_up: Vector3,
	scale: float,
	droop_deg: float,
	spin: float,
	fascicle_index: int
) -> Transform3D:
	match preset.mesh_style:
		FoliagePreset.MeshStyle.CLUSTER:
			return _build_cluster_transform(position, tangent, scale, spin)
		FoliagePreset.MeshStyle.NEEDLE:
			return _build_fascicle_transform(
				preset, position, tangent, turtle_up, scale, fascicle_index, spin
			)
		FoliagePreset.MeshStyle.SCALE:
			return _build_fascicle_transform(
				preset, position, tangent, turtle_up, scale, fascicle_index, spin
			)
		_:
			return _build_broadleaf_transform(position, tangent, turtle_up, scale, droop_deg, spin)


static func _build_fascicle_transform(
	preset: FoliagePreset,
	position: Vector3,
	tangent: Vector3,
	turtle_up: Vector3,
	scale: float,
	fascicle_index: int,
	spin: float
) -> Transform3D:
	var along: Vector3 = tangent.normalized()
	var side: Vector3 = turtle_up.cross(along)
	if side.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		side = Vector3Frame.reference_up_for_direction(along).cross(along)
	if side.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		side = Vector3.RIGHT
	side = side.normalized()
	var up: Vector3 = along.cross(side).normalized()

	var phyllotaxis: float = deg_to_rad(
		preset.fascicle_roll_step_deg * float(fascicle_index) + spin * preset.fascicle_roll_jitter_deg
	)
	side = side.rotated(along, phyllotaxis)
	up = along.cross(side).normalized()

	var basis := Basis(side, up, along)
	var style_scale: float = scale
	if preset.mesh_style == FoliagePreset.MeshStyle.SCALE:
		style_scale *= 0.85
	basis = basis.scaled(Vector3.ONE * style_scale)
	return Transform3D(basis, position)


static func _build_cluster_transform(position: Vector3, tangent: Vector3, scale: float, spin: float) -> Transform3D:
	var along: Vector3 = tangent.normalized()
	var radius: float = scale * CLUSTER_RADIUS_SCALE
	var offset: Vector3 = along * radius * 0.35
	var squash: float = 0.82
	var basis := Basis.IDENTITY
	if along.length_squared() > MeshConstants.DIR_EPSILON_SQ:
		basis = basis.rotated(along, spin * TAU)
	basis = basis.scaled(Vector3(radius, radius * squash, radius))
	return Transform3D(basis, position + offset)


static func _build_broadleaf_transform(
	position: Vector3,
	tangent: Vector3,
	turtle_up: Vector3,
	scale: float,
	droop_deg: float,
	spin: float
) -> Transform3D:
	var outward: Vector3 = tangent.normalized()
	var basis := _foliage_attachment_basis(outward, turtle_up, droop_deg, spin)
	basis = basis.scaled(Vector3.ONE * scale)
	return Transform3D(basis, position)


static func _foliage_attachment_basis(
	outward: Vector3,
	turtle_up: Vector3,
	droop_deg: float,
	spin: float
) -> Basis:
	var tangent: Vector3 = outward.normalized()
	var side: Vector3 = turtle_up.cross(tangent)
	if side.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		side = Vector3Frame.reference_up_for_direction(tangent).cross(tangent)
	if side.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		side = Vector3.RIGHT
	side = side.normalized()
	var drooped: Vector3 = tangent.rotated(side, deg_to_rad(droop_deg)).normalized()
	side = drooped.cross(Vector3.UP)
	if side.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		side = drooped.cross(Vector3.FORWARD)
	side = side.normalized()
	side = side.rotated(drooped, spin * TAU)
	var into_branch: Vector3 = side.cross(drooped).normalized()
	return Basis(side, drooped, into_branch)


static func _instance_count_for_tip(preset: FoliagePreset, foliage_amount: float) -> int:
	var amount: float = clampf(foliage_amount, 0.0, 1.0)
	var min_count: int = maxi(preset.instances_per_tip.x, 1)
	var max_count: int = maxi(preset.instances_per_tip.y, min_count)
	if amount <= 0.001:
		return 0
	if amount < 0.35:
		return min_count
	return int(round(lerpf(float(min_count), float(max_count), amount)))


static func _instance_scale(preset: FoliagePreset, tip_id: int, slot: int, foliage_amount: float) -> float:
	var base_scale: float = lerpf(preset.scale_range.x, preset.scale_range.y, foliage_amount)
	var jitter: float = _hash01(tip_id, slot, 17) * 0.1 - 0.05
	return maxf(base_scale + jitter, 0.15)


static func _droop_jitter(tip_id: int, slot: int) -> float:
	return (_hash01(tip_id, slot, 53) - 0.5) * 6.0


static func _build_instance_custom(
	preset: FoliagePreset,
	tip_id: int,
	slot: int,
	foliage_amount: float
) -> Color:
	var phase: float = _hash01(tip_id, slot, 11)
	var sway_scale: float = lerpf(0.85, 1.15, _hash01(tip_id, slot, 23))
	return Color(phase, sway_scale, clampf(foliage_amount, 0.0, 1.0), 0.0)


static func _hash01(a: int, b: int, salt: int) -> float:
	var value: int = absi(a * 92837111 + b * 689287499 + salt * 12345)
	return float(value % 10000) / 10000.0
