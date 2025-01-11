#[compute]
#version 450

layout(push_constant, std430) uniform Params {
    int _particle_count;
    float _smoothing_radius;
    int _padding[2];
};

layout(set = 0, binding = 0, std430) restrict buffer PositionBuffer {
    vec2 _position[];
};

layout(set = 0, binding = 1, rgba32f) uniform image2D _density_tex;

const float PI = 3.14159265359;

float smoothing_kernel(float radius, float dist) {
    float volume = PI * pow(radius, 8) / 4;
    float value = max(0, radius * radius - dist * dist);
    return value * value * value / volume;
}

float calculate_density(vec2 pos) {
    float density = 0;
    const float mass = 1;

    for (int i = 0; i < _particle_count; ++i) {
        float dist = length(pos - _position[i]);
        float influence = smoothing_kernel(_smoothing_radius, dist);
        density += mass * influence;
    }

    return density;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    float density = calculate_density(vec2(pos));
    // float density = calculate_density(vec2(320, 240) * 2.0);
    imageStore(_density_tex, pos, vec4(density * 100.0, 0.0, 0.0, 1.0));
}