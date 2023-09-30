shader_type spatial;
render_mode depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

uniform sampler2D albedo_texture : hint_default_white, filter_nearest;

uniform float zNear = 2;
uniform float zFar = 10.0;

uniform vec3 color : source_color    = vec3(0.8, 0.8, 0.8);
uniform vec3 emission : source_color = vec3(0.0, 0.0, 0.0);

const float outline_offset = 1.0;

#define DEPTH(offset) get_depth(INV_PROJECTION_MATRIX, SCREEN_UV + offset)

float get_depth(mat4 matrix, vec2 uv) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	vec4 upos = matrix * vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_position = upos.xyz / upos.w;
	return (zFar * zNear) / (zFar + (pixel_position.z * (zNear - zFar)));
}

float get_depth_unscaled(mat4 matrix, vec2 uv) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	vec4 upos = matrix * vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_position = upos.xyz / upos.w;
	return (zFar * zNear) / (zFar + (pixel_position.z * (zNear - zFar)));
}


vec3 get_normal(vec2 uv) {
	return texture(normal_texture, uv).xyz * 2.0 - 1.0;
}

vec3 overlay(vec3 base, vec3 blend) {
    return mix(2.0 * base * blend, 
		1.0 - 2.0 * (1.0 - base) * (1.0 - blend), clamp(base, 0.0, 1.0));
}

float textureCavity(vec2 uv, vec2 screen_pixel_size) {
	vec4 normal = texture(normal_texture, uv);
	float x_off = texture(normal_texture, uv - vec2(screen_pixel_size.x, 0)).x;
	float y_off = texture(normal_texture, uv + vec2(0, screen_pixel_size.y)).y;
	return (normal.x - x_off) + (normal.y - y_off) + 0.5;
}

void fragment() {
	// size of pixels in viewport coords
	vec2 ps = 1.0 / VIEWPORT_SIZE * outline_offset;
	
	float depth = DEPTH(0.0);
	float ddiff = abs(DEPTH(vec2(ps.x, 0.0)));
	ddiff = max(ddiff, abs(DEPTH(vec2(-ps.x, 0.0))));
	ddiff = max(ddiff, abs(DEPTH(vec2(ps.y, 0.0))));
	ddiff = max(ddiff, abs(DEPTH(vec2(-ps.y, 0.0))));
	
	float res = textureCavity(SCREEN_UV, ps);
	float s = sign(res);
	float cavityFac = s * pow(clamp(res - 0.5, -0.5, 0.5) * 0.5, 2.0);
	float depthFac = clamp(0.5 - ddiff, 0.0, 0.5) * 2.0;
	ALBEDO = COLOR.rgb * color * texture(albedo_texture, UV).rgb + vec3(cavityFac * depthFac);
	EMISSION = emission * COLOR.rgb;
}

void light() {
	float light_fac = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	light_fac = round(light_fac * 4.0) * 0.25;
    DIFFUSE_LIGHT += light_fac * LIGHT_COLOR * ALBEDO;
}
