class_name BranchMeshBuilder
extends RefCounted

const MeshConstants = preload("res://scripts/util/mesh_constants.gd")
const DeterministicNoise = preload("res://scripts/util/deterministic_noise.gd")
const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")
const BranchProfileSamples = preload("res://scripts/tree/branch_profile_samples.gd")

const MIN_SEGMENT_LENGTH := MeshConstants.MIN_CYLINDER_SEGMENT_LENGTH
const MIN_RING_SPACING := 0.022
const JOINT_OVERLAP_FRAC := 0.22


static func build_decimated_cylinder_specs(
	samples: Array,
	joint: Vector3,
	surface_seed: int,
	jitter_amount: float = 0.06,
	tip_dir: Vector3 = Vector3.UP
) -> Array:
	if samples.size() < 2:
		return []

	var centers: Array = compute_axis_centers(samples, tip_dir)
	var specs: Array = []
	for i in range(samples.size() - 1):
		var sample_a: Dictionary = samples[i]
		var sample_b: Dictionary = samples[i + 1]
		var start: Vector3 = joint + centers[i]
		var end: Vector3 = joint + centers[i + 1]
		var bottom_r: float = float(sample_a.get("r", 0.02))
		var top_r: float = float(sample_b.get("r", 0.02))
		bottom_r *= _jitter_scalar(surface_seed, i, 0, jitter_amount)
		top_r *= _jitter_scalar(surface_seed, i, 1, jitter_amount)

		var axis: Vector3 = end - start
		var height: float = axis.length()
		if height <= MIN_SEGMENT_LENGTH:
			continue

		var direction: Vector3 = axis / height
		if i > 0:
			var overlap: float = minf(bottom_r * JOINT_OVERLAP_FRAC, height * 0.18)
			start -= direction * overlap
		if i < samples.size() - 2:
			var overlap: float = minf(top_r * JOINT_OVERLAP_FRAC, height * 0.18)
			end += direction * overlap

		height = start.distance_to(end)
		if height <= MIN_SEGMENT_LENGTH:
			continue

		start += _position_jitter(surface_seed, i, direction, jitter_amount)
		end += _position_jitter(surface_seed, i + 1000, direction, jitter_amount)

		specs.append({
			"start": start,
			"end": end,
			"bottom_r": maxf(bottom_r, 0.003),
			"top_r": maxf(top_r, 0.003),
		})
	return specs


static func build_corner_blend_specs(
	samples: Array,
	joint: Vector3,
	surface_seed: int,
	min_bend_deg: float = 5.0,
	jitter_amount: float = 0.06,
	include_fork_tip: bool = false,
	tip_dir: Vector3 = Vector3.UP
) -> Array:
	if samples.size() < 2:
		return []

	var centers: Array = compute_axis_centers(samples, tip_dir)
	var blends: Array = []
	var min_bend: float = deg_to_rad(min_bend_deg)

	for i in range(1, samples.size() - 1):
		var bend: float = _bend_at_index(centers, i)
		if bend < min_bend:
			continue
		blends.append(_make_blend_spec(
			joint + centers[i],
			samples,
			i,
			bend,
			surface_seed,
			jitter_amount
		))

	if include_fork_tip and samples.size() >= 2:
		var tip_i: int = samples.size() - 1
		var dir_prev: Vector3 = (centers[tip_i] - centers[tip_i - 1]).normalized()
		var dir_tip: Vector3 = samples[tip_i].get("dir", Vector3.UP).normalized()
		var tip_bend: float = dir_prev.angle_to(dir_tip)
		if tip_bend >= min_bend * 0.5:
			blends.append(_make_blend_spec(
				joint + centers[tip_i],
				samples,
				tip_i,
				tip_bend,
				surface_seed,
				jitter_amount
			))

	return blends


static func compute_sample_centers(samples: Array) -> Array:
	var centers: Array = [Vector3.ZERO]
	for i in range(1, samples.size()):
		var step: float = float(samples[i].get("dist", 0.0)) - float(samples[i - 1].get("dist", 0.0))
		var direction: Vector3 = samples[i - 1].get("dir", Vector3.UP)
		centers.append(centers[i - 1] + direction.normalized() * step)
	return centers


