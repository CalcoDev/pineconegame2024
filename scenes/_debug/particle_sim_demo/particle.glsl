#[compute]
#version 450

struct Sphere {
    vec3 pos;
    float radius;
    vec4 color;
};

layout(set = 0, binding = 0, rgba32f) uniform image2D img;
layout(set = 0, binding = 1) uniform sampler2D skybox_tex;
layout(set = 0, binding = 2, std430) restrict buffer SpheresBuffer {
    int count;
    int _padding[3];
    Sphere data[];
} spheres_buffer;

layout(push_constant, std430) uniform Params {
    mat4 _camera_to_world;
    vec3 _view_params;
    float _padding;
} p;

struct Ray {
    vec3 origin;
    vec3 direction;
};

Ray create_ray(vec3 origin, vec3 direction) {
    Ray ray;
    ray.origin = origin;
    ray.direction = direction;
    return ray;
}

struct HitInfo {
    vec3 point;
    bool hit;
    vec3 norm;
    float dist;
    vec4 sphere_color;
};

const float PI = 3.14159265;

vec2 direction_to_uv(vec3 direction) {
    direction = normalize(direction);
    float u = 0.5 + atan(direction.z, direction.x) / (2.0 * PI);
    float v = 0.5 - asin(direction.y) / PI;
    return vec2(u, v);
}

HitInfo ray_sphere_collision(Ray ray, Sphere sphere) {
    HitInfo info;
    info.hit = false;
    info.dist = 0.0;
    info.point = vec3(0.0);
    info.norm = vec3(0.0);
    info.sphere_color = vec4(0.0, 0.0, 1.0, 1.0);
    vec3 offset = ray.origin - sphere.pos;
    float a = dot(ray.direction, ray.direction);
    float b = 2 * dot(offset, ray.direction);
    float c = dot(offset, offset) - sphere.radius * sphere.radius;
    float delta = b * b - 4 * a * c;
    if(delta >= 0.0) {
        float dist = (-b - sqrt(delta)) / (2.0 * a);
        if(dist >= 0) {
            info.hit = true;
            info.dist = dist;
            info.point = ray.origin + ray.direction * dist;
            info.norm = normalize(info.point - sphere.pos);
            info.sphere_color = sphere.color;
        }
    }
    return info;
}

HitInfo collide_with_all_spheres(Ray ray) {
    HitInfo info;
    info.hit = false;
    info.point = vec3(0.0);
    info.norm = vec3(0.0);
    info.dist = 10000.0;
    for (int i = 0; i < spheres_buffer.count; i++) {
        HitInfo other = ray_sphere_collision(ray, spheres_buffer.data[i]);
        if (other.hit) {
            info = other;
        }
    }

    return info;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 output_img_size = imageSize(img);
    vec2 output_uv = vec2(gl_GlobalInvocationID.xy) / vec2(output_img_size.xy);

    vec2 pixel_target = output_uv * 2.0 - 1.0;
    float output_ar = float(output_img_size.x) / float(output_img_size.y);
    pixel_target.x *= output_ar;

    vec3 view_point_local = vec3(pixel_target, 1.0) * p._view_params;
    vec3 view_point = (p._camera_to_world * vec4(view_point_local, 1.0)).xyz;
    Ray ray;
    ray.origin = (p._camera_to_world * vec4(vec3(0.0), 1.0)).xyz;
    ray.direction = normalize(view_point - ray.origin);

    vec2 skybox_uv = direction_to_uv(ray.direction);
    vec3 skybox_color = texture(skybox_tex, skybox_uv).rgb;

    HitInfo info;
    info.hit = false;
    info.dist = 999.9;
    vec4 col = vec4(0.0, 0.0, 0.0, 1.0);
    int i = 0;
    for (; i < spheres_buffer.count; i++) {
        Sphere s = spheres_buffer.data[i];
        HitInfo other = ray_sphere_collision(ray, s);
        if (other.hit && other.dist < info.dist) {
            info = other;
        }
    }
    if (info.hit) {
        col = info.sphere_color;
    }
    imageStore(img, ivec2(gl_GlobalInvocationID.xy), col);
}

// sample texture
// ivec2 image_size = imageSize(img);
// vec2 uv = vec2(gl_GlobalInvocationID.xy) / vec2(image_size.xy);
// vec4 col = texture(skybox_tex, uv);
// imageStore(img, pixel_pos, col);