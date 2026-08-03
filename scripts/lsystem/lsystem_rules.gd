class_name LSystemRules
extends RefCounted

var _rules: Dictionary = {}


func clear() -> void:
	_rules.clear()


func parse(rules_text: String) -> void:
	_rules.clear()
	for line in rules_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		var parts := trimmed.split("=", false, 1)
		if parts.size() == 2:
			_rules[parts[0].strip_edges()] = parts[1].strip_edges()


func has(symbol: String) -> bool:
	return _rules.has(symbol)


func get_production(symbol: String) -> String:
	if _rules.has(symbol):
		return str(_rules[symbol])
	return symbol


func as_dictionary() -> Dictionary:
	return _rules.duplicate()
