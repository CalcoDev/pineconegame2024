#[compute]
#version 450

// layout(set = 0, binding = 0, rgba8) uniform image2D input_tex;
layout(set = 0, binding = 0) uniform sampler2D input_samp;
layout(set = 0, binding = 1, rgba32f) uniform image2D output_tex;

layout(push_constant) uniform Params {
    int flip;
    int _padding[3];
} _params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID);
    ivec2 img_size = imageSize(output_tex);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / vec2(img_size.xy);
    
    // vec3 kernel_col = imageLoad(output_tex, pixel_coords).rgb;
    vec3 input_col = texture(input_samp, uv).rgb;
    // imageStore(output_tex, pixel_coords, vec4(kernel_col, abs(kernel_col.r - _params.flip)));
    imageStore(output_tex, pixel_coords, vec4(input_col, abs(input_col.r - _params.flip)));
    // imageStore(output_tex, pixel_coords, vec4(uv.xy, 0.0, 1.0));
}