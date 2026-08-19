shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform vec4 foliage_color : source_color = vec4(0.42, 0.56, 0.44, 1.0);
uniform float sway_amount = 0.02;
uniform float sway_speed = 1.2;
uniform vec3 wind_tilt = vec3(0.0);
uniform float wind_strength = 0.0;
uniform float underside_darken = 0.15;
uniform float petiole_length = 0.009;

float foliage_sway_weight(vec3 vertex) {
	// Origin is the branch attachment; petiole runs along +Z, blade extends in +Y.
	float along_petiole = max(vertex.z, 0.0);
	float blade_extent = max(vertex.y, 0.0) * 0.12;
	return smoothstep(0.0, max(petiole_length, 0.001), along_petiole + blade_extent);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r * TAU;
	float sway_scale = INSTANCE_CUSTOM.g;
	float maturity = INSTANCE_CUSTOM.b;
	float weight = foliage_sway_weight(VERTEX);

	vec3 tilt = wind_tilt * wind_strength * sway_scale * maturity * weight;
	float bob = sin(TIME * sway_speed + phase) * sway_amount * sway_scale * maturity * weight;
	VERTEX += tilt + vec3(0.0, bob, 0.0);
}

void fragment() {
	vec3 flat_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facing = clamp(dot(flat_normal, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 base = foliage_color.rgb * mix(1.0 - underside_darken, 1.0, facing);
	ALBEDO = base;
}
