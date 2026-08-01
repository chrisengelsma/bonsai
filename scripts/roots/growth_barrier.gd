class_name GrowthBarrier
extends RefCounted

var center: Vector3 = Vector3.ZERO
var radius: float = 0.05
var padding: float = 0.01


static func from_sphere(center: Vector3, radius: float, padding: float = 0.01) -> GrowthBarrier:
	var barrier = load("res://scripts/roots/growth_barrier.gd").new()
	barrier.center = center
	barrier.radius = radius
	barrier.padding = padding
	return barrier


static func from_mesh_instance(mesh_instance: MeshInstance3D, padding: float = 0.01) -> GrowthBarrier:
	var barrier = load("res://scripts/roots/growth_barrier.gd").new()
	barrier.center = mesh_instance.position
	var mesh: Mesh = mesh_instance.mesh
	if mesh is SphereMesh:
		barrier.radius = float(mesh.radius) * maxf(mesh_instance.scale.x, mesh_instance.scale.y)
	else:
		var aabb: AABB = mesh.get_aabb() if mesh else AABB()
		var scaled_extents: Vector3 = aabb.size * mesh_instance.scale
		barrier.radius = maxf(scaled_extents.x, scaled_extents.z) * 0.5
	barrier.padding = padding
	return barrier


func blocks_point(point: Vector3) -> bool:
	return center.distance_to(point) < radius + padding


func repulsion_at(point: Vector3) -> Vector3:
	var offset: Vector3 = point - center
	var dist: float = offset.length()
	var min_dist: float = radius + padding
	if dist >= min_dist or dist <= 0.0001:
		return Vector3.ZERO
	var push: Vector3 = offset / dist
	var strength: float = pow((min_dist - dist) / min_dist, 0.65)
	return push * strength
