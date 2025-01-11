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

// for now colliding against a single polygno, which is bad
layout(set = 0, binding = 5, std430) restrict buffer PolygonVerticesBuffer {
    vec2 data[];
} _polygon_vertices;

// for now colliding against a single polygno, which is bad
struct PolygonVertexInfoBuffer {
    int count;
    int offset;
};

layout(set = 0, binding = 6, std430) restrict buffer PolygonColliderBuffer {
    PolygonVertexInfoBuffer data[];
} _polygon_info;

layout(set = 1, binding = 0, rgba32f) uniform image2D kernel_tex;

layout(push_constant, std430) uniform Params {
    float delta;
    float gravity;
    float particle_radius;
    int circle_collider_count;
    int obb_collider_count;
    int polygon_collider_count;
    int particle_count;
    int _padding[1];
} _params;

vec2 rotate_vec(vec2 v, float rot) {
    float c = cos(rot);
    float s = sin(rot);
    return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

bool circle_line(vec2 pos, float radius, vec2 start, vec2 end) {
    vec2 d = end - start;
    vec2 f = start - pos;
    float a = dot(d, d);
    float b = 2.0 * dot(f, d);
    float c = dot(f, f) - radius * radius;
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
        return false;
    }
    discriminant = sqrt(discriminant);
    float t1 = (-b - discriminant) / (2.0 * a);
    float t2 = (-b + discriminant) / (2.0 * a);
    if ((t1 >= 0.0 && t1 <= 1.0) || (t2 >= 0.0 && t2 <= 1.0)) {
        return true;
    }
    return false;
}

float point_line_distance(vec2 point, vec2 start, vec2 end) {
    float dist;
    vec2 lineVector = end - start;
    vec2 pointVector = point - start;
    float lineLengthSq = dot(lineVector, lineVector);
    float t = dot(pointVector, lineVector) / lineLengthSq;
    t = clamp(t, 0.0, 1.0);
    vec2 closestPoint = start + t * lineVector;
    dist = length(point - closestPoint);
    return dist;
}

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

    for (int poly_idx = 0; poly_idx < _params.polygon_collider_count; ++poly_idx) {
        int count = _polygon_info.data[poly_idx].count;
        int offset = _polygon_info.data[poly_idx].offset;

        vec2 p = _particles.data[idx].position;
        bool c = false;

        float min_dist = 1e9;
        vec2 min_s;
        vec2 min_e;

        float inside_edge = 0.0;

        for (int i = 0; i < count; ++i) {
            vec2 s = _polygon_vertices.data[offset + i];
            vec2 e = _polygon_vertices.data[offset + ((i + 1) % count)];

            float dist = point_line_distance(p, s, e);
            bool a = dist < _params.particle_radius;
            if (dist < min_dist) {
                min_dist = dist * float(!a);
                min_s = s;
                min_e = e;
            }
            if (a) {
                c = true;
                inside_edge = dist;
                break;
            }

            if (
                ((s.y > p.y && e.y < p.y) || (s.y < p.y && e.y > p.y))
                && ( p.x < (e.x - s.x) * (p.y - s.y) / (e.y - s.y) + s.x )
            ) {
                c = !c;
            }
        }

        if (c) {
            vec2 edge = min_e - min_s;
            
            vec2 perp_clock = normalize(vec2(-edge.y, edge.x));
            vec2 perp_counter = normalize(vec2(edge.y, -edge.x));
            
            vec2 perp;
            bool c = false;
            vec2 p = pos + perp_clock * (min_dist + _params.particle_radius);
            for (int i = 0; i < count; ++i) {
                vec2 s = _polygon_vertices.data[offset + i];
                vec2 e = _polygon_vertices.data[offset + ((i + 1) % count)];
                if (
                    ((s.y > p.y && e.y < p.y) || (s.y < p.y && e.y > p.y))
                    && ( p.x < (e.x - s.x) * (p.y - s.y) / (e.y - s.y) + s.x )
                ) {
                    c = !c;
                }
            }
            if (c) {
                perp = perp_counter;
            } else {
                perp = perp_clock;
            }

            _particles.data[idx].position = pos + (perp * (min_dist + (_params.particle_radius - inside_edge)));
            _particles.data[idx].color = vec4(1.0, 0.0, 0.0, 1.0);

            vec2 particle_to_start = _particles.data[idx].position - min_s;
            float t = clamp(dot(particle_to_start, edge) / dot(edge, edge), 0.0, 1.0);
            vec2 closest_point = min_s + t * edge;
            vec2 normal = normalize(_particles.data[idx].position - closest_point);
            vec2 velocity = _particles.data[idx].velocity;
            vec2 reflected_velocity = velocity - 2.0 * dot(velocity, normal) * normal;
            _particles.data[idx].velocity = reflected_velocity;

            return;
        }
    }
                    
    _particles.data[idx].color = vec4(0.0, 1.0, 1.0, 1.0);
}

bool circle_circle(vec2 pos, float radius, vec2 cpos, float cradius) {
    vec2 dist = pos - cpos;
    float rad = radius + cradius;
    return dot(dist, dist) < rad * rad;
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