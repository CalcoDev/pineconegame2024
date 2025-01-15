#[compute]
#version 450

layout(push_constant, std430) uniform Params {
    int _particle_count;
    float _smoothing_radius;
    // int _padding[1];
    float _target_density;
    float _pressure_multiplier;
    vec4 _pressure_neg_col;
    vec4 _pressure_pos_col;
    vec4 _pressure_right_col;
};

layout(set = 0, binding = 0, std430) restrict buffer PositionBuffer {
    vec2 _position[];
};

layout(set = 0, binding = 1, rgba32f) uniform image2D _density_tex;

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

vec2 calculate_pressure_force(vec2 pos) {
    vec2 pressure = vec2(0, 0);

    const float mass = 1;
    for (int i = 0; i < _particle_count; ++i) {
        // if (i == idx) continue;
        // vec2 pos = _position[idx];
        float dist = length(pos - _position[i]);
        // dist = dist == 0.0 ? vec2(1.0, 1.0);
        vec2 dir = (dist == 0.0 ? vec2(1.0, 1.0) : ((pos - _position[i]) / dist));
        float slope = smoothing_kernel_derivative(_smoothing_radius, dist);
        float density = calculate_density(pos);
        pressure += density_to_pressure(density) * dir * slope * mass / density;
    }

    return pressure;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    float density = calculate_density(vec2(pos));
    float pressure = density_to_pressure(density);
   
    pressure /= 255.0 * 2 * 2;
    const float M = 0.01;
    vec4 col = vec4(pressure, 0.0, 0.0, 1.0);
    if (pressure < 0 - M) {
        col = _pressure_neg_col;
        pressure *= 2.0;
    }
    else if (pressure > 0 + M) {
        col = _pressure_pos_col;
        // pressure = 1.0;
    }
    else {
        col = _pressure_right_col;
        // pressure = 1.0 - pressure;
    }
    imageStore(_density_tex, pos, vec4(col.rgb * min(abs(pressure), 1.0), 1.0));
    // imageStore(_density_tex, pos, vec4(density, 1.0));

    // vec2 pressure_force = calculate_pressure_force(pos);
    // imageStore(_density_tex, pos, vec4(abs(density) / 25500000, 0.0, 0.0, 1.0));
    
    // float density = calculate_density(vec2(320, 240) * 2.0);
    // imageStore(_density_tex, pos, vec4(density / 255, 0.0, 0.0, 1.0));
    // imageStore(_density_tex, pos, vec4(abs(pressure / 255), 0.0, 0.0, 1.0));
}