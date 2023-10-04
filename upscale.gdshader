shader_type canvas_item;

void fragment() {
	vec2 texSize = vec2(textureSize(TEXTURE, 0));
	vec2 boxSize = clamp(fwidth(UV) * texSize, 1e-5, 1.0);
	vec2 tx = UV * texSize - 0.5 * boxSize;
	vec2 txOffset = smoothstep(1.0 - boxSize, vec2(1.0), fract(tx));
	vec2 uv = (floor(tx) + 0.5 + txOffset) * TEXTURE_PIXEL_SIZE;
	COLOR = texture(TEXTURE, uv);
}
