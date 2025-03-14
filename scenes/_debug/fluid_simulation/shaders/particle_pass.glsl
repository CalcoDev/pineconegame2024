#[compute]
#version 450

layout(push_constant, std430) uniform Params {
    int _particle_count;
    float _particle_radius;
    float _gravity;
    float _delta;
    
    float _smoothing_radius;
    float _target_density;
    float _pressure_multiplier;

    int _lookup_table_size;
    // float _padding[1];
};

layout(set = 0, binding = 0, std430) restrict buffer PositionBuffer {
    vec2 _position[];
};

layout(set = 0, binding = 1, std430) restrict buffer VelocityBuffer {
    vec2 _velocity[];
};

layout(set = 0, binding = 2, std430) restrict buffer DensityBuffer {
    float _density[];
};

struct SortEntry {
    int particle_index;
    uint hash;
};

layout(set = 0, binding = 3, std430) restrict buffer SpatialEntriesBuffer {
    SortEntry _lookup_entries[];
};

layout(set = 0, binding = 4, std430) restrict buffer OffsetBuffer {
    int _lookup_offsets[];
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

const float PI = 3.14159265359;

#include "_shared_density_data.glsl"

float density_to_pressure(float density) {
    float error = density - _target_density;
    float pressure = error * _pressure_multiplier;
    return pressure;
}

float calculate_density(vec2 pos) {
    float density = 0;
    const float mass = 1;

    for (int i = 0; i < _particle_count; ++i) {
        float dist = length(pos - _position[i]);
        float influence = smoothing_kernel(_smoothing_radius, dist);
        density += mass * influence;
    }

    return density * 3.0;
}

vec2 calculate_pressure_force(int idx) {
    vec2 pressure = vec2(0, 0);
    const float mass = 1;

    vec2 pos = _position[idx];
    for (int ox = -1; ox < 2; ++ox) {
        for (int oy = -1; oy < 2; ++oy) {
            int xx = int(pos.x / _smoothing_radius) + ox;
            int yy = int(pos.y / _smoothing_radius) + oy;
            uint a = uint(xx * 15823);
            uint b = uint(yy * 9737333);
            uint hash = a + b;
            uint offset_key = hash % _lookup_table_size;

            int start_index = _lookup_offsets[offset_key];
            int other_index = start_index;
            while (other_index < _particle_count && (_lookup_entries[start_index].hash % _lookup_table_size) == (_lookup_entries[other_index].hash % _lookup_table_size)) {
                int other = _lookup_entries[other_index].particle_index;
                other_index += 1;
                if (other == idx) {
                    continue;
                }
                
                vec2 pos = _position[idx];
                float dist = length(pos - _position[other]);
                vec2 dir = (dist == 0.0 ? vec2(1.0, 1.0) : ((pos - _position[other]) / dist));
                float slope = smoothing_kernel_derivative(_smoothing_radius, dist);
                float p = density_to_pressure(_density[other]);
                float shared_pressure = (p + density_to_pressure(_density[idx])) / 2.0;
                pressure += shared_pressure * dir * slope * mass / _density[other];
            }
        }
    }

    return pressure;
}

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= _particle_count)
        return;

    ivec2 pixel_coords = ivec2(_position[idx]);
    
    // _velocity[idx] += -((calculate_pressure_force(idx) / _density[idx]) * _delta) * 20.0;
    _velocity[idx] = -((calculate_pressure_force(idx) / _density[idx]) * _delta) * 200.0;

    _velocity[idx] += vec2(0.0, 1.0) * _gravity * _delta;
    _position[idx] += _velocity[idx] * _delta;
    handle_colisions(idx);
    
    pixel_coords = ivec2(_position[idx]);
    
    int xx = int(pixel_coords.x / _smoothing_radius);
    int yy = int(pixel_coords.y / _smoothing_radius);
    uint a = uint(xx * 15823);
    uint b = uint(yy * 9737333);
    uint hash = a + b;
    uint key = hash % _lookup_table_size;

    imageStore(_kernel_tex, pixel_coords, vec4(_lookup_entries[_lookup_offsets[key]].particle_index / float(_particle_count), 1.0, 0.0, 1.0));
    // imageStore(_kernel_tex, pixel_coords, vec4(key / 255.0, 1.0, 0.0, 1.0));
    // imageStore(_kernel_tex, pixel_coords, vec4(_lookup_entries[_lookup_offsets[key]].particle_index / float(_particle_count), 1.0, 0.0, 1.0));

    // imageStore(_kernel_tex, pixel_coords, vec4(_density[idx] , 0.0, 0.0, 1.0));
    // imageStore(_kernel_tex, pixel_coords, vec4(_lookup_entries[_lookup_offsets[idx]].particle_index / 255.0, 1.0, 0.0, 1.0));
    // imageStore(_kernel_tex, pixel_coords, vec4(_lookup_offsets[idx] / 255.0, 1.0, 0.0, 1.0));
}