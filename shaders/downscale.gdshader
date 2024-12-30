shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 100.0); // Size of the snapping grid in screen pixels

void fragment() {
    // Convert pixel size to UV space (based on screen resolution)
    vec2 grid_size_uv = pixel_size * SCREEN_PIXEL_SIZE;

    // Snap the screen UV to the nearest grid point
    vec2 snapped_screen_uv = floor(SCREEN_UV / grid_size_uv) * grid_size_uv;

    // Map the snapped screen UV back to texture UV coordinates
    vec2 snapped_texture_uv = snapped_screen_uv * vec2(textureSize(TEXTURE, 0));

    // Sample the texture at the snapped texture UV
    COLOR = texture(TEXTURE, snapped_texture_uv);
}

//void aaaaa() {
	    //// Get the size of the viewport in pixels
    //vec2 screen_size = vec2(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y);
//
    //// Calculate the block size in screen space
    //vec2 block_size = vec2(float(downscale_amount)) / screen_size;
//
    //// Snap the screen UV to the nearest multiple of block size
    //vec2 snapped_screen_uv = floor(SCREEN_UV / block_size) * block_size;
//
    //// Convert snapped screen UV back to texture UV
    //vec2 snapped_uv = snapped_screen_uv * screen_size / vec2(textureSize(TEXTURE, 0));
//
    //// Sample the texture at the snapped UV
    //COLOR = texture(TEXTURE, snapped_uv);
//}