extends RefCounted
class_name MobileUtils

static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()


static func is_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y >= viewport_size.x


static func get_safe_insets(viewport: Viewport) -> Dictionary:
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := viewport.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

	var scale := Vector2(
		vp_size.x / maxf(float(DisplayServer.screen_get_size().x), 1.0),
		vp_size.y / maxf(float(DisplayServer.screen_get_size().y), 1.0)
	)

	return {
		"left": safe.position.x * scale.x,
		"top": safe.position.y * scale.y,
		"right": maxf(0.0, vp_size.x - safe.end.x * scale.x),
		"bottom": maxf(0.0, vp_size.y - safe.end.y * scale.y),
	}
