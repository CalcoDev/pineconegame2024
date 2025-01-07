#[compute]
#version 450

layout(rgba32f, binding = 0, set = 0) uniform image2D img;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    imageStore(img, ivec2(gl_GlobalInvocationID.xy), vec4(1.0, 0.0, 0.0, 1.0));
}