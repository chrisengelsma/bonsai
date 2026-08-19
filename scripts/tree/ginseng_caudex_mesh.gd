class_name GinsengCaudexMesh
extends RefCounted

const BranchMeshBuilder = preload("res://scripts/tree/branch_mesh_builder.gd")
const GinsengBasalForm = preload("res://scripts/tree/ginseng_basal_form.gd")

## Intentional low-poly caudex — faceted cylinders/spheres, not ring loft.
const LOW_POLY_RADIAL_SEGMENTS := 6
const LOW_POLY_ARC_STEPS_MIN := 10
const LOW_POLY_ARC_STEPS_MAX := 14
const LOW_POLY_NODE_SPHERE_STRIDE := 3
const LOW_POLY_JITTER := 0.03

const LOBE_RADIAL_SEGMENTS := LOW_POLY_RADIAL_SEGMENTS
const NODE_SPHERE_STRIDE := LOW_POLY_NODE_SPHERE_STRIDE
const WIRE_THIN_RADIUS := 0.0012


## How far the visible neck should sink into the caudex bulb below y_top.
static func neck_embed_depth(height: float, bulk_radius: float, neck_radius: float) -> float:
	var profile: Dictionary = _profile_params(height, bulk_radius, neck_radius)
	var maturity: float = _height_maturity(height)
	var attach_t: float = lerpf(0.05, 0.12, maturity)
	var attach_y: float = _profile_y(profile, attach_t)
	return clampf(height - attach_y, 0.0, height * 0.22)


static func build(
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	_radial_segments: int = 0,
	arc_steps: int = 0,
	surface_seed: int = 17,
	lobe_scales: Array = [],
	max_height: float = -1.0
) -> ArrayMesh:
	var resolved_max: float = _resolve_max_height(max_height)
	var steps: int = _resolve_arc_steps(arc_steps, height, resolved_max)
	return _merge_meshes(
		_build_all_meridian_parts(
			arc_count,
			height,
			bulk_radius,
			top_radius,
			steps,
			surface_seed,
			lobe_scales,
			resolved_max
		).get("surfaces", []),
		Mesh.PRIMITIVE_TRIANGLES
	)


static func _resolve_arc_steps(requested: int, height: float, max_height: float = -1.0) -> int:
	if requested > 0:
		return clampi(requested, LOW_POLY_ARC_STEPS_MIN, LOW_POLY_ARC_STEPS_MAX)
	var maturity: float = clampf(
		height / maxf(_resolve_max_height(max_height), 0.001),
		0.0,
		1.0
	)
	return int(lerpf(
		float(LOW_POLY_ARC_STEPS_MIN),
		float(LOW_POLY_ARC_STEPS_MAX),
		maturity
	))


## Parenthesis guide curves: paired meridians forming () around the caudex.
static func build_centerlines(
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	curve_steps: int = 24,
	lobe_scales: Array = [],
	max_height: float = -1.0
) -> ArrayMesh:
	arc_count = clampi(arc_count, 1, 4)
	if height <= 0.008 or bulk_radius <= 0.001:
		return null

	var resolved_max: float = _resolve_max_height(max_height)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	append_centerlines(
		st,
		arc_count,
		height,
		bulk_radius,
		top_radius,
		curve_steps,
		lobe_scales,
		resolved_max
	)
	return st.commit()


static func append_centerlines(
	st: SurfaceTool,
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	curve_steps: int = 24,
	lobe_scales: Array = [],
	max_height: float = -1.0
) -> void:
	arc_count = clampi(arc_count, 1, 4)
	curve_steps = maxi(curve_steps, 8)
	var resolved_max: float = _resolve_max_height(max_height)
	var layout: Dictionary = _build_meridian_layout(
		arc_count, height, bulk_radius, top_radius, curve_steps, lobe_scales, resolved_max
	)

	for pair_i in range(arc_count):
		for side_sign in [-1.0, 1.0]:
			var key: String = _lobe_key(pair_i, side_sign)
			var nodes: Array = layout.get(key, [])
			if nodes.size() < 2:
				continue
			var points: Array = []
			for node in nodes:
				points.append(node.get("pos", Vector3.ZERO))
			_add_polyline(st, points)


