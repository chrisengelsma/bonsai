class_name CaudexGrowthModel
extends RefCounted


static func accumulate(graph, delta: float, pattern, moisture_factor: float) -> void:
	if not graph.has_caudex or delta <= 0.0 or moisture_factor <= 0.0:
		return

	var max_radius: float = _max_bulk_radius(pattern)
	if graph.caudex_bulk_radius >= max_radius:
		return

	var rate: float = pattern.cambium_growth_rate * pattern.basal_cambium_mult * delta * moisture_factor
	var room: float = max_radius - graph.caudex_bulk_radius
	rate *= clampf(room / maxf(max_radius * 0.32, 0.001), 0.06, 1.0)
	graph.caudex_bulk_radius = minf(graph.caudex_bulk_radius + rate, max_radius)


static func growth_factor_at_radius(bulk_radius: float, pattern) -> float:
	var max_radius: float = _max_bulk_radius(pattern)
	if max_radius <= 0.0:
		return 0.0
	var room: float = max_radius - bulk_radius
	return clampf(room / maxf(max_radius * 0.32, 0.001), 0.06, 1.0)


static func _max_bulk_radius(pattern) -> float:
	return pattern.trunk_thickness * pattern.basal_radius_mult
