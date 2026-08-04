class_name FoliageGrowthPath
extends RefCounted

const BranchMeshBuilder = preload("res://scripts/tree/branch_mesh_builder.gd")
const BranchSegment = preload("res://scripts/tree/branch_segment.gd")
const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")
const MeshConstants = preload("res://scripts/util/mesh_constants.gd")

const GOLDEN_ANGLE_DEG := 137.508


## Build world-space foliage anchors from a branch's recorded growth samples.
static func build_world_anchors(graph, node_id: int, preset: FoliagePreset) -> Array:
	if graph == null or preset == null or not graph.nodes.has(node_id):
		return []

	var node = graph.nodes[node_id]
	if graph.has_method("ensure_profile_render_ready"):
		graph.ensure_profile_render_ready(node)

	var length: float = maxf(node.length, MeshConstants.MIN_BRANCH_HEIGHT)
	if length <= 0.001:
		return []

	var joint: Vector3 = graph.get_joint(node_id)
	var samples: Array = BranchMeshBuilder.finalize_branch_samples(
		node.ring_samples,
		node.length,
		node.direction
	)
	if samples.is_empty():
		return _fallback_straight_anchors(graph, node_id, preset)

	var centers: Array = BranchMeshBuilder.compute_sample_centers(samples)
	var sample_anchors: Array = _anchors_from_ring_samples(
		samples, centers, joint, length, preset
	)
	var spaced_anchors: Array = _anchors_from_arc_spacing(
		samples, centers, joint, length, preset
	)
	return _merge_anchor_sets(sample_anchors, spaced_anchors, preset)


static func select_mature_anchors(all_anchors: Array, foliage_amount: float) -> Array:
	if all_anchors.is_empty():
		return []

	var sorted: Array = all_anchors.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dist", 0.0)) < float(b.get("dist", 0.0))
	)

	var maturity: float = clampf(foliage_amount, 0.0, 1.0)
	if maturity <= 0.001:
		return []

	var count: int = maxi(1, int(round(maturity * float(sorted.size()))))
	return sorted.slice(sorted.size() - count, sorted.size())


static func is_eligible_branch(node, preset: FoliagePreset) -> bool:
	if node == null or preset == null:
		return false
	if node.is_caudex_anchor:
		return false
	if not node.children.is_empty():
		return false
	if node.depth < preset.min_branch_depth:
		return false
	if preset.max_branch_thickness > 0.0 and node.thickness > preset.max_branch_thickness:
		return false
	return true


static func _anchors_from_ring_samples(
	samples: Array,
	centers: Array,
	joint: Vector3,
	length: float,
	preset: FoliagePreset
) -> Array:
	var anchors: Array = []
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		var dist: float = float(sample.get("dist", 0.0))
		if not _dist_in_foliage_window(dist, length, preset):
			continue
		var tangent: Vector3 = sample.get("dir", Vector3.UP).normalized()
		anchors.append({
			"position": joint + centers[i],
			"tangent": tangent,
			"dist": dist,
			"fascicle_index": i,
			"source": "growth_sample",
		})
	return anchors


static func _anchors_from_arc_spacing(
	samples: Array,
	centers: Array,
	joint: Vector3,
	length: float,
	preset: FoliagePreset
) -> Array:
	var start_dist: float = length * preset.leaf_start_ratio
	var end_dist: float = length * preset.leaf_end_ratio
	var cover: float = maxf(end_dist - start_dist, preset.fascicle_spacing)
	var count: int = maxi(1, int(round(cover / preset.fascicle_spacing)))
	count = mini(count, preset.max_fascicles_per_twigs)

	var anchors: Array = []
	for i in range(count):
		var dist: float = start_dist + (float(i) + 0.5) * cover / float(count)
		if dist > end_dist + 0.0001:
			continue
		var profile: Dictionary = BranchMeshBuilder.interpolate_sample_at_dist(samples, dist)
		var tangent: Vector3 = profile.get("dir", Vector3.UP).normalized()
		var local_center: Vector3 = _center_at_dist(samples, centers, dist)
		anchors.append({
			"position": joint + local_center,
			"tangent": tangent,
			"dist": dist,
			"fascicle_index": i,
			"source": "arc_spacing",
		})
	return anchors


static func _merge_anchor_sets(
	sample_anchors: Array,
	spaced_anchors: Array,
	preset: FoliagePreset
) -> Array:
	if preset.placement == FoliagePreset.Placement.TIP_ONLY:
		if spaced_anchors.is_empty():
			return sample_anchors
		return [spaced_anchors[-1]]

	if preset.placement == FoliagePreset.Placement.SEGMENT_SCATTER:
		return spaced_anchors if not spaced_anchors.is_empty() else sample_anchors

	# Growth-aligned fascicles: prefer ring samples; fill gaps with spaced sites.
	if sample_anchors.size() >= 2:
		return sample_anchors
	if not spaced_anchors.is_empty():
		return spaced_anchors
	return sample_anchors


static func _fallback_straight_anchors(graph, node_id: int, preset: FoliagePreset) -> Array:
	var seg: Dictionary = BranchSegment.from_graph(graph, node_id)
	var length: float = maxf(seg.length, MeshConstants.MIN_BRANCH_HEIGHT)
	var tangent: Vector3 = seg.direction.normalized()
	var start_dist: float = length * preset.leaf_start_ratio
	var end_dist: float = length * preset.leaf_end_ratio
	var cover: float = maxf(end_dist - start_dist, preset.fascicle_spacing)
	var count: int = maxi(1, int(round(cover / preset.fascicle_spacing)))
	count = mini(count, preset.max_fascicles_per_twigs)

	var anchors: Array = []
	for i in range(count):
		var dist: float = start_dist + (float(i) + 0.5) * cover / float(count)
		var t: float = clampf(dist / length, 0.0, 1.0)
		anchors.append({
			"position": seg.start.lerp(seg.end, t),
			"tangent": tangent,
			"dist": dist,
			"fascicle_index": i,
			"source": "fallback",
		})
	return anchors


static func _dist_in_foliage_window(dist: float, length: float, preset: FoliagePreset) -> bool:
	if length <= 0.0001:
		return false
	var t: float = dist / length
	return t >= preset.leaf_start_ratio and t <= preset.leaf_end_ratio


static func _center_at_dist(samples: Array, centers: Array, dist: float) -> Vector3:
	if samples.is_empty() or centers.is_empty():
		return Vector3.ZERO
	if dist <= float(samples[0].get("dist", 0.0)):
		return centers[0]
	for i in range(1, samples.size()):
		var prev_dist: float = float(samples[i - 1].get("dist", 0.0))
		var next_dist: float = float(samples[i].get("dist", 0.0))
		if dist <= next_dist:
			var span: float = next_dist - prev_dist
			var local_t: float = 0.0 if span <= 0.0001 else clampf((dist - prev_dist) / span, 0.0, 1.0)
			return centers[i - 1].lerp(centers[i], local_t)
	return centers[-1]
