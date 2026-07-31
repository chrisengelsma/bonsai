extends RefCounted

const GrowPatternScript = preload("res://scripts/tree/grow_pattern.gd")
const CLASSIC_PATTERN := preload("res://resources/species/classic_upright_pattern.tres")
const CASCADE_PATTERN := preload("res://resources/species/cascade_pattern.tres")


static func get_names() -> Array[String]:
	return [
		"Classic Upright",
		"Cascade",
		"Binary Tree",
		"Bushy",
		"Symmetric",
	]


static func load_preset(index: int):
	match index:
		0:
			return CLASSIC_PATTERN.duplicate(true)
		1:
			return CASCADE_PATTERN.duplicate(true)
		2:
			return _custom(
				"T",
				"T=F[+F][-F][&F]\nF=F",
				25.0,
				0.08,
				0.035,
				0.0,
				4,
				3
			)
		3:
			return _custom(
				"T",
				"T=F[+T][-T][\\T]\nF=F",
				22.0,
				0.07,
				0.03,
				0.1,
				5,
				3
			)
		4:
			return _custom(
				"T",
				"T=F[+S][-S][&S]\nS=F[+T][-T][^T]\nF=F",
				30.0,
				0.09,
				0.028,
				0.05,
				5,
				3
			)
		_:
			return CLASSIC_PATTERN.duplicate(true)


static func _custom(
	axiom: String,
	rules: String,
	angle: float,
	segment_length: float,
	growth_rate: float,
	gravity: float,
	max_depth: int,
	max_children: int = 2
) -> Resource:
	var pattern = GrowPatternScript.new()
	pattern.lsystem_axiom = axiom
	pattern.lsystem_rules_text = rules
	pattern.lsystem_angle_deg = angle
	pattern.lsystem_segment_length = segment_length
	pattern.tip_growth_rate = growth_rate
	pattern.gravity_curve = gravity
	pattern.max_branch_depth = max_depth
	pattern.use_lsystem = true
	pattern.trunk_thickness = 0.065
	pattern.branch_thickness = 0.024
	pattern.thickness_falloff = 0.72
	pattern.foliage_start_length = 0.05
	pattern.foliage_growth_rate = 0.16
	pattern.max_children_per_node = max_children
	pattern.lateral_roll_spread_deg = 42.0
	pattern.spatial_spread_deg = 16.0
	return pattern
