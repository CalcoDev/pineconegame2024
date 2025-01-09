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

// Collision Buffers
layout(set = 0, binding = 1, std430) restrict buffer CircleColliderPositionsBuffer {
    vec2 data[];
} _circle_col_pos;
layout(set = 0, binding = 2, std430) restrict buffer CircleColliderRadiusBuffer {
    float data[];
} _circle_col_radius;

struct OBBColliderData {
    vec2 position;
    vec2 half_extends;
};
layout(set = 0, binding = 3, std430) restrict buffer OBBColliderDataBuffer {
    OBBColliderData data[];
} _obb_col_data;
layout(set = 0, binding = 4, std430) restrict buffer OBBColliderRotationBuffer {
    float data[];
} _obb_col_rot;

layout(set = 1, binding = 0, rgba32f) uniform image2D kernel_tex;

layout(push_constant, std430) uniform Params {
    float delta;
    float gravity;
    float particle_radius;
    int circle_collider_count;
    int obb_collider_count;
    int particle_count;
    int padding[2];
} _params;

vec2 rotate_vec(vec2 v, float rot) {
    float c = cos(rot);
    float s = sin(rot);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void handle_colisions(int idx) {
    vec2 pos = _particles.data[idx].position;
    if (pos.y < 0 || pos.y > 240.0) {
        _particles.data[idx].velocity.y *= -1.0;
        return;
    }
    if (pos.x < 0.0 || pos.x > 320.0) {
        _particles.data[idx].velocity.x *= -1.0;
        return;
    }

    for (int i = 0; i < _params.circle_collider_count; ++i) {
        vec2 dist =  pos - _circle_col_pos.data[i];
        float rad = _circle_col_radius.data[i] + _params.particle_radius;
        if (dot(dist, dist) < rad * rad) {
            vec2 normal = normalize(dist);
            vec2 vel = _particles.data[idx].velocity;
            _particles.data[idx].velocity = vel - 2.0 * dot(vel, normal) * normal;
            _particles.data[idx].position = _circle_col_pos.data[i] + normal * rad;
            return;
        }
    }

    for (int i = 0; i < _params.obb_collider_count; ++i) {
        vec2 obb_pos = _obb_col_data.data[i].position;
        vec2 obb_half_extents = _obb_col_data.data[i].half_extends;
        vec2 local_position = rotate_vec(pos - obb_pos, -_obb_col_rot.data[i]);
        vec2 closest_point = clamp(local_position, -obb_half_extents, obb_half_extents);

        vec2 closest_point_world = rotate_vec(closest_point, _obb_col_rot.data[i]) + obb_pos;

        vec2 dist = pos - closest_point_world;
        if (dot(dist, dist) < _params.particle_radius * _params.particle_radius) {
            vec2 normal = normalize(dist);
            vec2 vel = _particles.data[idx].velocity;
            _particles.data[idx].velocity = vel - 2.0 * dot(vel, normal) * normal;
            _particles.data[idx].position = closest_point_world + normal * _params.particle_radius;
            return;
        }
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
    imageStore(kernel_tex, pixel_coords, vec4(1.0, 0.0, 0.0, 1.0));
}