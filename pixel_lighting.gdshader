shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_rough_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform vec3 color : source_color;

#define DEPTH(offset) get_depth(INV_PROJECTION_MATRIX, SCREEN_UV + offset)

float get_depth(mat4 matrix, vec2 uv) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	vec4 upos = matrix * vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_position = upos.xyz / upos.w;
	return pixel_position.z;
}
vec3 get_normal(vec2 uv) {
	return texture(normal_rough_texture, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	// size of pixels in viewport coords
	vec2 ps = 1.0 / VIEWPORT_SIZE;
	
	float depth = DEPTH(0.0);
	float ldepth = DEPTH(vec2(ps.x, 0.0));
	float rdepth = DEPTH(vec2(-ps.x, 0.0));
	float udepth = DEPTH(vec2(0.0, ps.y));
	float ddepth = DEPTH(vec2(0.0, -ps.y));
	float max_diff = max(max(max(
		abs(depth - ldepth),
		abs(depth - rdepth)),
		abs(depth - udepth)),
		abs(depth - ddepth));
	vec3 nml = get_normal(SCREEN_UV);
	vec3 rnml = get_normal(SCREEN_UV + vec2(-ps.x, 0.0));
	vec3 dnml = get_normal(SCREEN_UV + vec2(0.0, -ps.y));
	float max_dot = 1.0 - (min(
		dot(nml, rnml),
		dot(nml, dnml)));
	
    ALBEDO = vec3(clamp(1.0 - max_diff * 0.1, 0.0, 1.0) * clamp(max_dot * 3.0 - 0.64, 0.0, 1.0)) * 0.1 + color;
}
