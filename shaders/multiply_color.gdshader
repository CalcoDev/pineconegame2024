shader_type canvas_item;

uniform vec4 multiply_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // Multiply the default color (COLOR) with the uniform color (multiply_color)
    COLOR = texture(TEXTURE, UV) * multiply_color;
}
