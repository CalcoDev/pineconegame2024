#[compute]
#version 450

layout(rgba32f, binding = 0, set = 0) uniform image2D img;

layout(push_constant, std430) uniform Params {
    mat4 _camera_to_world;
    mat4 _camera_inverse_proj;
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

Ray create_camera_ray(vec2 uv) {
    // Transform the camera origin to world space
    vec3 origin = (p._camera_to_world * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

    // Invert the perspective projection of the view-space position
    vec3 direction = (p._camera_inverse_proj * vec4(uv, 0.0, 1.0)).xyz;
    // Transform the direction from camera to world space and normalize
    direction = (p._camera_to_world * vec4(direction, 0.0)).xyz;
    direction = normalize(direction);
    return create_ray(origin, direction);
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
    ivec2 pixel_pos = ivec2(gl_GlobalInvocationID.xy);

    ivec2 image_size = imageSize(img);
    vec2 uv = ((gl_GlobalInvocationID.xy) / vec2(image_size) * 2.0 - 1.0);
    float ar = float(image_size.x) / float(image_size.y);
    uv.x *= ar;

    Ray ray = create_camera_ray(uv);

    imageStore(img, pixel_pos, vec4(ray.direction * 0.5 + 0.5, 1.0));
    // imageStore(img, ivec2(gl_GlobalInvocationID.xy), vec4(1.0, 0.0, 0.0, 1.0));
}