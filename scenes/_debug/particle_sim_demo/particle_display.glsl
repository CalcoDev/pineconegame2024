#[compute]
#version 450

struct Particle {
    vec2 position;
    vec2 velocity;
    vec4 color;
};

layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {
    Particle data[];
} _particles;

layout(set = 1, binding = 0, rgba32f) uniform image2D kernel_tex;
layout(set = 1, binding = 1, rgba32f) uniform image2D output_tex;

layout(push_constant) uniform Params {
    ivec2 screen_top_left;
    ivec2 screen_size;
    vec3 particle_color;
    float particle_radius;
    int particle_count;
    int _padding[3];
} _params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID);
    ivec2 img_size = imageSize(output_tex);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / vec2(img_size.xy);

    // vec2 pixel_world_pos = _params.screen_top_left + ivec2(vec2(_params.screen_size) * uv);
    // vec3 color = vec3(0.0, 0.0, 0.0);

    int hr = int(_params.particle_radius);
    for (int y = -hr; y < hr; ++y) {
        for (int x = -hr; x < hr; ++x) {
            ivec2 pos = pixel_coords + ivec2(x, y);
            if (pos.x < 0 || pos.x > img_size.x || pos.y < 0 || pos.y > img_size.y) {
                continue;
            }
            vec2 d = vec2(pos - pixel_coords);
            if (abs(dot(d, d)) < _params.particle_radius * _params.particle_radius) {
                vec3 kernel_col = imageLoad(kernel_tex, pos).rgb;
                if (kernel_col.r > 0.0) {
                    imageStore(output_tex, pixel_coords, vec4(kernel_col, 1.0));
                }
            }
        }
    }
}