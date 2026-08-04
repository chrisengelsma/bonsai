extends Node

const MobileUtils = preload("res://scripts/platform/mobile_utils.gd")

var wind_tilt: Vector3 = Vector3.ZERO
var wind_strength: float = 0.0

@export var smoothing: float = 8.0
@export var desktop_ambient_strength: float = 0.12
@export var desktop_ambient_speed: float = 0.35


func _process(delta: float) -> void:
	var target: Vector3 = _read_target_tilt()
	var target_strength: float = target.length()
	if target_strength > 0.001:
		target = target / target_strength
	else:
		target = Vector3.ZERO
		target_strength = 0.0

	var blend: float = clampf(smoothing * delta, 0.0, 1.0)
	wind_tilt = wind_tilt.lerp(target, blend)
	wind_strength = lerpf(wind_strength, target_strength, blend)


func _read_target_tilt() -> Vector3:
	if MobileUtils.is_mobile():
		var accel := Input.get_accelerometer()
		return Vector3(accel.x, -accel.y, 0.0)

	var t: float = Time.get_ticks_msec() * 0.001 * desktop_ambient_speed
	return Vector3(sin(t * 1.1) * desktop_ambient_strength, cos(t * 0.9) * desktop_ambient_strength, 0.0)
