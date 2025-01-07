#[compute]
#version 450

layout(rgba32f, binding = 0) uniform image2D img;

// layout(set = 0, binding = 1, std430) restrict buffer TextureDataBuffer {
//     int width;
//     int height;
// } texture_data;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    // texture_out.data[gl_GlobalInvocationID.x] = ;
    imageStore(img, ivec2(gl_GlobalInvocationID.xy), vec4(1.0, 0.0, 0.0, 1.0));
}