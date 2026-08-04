extends Node
class_name TreeEditor

enum ToolMode { VIEW, PRUNE, GRAFT, TEND }

signal tool_mode_changed(mode: ToolMode)
signal branch_selected(branch_id: int)
signal dead_leaf_tended(tip_id: int)

var tool_mode: ToolMode = ToolMode.VIEW
var _graph
var _renderer
var _graft_donor_id: int = -1
var _enabled: bool = true


func setup(graph, renderer) -> void:
	_graph = graph
	_renderer = renderer
	if _renderer and not _renderer.branch_clicked.is_connected(_on_branch_clicked):
		_renderer.branch_clicked.connect(_on_branch_clicked)
	if _renderer and not _renderer.dead_leaf_clicked.is_connected(_on_dead_leaf_clicked):
		_renderer.dead_leaf_clicked.connect(_on_dead_leaf_clicked)
	_apply_renderer_tool_mode()


func set_enabled(value: bool) -> void:
	_enabled = value


func set_tool_mode(mode: ToolMode) -> void:
	tool_mode = mode
	_graft_donor_id = -1
	_apply_renderer_tool_mode()
	tool_mode_changed.emit(mode)


func _apply_renderer_tool_mode() -> void:
	if _renderer == null:
		return
	if _renderer.has_method("set_tend_pick_enabled"):
		_renderer.set_tend_pick_enabled(tool_mode == ToolMode.TEND)


func _on_branch_clicked(branch_id: int) -> void:
	if not _enabled or _graph == null:
		return
	if tool_mode == ToolMode.VIEW:
		return

	if tool_mode == ToolMode.PRUNE:
		if branch_id != _graph.root_id:
			_graph.cut_branch(branch_id)
			branch_selected.emit(branch_id)
		return

	if tool_mode == ToolMode.GRAFT:
		if _graft_donor_id < 0:
			if branch_id != _graph.root_id:
				_graft_donor_id = branch_id
				branch_selected.emit(branch_id)
		else:
			if branch_id != _graft_donor_id:
				_graph.graft(_graft_donor_id, branch_id)
				branch_selected.emit(branch_id)
			_graft_donor_id = -1


func _on_dead_leaf_clicked(tip_id: int) -> void:
	if not _enabled or _graph == null or tool_mode != ToolMode.TEND:
		return
	if GameState.tend_dead_leaf(tip_id):
		dead_leaf_tended.emit(tip_id)
		branch_selected.emit(tip_id)
