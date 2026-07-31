extends Node3D

@export var animation_duration: float = 1.2

var _can: Node3D
var _droplets: GPUParticles3D
var _busy: bool = false


func _ready() -> void:
	_build_can()
	_build_droplets()
	visible = false
	GameState.watering_started.connect(_on_watering_started)


func _build_can() -> void:
	_can = Node3D.new()
	_can.name = "Can"
	add_child(_can)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.1, 0.08)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.58, 0.62)
	body.material_override = mat
	_can.add_child(body)

	var spout := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.01
	cylinder.bottom_radius = 0.015
	cylinder.height = 0.08
	spout.mesh = cylinder
	spout.position = Vector3(0.06, 0.02, 0)
	spout.rotation_degrees = Vector3(0, 0, -60)
	spout.material_override = mat
	_can.add_child(spout)


func _build_droplets() -> void:
	_droplets = GPUParticles3D.new()
	_droplets.name = "Droplets"
	_droplets.emitting = false
	_droplets.amount = 24
	_droplets.lifetime = 0.6
	_droplets.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0, -4, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.04
	_droplets.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.01
	mesh.height = 0.02
	_droplets.draw_pass_1 = mesh
	add_child(_droplets)


func _on_watering_started() -> void:
	if _busy:
		return
	_busy = true
	visible = true
	position = Vector3(0.35, 0.5, 0.25)
	_can.rotation_degrees = Vector3(0, -30, 0)

	var tween := create_tween()
	tween.tween_property(self, "position", Vector3(0.1, 0.35, 0.15), animation_duration * 0.4)
	tween.parallel().tween_property(_can, "rotation_degrees", Vector3(0, -30, 45), animation_duration * 0.4)
	tween.tween_callback(_emit_droplets)
	tween.tween_interval(animation_duration * 0.3)
	tween.tween_property(_can, "rotation_degrees", Vector3(0, -30, 0), animation_duration * 0.2)
	tween.parallel().tween_property(self, "position", Vector3(0.35, 0.5, 0.25), animation_duration * 0.2)
	tween.tween_callback(_finish)


func _emit_droplets() -> void:
	_droplets.position = Vector3(0.1, 0.25, 0.15)
	_droplets.restart()
	_droplets.emitting = true
	AudioManager.play_sfx("water")


func _finish() -> void:
	visible = false
	_busy = false
	GameState.complete_watering()