static func build_wireframe(
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	arc_steps: int = 0,
	surface_seed: int = 17,
	lobe_scales: Array = [],
	max_height: float = -1.0
) -> ArrayMesh:
	var resolved_max: float = _resolve_max_height(max_height)
	var steps: int = _resolve_arc_steps(arc_steps, height, resolved_max)
	return _merge_meshes(
		_build_all_meridian_parts(
			arc_count,
			height,
			bulk_radius,
			top_radius,
			steps,
			surface_seed,
			lobe_scales,
			resolved_max
		).get("wires", []),
		Mesh.PRIMITIVE_LINES
	)


static func _build_all_meridian_parts(
	arc_count: int,
	height: float,
	bulk_radius: float,
	top_radius: float,
	arc_steps: int,
	surface_seed: int,
	lobe_scales: Array = [],
	max_height: float = -1.0
) -> Dictionary:
	arc_count = clampi(arc_count, 1, 4)
	if height <= 0.008 or bulk_radius <= 0.001:
		return {"surfaces": [], "wires": []}

	var meridian_radial: int = LOW_POLY_RADIAL_SEGMENTS
	var layout: Dictionary = _build_meridian_layout(
		arc_count, height, bulk_radius, top_radius, arc_steps, lobe_scales, max_height
	)
	var surfaces: Array = []
	var wires: Array = []

	for pair_i in range(arc_count):
		for side_i in range(2):
			var side_sign: float = -1.0 if side_i == 0 else 1.0
			var guide: Dictionary = _meridian_branch_samples_from_layout(
				pair_i,
				side_sign,
				layout,
				top_radius
			)
			var samples: Array = guide.get("samples", [])
			if samples.size() < 2:
				continue

			var meridian_seed: int = surface_seed + pair_i * 41 + side_i * 19
			var surface: ArrayMesh = BranchMeshBuilder.build_bulbed_chain_mesh(
				samples,
				meridian_seed,
				LOW_POLY_JITTER,
				guide.get("tip_dir", Vector3.UP),
				Vector3.ZERO,
				meridian_radial,
				false,
				1.02,
				LOW_POLY_NODE_SPHERE_STRIDE
			)
			if surface != null:
				surfaces.append(surface)
			var wire: ArrayMesh = BranchMeshBuilder.build_decimated_chain_wireframe(
				samples,
				meridian_seed,
				0.06,
				guide.get("tip_dir", Vector3.UP),
				Vector3.ZERO,
				meridian_radial,
				false
			)
			if wire != null:
				wires.append(wire)

	return {"surfaces": surfaces, "wires": wires}


static func _lobe_key(pair_i: int, side_sign: float) -> String:
	return "%d:%d" % [pair_i, 1 if side_sign >= 0.0 else -1]


static func _normalize_lobe_scales(arc_count: int, lobe_scales: Array) -> Array:
	var scales: Array = []
	for i in range(arc_count):
		if i < lobe_scales.size():
			scales.append(clampf(float(lobe_scales[i]), 0.55, 1.65))
		else:
			scales.append(1.0)
	return scales


static func _build_meridian_layout(
	arc_count: int,
	height: float,
	bulk_radius: float,
	neck_radius: float,
	curve_steps: int,
	lobe_scales: Array,
	max_height: float = -1.0
) -> Dictionary:
	arc_count = clampi(arc_count, 1, 4)
	curve_steps = maxi(curve_steps, 10)
	var profile: Dictionary = _profile_params(height, bulk_radius, neck_radius, max_height)
	var scales: Array = _normalize_lobe_scales(arc_count, lobe_scales)
	var layout: Dictionary = {}

	for step in range(curve_steps + 1):
		var t: float = float(step) / float(curve_steps)
		var step_nodes: Array = []
		for pair_i in range(arc_count):
			var lobe_scale: float = float(scales[pair_i])
			for side_sign in [-1.0, 1.0]:
				var knot: Dictionary = _meridian_knot(
					pair_i, side_sign, arc_count, t, profile, height, bulk_radius
				)
				knot.meridian_r *= lobe_scale
				knot.offset = knot.meridian_r * _lateral_offset_factor(t)
				knot.y = _profile_y(profile, t)
				knot.pos = knot.axis * knot.offset + Vector3(0.0, knot.y, 0.0)
				var tube_r: float = _tube_radius_from_knot(knot, t, neck_radius, lobe_scale)
				step_nodes.append({
					"pair_i": pair_i,
					"side_sign": side_sign,
					"t": t,
					"pos": knot.pos,
					"meridian_r": knot.meridian_r,
					"r": tube_r,
				})
		_separate_meridian_step(step_nodes, t)
		for node in step_nodes:
			var key: String = _lobe_key(int(node.pair_i), float(node.side_sign))
			if not layout.has(key):
				layout[key] = []
			layout[key].append(node)

	return layout


