class_name GinsengBasalForm
extends RefCounted

const CAUDEX_HEIGHT := 0.105
const NECK_LENGTH := 0.04
const CROWN_STEM_LENGTH := 0.05


static func build(graph, pattern) -> int:
	var neck_thickness: float = maxf(pattern.branch_thickness * 1.05, pattern.trunk_thickness * 0.38)
	var crown_thickness: float = maxf(pattern.branch_thickness * 1.1, pattern.trunk_thickness * 0.4)

	graph.has_caudex = true
	graph.caudex_arc_count = clampi(pattern.basal_arc_count, 2, 4)
	graph.caudex_height = CAUDEX_HEIGHT
	graph.caudex_bulk_radius = pattern.trunk_thickness * 0.92

	var anchor = graph._create_node(-1, Vector3.UP, neck_thickness, 0)
	anchor.length = CAUDEX_HEIGHT
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
