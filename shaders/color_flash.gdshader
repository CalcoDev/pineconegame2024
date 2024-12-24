shader_type canvas_item;

uniform vec4 solid_color: source_color;

uniform int width: hint_range(0, 5, 1);
uniform vec4 outline_color: source_color;

void fragment() {
	float pixel_size_x = 1.0/float(textureSize(TEXTURE,0).x);
	float pixel_size_y = 1.0/float(textureSize(TEXTURE,0).y);
	vec2 pixel_size = vec2(pixel_size_x, pixel_size_y);
	if (texture(TEXTURE, UV).a == 0.) { 
		for(int x = -width; x <= width; x++) {
			for(int y = -width; y <= width; y++) {
				vec2 pixel_offset = vec2(float(x),float(y));
				if( texture(TEXTURE, UV+(pixel_offset*pixel_size)).a > 0.) {
					vec4 resulting_color = outline_color;
					COLOR = resulting_color;
				}
			}
		}
	} else {
		vec4 texture_color = texture(TEXTURE, UV);
    	COLOR = vec4(mix(texture_color.rgb, solid_color.rgb, solid_color.a), texture_color.a);	
	}
}