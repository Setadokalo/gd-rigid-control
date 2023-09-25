shader_type canvas_item;

void fragment() {
	COLOR = texture(TEXTURE, UV);
//	COLOR.rgb = trunc(COLOR.rgb * 50.0) * 0.02;
}
