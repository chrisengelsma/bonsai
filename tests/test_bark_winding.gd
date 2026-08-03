extends SceneTree

const BranchMeshBuilder = preload("res://scripts/tree/branch_mesh_builder.gd")

func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(_check_ring_loft_normals())
	failures.append_array(_check_swept_tube_normals())

	if failures.is_empty():
		print("ALL CHECKS PASSED (bark winding)")
	else:
		for failure in failures:
			print("FAIL: ", failure)
	quit(1 if not failures.is_empty() else 0)

func _check_ring_loft_normals() -> Array[String]:
	var samples: Array = [
		{"dist": 0.0, "dir": Vector3.UP, "r": 0.05},
		{"dist": 0.2, "dir": Vector3.UP, "r": 0.045},
	]
	return _check_outward_normals(
		"ring_loft",
		BranchMeshBuilder.build_bark_branch_meshes(
			samples,
			BranchMeshBuilder.generate_locked_wobble(7, 12, 0.0),
			12,
			true,
			0.2,
			Vector3.UP,
			0.04,
			true
		).get("surface"),
		Vector3.UP
	)

func _check_swept_tube_normals() -> Array[String]:
	var direction: Vector3 = Vector3.UP
	var samples: Array = [
		{"dist": 0.0, "dir": direction, "r": 0.05},
		{"dist": 0.18, "dir": direction, "r": 0.04},
	]
	return _check_outward_normals(
		"swept_tube",
		BranchMeshBuilder.build_bark_branch_meshes(
			samples,
			BranchMeshBuilder.generate_locked_wobble(9, 12, 0.0),
			12,
			false,
			0.18,
			direction,
			0.04,
			true
		).get("surface"),
		direction
	)

func _check_outward_normals(label: String, mesh: ArrayMesh, axis: Vector3) -> Array[String]:
	var failures: Array[String] = []
	if mesh == null:
		failures.append("%s mesh was null" % label)
		return failures

	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var axis_n: Vector3 = axis.normalized()
	var checked := 0
	var inward := 0

	for i in range(vertices.size()):
		var vertex: Vector3 = vertices[i]
		var normal: Vector3 = normals[i]
		if absf(normal.dot(axis_n)) > 0.92:
			continue
		var radial: Vector3 = vertex - axis_n * vertex.dot(axis_n)
		if radial.length_squared() < 2.5e-4:
			continue
		checked += 1
		if normal.dot(radial.normalized()) < 0.15:
			inward += 1

	if checked == 0:
		failures.append("%s had no shell vertices to check" % label)
	elif inward > 0:
		failures.append("%s has %d/%d inward-facing normals" % [label, inward, checked])
	return failures
