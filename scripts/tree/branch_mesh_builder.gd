class_name BranchMeshBuilder
extends RefCounted

const MIN_RING_SPACING := 0.022


static func build_solid_branch(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int = 10,
	branch_length: float = 0.0
) -> ArrayMesh:
	var dense_samples: Array = _densify_samples(samples, branch_length)
	if dense_samples.size() < 2:
		return null
	return build_from_ring_samples(dense_samples, locked_wobble, radial_segments)


static func build_from_ring_samples(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int = 10
) -> ArrayMesh:
	if samples.size() < 2:
		return null

	radial_segments = maxi(radial_segments, 6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var centers: Array = _compute_sample_centers(samples)
	var rings: Array = []
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		var direction: Vector3 = sample.get("dir", Vector3.UP)
		var radius: float = float(sample.get("r", 0.02))
		rings.append(_build_ring_points(centers[i], direction, radius, locked_wobble, radial_segments))

	for ring_i in range(samples.size() - 1):
		for seg_i in range(radial_segments):
			var next_seg: int = (seg_i + 1) % radial_segments
			_add_quad(
				st,
				rings[ring_i][seg_i],
				rings[ring_i][next_seg],
				rings[ring_i + 1][next_seg],
				rings[ring_i + 1][seg_i]
			)

	return st.commit()


static func build_tapered_segment(
	height: float,
	bottom_radius: float,
	top_radius: float,
	radial_segments: int = 10,
	ring_count: int = 3,
	bark_variation: float = 0.11,
	surface_seed: int = 0
) -> ArrayMesh:
	height = maxf(height, 0.02)
	bottom_radius = maxf(bottom_radius, 0.004)
	top_radius = maxf(top_radius, 0.003)
	radial_segments = maxi(radial_segments, 6)
	ring_count = maxi(ring_count, 1)

	var samples: Array = []
	for ring_i in range(ring_count + 1):
		var t: float = float(ring_i) / float(ring_count)
		samples.append({
			"dist": height * t,
			"dir": Vector3.UP,
			"r": lerpf(bottom_radius, top_radius, t),
		})

	var wobble: Array = generate_locked_wobble(surface_seed, radial_segments, bark_variation)
	return build_solid_branch(samples, wobble, radial_segments, height)


static func generate_locked_wobble(surface_seed: int, radial_segments: int, amount: float) -> Array:
	var wobble: Array = []
	for seg_i in range(radial_segments):
		wobble.append(_radius_wobble(surface_seed, 0, seg_i, amount))
	return wobble


static func get_profile_tip_offset(samples: Array) -> Vector3:
	if samples.is_empty():
		return Vector3.ZERO
	var centers := _compute_sample_centers(samples)
	return centers[-1]


static func _densify_samples(samples: Array, branch_length: float) -> Array:
	if samples.is_empty():
		return []

	var total_length: float = branch_length
	if total_length <= 0.001:
		total_length = float(samples[-1].get("dist", 0.0))
	if total_length <= 0.001:
		return samples.duplicate()

	var ring_count: int = maxi(3, int(ceil(total_length / MIN_RING_SPACING)))
	var dense: Array = []
	for ring_i in range(ring_count + 1):
		var dist: float = total_length * float(ring_i) / float(ring_count)
		dense.append(_interpolate_sample_at_dist(samples, dist))
	return dense


static func _interpolate_sample_at_dist(samples: Array, dist: float) -> Dictionary:
	if samples.is_empty():
		return {"dist": dist, "dir": Vector3.UP, "r": 0.02}

	if dist <= float(samples[0].get("dist", 0.0)):
		var first: Dictionary = samples[0]
		return {
			"dist": dist,
			"dir": first.get("dir", Vector3.UP),
			"r": float(first.get("r", 0.02)),
		}

	var segment_dir: Vector3 = samples[0].get("dir", Vector3.UP)
	for i in range(samples.size() - 1):
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		var a_dist: float = float(a.get("dist", 0.0))
		var b_dist: float = float(b.get("dist", 0.0))
		segment_dir = a.get("dir", Vector3.UP)
		if dist < a_dist:
			continue
		if dist <= b_dist or i == samples.size() - 2:
			var t: float = 0.0
			if absf(b_dist - a_dist) > 0.0001:
				t = clampf((dist - a_dist) / (b_dist - a_dist), 0.0, 1.0)
			return {
				"dist": dist,
				"dir": segment_dir,
				"r": lerpf(float(a.get("r", 0.02)), float(b.get("r", 0.02)), t),
			}

	var last: Dictionary = samples[-1]
	return {
		"dist": dist,
		"dir": last.get("dir", Vector3.UP),
		"r": float(last.get("r", 0.02)),
	}


static func _compute_sample_centers(samples: Array) -> Array:
	var centers: Array = [Vector3.ZERO]
	for i in range(1, samples.size()):
		var step: float = float(samples[i].get("dist", 0.0)) - float(samples[i - 1].get("dist", 0.0))
		var direction: Vector3 = samples[i - 1].get("dir", Vector3.UP)
		centers.append(centers[i - 1] + direction.normalized() * step)
	return centers


static func _build_ring_points(
	center: Vector3,
	direction: Vector3,
	radius: float,
	locked_wobble: Array,
	radial_segments: int
) -> Array:
	var dir: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3.UP
	if absf(dir.dot(reference)) > 0.92:
		reference = Vector3.FORWARD
	var right: Vector3 = dir.cross(reference).normalized()
	var forward: Vector3 = right.cross(dir).normalized()

	var points: Array = []
	for seg_i in range(radial_segments):
		var angle: float = TAU * float(seg_i) / float(radial_segments)
		var wobble: float = 1.0
		if not locked_wobble.is_empty():
			wobble = float(locked_wobble[seg_i % locked_wobble.size()])
		var r: float = radius * wobble
		points.append(center + (right * cos(angle) + forward * sin(angle)) * r)
	return points


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(st, a, b, c)
	_add_triangle(st, a, c, d)


static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 0.0000001:
		return
	normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)


static func _radius_wobble(surface_seed: int, ring: int, seg: int, amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	var h: int = absi(hash(Vector3i(surface_seed, ring, seg)))
	var n: float = float(h % 10001) / 5000.0 - 1.0
	return 1.0 + n * amount
