extends RefCounted

const LSystemParams = preload("res://scripts/lsystem/lsystem_params.gd")
const CLASSIC_PATTERN := preload("res://resources/species/classic_upright_pattern.tres")
const CASCADE_PATTERN := preload("res://resources/species/cascade_pattern.tres")
const GINSENG_PATTERN := preload("res://resources/species/ginseng_ficus_pattern.tres")
const JUNIPER_PATTERN := preload("res://resources/species/juniper_pattern.tres")


static func get_names() -> Array[String]:
	return [
		"Classic Upright",
		"Cascade",
		"Ginseng Ficus",
		"Juniper",
		"Binary Tree",
		"Bushy",
		"Symmetric",
	]


static func load_preset(index: int) -> LSystemParams:
	match index:
		0:
			return LSystemParams.from_grow_pattern(CLASSIC_PATTERN)
		1:
			return LSystemParams.from_grow_pattern(CASCADE_PATTERN)
		2:
			return LSystemParams.from_grow_pattern(GINSENG_PATTERN)
		3:
			return LSystemParams.from_grow_pattern(JUNIPER_PATTERN)
		4:
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
		5:
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
		6:
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
			return LSystemParams.from_grow_pattern(CLASSIC_PATTERN)


static func _custom(
	axiom: String,
	rules: String,
	angle: float,
	segment_length: float,
	growth_rate: float,
	gravity: float,
	max_depth: int,
	_max_children: int = 2
) -> LSystemParams:
	var params := LSystemParams.new()
	params.axiom = axiom
	params.rules_text = rules
	params.angle_deg = angle
	params.segment_length = segment_length
	params.growth_rate = growth_rate
	params.gravity = gravity
	params.iterations = max_depth
	params.max_children = _max_children
	params.deterministic = true
	return params
