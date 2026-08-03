class_name AxialChain
extends RefCounted

const GrowthLimits = preload("res://scripts/tree/growth_limits.gd")


static func chain_at_joint(nodes: Dictionary, node_id: int) -> float:
	if not nodes.has(node_id):
		return 0.0
	var total: float = 0.0
	var current_id: int = node_id
	while nodes.has(current_id):
		var current = nodes[current_id]
		if current.parent_id < 0:
			break
		var parent = nodes[current.parent_id]
		if parent.depth != current.depth:
			break
		total += parent.length
		current_id = current.parent_id
	return total


static func chain_total(nodes: Dictionary, node_id: int) -> float:
	if not nodes.has(node_id):
		return 0.0
	return chain_at_joint(nodes, node_id) + nodes[node_id].length


static func remaining_budget(nodes: Dictionary, node_id: int) -> float:
	if not nodes.has(node_id):
		return 0.0
	var node = nodes[node_id]
	var depth_cap: float = GrowthLimits.max_length_for_depth(node.depth)
	return depth_cap - chain_total(nodes, node_id)


static func length_budget_for_tip(nodes: Dictionary, node_id: int) -> float:
	if not nodes.has(node_id):
		return GrowthLimits.MAX_TWIG_LENGTH
	var node = nodes[node_id]
	var depth_cap: float = GrowthLimits.max_length_for_depth(node.depth)
	return maxf(depth_cap - chain_at_joint(nodes, node_id), 0.0)


static func max_chain(nodes: Dictionary) -> float:
	var max_chain_length := 0.0
	for node_id in nodes.keys():
		max_chain_length = maxf(max_chain_length, chain_total(nodes, node_id))
	return max_chain_length
