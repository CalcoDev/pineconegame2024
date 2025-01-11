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

layout(set = 0, binding = 1, std430) restrict buffer DensityBuffer {
    float _density[];
};

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

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int index = int(gl_GlobalInvocationID.x);
    _density[index] = calculate_density(_position[index]);
}