extends RefCounted

const LSystemParams = preload("res://scripts/lsystem/lsystem_params.gd")
const CLASSIC_PATTERN := preload("res://resources/species/classic_upright_pattern.tres")
const CASCADE_PATTERN := preload("res://resources/species/cascade_pattern.tres")
const GINSENG_PATTERN := preload("res://resources/species/ginseng_ficus_pattern.tres")
const JUNIPER_PATTERN := preload("res://resources/species/juniper_pattern.tres")
const CLASSIC_SPECIES := preload("res://resources/species/classic_upright.tres")
const CASCADE_SPECIES := preload("res://resources/species/cascade.tres")
const GINSENG_SPECIES := preload("res://resources/species/ginseng_ficus.tres")
const JUNIPER_SPECIES := preload("res://resources/species/juniper.tres")


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
	var params: LSystemParams
	match index:
		0:
			params = LSystemParams.from_grow_pattern(CLASSIC_PATTERN)
		1:
			params = LSystemParams.from_grow_pattern(CASCADE_PATTERN)
		2:
			params = LSystemParams.from_grow_pattern(GINSENG_PATTERN)
		3:
			params = LSystemParams.from_grow_pattern(JUNIPER_PATTERN)
		4:
			params = _custom(
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
			params = _custom(
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
			params = _custom(
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
			params = LSystemParams.from_grow_pattern(CLASSIC_PATTERN)
	_apply_colonization_preset(params, index)
	var species := species_for_preset(index)
	if species != null:
		params.sync_foliage_from_preset(species.foliage)
	return params


static func _apply_colonization_preset(params: LSystemParams, index: int) -> void:
	match index:
		0:
			params.use_space_colonization = true
			params.colonization_volume_preset = "dome"
			params.colonization_strength = 0.32
			params.colonization_spawn_strength = 0.22
		1:
			params.use_space_colonization = true
			params.colonization_volume_preset = "cascade_teardrop"
			params.colonization_strength = 0.38
			params.colonization_spawn_strength = 0.28
		2:
			params.use_space_colonization = false
			params.colonization_volume_preset = "dome"
			params.colonization_point_count = 80
		3:
			params.use_space_colonization = true
			params.colonization_volume_preset = "flat_pad"
			params.colonization_strength = 0.3
			params.colonization_spawn_strength = 0.24
		_:
			params.use_space_colonization = false
			params.colonization_volume_preset = "dome"


static func get_volume_preset_names() -> Array[String]:
	return ["dome", "cascade_teardrop", "flat_pad", "column"]


static func species_for_preset(index: int) -> TreeSpecies:
	match index:
		0:
			return _duplicate_species(CLASSIC_SPECIES)
		1:
			return _duplicate_species(CASCADE_SPECIES)
		2:
			return _duplicate_species(GINSENG_SPECIES)
		3:
			return _duplicate_species(JUNIPER_SPECIES)
		_:
			return _duplicate_species(CLASSIC_SPECIES)


static func _duplicate_species(base: TreeSpecies) -> TreeSpecies:
	if base == null:
		return null
	var species: TreeSpecies = base.duplicate(true)
	if species == null:
		return null
	if species.foliage != null:
		species.foliage = species.foliage.duplicate(true)
	return species


static func pattern_for_preset(index: int) -> GrowPattern:
	match index:
		0:
			return CLASSIC_PATTERN
		1:
			return CASCADE_PATTERN
		2:
			return GINSENG_PATTERN
		3:
			return JUNIPER_PATTERN
		_:
			return CLASSIC_PATTERN


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
