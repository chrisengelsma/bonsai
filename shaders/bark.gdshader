shader_type spatial;

uniform vec4 bark_color : source_color = vec4(0.55, 0.35, 0.2, 1.0);
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.94;

varying vec3 world_vertex;

void vertex() {
	world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 facet = floor(world_vertex.xz * 42.0);
	float grain = fract(sin(dot(facet, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 albedo = bark_color.rgb * mix(0.88, 1.08, grain);
	ALBEDO = albedo;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.12;
}
