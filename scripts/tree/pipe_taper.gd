class_name PipeTaper
extends RefCounted

const MathUtils = preload("res://scripts/util/math_utils.gd")

const MIN_RADIUS := 0.0035


## Combine child pipe radii into the parent pipe radius (classic area law when exponent = 2).
static func combine_child_radii(radii: Array, exponent: float = 2.0) -> float:
	if radii.is_empty():
		return MIN_RADIUS

	var sum: float = 0.0
	for radius in radii:
		sum += pow(maxf(float(radius), MIN_RADIUS), exponent)
	return maxf(pow(sum, 1.0 / exponent), MIN_RADIUS)


static func terminal_tip_radius(base_radius: float, taper_ratio: float = 0.58) -> float:
	return maxf(base_radius * clampf(taper_ratio, 0.35, 0.95), MIN_RADIUS)


static func segment_radius(
	base_radius: float,
	tip_radius: float,
	t: float,
	power: float = 1.12
) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return lerpf(base_radius, tip_radius, MathUtils.smoothstep(pow(u, power)))
