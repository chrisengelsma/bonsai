class_name Vector3Frame
extends RefCounted

const MeshConstants = preload("res://scripts/util/mesh_constants.gd")


static func reference_up_for_direction(
	direction: Vector3,
	threshold: float = MeshConstants.PARALLEL_DOT_THRESHOLD
) -> Vector3:
	var dir: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3.UP
	if absf(dir.dot(reference)) > threshold:
		reference = Vector3.FORWARD
	return reference


static func safe_tangent_axis(
	direction: Vector3,
	fallback: Vector3 = Vector3.RIGHT
) -> Vector3:
	var tangent: Vector3 = direction.cross(Vector3.UP)
	if tangent.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		tangent = direction.cross(Vector3.FORWARD)
	if tangent.length_squared() < MeshConstants.DIR_EPSILON_SQ:
		return fallback
	return tangent.normalized()


static func sanitize_turtle_up(heading: Vector3, hint: Vector3) -> Vector3:
	var up_hint: Vector3 = hint.normalized()
	if up_hint.length_squared() < MeshConstants.DIR_EPSILON_SQ \
			or absf(heading.normalized().dot(up_hint)) > MeshConstants.ORIENT_PARALLEL_DOT_THRESHOLD:
		up_hint = Vector3.FORWARD
		if absf(heading.normalized().dot(up_hint)) > MeshConstants.ORIENT_PARALLEL_DOT_THRESHOLD:
			up_hint = Vector3.RIGHT
	return up_hint


static func init_turtle_frame(heading: Vector3, turtle_up_hint: Vector3) -> Dictionary:
	var heading_n: Vector3 = heading.normalized()
	var turtle_up: Vector3 = sanitize_turtle_up(heading_n, turtle_up_hint)
	var left: Vector3 = turtle_up.cross(heading_n).normalized()
	turtle_up = heading_n.cross(left).normalized()
	return {"heading": heading_n, "left": left, "up": turtle_up}


static func basis_along_direction(direction: Vector3) -> Basis:
	if direction.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		return Basis.IDENTITY
	var y_axis: Vector3 = direction.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(y_axis)
	if x_axis.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		x_axis = Vector3.FORWARD.cross(y_axis)
	if x_axis.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		return Basis.IDENTITY
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = y_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


static func orient_cylinder_mesh(
	mesh_instance: Node3D,
	start: Vector3,
	direction: Vector3,
	height: float
) -> void:
	if direction.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		return
	mesh_instance.position = start + direction.normalized() * (height * 0.5)
	mesh_instance.basis = basis_along_direction(direction)


static func cylinder_transform(start: Vector3, end: Vector3, radius_scale: float) -> Transform3D:
	var delta: Vector3 = end - start
	var length: float = delta.length()
	if length <= MeshConstants.MIN_CYLINDER_SEGMENT_LENGTH:
		return Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), start)

	var direction: Vector3 = delta / length
	var y_axis: Vector3 = direction
	var x_axis: Vector3 = Vector3.UP.cross(y_axis)
	if x_axis.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		x_axis = Vector3.FORWARD.cross(y_axis)
	if x_axis.length_squared() <= MeshConstants.DIR_EPSILON_SQ:
		return Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), start)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = y_axis.cross(x_axis).normalized()
	var basis := Basis(x_axis * radius_scale, y_axis * length, z_axis * radius_scale)
	return Transform3D(basis, start + direction * (length * 0.5))


static func project_along_segment(start: Vector3, end: Vector3, point: Vector3, min_along: float = 0.02) -> float:
	var segment: Vector3 = end - start
	var length_sq: float = segment.length_squared()
	if length_sq <= MeshConstants.DIR_EPSILON_SQ:
		return min_along
	return clampf((point - start).dot(segment) / length_sq, min_along, 1.0)
