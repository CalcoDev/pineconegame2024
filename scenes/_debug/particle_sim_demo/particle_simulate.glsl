#[compute]
#version 450

struct Particle {
    vec2 position;
    vec2 velocity;
};

layout(set = 0, binding = 0, std430) restrict buffer ParticleBuffer {
    int count;
    int _padding[1];
    Particle data[];
} _particles;

layout(push_constant, std430) uniform Params {
    float delta;
    float gravity;
    float _padding[2];
} _params;

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int idx = int(gl_GlobalInvocationID.x);
    _particles.data[idx].velocity += vec2(0.0, 1.0) * _params.gravity * _params.delta;
    _particles.data[idx].position += _particles.data[idx].velocity * _params.delta;

    vec2 pos = _particles.data[idx].position;
    if (pos.y < 0 || pos.y > 240.0) {
        _particles.data[idx].velocity.y *= -1.0;
    }
    if (pos.x < 0.0 || pos.x > 320.0) {
        _particles.data[idx].velocity.x *= -1.0;
    }
}