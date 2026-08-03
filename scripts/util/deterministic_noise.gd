class_name DeterministicNoise
extends RefCounted


static func unit_hash(seed: int, a: int, b: int) -> float:
	var h: int = absi(hash(Vector3i(seed, a, b)))
	return float(h % 10001) / 5000.0 - 1.0
