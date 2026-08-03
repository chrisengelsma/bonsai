class_name LSystemParams
extends Resource

@export var axiom: String = "T"
@export_multiline var rules_text: String = "T=F[+S][-S]\nS=F[+T][-T]\nF=F"
@export var angle_deg: float = 28.0
@export var segment_length: float = 0.1
@export var growth_rate: float = 0.03
@export var iterations: int = 4
@export var max_children: int = 3
@export var seed_position: Vector3 = Vector3.ZERO
@export var gravity: float = 0.0

@export var deterministic: bool = true
@export var angle_jitter_deg: float = 0.0
@export var segment_length_jitter: float = 0.0
@export var spatial_spread_deg: float = 0.0
@export var lateral_roll_spread_deg: float = 0.0
@export var lateral_skip_chance: float = 0.0
@export var growth_energy_variance: float = 0.0
@export var apical_dominance: float = 0.8
@export var auxin_decay: float = 0.68
@export var auxin_source_strength: float = 1.0

@export var line_color: Color = Color(0.55, 0.35, 0.2, 1.0)
@export var line_width: float = 0.004
@export var render_cylinders: bool = false


func duplicate_params() -> LSystemParams:
	return duplicate(true)


func apply_random_factor(factor: float) -> void:
	factor = clampf(factor, 0.0, 1.0)
	if factor <= 0.001:
		return
	deterministic = false
	angle_jitter_deg = lerpf(0.0, 18.0, factor)
	spatial_spread_deg = lerpf(0.0, 22.0, factor)
	segment_length_jitter = lerpf(0.0, 0.35, factor)
	growth_energy_variance = lerpf(0.0, 0.35, factor)
	lateral_skip_chance = lerpf(0.0, 0.2, factor)
	lateral_roll_spread_deg = lerpf(0.0, 40.0, factor)


func clamp_values() -> void:
	axiom = axiom.strip_edges()
	if axiom.is_empty():
		axiom = "T"
	angle_deg = clampf(angle_deg, 5.0, 58.0)
	segment_length = clampf(segment_length, 0.03, 0.14)
	growth_rate = clampf(growth_rate, 0.005, 0.04)
	iterations = clampi(iterations, 1, 8)
	max_children = clampi(max_children, 1, 6)
	gravity = clampf(gravity, 0.0, 1.1)
	angle_jitter_deg = maxf(angle_jitter_deg, 0.0)
	segment_length_jitter = clampf(segment_length_jitter, 0.0, 0.5)
	spatial_spread_deg = maxf(spatial_spread_deg, 0.0)
	lateral_roll_spread_deg = maxf(lateral_roll_spread_deg, 0.0)
	lateral_skip_chance = clampf(lateral_skip_chance, 0.0, 1.0)
	growth_energy_variance = clampf(growth_energy_variance, 0.0, 1.0)
	apical_dominance = clampf(apical_dominance, 0.0, 1.0)
	auxin_decay = clampf(auxin_decay, 0.2, 0.95)
	auxin_source_strength = clampf(auxin_source_strength, 0.1, 2.5)
	line_width = clampf(line_width, 0.001, 0.02)


static func from_grow_pattern(pattern) -> LSystemParams:
	var params := LSystemParams.new()
	params.axiom = pattern.lsystem_axiom
	params.rules_text = pattern.lsystem_rules_text
	params.angle_deg = pattern.lsystem_angle_deg
	params.segment_length = pattern.lsystem_segment_length
	params.growth_rate = pattern.tip_growth_rate
	params.iterations = pattern.max_branch_depth
	params.max_children = pattern.max_children_per_node
	params.gravity = pattern.gravity_curve
	params.deterministic = pattern.deterministic_growth
	params.angle_jitter_deg = pattern.angle_jitter_deg
	params.segment_length_jitter = pattern.segment_length_jitter
	params.spatial_spread_deg = pattern.spatial_spread_deg
	params.lateral_roll_spread_deg = pattern.lateral_roll_spread_deg
	params.lateral_skip_chance = pattern.lateral_skip_chance
	params.growth_energy_variance = pattern.growth_energy_variance
	params.apical_dominance = pattern.apical_dominance
	params.auxin_decay = pattern.auxin_decay
	params.auxin_source_strength = pattern.auxin_source_strength
	return params


func apply_to_grow_pattern(pattern) -> void:
	pattern.lsystem_axiom = axiom
	pattern.lsystem_rules_text = rules_text
	pattern.lsystem_angle_deg = angle_deg
	pattern.lsystem_segment_length = segment_length
	pattern.tip_growth_rate = growth_rate
	pattern.max_branch_depth = iterations
	pattern.max_children_per_node = max_children
	pattern.gravity_curve = gravity
	pattern.deterministic_growth = deterministic
	pattern.angle_jitter_deg = angle_jitter_deg
	pattern.segment_length_jitter = segment_length_jitter
	pattern.spatial_spread_deg = spatial_spread_deg
	pattern.lateral_roll_spread_deg = lateral_roll_spread_deg
	pattern.lateral_skip_chance = lateral_skip_chance
	pattern.growth_energy_variance = growth_energy_variance
	pattern.apical_dominance = apical_dominance
	pattern.auxin_decay = auxin_decay
	pattern.auxin_source_strength = auxin_source_strength
	pattern.use_lsystem = true
	pattern.use_auxin = true
	pattern.invalidate_rules_cache()
