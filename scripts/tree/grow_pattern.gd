class_name GrowPattern
extends Resource

## Turtle movement per completed segment (classic L-system interpretation).
@export var lsystem_axiom: String = "T"
@export_multiline var lsystem_rules_text: String = "T=F[+S][-S]\nS=F[+T][-T]\nF=F"
@export var lsystem_angle_deg: float = 28.0
@export var lsystem_segment_length: float = 0.1
@export var angle_jitter_deg: float = 7.0
@export var lateral_roll_spread_deg: float = 42.0
@export var spatial_spread_deg: float = 16.0
@export var segment_length_jitter: float = 0.14
@export var lateral_skip_chance: float = 0.12
@export var growth_energy_variance: float = 0.2
@export var cambium_growth_rate: float = 0.0011
@export var ring_sample_spacing: float = 0.028
@export var use_lsystem: bool = true
@export var deterministic_growth: bool = true
@export var use_fork_bulb: bool = false
@export var foliage_style: String = "none"

@export var tip_growth_rate: float = 0.02
@export var branch_angle_range: Vector2 = Vector2(25.0, 55.0)
@export var branch_split_chance: float = 0.08
@export var max_branch_depth: int = 4
@export var max_children_per_node: int = 3
@export var apical_dominance: float = 0.7
@export var thickness_falloff: float = 0.75
@export var foliage_start_length: float = 0.08
@export var foliage_growth_rate: float = 0.15
@export var gravity_curve: float = 0.0
@export var regrowth_delay: float = 2.0
@export var regrowth_chance: float = 0.4
@export var trunk_thickness: float = 0.022
@export var branch_thickness: float = 0.009

var _rules_cache: Dictionary = {}


func invalidate_rules_cache() -> void:
	_rules_cache.clear()


func get_lsystem_rules() -> Dictionary:
	if not _rules_cache.is_empty():
		return _rules_cache
	_rules_cache = {}
	for line in lsystem_rules_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		var parts := trimmed.split("=", false, 1)
		if parts.size() == 2:
			_rules_cache[parts[0].strip_edges()] = parts[1].strip_edges()
	return _rules_cache


func get_production(symbol: String) -> String:
	var rules := get_lsystem_rules()
	if rules.has(symbol):
		return str(rules[symbol])
	return symbol
