class_name FoliageMeshBuilder
extends RefCounted

const FoliagePreset = preload("res://scripts/tree/foliage_preset.gd")

static var _mesh_cache: Dictionary = {}


static func get_mesh(style: FoliagePreset.MeshStyle, preset: FoliagePreset = null) -> Mesh:
	var spread_key: String = str(preset.needle_spread_deg) if preset else ""
	var count_key: String = str(preset.fascicle_needle_count) if preset else ""
	var cache_key: String = "%d_%s_%s_%s" % [
		style,
		str(preset.needle_length) if preset else "",
		spread_key,
		count_key,
	]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]

	var mesh: Mesh
	match style:
		FoliagePreset.MeshStyle.CLUSTER:
			mesh = _build_cluster_mesh()
		FoliagePreset.MeshStyle.BROADLEAF:
			mesh = _build_broadleaf_mesh(false)
		FoliagePreset.MeshStyle.NEEDLE:
			var needle_count: int = preset.fascicle_needle_count if preset else 2
			var needle_len: float = preset.needle_length if preset else 0.028
			var spread_deg: float = preset.needle_spread_deg if preset else 28.0
			mesh = _build_needle_fascicle_mesh(needle_count, needle_len, spread_deg)
		FoliagePreset.MeshStyle.SCALE:
			var scale_count: int = preset.fascicle_needle_count if preset else 3
			mesh = _build_scale_whorl_mesh(scale_count)
		_:
			mesh = _build_broadleaf_mesh(true)

	_mesh_cache[cache_key] = mesh
	return mesh


static func get_dead_leaf_mesh(preset: FoliagePreset) -> Mesh:
	if preset == null:
		return _build_broadleaf_mesh(true)
	if preset.mesh_style == FoliagePreset.MeshStyle.SCALE:
		return _build_scale_whorl_mesh(1)
	if preset.mesh_style == FoliagePreset.MeshStyle.NEEDLE:
		return _build_single_needle_mesh(preset.needle_length if preset else 0.028)
	return _build_broadleaf_mesh(true)


static func _build_cluster_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 5
	sphere.rings = 3
	return sphere


static func _build_broadleaf_mesh(single_quad: bool) -> ArrayMesh:
	var width: float = 0.022
	var height: float = 0.032
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st,
		Vector3(-width * 0.5, 0.0, 0.0),
		Vector3(width * 0.5, 0.0, 0.0),
		Vector3(width * 0.5, height, 0.0),
		Vector3(-width * 0.5, height, 0.0)
	)
	if not single_quad:
		_add_quad(st,
			Vector3(0.0, 0.0, -width * 0.5),
			Vector3(0.0, 0.0, width * 0.5),
			Vector3(0.0, height, width * 0.5),
			Vector3(0.0, height, -width * 0.5)
		)
	return st.commit()


static func _build_single_needle_mesh(needle_length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = maxf(needle_length, 0.012)
	var dir := Vector3(0.0, 0.0, 1.0)
	_add_crossed_needle(st, Vector3.ZERO, dir, length, _needle_half_width(length))
	return st.commit()


## Fascicle at origin; local +Z is the twig axis. Each needle is a crossed pair of thin quads.
static func _build_needle_fascicle_mesh(needle_count: int, needle_length: float, spread_deg: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length: float = maxf(needle_length, 0.012)
	var half_width: float = _needle_half_width(length)
	var directions: Array = _fascicle_needle_directions(needle_count, spread_deg)
	for dir in directions:
		_add_crossed_needle(st, Vector3.ZERO, dir, length, half_width)
	return st.commit()


static func _needle_half_width(length: float) -> float:
	return maxf(length * 0.022, 0.00035)


static func _fascicle_needle_directions(needle_count: int, spread_deg: float) -> Array:
	var count: int = maxi(needle_count, 1)
	var spread: float = deg_to_rad(clampf(spread_deg, 10.0, 75.0))
	var directions: Array = []

	if count == 1:
		directions.append(Vector3(0.0, 0.0, 1.0))
		return directions

	if count == 2:
		var half_v: float = spread * 0.55
		directions.append(Vector3(sin(half_v), 0.0, cos(half_v)).normalized())
		directions.append(Vector3(-sin(half_v), 0.0, cos(half_v)).normalized())
		return directions

	for i in range(count):
		var azimuth: float = TAU * float(i) / float(count)
		var radial := Vector3(cos(azimuth), sin(azimuth), 0.0)
		var dir := (Vector3(0.0, 0.0, 1.0) * cos(spread) + radial * sin(spread)).normalized()
		directions.append(dir)
	return directions


static func _add_crossed_needle(
	st: SurfaceTool,
	origin: Vector3,
	dir: Vector3,
	length: float,
	half_width: float
) -> void:
	var direction: Vector3 = dir.normalized()
	var tip: Vector3 = origin + direction * length
	var tip_narrow: Vector3 = origin + direction * length * 0.92
	var side_a: Vector3 = Vector3.UP.cross(direction)
	if side_a.length_squared() < 0.0001:
		side_a = Vector3.RIGHT
	side_a = side_a.normalized()
	var side_b: Vector3 = direction.cross(side_a).normalized()
	var base_a: Vector3 = side_a * half_width
	var base_b: Vector3 = side_b * half_width
	var tip_a: Vector3 = side_a * half_width * 0.2
	var tip_b: Vector3 = side_b * half_width * 0.2

	_add_quad(st, origin - base_a, origin + base_a, tip_narrow + tip_a, tip_narrow - tip_a)
	_add_quad(st, origin - base_b, origin + base_b, tip_narrow + tip_b, tip_narrow - tip_b)
	_add_triangle(st, tip_narrow + tip_a, tip_narrow - tip_a, tip)
	_add_triangle(st, tip_narrow + tip_b, tip_narrow - tip_b, tip)


static func _build_scale_whorl_mesh(scale_count: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = maxi(scale_count, 1)
	var width: float = 0.013
	var height: float = 0.017
	for i in range(count):
		var azimuth: float = TAU * float(i) / float(count) + deg_to_rad(18.0)
		var radial := Vector3(cos(azimuth), sin(azimuth), 0.0)
		var outward := (radial * 0.82 + Vector3(0.0, 0.0, 0.28)).normalized()
		var tangent := Vector3.UP.cross(outward)
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.RIGHT
		tangent = tangent.normalized() * width * 0.5
		var tip: Vector3 = outward * height
		var base_inner: Vector3 = radial * 0.003
		_add_quad(
			st,
			base_inner - tangent,
			base_inner + tangent,
			base_inner + tangent + tip,
			base_inner - tangent + tip
		)
	return st.commit()


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(st, a, b, c)
	_add_triangle(st, a, c, d)


static func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
