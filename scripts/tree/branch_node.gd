class_name BranchNode
extends RefCounted

var id: int = -1
var parent_id: int = -1
var direction: Vector3 = Vector3.UP
var length: float = 0.0
var thickness: float = 0.03
var age: float = 0.0
var growth_energy: float = 1.0
var foliage_amount: float = 0.0
var is_growing_tip: bool = true
var freeze_length: bool = false
var prune_seed_pending: bool = false
var prune_cut_radius: float = -1.0
var is_graft: bool = false
var graft_species_id: String = ""
var cut_timestamp: float = -1.0
var children: Array = []
var depth: int = 0
var lsymbol: String = "T"
var length_at_last_production: float = 0.0
var turtle_up: Vector3 = Vector3.FORWARD
var next_segment_length: float = -1.0
var base_thickness: float = 0.03
var cambium_thickness: float = 0.0
var locked_wobble: Array = []
var ring_samples: Array = []
var last_ring_sample_dist: float = 0.0
var last_profile_direction: Vector3 = Vector3.UP
var profile_frame_right: Vector3 = Vector3.ZERO
var profile_joint_radius: float = -1.0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"parent_id": parent_id,
		"direction": [direction.x, direction.y, direction.z],
		"length": length,
		"thickness": thickness,
		"age": age,
		"growth_energy": growth_energy,
		"foliage_amount": foliage_amount,
		"is_growing_tip": is_growing_tip,
		"freeze_length": freeze_length,
		"prune_seed_pending": prune_seed_pending,
		"prune_cut_radius": prune_cut_radius,
		"is_graft": is_graft,
		"graft_species_id": graft_species_id,
		"cut_timestamp": cut_timestamp,
		"children": children.duplicate(),
		"depth": depth,
		"lsymbol": lsymbol,
		"length_at_last_production": length_at_last_production,
		"turtle_up": [turtle_up.x, turtle_up.y, turtle_up.z],
		"next_segment_length": next_segment_length,
		"base_thickness": base_thickness,
		"cambium_thickness": cambium_thickness,
		"locked_wobble": locked_wobble.duplicate(),
		"ring_samples": _serialize_ring_samples(),
		"last_ring_sample_dist": last_ring_sample_dist,
		"last_profile_direction": [last_profile_direction.x, last_profile_direction.y, last_profile_direction.z],
		"profile_frame_right": [profile_frame_right.x, profile_frame_right.y, profile_frame_right.z],
		"profile_joint_radius": profile_joint_radius,
	}


func _serialize_ring_samples() -> Array:
	var data: Array = []
	for sample in ring_samples:
		if sample is Dictionary:
			var dir: Vector3 = sample.get("dir", Vector3.UP)
			data.append({
				"dist": float(sample.get("dist", 0.0)),
				"r": float(sample.get("r", thickness)),
				"dir": [dir.x, dir.y, dir.z],
			})
	return data


static func from_dict(data: Dictionary):
	var node = load("res://scripts/tree/branch_node.gd").new()
	node.id = int(data.get("id", -1))
	node.parent_id = int(data.get("parent_id", -1))
	var dir: Array = data.get("direction", [0.0, 1.0, 0.0])
	node.direction = Vector3(float(dir[0]), float(dir[1]), float(dir[2])).normalized()
	node.length = float(data.get("length", 0.0))
	node.thickness = float(data.get("thickness", 0.03))
	node.age = float(data.get("age", 0.0))
	node.growth_energy = float(data.get("growth_energy", 1.0))
	node.foliage_amount = float(data.get("foliage_amount", 0.0))
	node.is_growing_tip = bool(data.get("is_growing_tip", true))
	node.freeze_length = bool(data.get("freeze_length", false))
	node.prune_seed_pending = bool(data.get("prune_seed_pending", false))
	node.prune_cut_radius = float(data.get("prune_cut_radius", -1.0))
	node.is_graft = bool(data.get("is_graft", false))
	node.graft_species_id = str(data.get("graft_species_id", ""))
	node.cut_timestamp = float(data.get("cut_timestamp", -1.0))
	var child_data: Array = data.get("children", [])
	node.children.assign(child_data)
	node.depth = int(data.get("depth", 0))
	node.lsymbol = str(data.get("lsymbol", "T"))
	node.length_at_last_production = float(data.get("length_at_last_production", 0.0))
	var turtle_up_data: Array = data.get("turtle_up", [0.0, 0.0, -1.0])
	node.turtle_up = Vector3(float(turtle_up_data[0]), float(turtle_up_data[1]), float(turtle_up_data[2])).normalized()
	node.next_segment_length = float(data.get("next_segment_length", -1.0))
	node.base_thickness = float(data.get("base_thickness", node.thickness))
	node.cambium_thickness = float(data.get("cambium_thickness", 0.0))
	node.locked_wobble = []
	var wobble_data: Array = data.get("locked_wobble", [])
	node.locked_wobble.assign(wobble_data)
	node.last_ring_sample_dist = float(data.get("last_ring_sample_dist", 0.0))
	var profile_dir: Array = data.get("last_profile_direction", [0.0, 1.0, 0.0])
	node.last_profile_direction = Vector3(
		float(profile_dir[0]),
		float(profile_dir[1]),
		float(profile_dir[2])
	).normalized()
	var frame_right_data: Array = data.get("profile_frame_right", [0.0, 0.0, 0.0])
	node.profile_frame_right = Vector3(
		float(frame_right_data[0]),
		float(frame_right_data[1]),
		float(frame_right_data[2])
	)
	node.profile_joint_radius = float(data.get("profile_joint_radius", -1.0))
	node.ring_samples = []
	for sample_data in data.get("ring_samples", []):
		if sample_data is Dictionary:
			var dir_data: Array = sample_data.get("dir", [0.0, 1.0, 0.0])
			node.ring_samples.append({
				"dist": float(sample_data.get("dist", 0.0)),
				"r": float(sample_data.get("r", node.thickness)),
				"dir": Vector3(float(dir_data[0]), float(dir_data[1]), float(dir_data[2])).normalized(),
			})
	return node
