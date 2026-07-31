shader_type spatial;
render_mode cull_disabled;

uniform vec4 foliage_color : source_color = vec4(0.42, 0.56, 0.44, 1.0);
uniform float sway_amount = 0.02;
uniform float sway_speed = 1.2;

void vertex() {
	float sway = sin(TIME * sway_speed + VERTEX.x * 4.0 + VERTEX.z * 3.0) * sway_amount;
	VERTEX.x += sway;
}

void fragment() {
	ALBEDO = foliage_color.rgb;
}
