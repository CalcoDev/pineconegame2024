shader_type canvas_item;

uniform vec4 solid_color: source_color;

uniform bool thick = false;
uniform int width: hint_range(0, 5, 1);
uniform vec4 outline_color: source_color;

const vec4 background = vec4(1., 1., 1., 0.);

float dist(vec4 c1, vec4 c2) {
	return (c1 == c2) ? 0.0 : abs(c1.r - c2.r) + abs(c1.g - c2.g) + abs(c1.b - c2.b);
}

bool similar(vec4 c1, vec4 c2, vec4 input) {
	return (c1 == c2 || (dist(c1, c2) <= dist(input, c2) && dist(c1, c2) <= dist(input, c1)));
}

bool different(vec4 c1, vec4 c2, vec4 input) {
	return !similar(c1, c2, input);
}

vec4 scale2x(sampler2D tex, vec2 uv, vec2 pixel_size) {
	vec4 input = texture(tex, uv);

	vec4 cD = texture(tex, uv + pixel_size * vec2(-1., .0));
	cD.a = 1.0;
	vec4 cF = texture(tex, uv + pixel_size * vec2(1., .0));
	cF.a = 1.0;
	vec4 cH = texture(tex, uv + pixel_size * vec2(.0, 1.));
	cH.a = 1.0;
	vec4 cB = texture(tex, uv + pixel_size * vec2(.0, -1.));
	cB.a = 1.0;
	vec4 cA = texture(tex, uv + pixel_size * vec2(-1., -1.));
	cA.a = 1.0;
	vec4 cI = texture(tex, uv + pixel_size * vec2(1., 1.));
	cI.a = 1.0;
	vec4 cG = texture(tex, uv + pixel_size * vec2(-1., 1.));
	cG.a = 1.0;
	vec4 cC = texture(tex, uv + pixel_size * vec2(1., -1.));
	cC.a = 1.0;

	if (different(cD,cF, input)
     && different(cH,cB, input)
     && ((similar(input, cD, input) || similar(input, cH, input) || similar(input, cF, input) || similar(input, cB, input) ||
         ((different(cA, cI, input) || similar(input, cG, input) || similar(input, cC, input)) &&
          (different(cG, cC, input) || similar(input, cA, input) || similar(input, cI, input))))))
    {
		vec2 unit = uv - (floor(uv / pixel_size) * pixel_size);
		vec2 pixel_half_size = pixel_size / 2.0;
		if (unit.x < pixel_half_size.x && unit.y < pixel_half_size.y) {
			return ((similar(cB, cD, input) && ((different(input, cA, input) || different(cB, background, input)) && (different(input, cA, input) || different(input, cI, input) || different(cB, cC, input) || different(cD, cG, input)))) ? cB : input);
		}

		if (unit.x >= pixel_half_size.x && unit.y < pixel_half_size.y) {
			return ((similar(cF, cB, input) && ((different(input, cC, input) || different(cF, background, input)) && (different(input, cC, input) || different(input, cG, input) || different(cF, cI, input) || different(cB, cA, input)))) ? cF : input);
		}

		if (unit.x < pixel_half_size.x && unit.y >= pixel_half_size.y) {
			return ((similar(cD, cH, input) && ((different(input, cG, input) || different(cD, background, input)) && (different(input, cG, input) || different(input, cC, input) || different(cD, cA, input) || different(cH, cI, input)))) ? cD : input);
		}

        return ((similar(cH, cF, input) && ((different(input, cI, input) || different(cH, background, input)) && (different(input, cI, input) || different(input, cA, input) || different(cH, cG, input) || different(cF, cC, input)))) ? cH : input);
    }

	return input;
}

void fragment() {
	float pixel_size_x = 1.0/float(textureSize(TEXTURE,0).x);
	float pixel_size_y = 1.0/float(textureSize(TEXTURE,0).y);
	vec2 pixel_size = vec2(pixel_size_x, pixel_size_y);
	if (texture(TEXTURE, UV).a == 0.) {
		for(int x = -width; x <= width; x++) {
			for(int y = -width; y <= width; y++) {
				if (!thick && abs(x) == abs(y)) {
					continue;
				}
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
	//COLOR = scale2x(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
}