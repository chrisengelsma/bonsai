class_name BasalRadiusProfile
extends RefCounted

## Mid-segment swell for sculpted basal legs (ginseng caudex).


static func apply_bulge(radius: float, local_t: float, node, pattern) -> float:
	if pattern == null or not node.is_basal_leg:
		return radius
	var strength: float = float(pattern.basal_bulge_strength)
	if strength <= 0.0:
		return radius
	var t: float = clampf(local_t, 0.0, 1.0)
	var swell: float = pow(sin(t * PI), 0.72)
	return radius * (1.0 + strength * swell)
