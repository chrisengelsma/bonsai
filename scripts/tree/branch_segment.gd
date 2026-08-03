class_name BranchSegment
extends RefCounted

const MeshConstants = preload("res://scripts/util/mesh_constants.gd")
const Vector3Frame = preload("res://scripts/util/vector3_frame.gd")


static func from_graph(graph, node_id: int) -> Dictionary:
	var start: Vector3 = graph.get_joint(node_id)
	var end: Vector3 = graph.get_world_tip(node_id)
	var direction: Vector3 = (end - start).normalized()
	var length: float = maxf(start.distance_to(end), MeshConstants.MIN_BRANCH_HEIGHT)
	return {
		"start": start,
		"end": end,
		"direction": direction,
		"length": length,
	}


static func prune_hit_along(graph, node_id: int, hit_position: Vector3, min_along: float = 0.02) -> Vector3:
	var segment := from_graph(graph, node_id)
	var along: float = Vector3Frame.project_along_segment(
		segment.start,
		segment.end,
		hit_position,
		min_along
	)
	return segment.start.lerp(segment.end, along)
