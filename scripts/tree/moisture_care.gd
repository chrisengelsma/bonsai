class_name MoistureCare
extends RefCounted

## Cozy moisture care — growth scaling and status labels without a separate health stat.

const TEND_MOISTURE_BUMP := 0.05
const GROWTH_STOP_FRACTION := 0.5


static func growth_factor(moisture: float, threshold: float) -> float:
	if threshold <= 0.0:
		return 1.0 if moisture > 0.0 else 0.0
	var dry_cutoff: float = threshold * GROWTH_STOP_FRACTION
	if moisture <= dry_cutoff:
		return 0.0
	return smoothstep(dry_cutoff, 1.0, moisture)


static func is_growing(moisture: float, threshold: float) -> bool:
	return growth_factor(moisture, threshold) > 0.0


static func moisture_status_label(moisture: float, threshold: float) -> String:
	if moisture < threshold * GROWTH_STOP_FRACTION:
		return "Thirsty"
	if moisture < threshold:
		return "Content"
	if moisture >= 0.85:
		return "Happy"
	return "Content"


static func growth_status_label(moisture: float, threshold: float) -> String:
	if not is_growing(moisture, threshold):
		return "Needs water"
	return "Growing"


static func apply_tend_moisture_bump(moisture: float, bump: float = TEND_MOISTURE_BUMP) -> float:
	return minf(1.0, moisture + bump)
