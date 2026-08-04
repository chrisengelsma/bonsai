class_name FoliagePreset
extends Resource

const GOLDEN_ANGLE_DEG := 137.508

enum MeshStyle { NONE, CLUSTER, BROADLEAF, NEEDLE, SCALE }
enum Placement { TIP_ONLY, SEGMENT_SCATTER, FASCICLE_ALONG_SEGMENT }

@export var mesh_style: MeshStyle = MeshStyle.CLUSTER
@export var placement: Placement = Placement.TIP_ONLY

@export var instances_per_tip: Vector2i = Vector2i(1, 1)
@export var segment_scatter_count: int = 0
@export var scale_range: Vector2 = Vector2(0.6, 1.0)
@export var droop_deg: float = 15.0

@export var fascicle_needle_count: int = 2
@export var needle_length: float = 0.028
@export var needle_spread_deg: float = 28.0
@export var fascicle_spacing: float = 0.011
@export var fascicle_cover_frac: float = 0.78
@export var fascicle_roll_step_deg: float = GOLDEN_ANGLE_DEG
@export var fascicle_roll_jitter_deg: float = 12.0
@export var max_fascicles_per_twigs: int = 10

## Skip foliage near the parent joint (fraction of branch length).
@export_range(0.0, 0.5, 0.01) var leaf_start_ratio: float = 0.08
## Stop foliage before the very tip (fraction of branch length).
@export_range(0.5, 1.0, 0.01) var leaf_end_ratio: float = 0.96
## Minimum graph depth before a twig may carry foliage.
@export var min_branch_depth: int = 2
## Only twigs thinner than this radius get foliage (0 disables the gate).
@export var max_branch_thickness: float = 0.0

@export var albedo_color: Color = Color(0.42, 0.56, 0.44)
@export var underside_darken: float = 0.15
@export var hue_jitter: float = 0.04

@export var sway_amount: float = 0.02
@export var sway_speed: float = 1.2
@export var tilt_sensitivity: float = 1.0

@export var dead_leaf_color: Color = Color(0.42, 0.28, 0.14)
@export var dead_leaf_scale: float = 0.9
@export var dead_leaf_droop_extra_deg: float = 25.0

@export var seasonal_enabled: bool = false


static func has_live_foliage(species) -> bool:
	if species == null:
		return false
	var preset = species.foliage if "foliage" in species else null
	if preset == null:
		return false
	return preset.mesh_style != MeshStyle.NONE


static func resolve(species) -> FoliagePreset:
	if species == null or not ("foliage" in species) or species.foliage == null:
		return null
	return species.foliage


static func has_foliage_growth(species, pattern = null) -> bool:
	if has_live_foliage(species):
		return true
	return pattern != null and str(pattern.foliage_style) != "none"
