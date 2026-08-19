class_name GinsengBasalForm
extends RefCounted

const START_CAUDEX_HEIGHT := 0.076
const MAX_CAUDEX_HEIGHT := 0.72
const NECK_LENGTH := 0.03
const CROWN_STEM_LENGTH := 0.028
const LOBE_SCALE_MIN := 0.72
const LOBE_SCALE_MAX := 1.12


static func roll_lobe_scales(rng: RandomNumberGenerator, arc_count: int) -> Array:
	var scales: Array = []
	for _i in range(clampi(arc_count, 1, 4)):
		scales.append(rng.randf_range(LOBE_SCALE_MIN, LOBE_SCALE_MAX))
	return scales


static func build(graph, pattern, arc_count: int = -1) -> int:
	var neck_thickness: float = maxf(pattern.branch_thickness * 1.05, pattern.trunk_thickness * 0.38)
	var crown_thickness: float = maxf(pattern.branch_thickness * 1.1, pattern.trunk_thickness * 0.4)

	graph.has_caudex = true
	var count: int = arc_count if arc_count >= 1 else pattern.basal_arc_count
	graph.caudex_arc_count = clampi(count, 1, 4)
	graph.caudex_lobe_scales = roll_lobe_scales(graph.get_rng(), graph.caudex_arc_count)
	graph.caudex_height = START_CAUDEX_HEIGHT
	graph.caudex_max_height = _resolve_max_height(pattern)
	graph.caudex_bulk_radius = maxf(pattern.trunk_thickness * 0.2, 0.0048)

	var anchor = graph._create_node(-1, Vector3.UP, neck_thickness, 0)
	anchor.length = START_CAUDEX_HEIGHT
	anchor.base_thickness = neck_thickness
	anchor.thickness = neck_thickness
	anchor.freeze_length = true
	anchor.is_growing_tip = false
	anchor.is_caudex_anchor = true
	anchor.lsymbol = "F"
	anchor.stochastic_direction = false
	graph._init_branch_profile(anchor)

	var neck = graph._create_node(anchor.id, Vector3.UP, neck_thickness, 1)
	neck.length = NECK_LENGTH
	neck.base_thickness = neck_thickness
	neck.thickness = neck_thickness
	neck.freeze_length = true
	neck.is_growing_tip = false
	neck.lsymbol = "F"
	neck.stochastic_direction = false
	graph._init_branch_profile(neck)

	var crown = graph._create_node(neck.id, Vector3.UP, crown_thickness, 2)
	crown.length = CROWN_STEM_LENGTH
	crown.base_thickness = crown_thickness
	crown.thickness = crown_thickness
	crown.is_growing_tip = true
	crown.lsymbol = pattern.lsystem_axiom if pattern.use_lsystem else "T"
	crown.stochastic_direction = not pattern.deterministic_growth
	crown.turtle_up = Vector3.FORWARD
	crown.growth_energy = graph._roll_growth_energy(pattern)
	graph._init_branch_profile(crown)

	graph.root_id = anchor.id
	return crown.id


static func _resolve_max_height(pattern) -> float:
	if pattern != null and pattern.caudex_max_height > 0.0:
		return pattern.caudex_max_height
	return MAX_CAUDEX_HEIGHT
