extends "res://scripts/orbit_camera.gd"

## Lab camera: always orbitable, wider zoom range, no save writes.


func _ready() -> void:
	super._ready()
	distance = 5.0


func _can_orbit() -> bool:
	return true


func _save_camera_state() -> void:
	pass