static func _separate_meridian_step(nodes: Array, t: float) -> void:
	if nodes.size() < 2:
		return

	var originals: Array = []
	for node in nodes:
		originals.append((node as Dictionary).get("pos", Vector3.ZERO))

	const ITERATIONS := 8
	for _iter in range(ITERATIONS):
		for a_i in range(nodes.size()):
			for b_i in range(a_i + 1, nodes.size()):
				_resolve_meridian_overlap(nodes[a_i], nodes[b_i])

	var neck_lock: float = 1.0 - smoothstep(0.0, 0.16, t)
	if neck_lock <= 0.001:
		return
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		node.pos = node.pos.lerp(originals[i], neck_lock)


static func _resolve_meridian_overlap(a: Dictionary, b: Dictionary) -> void:
	var pa: Vector3 = a.get("pos", Vector3.ZERO)
	var pb: Vector3 = b.get("pos", Vector3.ZERO)
	var ra: float = float(a.get("r", 0.01))
	var rb: float = float(b.get("r", 0.01))
	var delta := Vector2(pb.x - pa.x, pb.z - pa.z)
	var dist_sq: float = delta.length_squared()
	var min_dist: float = (ra + rb) * 0.96
	if dist_sq >= min_dist * min_dist:
		return

	var dist: float = sqrt(dist_sq)
	var dir: Vector2
	if dist > 0.0001:
		dir = delta / dist
	else:
		dir = Vector2(1.0, 0.0)

	var push: float = (min_dist - dist) * 0.52
	var push3 := Vector3(dir.x, 0.0, dir.y) * push
	a.pos = pa - push3
	b.pos = pb + push3

	var overlap: float = min_dist - dist
	if overlap > 0.0:
		var squish: float = clampf(overlap / maxf(min_dist, 0.001), 0.0, 0.14)
		a.r = maxf(ra * (1.0 - squish * 0.4), WIRE_THIN_RADIUS)
		b.r = maxf(rb * (1.0 - squish * 0.4), WIRE_THIN_RADIUS)


static func _tube_radius_from_knot(
	knot: Dictionary,
	t: float,
	neck_radius: float,
	lobe_scale: float
) -> float:
	var base_r: float = maxf(float(knot.meridian_r) * 0.46, WIRE_THIN_RADIUS)
	var neck_blend: float = smoothstep(0.0, 0.14, t)
	var tube_r: float = lerpf(
		maxf(neck_radius * 0.88, WIRE_THIN_RADIUS * 2.0),
		base_r,
		neck_blend
	)
	var toe_pinch: float = smoothstep(0.9, 1.0, t)
	tube_r = lerpf(tube_r, WIRE_THIN_RADIUS, toe_pinch)
	return maxf(tube_r, WIRE_THIN_RADIUS)


static func _meridian_branch_samples_from_layout(
	pair_i: int,
	side_sign: float,
	layout: Dictionary,
	neck_radius: float
) -> Dictionary:
	var key: String = _lobe_key(pair_i, side_sign)
	var nodes: Array = layout.get(key, [])
	if nodes.size() < 2:
		return {"samples": [], "length": 0.0, "tip_dir": Vector3.UP}

	var samples: Array = []
	var dist: float = 0.0
	for i in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var pos: Vector3 = node.get("pos", Vector3.ZERO)
		if i > 0:
			var prev_pos: Vector3 = nodes[i - 1].get("pos", Vector3.ZERO)
			dist += pos.distance_to(prev_pos)

		var dir: Vector3 = Vector3.UP
		if nodes.size() > 1:
			var prev_pos: Vector3 = nodes[maxi(i - 1, 0)].get("pos", Vector3.ZERO)
			var next_pos: Vector3 = nodes[mini(i + 1, nodes.size() - 1)].get("pos", Vector3.ZERO)
			dir = (next_pos - prev_pos).normalized()

		samples.append({
			"dist": dist,
			"dir": dir,
			"r": maxf(float(node.get("r", WIRE_THIN_RADIUS)), WIRE_THIN_RADIUS),
			"pos": pos,
		})

	return {
		"samples": samples,
		"length": dist,
		"tip_dir": samples[-1].dir,
	}


