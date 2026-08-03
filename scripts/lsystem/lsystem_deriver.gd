class_name LSystemDeriver
extends RefCounted


static func derive(axiom: String, rules: Dictionary, iterations: int) -> String:
	var current: String = axiom
	var steps: int = maxi(iterations, 0)
	for _i in range(steps):
		var next := ""
		for index in range(current.length()):
			var symbol: String = current[index]
			if rules.has(symbol):
				next += str(rules[symbol])
			else:
				next += symbol
		current = next
	return current
