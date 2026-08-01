class_name RootNode
extends RefCounted

var id: int = -1
var parent_id: int = -1
var points: Array = []
var thickness: float = 0.01
var depth: int = 0
var children: Array = []
var is_growing_tip: bool = true
var points_since_branch: int = 0
var outward_bias: Vector3 = Vector3.ZERO
var growth_heading: Vector3 = Vector3.ZERO
var squirm_phase: float = 0.0


func path_length() -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


func tip() -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	return points[-1]


func to_dict() -> Dictionary:
	var point_data: Array = []
	for point in points:
		if point is Vector3:
			point_data.append([point.x, point.y, point.z])
	var bias: Vector3 = outward_bias
	var heading: Vector3 = growth_heading
	return {
		"id": id,
		"parent_id": parent_id,
		"points": point_data,
		"thickness": thickness,
		"depth": depth,
		"children": children.duplicate(),
		"is_growing_tip": is_growing_tip,
		"points_since_branch": points_since_branch,
		"outward_bias": [bias.x, bias.y, bias.z],
		"growth_heading": [heading.x, heading.y, heading.z],
		"squirm_phase": squirm_phase,
	}


static func from_dict(data: Dictionary):
	var node = load("res://scripts/roots/root_node.gd").new()
	node.id = int(data.get("id", -1))
	node.parent_id = int(data.get("parent_id", -1))
	node.points = []
	for point_data in data.get("points", []):
		if point_data is Array and point_data.size() >= 3:
			node.points.append(Vector3(
				float(point_data[0]),
				float(point_data[1]),
				float(point_data[2])
			))
	var bias_data: Array = data.get("outward_bias", [0.0, 0.0, 0.0])
	node.outward_bias = Vector3(
		float(bias_data[0]),
		float(bias_data[1]),
		float(bias_data[2])
	).normalized()
	var heading_data: Array = data.get("growth_heading", [0.0, 0.0, 0.0])
	node.growth_heading = Vector3(
		float(heading_data[0]),
		float(heading_data[1]),
		float(heading_data[2])
	)
	node.thickness = float(data.get("thickness", 0.01))
	node.depth = int(data.get("depth", 0))
	node.children.assign(data.get("children", []))
	node.is_growing_tip = bool(data.get("is_growing_tip", true))
	node.points_since_branch = int(data.get("points_since_branch", 0))
	node.squirm_phase = float(data.get("squirm_phase", 0.0))
	return node
