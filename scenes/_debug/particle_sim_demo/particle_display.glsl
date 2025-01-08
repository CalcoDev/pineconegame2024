#[compute]
#version 450

struct Particle {
    vec2 position;
    vec2 velocity;
    vec4 color;
};

layout(set = 0, binding = 0, rgba32f) uniform image2D output_tex;

layout(set = 0, binding = 1, std430) restrict buffer ParticleBuffer {
    Particle data[];
} _particles;

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

    vec2 pixel_world_pos = _params.screen_top_left + ivec2(vec2(_params.screen_size) * uv);
    vec3 color = vec3(0.0);
    // float min_dist = float(screen_size.x * screen_size.x + screen_size.y + screen_size.y);
    for (int i = 0; i < _params.particle_count; ++i) {
        vec2 diff = _particles.data[i].position - pixel_world_pos;
        float dist_sqr = diff.x * diff.x + diff.y * diff.y;
        if (dist_sqr < _params.particle_radius * _params.particle_radius) {
            // min_dist = dist_sqr;
            color = _particles.data[i].color.rgb;
            break;
        }
    }

    imageStore(output_tex, pixel_coords, vec4(color, 1.0));
}