## Bark spine follows one () meridian; radius swells from wire-thin at the foot.
static func _meridian_branch_samples(
	pair_i: int,
	side_sign: float,
	arc_count: int,
	height: float,
	bulk_radius: float,
	neck_radius: float,
	curve_steps: int,
	lobe_scales: Array = []
) -> Dictionary:
	arc_count = clampi(arc_count, 1, 4)
	curve_steps = maxi(curve_steps, 10)
	var layout: Dictionary = _build_meridian_layout(
		arc_count, height, bulk_radius, neck_radius, curve_steps, lobe_scales
	)
	return _meridian_branch_samples_from_layout(pair_i, side_sign, layout, neck_radius)


static func _merge_meshes(parts: Array, primitive: int) -> ArrayMesh:
	return BranchMeshBuilder.merge_meshes(parts, primitive)


static func _add_polyline(st: SurfaceTool, points: Array) -> void:
	for i in range(points.size() - 1):
		st.add_vertex(points[i])
		st.add_vertex(points[i + 1])


static func _profile_params(
	height: float,
	bulk_radius: float,
	neck_radius: float,
	max_height: float = -1.0
) -> Dictionary:
	var maturity: float = maxf(_height_maturity(height, max_height), _bulk_maturity(bulk_radius))
	var spread: float = lerpf(0.32, 1.0, maturity)
	var foot_spread: float = lerpf(0.62, 0.86, maturity) * spread
	return {
		"neck": maxf(neck_radius * 0.78, bulk_radius * 0.14),
		"foot_r": maxf(bulk_radius * foot_spread, WIRE_THIN_RADIUS * 6.0),
		"peak_r": bulk_radius * 1.22 * spread,
		"y_bottom": -bulk_radius * lerpf(0.02, 0.06, maturity),
		"y_top": height,
		"foot_drop": bulk_radius * lerpf(0.06, 0.14, maturity),
		"maturity": maturity,
	}


## t = 0 at the neck, t = 1 at the splayed foot. Meridians grow downward.
static func _meridian_knot(
	pair_i: int,
	side_sign: float,
	arc_count: int,
	t: float,
	profile: Dictionary,
	height: float,
	bulk_radius: float
) -> Dictionary:
	var axis: Vector3 = _leg_axis(pair_i, arc_count, t, float(profile.get("maturity", 0.0))) * side_sign
	var meridian_r: float = (
		_meridian_radius(t, profile.foot_r, profile.neck, profile.peak_r)
		* _foot_splay_factor(t)
	)
	var offset: float = meridian_r * _lateral_offset_factor(t)
	var y: float = _profile_y(profile, t)
	return {
		"axis": axis,
		"meridian_r": meridian_r,
		"offset": offset,
		"y": y,
		"pos": axis * offset + Vector3(0.0, y, 0.0),
	}


static func _profile_y(profile: Dictionary, t: float) -> float:
	var foot_drop: float = float(profile.get("foot_drop", 0.0))
	return lerpf(profile.y_top, profile.y_bottom - foot_drop, t)


static func _height_maturity(height: float, max_height: float = -1.0) -> float:
	var start_h: float = GinsengBasalForm.START_CAUDEX_HEIGHT
	var max_h: float = _resolve_max_height(max_height)
	return clampf((height - start_h) / maxf(max_h - start_h, 0.001), 0.0, 1.0)


static func _resolve_max_height(max_height: float) -> float:
	if max_height > 0.0:
		return max_height
	return GinsengBasalForm.MAX_CAUDEX_HEIGHT


static func _bulk_maturity(bulk_radius: float) -> float:
	var start_r: float = WIRE_THIN_RADIUS * 6.0
	var max_r: float = 0.26
	return clampf((bulk_radius - start_r) / maxf(max_r - start_r, 0.001), 0.0, 1.0)


