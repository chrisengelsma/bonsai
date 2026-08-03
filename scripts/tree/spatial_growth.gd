class_name SpatialGrowth
extends RefCounted

const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")

## Helpers for spreading branches in full 3D instead of a single plane.


static func spread_direction(
	base_direction: Vector3,
	spread_deg: float,
	rng: RandomNumberGenerator
) -> Vector3:
	if spread_deg <= 0.0:
		return base_direction.normalized()

	var direction: Vector3 = base_direction.normalized()
	var tangent: Vector3 = Vector3Frame.safe_tangent_axis(direction)
	var bitangent: Vector3 = direction.cross(tangent).normalized()

	var pitch: float = deg_to_rad(rng.randf_range(-spread_deg, spread_deg))
	var yaw: float = deg_to_rad(rng.randf_range(-spread_deg, spread_deg))
	return direction.rotated(tangent, pitch).rotated(bitangent, yaw).normalized()


static func roll_turtle_frame(
	heading: Vector3,
	left: Vector3,
	turtle_up: Vector3,
	roll_deg: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	if roll_deg <= 0.0:
		return {"heading": heading, "left": left, "up": turtle_up}

	var axis: Vector3 = heading.normalized()
	var roll: float = deg_to_rad(rng.randf_range(-roll_deg, roll_deg))
	return {
		"heading": axis,
		"left": left.rotated(axis, roll).normalized(),
		"up": turtle_up.rotated(axis, roll).normalized(),
	}


static func random_turtle_up(direction: Vector3, rng: RandomNumberGenerator, roll_deg: float) -> Vector3:
	var heading: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3Frame.reference_up_for_direction(heading)
	var left: Vector3 = reference.cross(heading).normalized()
	var up: Vector3 = heading.cross(left).normalized()
	if roll_deg > 0.0:
		var roll: float = deg_to_rad(rng.randf_range(-roll_deg, roll_deg))
		up = up.rotated(heading, roll).normalized()
	return up
