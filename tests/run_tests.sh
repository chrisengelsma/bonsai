#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

TESTS=(
	"tests/test_bark_winding.gd"
	"tests/test_axial_growth.gd"
	"tests/test_lsystem_model.gd"
	"tests/test_crown_attractor_field.gd"
	"tests/test_moisture_care.gd"
	"tests/test_dead_leaf_model.gd"
	"tests/test_basal_form.gd"
	"tests/test_caudex_arcs.gd"
)

failed=0
for test in "${TESTS[@]}"; do
	echo "==> $test"
	if ! godot --headless -s "$test"; then
		failed=1
	fi
	echo
done

if [[ "$failed" -ne 0 ]]; then
	echo "One or more tests failed."
	exit 1
fi

echo "All tests passed."
