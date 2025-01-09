#[compute]
#version 450

struct Particle {
    vec2 position;
    vec2 velocity;
    vec4 color;
};

layout(set = 0, binding = 0, rgba32f) uniform image2D output_tex;

layout(set = 0, binding = 1, std430) restrict buffer ParticleBuffer {
    Particle data[];
} _particles;

layout(push_constant) uniform Params {
    ivec2 screen_top_left;
    ivec2 screen_size;
    vec3 particle_color;
    float particle_radius;
    int particle_count;
    int _padding[3];
} _params;


#include "particle_shared.glsl"

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID);
    ivec2 img_size = imageSize(output_tex);
    vec2 uv = vec2(gl_GlobalInvocationID.xy) / vec2(img_size.xy);

    vec2 pixel_world_pos = _params.screen_top_left + ivec2(vec2(_params.screen_size) * uv);
    vec3 color = vec3(0.0, 0.0, 0.0);
    
    // for (int i = 0; i < _params.particle_count; ++i) {
    //     vec2 diff = _particles.data[i].position - pixel_world_pos;
    //     float dist_sqr = diff.x * diff.x + diff.y * diff.y;
    //     if (dist_sqr < _params.particle_radius * _params.particle_radius) {
    //         color = _particles.data[i].color.rgb;
    //         break;
    //     }
    // }

    ivec2 grid_cell_og = get_grid_cell(pixel_world_pos);

    bool found = false;
    for (int yoff = -1; yoff < 2; ++yoff) {
        for (int xoff = -1; xoff < 2; ++xoff) {
            int bucket_index = hash_grid_cell(grid_cell_og + ivec2(xoff, yoff));
            int current_index = _bucket_indices.data[bucket_index];
            while (current_index != -1) {
                int current = _hashtable.data[current_index].particle_index;
                vec2 diff = _particles.data[current].position - pixel_world_pos;
                float dist_sqr = diff.x * diff.x + diff.y * diff.y;
                if (dist_sqr < _params.particle_radius * _params.particle_radius) {
                    color = _particles.data[current].color.rgb;
                    found = true;
                    break;
                }
                current_index = _hashtable.data[current_index].next;
            } 
            if (found) {
                break;
            }
        }
        if (found) {
            break;
        }
    }


    // ivec2 grid_cell_og = get_grid_cell(pixel_world_pos);
    // bool found = false;
    // for (int yoff = -1; yoff < 2; ++yoff) {
    //     for (int xoff = -1; xoff < 2; ++xoff) {
    //         ivec2 grid_cell = grid_cell_og + ivec2(xoff, yoff);
    //         color = vec3(vec2(grid_cell.xy) / 20.0, 0.0);
    //         int grid_cell_hash = hash_grid_cell(grid_cell);
    //         int entry_index = grid_cell_hash * MAX_CHAIN_LENGTH;

    //         for (int i = 0; i < MAX_CHAIN_LENGTH; ++i) {
    //             int current_index = entry_index + i;
    //             int current = _hashtable.data[current_index].particle_index;
    //             if (current == -1) {
    //                 break;
    //             }
    //             vec2 diff = _particles.data[current].position - pixel_world_pos;
    //             float dist_sqr = diff.x * diff.x + diff.y * diff.y;
    //             if (dist_sqr < _params.particle_radius * _params.particle_radius) {
    //                 color = _particles.data[current].color.rgb;
    //                 found = true;
    //                 break;
    //             }
    //         }


    imageStore(output_tex, pixel_coords, vec4(color, 1.0));
}