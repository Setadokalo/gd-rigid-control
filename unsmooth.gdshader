shader_type spatial;

uniform vec3 albedo: source_color;
uniform sampler2D surface_noise;

void vertex() {
	VERTEX += NORMAL * 0.2 * texture(surface_noise, VERTEX.xz).xyz;
}

void fragment() {
	NORMAL = normalize(cross(-dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = albedo;
}
