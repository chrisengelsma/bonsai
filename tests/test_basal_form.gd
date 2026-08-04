extends SceneTree

const BasalForm = preload("res://scripts/tree/basal_form.gd")
const GinsengBasalForm = preload("res://scripts/tree/ginseng_basal_form.gd")
const TreeGraph = preload("res://scripts/tree/tree_graph.gd")
const GrowPattern = preload("res://scripts/tree/grow_pattern.gd")
const TreeSpecies = preload("res://scripts/catalog/tree_species.gd")
const GinsengCaudexMesh = preload("res://scripts/tree/ginseng_caudex_mesh.gd")


func _init() -> void:
	_test_standard_starter()
	_test_ginseng_caudex_starter()
	_test_caudex_mesh_builds()
	print("test_basal_form: all passed")
	quit()


func _test_standard_starter() -> void:
	var graph := TreeGraph.new()
	var species := TreeSpecies.new()
	species.id = "classic_upright"
	species.basal_form = BasalForm.STANDARD
	var pattern := GrowPattern.new()
	graph._create_default_starter(species, pattern)
	assert(graph.has_caudex == false)
	assert(graph.nodes.size() == 1)


func _test_ginseng_caudex_starter() -> void:
	var graph := TreeGraph.new()
	var species := TreeSpecies.new()
	species.id = "ginseng_ficus"
	species.basal_form = BasalForm.GINSENG_CAUDEX
	var pattern := GrowPattern.new()
	pattern.basal_arc_count = 3
	graph._create_default_starter(species, pattern)
	assert(graph.has_caudex == true)
	assert(graph.caudex_bulk_radius > 0.0)
	assert(graph.caudex_arc_count == 3)
	assert(graph.nodes.size() == 3)
	var anchor = graph.nodes[graph.root_id]
	assert(anchor.is_caudex_anchor == true)
	var leg_count := 0
	for node in graph.nodes.values():
		if node.is_basal_leg:
			leg_count += 1
	assert(leg_count == 0)


func _test_caudex_mesh_builds() -> void:
	var mesh: ArrayMesh = GinsengCaudexMesh.build(3, 0.1, 0.04, 0.012)
	assert(mesh != null)
	assert(mesh.get_surface_count() > 0)
