class_name BranchProfileSamples
extends RefCounted

const MeshConstants = preload("res://scripts/util/mesh_constants.gd")


static func resolve_tip_direction(tip_dir: Vector3, samples: Array, fallback: Vector3 = Vector3.UP) -> Vector3:
	if tip_dir.length_squared() > MeshConstants.DIR_EPSILON_SQ:
		return tip_dir.normalized()
	if not samples.is_empty():
		return samples[-1].get("dir", fallback).normalized()
	return fallback


static func append_sample(
	samples: Array,
	dist: float,
	direction: Vector3,
	dist_eps: float = MeshConstants.DIST_EPSILON,
	angle_eps_deg: float = 0.35
) -> void:
	if samples.is_empty():
		samples.append({"dist": dist, "dir": direction.normalized()})
		return

	var last: Dictionary = samples[-1]
	var last_dist: float = float(last.get("dist", 0.0))
	if dist <= last_dist + dist_eps:
		return

	var last_dir: Vector3 = last.get("dir", Vector3.UP).normalized()
	if last_dir.angle_to(direction.normalized()) < deg_to_rad(angle_eps_deg) \
			and dist - last_dist < dist_eps * 2.0:
		return

	samples.append({"dist": dist, "dir": direction.normalized()})