static func compute_axis_centers(samples: Array, tip_dir: Vector3) -> Array:
	var tip_direction: Vector3 = BranchProfileSamples.resolve_tip_direction(tip_dir, samples)

	var centers: Array = []
	for sample in samples:
		centers.append(tip_direction * float(sample.get("dist", 0.0)))
	return centers


static func interpolate_sample_at_dist(samples: Array, dist: float) -> Dictionary:
	if samples.is_empty():
		return {"dist": dist, "dir": Vector3.UP, "r": 0.02}

	if dist <= float(samples[0].get("dist", 0.0)):
		var first: Dictionary = samples[0]
		return {
			"dist": dist,
			"dir": first.get("dir", Vector3.UP),
			"r": float(first.get("r", 0.02)),
		}

	for i in range(samples.size() - 1):
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		var a_dist: float = float(a.get("dist", 0.0))
		var b_dist: float = float(b.get("dist", 0.0))
		if dist < a_dist:
			continue
		if dist <= b_dist or i == samples.size() - 2:
			var t: float = 0.0
			if absf(b_dist - a_dist) > 0.0001:
				t = clampf((dist - a_dist) / (b_dist - a_dist), 0.0, 1.0)
			var dir_a: Vector3 = a.get("dir", Vector3.UP)
			return {
				"dist": dist,
				"dir": dir_a.slerp(b.get("dir", Vector3.UP), t).normalized(),
				"r": lerpf(float(a.get("r", 0.02)), float(b.get("r", 0.02)), t),
			}

	var last: Dictionary = samples[-1]
	return {
		"dist": dist,
		"dir": last.get("dir", Vector3.UP),
		"r": float(last.get("r", 0.02)),
	}


static func _make_blend_spec(
	center: Vector3,
	samples: Array,
	index: int,
	bend: float,
	surface_seed: int,
	jitter_amount: float
) -> Dictionary:
	var r_prev: float = float(samples[maxi(index - 1, 0)].get("r", 0.02))
	var r_curr: float = float(samples[index].get("r", 0.02))
	var r_next: float = float(samples[mini(index + 1, samples.size() - 1)].get("r", 0.02))
	var base_r: float = maxf(r_curr, maxf(r_prev, r_next) * 0.9)
	var swell: float = 1.0 + sin(bend) * 0.28
	var radius: float = base_r * swell * _jitter_scalar(surface_seed, index, 3, jitter_amount * 0.45)
	return {
		"center": center,
		"radius": maxf(radius, 0.003),
	}


static func _bend_at_index(centers: Array, index: int) -> float:
	if index <= 0 or index >= centers.size() - 1:
		return 0.0
	var dir_prev: Vector3 = (centers[index] - centers[index - 1]).normalized()
	var dir_next: Vector3 = (centers[index + 1] - centers[index]).normalized()
	return dir_prev.angle_to(dir_next)


static func _position_jitter(seed: int, salt: int, direction: Vector3, amount: float) -> Vector3:
	if amount <= 0.0:
		return Vector3.ZERO
	var side: Vector3 = Vector3Frame.safe_tangent_axis(direction)
	var up: Vector3 = side.cross(direction).normalized()
	var jx: float = DeterministicNoise.unit_hash(seed, salt, 11) * amount * 0.004
	var jy: float = DeterministicNoise.unit_hash(seed, salt, 23) * amount * 0.004
	return side * jx + up * jy


