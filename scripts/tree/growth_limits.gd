class_name GrowthLimits
extends RefCounted

## Hard caps that keep procedural trees bonsai-sized and performant.

const MAX_TOTAL_NODES := 88
const MAX_ACTIVE_TIPS := 18
const MAX_BRANCH_DEPTH := 6
const MAX_CHILDREN_PER_NODE := 3
const MAX_TREE_HEIGHT := 1.45

const MAX_TRUNK_LENGTH := 0.95
const MAX_PRIMARY_LENGTH := 0.55
const MAX_SECONDARY_LENGTH := 0.38
const MAX_TWIG_LENGTH := 0.28

const MIN_SEGMENT_LENGTH := 0.045
const MAX_SEGMENT_LENGTH := 0.14
const MAX_TIP_GROWTH_RATE := 0.04
const MAX_BRANCH_ANGLE_DEG := 58.0
const MAX_GRAVITY_CURVE := 1.1

const MAX_GAME_GROW_SPEED := 8.0
const MAX_LAB_GROW_SPEED := 12.0


static func clamp_pattern(pattern) -> void:
	if pattern == null:
		return
	pattern.max_branch_depth = clampi(pattern.max_branch_depth, 2, MAX_BRANCH_DEPTH)
	pattern.max_children_per_node = clampi(pattern.max_children_per_node, 1, MAX_CHILDREN_PER_NODE)
	pattern.lsystem_segment_length = clampf(
		pattern.lsystem_segment_length,
		MIN_SEGMENT_LENGTH,
		MAX_SEGMENT_LENGTH
	)
	pattern.tip_growth_rate = clampf(pattern.tip_growth_rate, 0.005, MAX_TIP_GROWTH_RATE)
	pattern.lsystem_angle_deg = clampf(pattern.lsystem_angle_deg, 8.0, MAX_BRANCH_ANGLE_DEG)
	pattern.gravity_curve = clampf(pattern.gravity_curve, 0.0, MAX_GRAVITY_CURVE)
	pattern.angle_jitter_deg = clampf(pattern.angle_jitter_deg, 0.0, 18.0)
	pattern.segment_length_jitter = clampf(pattern.segment_length_jitter, 0.0, 0.35)
	pattern.lateral_skip_chance = clampf(pattern.lateral_skip_chance, 0.0, 0.35)
	pattern.growth_energy_variance = clampf(pattern.growth_energy_variance, 0.0, 0.4)
	pattern.lateral_roll_spread_deg = clampf(pattern.lateral_roll_spread_deg, 0.0, 60.0)
	pattern.spatial_spread_deg = clampf(pattern.spatial_spread_deg, 0.0, 28.0)
	pattern.cambium_growth_rate = clampf(pattern.cambium_growth_rate, 0.0, 0.004)
	pattern.ring_sample_spacing = clampf(pattern.ring_sample_spacing, 0.012, 0.06)


static func max_length_for_depth(depth: int) -> float:
	match depth:
		0:
			return MAX_TRUNK_LENGTH
		1:
			return MAX_PRIMARY_LENGTH
		2:
			return MAX_SECONDARY_LENGTH
		_:
			return MAX_TWIG_LENGTH


static func can_add_node(current_count: int) -> bool:
	return current_count < MAX_TOTAL_NODES


static func clamp_game_grow_speed(value: float) -> float:
	return clampf(value, 0.1, MAX_GAME_GROW_SPEED)


static func clamp_lab_grow_speed(value: float) -> float:
	return clampf(value, 0.5, MAX_LAB_GROW_SPEED)
