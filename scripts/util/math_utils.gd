class_name MathUtils
extends RefCounted


static func smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
