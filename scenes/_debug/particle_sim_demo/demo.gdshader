shader_type canvas_item;

void fragment() {
	if (texture(TEXTURE, UV).r == 0.) {
		discard;
	}
}
