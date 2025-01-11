#[compute]
#version 450

layout(push_constant, std430) uniform Params {
    int _particle_count;
    float _particle_radius;
    float _gravity;
    float _delta;
};

layout(set = 0, binding = 0, std430) restrict buffer PositionBuffer {
    vec2 _position[];
};

layout(set = 0, binding = 1, std430) restrict buffer VelocityBuffer {
    vec2 _velocity[];
};

layout(set = 1, binding = 0, rgba32f) uniform image2D _kernel_tex;

void handle_colisions(int idx) {
    const float SCALE = 4.0;

    vec2 pos = _position[idx];
    if (pos.y - _particle_radius < 0 || pos.y + _particle_radius > SCALE * 240.0) {
        _velocity[idx].y *= -1.0;
        if (pos.y - _particle_radius < 0)
            _position[idx].y = _particle_radius + 0.1;
        else
            _position[idx].y = SCALE * 240.0 - _particle_radius + 0.1;
        return;
    }
    if (pos.x - _particle_radius < 0.0 || pos.x + _particle_radius > SCALE * 320.0) {
        _velocity[idx].x *= -1.0;
        if (pos.x - _particle_radius < 0)
            _position[idx].x = _particle_radius + 0.1;
        else
            _position[idx].x = SCALE * 320.0 - _particle_radius + 0.1;
        return;
    }
}

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= _particle_count)
        return;

    ivec2 pixel_coords = ivec2(_position[idx]);
    
    _velocity[idx] += vec2(0.0, 1.0) * _gravity * _delta;
    _position[idx]+= _velocity[idx] * _delta;
    handle_colisions(idx);
    
    pixel_coords = ivec2(_position[idx]);
    imageStore(_kernel_tex, pixel_coords, vec4(1.0, 0.0, 0.0, 1.0));
}