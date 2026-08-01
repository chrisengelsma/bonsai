class_name PotBounds
extends RefCounted

## Interior bowl volume in Pot node local space (Y up, bowl floor at floor_y).

var floor_y: float = 0.0
var rim_y: float = 0.18
var top_inner_radius: float = 0.52
var bottom_inner_radius: float = 0.48


static func from_pot_mesh(
	floor_y: float = 0.0,
	rim_y: float = 0.18,
	top_outer_radius: float = 0.66,
	bottom_outer_radius: float = 0.54,
	wall_thickness: float = 0.12
):
	var bounds = load("res://scripts/pot/pot_bounds.gd").new()
	bounds.floor_y = floor_y
	bounds.rim_y = rim_y
	bounds.top_inner_radius = maxf(top_outer_radius - wall_thickness, 0.08)
	bounds.bottom_inner_radius = maxf(bottom_outer_radius - wall_thickness, 0.06)
	return bounds


func inner_radius_at_y(y: float) -> float:
	var t: float = inverse_lerp(floor_y, rim_y, clampf(y, floor_y, rim_y))
	return lerpf(bottom_inner_radius, top_inner_radius, t)


func contains_point(local_pos: Vector3) -> bool:
	if local_pos.y < floor_y - 0.0001 or local_pos.y > rim_y + 0.0001:
		return false
	var radial: float = Vector2(local_pos.x, local_pos.z).length()
	return radial <= inner_radius_at_y(local_pos.y) + 0.0001


func boundary_normal_at(point: Vector3, epsilon: float = 0.005) -> Vector3:
	if point.y <= floor_y + epsilon:
		return Vector3.UP
	if point.y >= rim_y - epsilon:
		return Vector3.DOWN

	var radial: Vector2 = Vector2(point.x, point.z)
	var radius: float = radial.length()
	if radius <= 0.0001:
		return Vector3.ZERO

	var max_r: float = inner_radius_at_y(point.y)
	if radius >= max_r - epsilon:
		return Vector3(radial.x / radius, 0.0, radial.y / radius).normalized()

	return Vector3.ZERO


func clamp_point(local_pos: Vector3) -> Vector3:
	var clamped_y: float = clampf(local_pos.y, floor_y, rim_y)
	var radial: Vector2 = Vector2(local_pos.x, local_pos.z)
	var max_r: float = inner_radius_at_y(clamped_y)
	if radial.length_squared() > max_r * max_r and radial.length_squared() > 0.000001:
		radial = radial.normalized() * max_r
	return Vector3(radial.x, clamped_y, radial.y)


func constrain_segment(joint: Vector3, direction: Vector3, length: float) -> Dictionary:
	var dir: Vector3 = direction.normalized()
	if length <= 0.0:
		return {"length": 0.0, "blocked": false, "tip": joint}

	var end: Vector3 = joint + dir * length
	if contains_point(end):
		return {"length": length, "blocked": false, "tip": end}

	var lo: float = 0.0
	var hi: float = length
	for _step in range(14):
		var mid: float = (lo + hi) * 0.5
		if contains_point(joint + dir * mid):
			lo = mid
		else:
			hi = mid

	var allowed: float = maxf(lo, 0.0)
	return {
		"length": allowed,
		"blocked": allowed < length - 0.0005,
		"tip": joint + dir * allowed,
	}
