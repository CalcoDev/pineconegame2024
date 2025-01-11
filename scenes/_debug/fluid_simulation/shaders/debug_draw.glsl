#[compute]
#version 450

layout(push_constant) uniform Params {
    float _particle_radius;
    // vec3 _particle_color;
    float _padding[3];
};

layout(set = 0, binding = 0, rgba32f) uniform image2D _kernel_tex;
layout(set = 0, binding = 1, rgba32f) uniform image2D _output_tex;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID);
    ivec2 img_size = imageSize(_output_tex);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / vec2(img_size.xy);

    int hr = int(_particle_radius + 1);
    for (int y = -hr; y < hr; ++y) {
        for (int x = -hr; x < hr; ++x) {
            ivec2 pos = pixel_coords + ivec2(x, y);
            if (pos.x < 0 || pos.x > img_size.x || pos.y < 0 || pos.y > img_size.y) {
                continue;
            }
            vec2 d = vec2(pos - pixel_coords);
            if (abs(dot(d, d)) < _particle_radius * _particle_radius) {
                vec3 kernel_col = imageLoad(_kernel_tex, pos).rgb;
                if (length(kernel_col) > 0.0) {
                    // imageStore(_output_tex, pixel_coords, vec4(kernel_col, 1.0));
                    // imageStore(_output_tex, pixel_coords, vec4(_particle_color, 1.0));
                    imageStore(_output_tex, pixel_coords, vec4(vec4(_padding[0], _padding[1], _padding[2], 1.0)));
                }
            }
        }
    }
    // imageStore(_output_tex, pixel_coords, vec4(uv.xy, 0.0, 1.0));
}