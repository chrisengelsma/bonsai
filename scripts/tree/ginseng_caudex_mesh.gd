class_name GinsengCaudexMesh
extends RefCounted

const DeterministicNoise = preload("res://scripts/util/deterministic_noise.gd")


static func build(
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	radial_segments: int = 10,
	arc_steps: int = 12,
	surface_seed: int = 17
) -> ArrayMesh:
	arc_count = clampi(arc_count, 2, 4)
	if height <= 0.01 or bulk_radius <= 0.005:
		return null

	var base_radius: float = bulk_radius * 0.78
	var bulge_radius: float = bulk_radius
	var neck_radius: float = maxf(top_radius, bulk_radius * 0.38)
	var arcs: Array = _build_arc_polylines(
		arc_count,
		height,
		base_radius,
		bulge_radius,
		neck_radius,
		arc_steps,
		surface_seed
	)
	if arcs.is_empty():
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for arc_i in range(arc_count):
		var next_i: int = (arc_i + 1) % arc_count
		var arc_a: Array = arcs[arc_i]
		var arc_b: Array = arcs[next_i]
		for step in range(arc_steps):
			_add_quad(
				st,
				arc_a[step],
				arc_a[step + 1],
				arc_b[step + 1],
				arc_b[step]
			)

	var center_bottom := Vector3.ZERO
	for arc_i in range(arc_count):
		var next_i: int = (arc_i + 1) % arc_count
		var a: Vector3 = arcs[arc_i][0]
		var b: Vector3 = arcs[next_i][0]
		st.add_vertex(center_bottom)
		st.add_vertex(a)
		st.add_vertex(b)

	var center_top := Vector3(0.0, height, 0.0)
	for arc_i in range(arc_count):
		var next_i: int = (arc_i + 1) % arc_count
		var a: Vector3 = arcs[arc_i][-1]
		var b: Vector3 = arcs[next_i][-1]
		st.add_vertex(center_top)
		st.add_vertex(b)
		st.add_vertex(a)

	return st.commit()


static func build_wireframe(
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	arc_steps: int = 12,
	surface_seed: int = 17
) -> ArrayMesh:
	var base_radius: float = bulk_radius * 0.78
	var bulge_radius: float = bulk_radius
	var neck_radius: float = maxf(top_radius, bulk_radius * 0.38)
	var arcs: Array = _build_arc_polylines(
		arc_count,
		height,
		base_radius,
		bulge_radius,
		neck_radius,
		arc_steps,
		surface_seed
	)
	if arcs.is_empty():
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for arc in arcs:
		for i in range(arc.size() - 1):
			st.add_vertex(arc[i])
			st.add_vertex(arc[i + 1])

	for step in range(arc_steps + 1):
		for arc_i in range(arc_count):
			var next_i: int = (arc_i + 1) % arc_count
			st.add_vertex(arcs[arc_i][step])
			st.add_vertex(arcs[next_i][step])

	return st.commit()


static func _build_arc_polylines(
	arc_count: int,
	height: float,
	base_radius: float,
	bulge_radius: float,
	neck_radius: float,
	arc_steps: int,
	surface_seed: int
) -> Array:
	var arcs: Array = []
	for arc_i in range(arc_count):
		var yaw: float = TAU * float(arc_i) / float(arc_count)
		var outward := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
		var wobble: float = DeterministicNoise.unit_hash(surface_seed, arc_i, 0) * bulge_radius * 0.08
		var bulge: float = bulge_radius + wobble
		var bottom := outward * base_radius
		var mid := outward * bulge + Vector3(0.0, height * 0.46, 0.0)
		var top := outward * neck_radius + Vector3(0.0, height, 0.0)
		var points: Array = []
		for step in range(arc_steps + 1):
			var t: float = float(step) / float(arc_steps)
			var inv: float = 1.0 - t
			var point: Vector3 = bottom * inv * inv + mid * 2.0 * inv * t + top * t * t
			points.append(point)
		arcs.append(points)
	return arcs


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() > 0.0000001:
		normal = normal.normalized()
	else:
		normal = Vector3.UP
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(d)
