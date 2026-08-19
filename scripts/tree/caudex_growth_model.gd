class_name CaudexGrowthModel
extends RefCounted

const GinsengBasalForm = preload("res://scripts/tree/ginseng_basal_form.gd")

## Visual bulk swell per unit of basal cambium.
const BULK_CAMBIUM_SCALE := 9.0
## Vertical uplift per unit of basal cambium.
const HEIGHT_CAMBIUM_SCALE := 9.0


## Called when basal cambium thickens on the ginseng neck/anchor path.
static func accumulate_from_cambium(graph, cambium_rate: float, pattern) -> void:
	if not graph.has_caudex or cambium_rate <= 0.0:
		return

	var growth_scale: float = _growth_scale(pattern)
	var max_bulk: float = _max_bulk_radius(pattern)
	if graph.caudex_bulk_radius < max_bulk:
		var room: float = max_bulk - graph.caudex_bulk_radius
		graph.caudex_bulk_radius = minf(
			graph.caudex_bulk_radius + cambium_rate * BULK_CAMBIUM_SCALE * growth_scale * _growth_damping(room, max_bulk),
			max_bulk
		)

	_grow_height_from_cambium(graph, cambium_rate * growth_scale, pattern)
	_sync_anchor_length(graph)


static func growth_factor_at_radius(bulk_radius: float, pattern) -> float:
	var max_radius: float = _max_bulk_radius(pattern)
	if max_radius <= 0.0:
		return 0.0
	var room: float = max_radius - bulk_radius
	return _growth_damping(room, max_radius)


static func _grow_height_from_cambium(graph, cambium_rate: float, pattern) -> void:
	var max_height: float = _max_height(pattern, graph)
	if graph.caudex_height < GinsengBasalForm.START_CAUDEX_HEIGHT:
		graph.caudex_height = GinsengBasalForm.START_CAUDEX_HEIGHT
	if graph.caudex_height >= max_height:
		return

	var room: float = max_height - graph.caudex_height
	var start_height: float = GinsengBasalForm.START_CAUDEX_HEIGHT
	var height_delta: float = (
		cambium_rate * HEIGHT_CAMBIUM_SCALE * _growth_damping(room, max_height - start_height)
	)
	graph.caudex_height = minf(graph.caudex_height + height_delta, max_height)


static func _sync_anchor_length(graph) -> void:
	if not graph.nodes.has(graph.root_id):
		return
	var anchor = graph.nodes[graph.root_id]
	if anchor.is_caudex_anchor:
		anchor.length = graph.caudex_height
		_sync_anchor_profile_tip(anchor, graph.caudex_height)


static func _sync_anchor_profile_tip(anchor, tip_dist: float) -> void:
	if anchor.ring_samples.is_empty():
		return
	var tip_dir: Vector3 = anchor.direction.normalized()
	var last: Dictionary = anchor.ring_samples[-1].duplicate()
	last["dist"] = tip_dist
	last["dir"] = tip_dir
	anchor.ring_samples[-1] = last
	if anchor.ring_samples.size() > 1:
		var first: Dictionary = anchor.ring_samples[0].duplicate()
		first["dir"] = tip_dir
		anchor.ring_samples[0] = first
	anchor.last_profile_direction = tip_dir
	anchor.last_ring_sample_dist = tip_dist


static func _growth_damping(room: float, span: float) -> float:
	return clampf(room / maxf(span * 0.5, 0.001), 0.4, 1.0)


static func _growth_scale(pattern) -> float:
	if pattern == null:
		return 1.0
	return clampf(pattern.caudex_growth_mult, 0.05, 2.0)


static func _start_bulk_radius(pattern) -> float:
	return maxf(pattern.trunk_thickness * 0.2, 0.0048)


static func _max_bulk_radius(pattern) -> float:
	return pattern.trunk_thickness * pattern.basal_radius_mult


static func _max_height(pattern, graph) -> float:
	if graph != null and graph.caudex_max_height > 0.0:
		return graph.caudex_max_height
	if pattern != null and pattern.caudex_max_height > 0.0:
		return pattern.caudex_max_height
	return GinsengBasalForm.MAX_CAUDEX_HEIGHT
