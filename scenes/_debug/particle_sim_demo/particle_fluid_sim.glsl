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

layout(push_constant, std430) uniform Params {
    int particle_count;
    float delta;
    float gravity;
    float particle_radius;
    // int _padding[1];
} _params;

void handle_colisions(int idx) {
    const float SCALE = 4.0;

    vec2 pos = _particles.data[idx].position;
    if (pos.y - _params.particle_radius < 0 || pos.y + _params.particle_radius > SCALE * 240.0) {
        _particles.data[idx].velocity.y *= -1.0;
        if (pos.y - _params.particle_radius < 0)
            _particles.data[idx].position.y = _params.particle_radius + 0.1;
        else
            _particles.data[idx].position.y = SCALE * 240.0 - _params.particle_radius + 0.1;
        return;
    }
    if (pos.x - _params.particle_radius < 0.0 || pos.x + _params.particle_radius > SCALE * 320.0) {
        _particles.data[idx].velocity.x *= -1.0;
        if (pos.x - _params.particle_radius < 0)
            _particles.data[idx].position.x = _params.particle_radius + 0.1;
        else
            _particles.data[idx].position.x = SCALE * 320.0 - _params.particle_radius + 0.1;
        return;
    }
}

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int idx = int(gl_GlobalInvocationID.x);

    ivec2 pixel_coords = ivec2(_particles.data[idx].position);
    
    _particles.data[idx].velocity += vec2(0.0, 1.0) * _params.gravity * _params.delta;
    _particles.data[idx].position += _particles.data[idx].velocity * _params.delta;
    handle_colisions(idx);
    
    pixel_coords = ivec2(_particles.data[idx].position);
    imageStore(kernel_tex, pixel_coords, vec4(_particles.data[idx].color.rgb, 1.0));
    // imageStore(
    //     kernel_tex, pixel_coords, vec4(
    //         _params.polygon_collider_count / 255.0,
    //         float(_polygon_info.data[1].count) / 255.0,
    //         float(_polygon_info.data[1].offset) / 255.0,
    //         // 1.0, 1.0,
    //         1.0
    //     )
    // );
}