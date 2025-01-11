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

float smoothing_kernel(float radius, float dist) {
    float volume = PI * pow(radius, 8) / 4;
    float value = max(0, radius * radius - dist * dist);
    return value * value * value / volume;
}

float smoothing_kernel_derivative(float radius, float dist) {
    if (dist >= radius) return 0;
    float f = radius * radius - dist * dist;
    float scale = -24 / (PI * pow(radius, 8));
    return scale * dist * f * f;
}

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

    return density;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    float density = calculate_density(vec2(pos));
    float pressure = density_to_pressure(density);
   
    const float M = 0.0001;
    vec4 col = vec4(pressure, 0.0, 0.0, 1.0);
    if (pressure < 0 - M) col = _pressure_neg_col;
    else if (pressure > 0 + M) col = _pressure_pos_col;
    else col = _pressure_right_col;
    
    // float density = calculate_density(vec2(320, 240) * 2.0);
    // imageStore(_density_tex, pos, vec4(pressure, 0.0, 0.0, 1.0));
    imageStore(_density_tex, pos, vec4(col.rgb, 1.0));
}