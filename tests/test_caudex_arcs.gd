extends SceneTree

const BasalForm = preload("res://scripts/tree/basal_form.gd")
const TreeGraph = preload("res://scripts/tree/tree_graph.gd")
const GrowPattern = preload("res://scripts/tree/grow_pattern.gd")
const TreeSpecies = preload("res://scripts/catalog/tree_species.gd")
const GinsengCaudexMesh = preload("res://scripts/tree/ginseng_caudex_mesh.gd")


func _init() -> void:
	_test_connected_caudex_mesh()
	_test_caudex_bulk_grows()
	print("test_caudex_arcs: all passed")
	quit()


func _test_connected_caudex_mesh() -> void:
	var mesh: ArrayMesh = GinsengCaudexMesh.build(4, 0.11, 0.045, 0.014)
	assert(mesh != null)
	var wire: ArrayMesh = GinsengCaudexMesh.build_wireframe(4, 0.11, 0.045, 0.014)
	assert(wire != null)


func _test_caudex_bulk_grows() -> void:
	var graph := TreeGraph.new()
	var species := TreeSpecies.new()
	species.id = "ginseng_ficus"
	species.basal_form = BasalForm.GINSENG_CAUDEX
	var pattern := GrowPattern.new()
	pattern.basal_arc_count = 3
	pattern.basal_cambium_mult = 2.0
	pattern.trunk_thickness = 0.05
	pattern.basal_radius_mult = 2.5
	pattern.cambium_growth_rate = 0.01
	graph._create_default_starter(species, pattern)
	var start_r: float = graph.caudex_bulk_radius
	for _i in range(40):
		graph.grow(0.5, pattern, 1.0, 1.0, 1.0)
	assert(graph.caudex_bulk_radius > start_r)
