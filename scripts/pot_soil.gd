extends MeshInstance3D

@export var dry_color: Color = Color(0.76, 0.62, 0.45)
@export var wet_color: Color = Color(0.42, 0.28, 0.18)

var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	material_override = _material
	var soil = CatalogRegistry.get_equipped_soil()
	if soil:
		dry_color = soil.dry_color
		wet_color = soil.wet_color
	set_moisture(GameState.moisture)
	GameState.moisture_changed.connect(set_moisture)


func set_moisture(value: float) -> void:
	if _material:
		_material.albedo_color = dry_color.lerp(wet_color, clampf(value, 0.0, 1.0))