## Leg axes fan outward at the feet (high t) only.
static func _leg_axis(pair_i: int, arc_count: int, t: float, maturity: float) -> Vector3:
	var foot_spread: float = smoothstep(0.42, 1.0, t)
	var spread_angle: float = lerpf(1.0, lerpf(1.1, 1.2, maturity), foot_spread)
	var yaw: float = TAU * float(pair_i) / float(arc_count) * spread_angle
	return Vector3(sin(yaw), 0.0, cos(yaw)).normalized()


## Belly swells toward the feet (high t).
static func _bulb_swell(t: float) -> float:
	const PEAK_T := 0.74
	if t <= PEAK_T:
		var rise: float = t / maxf(PEAK_T, 0.001)
		return sin(PI * 0.5 * rise) * 1.34
	var falloff: float = (t - PEAK_T) / maxf(1.0 - PEAK_T, 0.001)
	return cos(PI * 0.5 * falloff) * lerpf(1.34, 0.18, falloff)


static func _foot_splay_factor(t: float) -> float:
	return lerpf(1.0, 1.36, smoothstep(0.48, 1.0, t))


## () meridians merge at the neck (t = 0) and split toward the feet (t = 1).
static func _lateral_offset_factor(t: float) -> float:
	return smoothstep(0.12, 0.58, t)


static func _meridian_radius(t: float, foot_r: float, neck_r: float, peak_r: float) -> float:
	var spine: float = lerpf(neck_r, foot_r, pow(t, 1.08))
	var bulge: float = maxf(peak_r - lerpf(neck_r, foot_r, 0.84), 0.0)
	return spine + bulge * _bulb_swell(t)


static func _single_bulb_radius(t: float, foot_r: float, neck_r: float, peak_r: float) -> float:
	return _meridian_radius(t, foot_r, neck_r, peak_r)


## Debug / test helper: ring samples on one meridian bark tube.
static func _build_lobe_height_rings(
	lobe_i: int,
	lobe_count: int,
	height: float,
	bulk_radius: float,
	neck_radius: float,
	height_steps: int,
	_arc_segments: int,
	_chord_segments: int,
	_surface_seed: int
) -> Array:
	var guide: Dictionary = _meridian_branch_samples(
		lobe_i, 1.0, lobe_count, height, bulk_radius, neck_radius, height_steps
	)
	var samples: Array = guide.get("samples", [])
	if samples.size() < 2:
		return []

	var centers: Array = BranchMeshBuilder.compute_sample_centers(samples)
	var rings: Array = []
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		var center: Vector3 = centers[i]
		var dir: Vector3 = sample.get("dir", Vector3.UP).normalized()
		var radius: float = float(sample.get("r", 0.02))
		rings.append(
			BranchMeshBuilder._build_ring_points(
				center,
				dir,
				radius,
				[],
				LOBE_RADIAL_SEGMENTS
			)
		)
	return rings


static func _build_height_rings(
	lobe_count: int,
	height: float,
	bulk_radius: float,
	neck_radius: float,
	height_steps: int,
	_ring_segments: int,
	_surface_seed: int
) -> Array:
	return _build_lobe_height_rings(
		0, lobe_count, height, bulk_radius, neck_radius, height_steps, 0, 0, 0
	)


static func _build_arc_polylines(
	arc_count: int,
	height: float,
	bulk_radius: float,
	neck_radius: float,
	arc_steps: int,
	surface_seed: int
) -> Array:
	return _build_height_rings(
		arc_count, height, bulk_radius, neck_radius, arc_steps, arc_count * 5, surface_seed
	)


static func _build_meridian_polylines(
	lobe_count: int,
	height: float,
	bulk_radius: float,
	neck_radius: float,
	arc_steps: int,
	surface_seed: int
) -> Array:
	var rings: Array = _build_height_rings(
		lobe_count, height, bulk_radius, neck_radius, arc_steps, lobe_count * 5, surface_seed
	)
	if rings.is_empty():
		return []
	var meridians: Array = []
	var ring_points: int = rings[0].size()
	for meridian_i in range(ring_points):
		var points: Array = []
		for ring in rings:
			points.append(ring[meridian_i])
		meridians.append(points)
	return meridians
