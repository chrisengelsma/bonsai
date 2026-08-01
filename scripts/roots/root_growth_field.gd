class_name RootGrowthField
extends RefCounted

const PotBoundsClass = preload("res://scripts/pot/pot_bounds.gd")
const GrowthBarrierClass = preload("res://scripts/roots/growth_barrier.gd")

var bowl
var barriers: Array = []


static func create(bowl_bounds, barrier_list: Array = []) -> RootGrowthField:
	var field = load("res://scripts/roots/root_growth_field.gd").new()
	field.bowl = bowl_bounds
	field.barriers = barrier_list.duplicate()
	return field


func is_free(point: Vector3) -> bool:
	if bowl == null or not bowl.contains_point(point):
		return false
	for barrier in barriers:
		if barrier.blocks_point(point):
			return false
	return true


func repulsion_at(point: Vector3) -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for barrier in barriers:
		total += barrier.repulsion_at(point)
	return total


func resistance_at(point: Vector3) -> float:
	var resistance: float = 0.0

	if bowl != null:
		var inner_radius: float = bowl.inner_radius_at_y(point.y)
		if inner_radius > 0.0001:
			var radial: float = Vector2(point.x, point.z).length() / inner_radius
			resistance += pow(clampf(radial, 0.0, 1.0), 3.0) * 0.35

	for barrier in barriers:
		var offset: Vector3 = point - barrier.center
		var dist: float = offset.length()
		var influence: float = barrier.radius + barrier.padding * 3.5
		if dist < influence:
			var t: float = 1.0 - clampf(dist / influence, 0.0, 1.0)
			resistance += t * t * 1.25

	return resistance


func segment_resistance(start: Vector3, end: Vector3, samples: int = 6) -> float:
	if samples <= 0:
		return resistance_at(end)
	var total: float = 0.0
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		total += resistance_at(start.lerp(end, t))
	return total / float(samples + 1)


func segment_clear(start: Vector3, end: Vector3, samples: int = 5) -> bool:
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		if not is_free(start.lerp(end, t)):
			return false
	return true


func constrain_step(start: Vector3, direction: Vector3, length: float) -> Dictionary:
	var dir: Vector3 = direction.normalized()
	if length <= 0.0:
		return {"length": 0.0, "blocked": false, "tip": start, "direction": dir}

	var end: Vector3 = start + dir * length
	if is_free(end) and segment_clear(start, end):
		return {"length": length, "blocked": false, "tip": end, "direction": dir}

	var lo: float = 0.0
	var hi: float = length
	for _i in range(14):
		var mid: float = (lo + hi) * 0.5
		var mid_point: Vector3 = start + dir * mid
		if is_free(mid_point) and segment_clear(start, mid_point):
			lo = mid
		else:
			hi = mid

	var allowed: float = maxf(lo, 0.0)
	var tip: Vector3 = start + dir * allowed
	var blocked: bool = allowed < length - 0.0005
	var normal: Vector3 = Vector3.ZERO
	if blocked and bowl != null:
		normal = bowl.boundary_normal_at(tip)
		if normal.length_squared() <= 0.0001:
			normal = collision_normal_at(tip)
	return {
		"length": allowed,
		"blocked": blocked,
		"tip": tip,
		"direction": dir,
		"normal": normal,
	}


func find_step_around(start: Vector3, preferred_dir: Vector3, length: float) -> Dictionary:
	var base_dir: Vector3 = _steer_direction(start, preferred_dir)
	var candidates: Array = []

	for angle_deg in range(-90, 91, 10):
		candidates.append(base_dir.rotated(Vector3.UP, deg_to_rad(float(angle_deg))))

	for tilt_deg in [-38.0, -24.0, -12.0, 8.0, 22.0, 36.0]:
		var tilted: Vector3 = base_dir.rotated(Vector3.RIGHT, deg_to_rad(tilt_deg)).normalized()
		for angle_deg in range(-75, 76, 12):
			candidates.append(tilted.rotated(Vector3.UP, deg_to_rad(float(angle_deg))))

	var best: Dictionary = {}
	var best_score: float = INF
	var pref: Vector3 = preferred_dir.normalized()
	for candidate in candidates:
		var dir: Vector3 = (candidate as Vector3).normalized()
		if dir.length_squared() <= 0.0001:
			continue
		var step: Dictionary = constrain_step(start, dir, length)
		var allowed: float = float(step.get("length", 0.0))
		if allowed <= 0.0001:
			continue
		var tip: Vector3 = step.get("tip", start)
		var path_cost: float = segment_resistance(start, tip, 5)
		var bias: float = (1.0 - dir.dot(pref)) * 0.1
		if dir.dot(Vector3.DOWN) < 0.0:
			bias += absf(dir.dot(Vector3.DOWN)) * 0.08
		var horizontal: float = Vector2(dir.x, dir.z).length()
		bias -= horizontal * 0.07
		if bowl != null and start.y <= bowl.floor_y + 0.02:
			var down_penalty: float = maxf(dir.dot(Vector3.DOWN), 0.0)
			bias += down_penalty * 0.45
			bias -= horizontal * 0.12
		var score: float = path_cost + bias - (allowed / length) * 0.05
		if score < best_score:
			best_score = score
			best = step

	if best.is_empty():
		return {
			"length": 0.0,
			"blocked": true,
			"tip": start,
			"direction": base_dir,
			"normal": collision_normal_at(start),
		}
	return best


func collision_normal_at(point: Vector3) -> Vector3:
	if bowl != null:
		var bowl_normal: Vector3 = bowl.boundary_normal_at(point)
		if bowl_normal.length_squared() > 0.0001:
			return bowl_normal

	for barrier in barriers:
		var offset: Vector3 = point - barrier.center
		var dist: float = offset.length()
		var min_dist: float = barrier.radius + barrier.padding
		if dist < min_dist and dist > 0.0001:
			return offset / dist

	return Vector3.ZERO


func _steer_direction(point: Vector3, preferred_dir: Vector3) -> Vector3:
	var repulsion: Vector3 = repulsion_at(point)
	if repulsion.length_squared() <= 0.0001:
		return preferred_dir.normalized()
	var steered: Vector3 = preferred_dir + repulsion * 3.2
	if steered.length_squared() <= 0.0001:
		return preferred_dir.normalized()
	return steered.normalized()
