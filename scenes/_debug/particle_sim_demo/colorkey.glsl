#[compute]
#version 450

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
    
    vec3 kernel_col = imageLoad(output_tex, pixel_coords).rgb;
    imageStore(output_tex, pixel_coords, vec4(kernel_col, abs(kernel_col.r - _params.flip)));
}