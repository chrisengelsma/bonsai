extends SceneTree

const MoistureCare = preload("res://scripts/tree/moisture_care.gd")

const THRESHOLD := 0.25


func _init() -> void:
	var failures: Array[String] = []
	failures.append_array(_test_growth_factor())
	failures.append_array(_test_is_growing())
	failures.append_array(_test_status_labels())
	failures.append_array(_test_tend_moisture_bump())

	if failures.is_empty():
		print("ALL CHECKS PASSED (moisture care)")
	else:
		for failure in failures:
			print("FAIL: ", failure)
	quit(1 if not failures.is_empty() else 0)


func _test_growth_factor() -> Array[String]:
	var failures: Array[String] = []
	var dry_cutoff: float = THRESHOLD * MoistureCare.GROWTH_STOP_FRACTION

	if MoistureCare.growth_factor(0.0, THRESHOLD) != 0.0:
		failures.append("growth_factor at 0 should be 0")
	if MoistureCare.growth_factor(dry_cutoff, THRESHOLD) != 0.0:
		failures.append("growth_factor at dry cutoff should be 0")
	if MoistureCare.growth_factor(1.0, THRESHOLD) < 0.99:
		failures.append("growth_factor at 1.0 should be near 1")
	if MoistureCare.growth_factor(0.5, THRESHOLD) >= MoistureCare.growth_factor(0.9, THRESHOLD):
		failures.append("growth_factor should increase with moisture")
	return failures


func _test_is_growing() -> Array[String]:
	var failures: Array[String] = []
	if MoistureCare.is_growing(0.0, THRESHOLD):
		failures.append("is_growing should be false when dry")
	if not MoistureCare.is_growing(0.8, THRESHOLD):
		failures.append("is_growing should be true when moist")
	return failures


func _test_status_labels() -> Array[String]:
	var failures: Array[String] = []
	if MoistureCare.moisture_status_label(0.05, THRESHOLD) != "Thirsty":
		failures.append("expected Thirsty label when very dry")
	if MoistureCare.moisture_status_label(0.9, THRESHOLD) != "Happy":
		failures.append("expected Happy label when moist")
	if MoistureCare.growth_status_label(0.0, THRESHOLD) != "Needs water":
		failures.append("expected Needs water growth label when dry")
	if MoistureCare.growth_status_label(0.9, THRESHOLD) != "Growing":
		failures.append("expected Growing label when moist")
	return failures


func _test_tend_moisture_bump() -> Array[String]:
	var failures: Array[String] = []
	var bumped: float = MoistureCare.apply_tend_moisture_bump(0.5)
	if absf(bumped - 0.55) > 0.001:
		failures.append("tend bump should add 0.05")
	if MoistureCare.apply_tend_moisture_bump(0.98) != 1.0:
		failures.append("tend bump should cap at 1.0")
	return failures
