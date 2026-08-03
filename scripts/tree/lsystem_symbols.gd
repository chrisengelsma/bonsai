class_name LSystemSymbols
extends RefCounted


static func is_module_symbol(symbol: String) -> bool:
	if symbol.length() != 1:
		return false
	var code: int = symbol.unicode_at(0)
	return code >= 65 and code <= 90


static func is_lateral_module(symbol: String) -> bool:
	return is_module_symbol(symbol) and symbol != "F"


static func first_lateral_symbol(production: String) -> String:
	for i in production.length():
		var symbol: String = production[i]
		if is_lateral_module(symbol):
			return symbol
	return ""


static func lateral_regrowth_symbol(pattern) -> String:
	var rules = pattern.get_lsystem_rules()
	if rules.has("S"):
		return "S"
	if rules.has("B"):
		return "B"
	return pattern.lsystem_axiom
