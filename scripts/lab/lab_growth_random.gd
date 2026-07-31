extends RefCounted
class_name LabGrowthRandom

## Maps a 0..1 lab slider to stochastic growth parameters.


static func apply_to_pattern(pattern, factor: float) -> void:
	factor = clampf(factor, 0.0, 1.0)
	pattern.deterministic_growth = factor <= 0.001
	pattern.angle_jitter_deg = lerpf(0.0, 18.0, factor)
	pattern.spatial_spread_deg = lerpf(0.0, 22.0, factor)
	pattern.segment_length_jitter = lerpf(0.0, 0.35, factor)
	pattern.growth_energy_variance = lerpf(0.0, 0.35, factor)
	pattern.lateral_skip_chance = lerpf(0.0, 0.2, factor)
	pattern.lateral_roll_spread_deg = lerpf(0.0, 40.0, factor)