static func _jitter_scalar(seed: int, index: int, channel: int, amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	return 1.0 + DeterministicNoise.unit_hash(seed, index, channel) * amount


static func _radius_wobble(surface_seed: int, ring: int, seg: int, amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	var h: int = absi(hash(Vector3i(surface_seed, ring, seg)))
	var n: float = float(h % 10001) / 5000.0 - 1.0
	return 1.0 + n * amount


static func build_cylinder_wireframe(
	height: float,
	bottom_radius: float,
	top_radius: float,
	radial_segments: int = 10
) -> ArrayMesh:
	height = maxf(height, 0.02)
	bottom_radius = maxf(bottom_radius, 0.003)
	top_radius = maxf(top_radius, 0.003)
	radial_segments = maxi(radial_segments, 6)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var half_h: float = height * 0.5
	var bottom_y: float = -half_h
	var top_y: float = half_h

	var bottom_ring: Array = []
	var top_ring: Array = []
	for seg_i in range(radial_segments):
		var angle: float = TAU * float(seg_i) / float(radial_segments)
		var x: float = cos(angle)
		var z: float = sin(angle)
		bottom_ring.append(Vector3(x * bottom_radius, bottom_y, z * bottom_radius))
		top_ring.append(Vector3(x * top_radius, top_y, z * top_radius))

	for seg_i in range(radial_segments):
		var next_seg: int = (seg_i + 1) % radial_segments
		_add_line(st, bottom_ring[seg_i], bottom_ring[next_seg])
		_add_line(st, top_ring[seg_i], top_ring[next_seg])
		_add_line(st, bottom_ring[seg_i], top_ring[seg_i])

	return st.commit()


static func build_sphere_wireframe(radius: float, radial_segments: int = 10) -> ArrayMesh:
	radius = maxf(radius, 0.003)
	radial_segments = maxi(radial_segments, 6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var rings: int = maxi(radial_segments / 2, 4)
	for ring_i in range(rings + 1):
		var v: float = float(ring_i) / float(rings)
		var phi: float = lerpf(-PI * 0.5, PI * 0.5, v)
		var ring_y: float = sin(phi) * radius
		var ring_r: float = cos(phi) * radius
		var ring_points: Array = []
		for seg_i in range(radial_segments):
			var angle: float = TAU * float(seg_i) / float(radial_segments)
			ring_points.append(Vector3(cos(angle) * ring_r, ring_y, sin(angle) * ring_r))
		for seg_i in range(radial_segments):
			var next_seg: int = (seg_i + 1) % radial_segments
			_add_line(st, ring_points[seg_i], ring_points[next_seg])

	for seg_i in range(radial_segments):
		var angle: float = TAU * float(seg_i) / float(radial_segments)
		var x: float = cos(angle)
		var z: float = sin(angle)
		_add_line(st, Vector3(x * radius, 0.0, z * radius), Vector3(-x * radius, 0.0, -z * radius))
		_add_line(st, Vector3(0.0, radius, 0.0), Vector3(0.0, -radius, 0.0))

	return st.commit()


static func _add_line(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)


static func build_solid_branch(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int = 10,
	branch_length: float = 0.0,
	tip_dir: Vector3 = Vector3.UP
) -> ArrayMesh:
	return build_bark_branch_meshes(
		samples,
		locked_wobble,
		radial_segments,
		true,
		branch_length,
		tip_dir,
		MIN_RING_SPACING
	).get("surface")


static func build_swept_tube_branch(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int = 10,
	branch_length: float = 0.0,
	tip_dir: Vector3 = Vector3.UP
) -> ArrayMesh:
	return build_bark_branch_meshes(
		samples,
		locked_wobble,
		radial_segments,
		false,
		branch_length,
		tip_dir,
		MIN_RING_SPACING
	).get("surface")


static func build_bark_branch_meshes(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int,
	densify: bool,
	branch_length: float,
	tip_dir: Vector3,
	ring_spacing: float,
	close_end: bool = true
) -> Dictionary:
	var empty: Dictionary = {"surface": null, "wireframe": null}
	if samples.size() < 2:
		return empty

	var prepared: Array = finalize_branch_samples(samples, branch_length, tip_dir)
	prepared = _filter_monotonic_ring_samples(prepared)
	if prepared.size() < 2:
		return empty

	var spacing: float = MIN_RING_SPACING if densify else maxf(ring_spacing, MIN_RING_SPACING)
	var spine: Array = _build_spine_path(prepared, branch_length, tip_dir, spacing)
	if spine.size() < 2:
		return empty

	var rings: Array = _build_branch_rings_from_spine(spine, locked_wobble, radial_segments)
	if rings.size() < 2:
		return empty

	var cap_center: Vector3 = spine[-1].get("center", Vector3.ZERO)
	var cap_normal: Vector3 = spine[-1].get("tangent", tip_dir).normalized()

	return {
		"surface": _build_surface_from_rings(
			rings,
			radial_segments,
			close_end,
			cap_center,
			cap_normal
		),
		"wireframe": build_wireframe_from_rings(
			rings,
			radial_segments,
			close_end,
			cap_center
		),
	}


static func build_disc_cap_mesh(
	radius: float,
	direction: Vector3,
	radial_segments: int
) -> ArrayMesh:
	radius = maxf(radius, 0.003)
	var dir: Vector3 = direction.normalized()
	if dir.length_squared() <= 0.0001:
		dir = Vector3.UP
	var ring: Array = _build_ring_points(Vector3.ZERO, dir, radius, [], radial_segments)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_end_cap(st, ring, Vector3.ZERO, dir, radial_segments)
	return st.commit()


static func _build_spine_path(
	samples: Array,
	branch_length: float,
	tip_dir: Vector3,
	ring_spacing: float
) -> Array:
	var length: float = maxf(branch_length, 0.02)
	var tip_direction: Vector3 = BranchProfileSamples.resolve_tip_direction(tip_dir, samples)

	var ring_count: int = maxi(2, int(ceil(length / maxf(ring_spacing, 0.004))) + 1)
	var spine: Array = []
	for ring_i in range(ring_count):
		var t: float = float(ring_i) / float(ring_count - 1)
		var dist: float = length * t
		var profile_sample: Dictionary = interpolate_sample_at_dist(samples, dist)
		spine.append({
			"center": tip_direction * dist,
			"tangent": tip_direction,
			"r": float(profile_sample.get("r", 0.02)),
			"dist": dist,
		})
	return spine


static func _build_branch_rings_from_spine(
	spine: Array,
	locked_wobble: Array,
	radial_segments: int
) -> Array:
	radial_segments = maxi(radial_segments, 6)
	var rings: Array = []
	var right: Vector3 = Vector3.ZERO
	var prev_dir: Vector3 = Vector3.ZERO
	for point in spine:
		var direction: Vector3 = point.get("tangent", Vector3.UP).normalized()
		var center: Vector3 = point.get("center", Vector3.ZERO)
		var radius: float = float(point.get("r", 0.02))
		if right.length_squared() <= 0.0001:
			right = _ring_reference_right(direction)
		elif prev_dir.length_squared() > 0.0001:
			right = _parallel_transport_right(right, prev_dir, direction)
		rings.append(_build_ring_points(
			center,
			direction,
			radius,
			locked_wobble,
			radial_segments,
			right
		))
		prev_dir = direction
	return rings


static func _filter_monotonic_ring_samples(samples: Array) -> Array:
	if samples.size() < 2:
		return samples

	const MIN_STEP := 0.0015
	var filtered: Array = [samples[0].duplicate()]
	for i in range(1, samples.size()):
		var sample: Dictionary = samples[i]
		var dist: float = float(sample.get("dist", 0.0))
		var prev_dist: float = float(filtered[-1].get("dist", 0.0))
		if dist <= prev_dist + MIN_STEP:
			var merged: Dictionary = sample.duplicate()
			merged["dist"] = prev_dist
			filtered[-1] = merged
			continue
		filtered.append(sample.duplicate())
	return filtered


static func finalize_branch_samples(
	samples: Array,
	branch_length: float,
	tip_dir: Vector3
) -> Array:
	if samples.is_empty():
		return []

	var length: float = maxf(branch_length, 0.02)
	var tip_direction: Vector3 = BranchProfileSamples.resolve_tip_direction(tip_dir, samples)

	var finalized: Array = []
	for sample in samples:
		if sample is Dictionary and float(sample.get("dist", 0.0)) <= length + 0.001:
			finalized.append(sample.duplicate())

	if finalized.is_empty():
		finalized.append(samples[0].duplicate())

	var last: Dictionary = finalized[-1].duplicate()
	last["dist"] = length
	last["dir"] = tip_direction
	var tip_sample: Dictionary = interpolate_sample_at_dist(samples, length)
	last["r"] = float(tip_sample.get("r", finalized[-1].get("r", 0.02)))
	finalized[-1] = last
	return finalized


static func _build_branch_rings(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int
) -> Array:
	var spine: Array = []
	var centers: Array = compute_sample_centers(samples)
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		spine.append({
			"center": centers[i],
			"tangent": sample.get("dir", Vector3.UP),
			"r": float(sample.get("r", 0.02)),
		})
	return _build_branch_rings_from_spine(spine, locked_wobble, radial_segments)


static func _build_surface_from_rings(
	rings: Array,
	radial_segments: int,
	close_end: bool = false,
	cap_center: Vector3 = Vector3.ZERO,
	cap_normal: Vector3 = Vector3.UP
) -> ArrayMesh:
	if rings.size() < 2:
		return null

	radial_segments = maxi(radial_segments, 6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_offset: int = 0
	for ring_i in range(rings.size() - 1):
		var ring_a: Array = rings[ring_i]
		var ring_b: Array = rings[ring_i + 1]
		ring_offset = _best_ring_offset(ring_a, ring_b, radial_segments, ring_offset)
		for seg_i in range(radial_segments):
			var next_seg: int = (seg_i + 1) % radial_segments
			var seg_b: int = (seg_i + ring_offset) % radial_segments
			var next_seg_b: int = (seg_i + ring_offset + 1) % radial_segments
			_add_quad(st, ring_a[seg_i], ring_a[next_seg], ring_b[next_seg_b], ring_b[seg_b])

	if close_end:
		_append_end_cap(st, rings[-1], cap_center, cap_normal, radial_segments)
	return st.commit()


static func build_wireframe_from_rings(
	rings: Array,
	radial_segments: int,
	close_end: bool = false,
	cap_center: Vector3 = Vector3.ZERO
) -> ArrayMesh:
	if rings.size() < 2:
		return null

	radial_segments = maxi(radial_segments, 6)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for ring in rings:
		for seg_i in range(radial_segments):
			var next_seg: int = (seg_i + 1) % radial_segments
			_add_line(st, ring[seg_i], ring[next_seg])

	var ring_offset: int = 0
	for ring_i in range(rings.size() - 1):
		var ring_a: Array = rings[ring_i]
		var ring_b: Array = rings[ring_i + 1]
		ring_offset = _best_ring_offset(ring_a, ring_b, radial_segments, ring_offset)
		for seg_i in range(radial_segments):
			var seg_b: int = (seg_i + ring_offset) % radial_segments
			_add_line(st, ring_a[seg_i], ring_b[seg_b])

	if close_end:
		var last_ring: Array = rings[-1]
		for seg_i in range(radial_segments):
			_add_line(st, cap_center, last_ring[seg_i])
	return st.commit()


static func build_from_ring_samples(
	samples: Array,
	locked_wobble: Array,
	radial_segments: int = 10
) -> ArrayMesh:
	if samples.size() < 2:
		return null

	var rings: Array = _build_branch_rings(samples, locked_wobble, radial_segments)
	return _build_surface_from_rings(rings, radial_segments)


static func build_fork_hub(
	hub_center: Vector3,
	parent_dir: Vector3,
	parent_radius: float,
	child_specs: Array,
	radial_segments: int = 10,
	collar_steps: int = 4
) -> ArrayMesh:
	if child_specs.is_empty():
		return null

	radial_segments = maxi(radial_segments, 6)
	collar_steps = maxi(collar_steps, 2)
	var parent_dir_n: Vector3 = parent_dir.normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for child_spec in child_specs:
		var child_dir: Vector3 = child_spec.get("dir", Vector3.UP).normalized()
		var child_r: float = float(child_spec.get("r", 0.02))
		var rings: Array = []
		var right: Vector3 = _ring_reference_right(parent_dir_n)
		var prev_dir: Vector3 = parent_dir_n
		for step in range(collar_steps + 1):
			var t: float = float(step) / float(collar_steps)
			var blend_dir: Vector3 = parent_dir_n.slerp(child_dir, t).normalized()
			var blend_r: float = lerpf(parent_radius, child_r, t)
			var offset: Vector3 = blend_dir * (parent_radius * 0.2 * t)
			if step > 0:
				right = _parallel_transport_right(right, prev_dir, blend_dir)
			rings.append(_build_ring_points(
				hub_center + offset,
				blend_dir,
				blend_r,
				[],
				radial_segments,
				right
			))
			prev_dir = blend_dir

		var hub_offset: int = 0
		for ring_i in range(rings.size() - 1):
			var ring_a: Array = rings[ring_i]
			var ring_b: Array = rings[ring_i + 1]
			hub_offset = _best_ring_offset(ring_a, ring_b, radial_segments, hub_offset)
			for seg_i in range(radial_segments):
				var next_seg: int = (seg_i + 1) % radial_segments
				var seg_b: int = (seg_i + hub_offset) % radial_segments
				var next_seg_b: int = (seg_i + hub_offset + 1) % radial_segments
				_add_quad(st, ring_a[seg_i], ring_a[next_seg], ring_b[next_seg_b], ring_b[seg_b])

	return st.commit()


static func generate_locked_wobble(surface_seed: int, radial_segments: int, amount: float) -> Array:
	var wobble: Array = []
	for seg_i in range(radial_segments):
		wobble.append(_radius_wobble(surface_seed, 0, seg_i, amount))
	return wobble


static func densify_samples(samples: Array, branch_length: float) -> Array:
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
		dense.append(interpolate_sample_at_dist(samples, dist))
	return dense


static func _build_ring_points(
	center: Vector3,
	direction: Vector3,
	radius: float,
	locked_wobble: Array,
	radial_segments: int,
	right_hint: Vector3 = Vector3.ZERO
) -> Array:
	var dir: Vector3 = direction.normalized()
	var right: Vector3
	if right_hint.length_squared() > 0.0001:
		right = right_hint - dir * dir.dot(right_hint)
		if right.length_squared() > 0.0001:
			right = right.normalized()
		else:
			right = _ring_reference_right(dir)
	else:
		right = _ring_reference_right(dir)
	var forward: Vector3 = right.cross(dir).normalized()
	right = dir.cross(forward).normalized()

	var points: Array = []
	for seg_i in range(radial_segments):
		var angle: float = -TAU * float(seg_i) / float(radial_segments)
		var wobble: float = 1.0
		if not locked_wobble.is_empty():
			wobble = float(locked_wobble[seg_i % locked_wobble.size()])
		var r: float = radius * wobble
		points.append(center + (right * cos(angle) + forward * sin(angle)) * r)
	return points


static func _ring_reference_right(direction: Vector3) -> Vector3:
	return Vector3Frame.safe_tangent_axis(direction.normalized())


static func _parallel_transport_right(right: Vector3, from_dir: Vector3, to_dir: Vector3) -> Vector3:
	var from_n: Vector3 = from_dir.normalized()
	var to_n: Vector3 = to_dir.normalized()
	var transported: Vector3 = right
	if from_n.dot(to_n) < 0.999:
		var axis: Vector3 = from_n.cross(to_n)
		if axis.length_squared() > 0.0000001:
			transported = right.rotated(axis.normalized(), from_n.angle_to(to_n))
	transported = transported - to_n * transported.dot(to_n)
	if transported.length_squared() < 0.0000001:
		return _ring_reference_right(to_n)
	return transported.normalized()


static func _best_ring_offset(
	ring_a: Array,
	ring_b: Array,
	radial_segments: int,
	hint: int = 0
) -> int:
	var best_offset: int = 0
	var best_score: float = INF
	for step in range(radial_segments):
		var offset: int = (hint + step) % radial_segments
		var score: float = 0.0
		for seg_i in range(radial_segments):
			score += ring_a[seg_i].distance_squared_to(ring_b[(seg_i + offset) % radial_segments])
		if score < best_score:
			best_score = score
			best_offset = offset
	return best_offset


static func _append_end_cap(
	st: SurfaceTool,
	ring: Array,
	axis_center: Vector3,
	cap_normal: Vector3,
	radial_segments: int
) -> void:
	if ring.is_empty():
		return

	var outward: Vector3 = cap_normal.normalized()
	if outward.length_squared() <= 0.0001:
		outward = Vector3.UP

	var edge_a: Vector3 = ring[0] - axis_center
	var edge_b: Vector3 = ring[1 % radial_segments] - axis_center
	var flip: bool = edge_a.cross(edge_b).dot(outward) < 0.0

	for seg_i in range(radial_segments):
		var next_seg: int = (seg_i + 1) % radial_segments
		if flip:
			_add_triangle_with_normal(st, axis_center, ring[next_seg], ring[seg_i], outward)
		else:
			_add_triangle_with_normal(st, axis_center, ring[seg_i], ring[next_seg], outward)


static func _add_triangle_with_normal(
	st: SurfaceTool,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3
) -> void:
	var face_normal: Vector3 = (b - a).cross(c - a)
	if face_normal.length_squared() < 1e-20:
		return
	var shaded_normal: Vector3 = normal.normalized()
	st.set_normal(shaded_normal)
	st.add_vertex(a)
	st.set_normal(shaded_normal)
	st.add_vertex(b)
	st.set_normal(shaded_normal)
	st.add_vertex(c)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(st, a, b, c)
	_add_triangle(st, a, c, d)


static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 1e-20:
		return
	normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
