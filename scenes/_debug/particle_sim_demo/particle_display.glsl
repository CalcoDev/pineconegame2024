#[compute]
#version 450

struct Particle {
    vec2 position;
    vec2 velocity;
};

layout(set = 0, binding = 0, rgba32f) uniform image2D output_tex;

layout(set = 0, binding = 1, std430) restrict buffer ParticleBuffer {
    int count;
    int _padding[1];
    Particle data[];
} _particles;

layout(push_constant) uniform Params {
    ivec2 screen_top_left;
    ivec2 screen_size;
    vec3 particle_color;
    float particle_radius;
} _params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID);
    ivec2 img_size = imageSize(output_tex);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / vec2(img_size.xy);

    vec2 pixel_world_pos = _params.screen_top_left + ivec2(vec2(_params.screen_size) * uv);
    vec3 color = vec3(0.0);
    // float min_dist = float(screen_size.x * screen_size.x + screen_size.y + screen_size.y);
    for (int i = 0; i < _particles.count; ++i) {
        vec2 diff = _particles.data[i].position - pixel_world_pos;
        float dist_sqr = diff.x * diff.x + diff.y * diff.y;
        if (dist_sqr < _params.particle_radius * _params.particle_radius) {
            // min_dist = dist_sqr;
            color = _params.particle_color;
        }
    }

    // vec3 color = vec3(uv, 0.0);
    // vec3 color = _params.particle_color;
    // vec3 color = vec3(pixel_world_pos / vec2(img_size.xy), 0.0);
    imageStore(output_tex, pixel_coords, vec4(color, 1.0));
}