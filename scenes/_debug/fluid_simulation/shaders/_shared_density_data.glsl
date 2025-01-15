const float SCALE = 100.0;

float smoothing_kernel(float radius, float dist) {
    radius /= SCALE;
    dist /= SCALE;
    // float volume = PI * pow(radius, 8) / 4;
    // float value = max(0, radius * radius - dist * dist);
    // return value * value * value / volume;

    if (dist >= radius) return 0;
    float volume = (PI * pow(radius, 4)) / 6;
    return (radius - dist) * (radius - dist) / volume;
}

float smoothing_kernel_derivative(float radius, float dist) {
    radius /= SCALE;
    dist /= SCALE;
    // if (dist >= radius) return 0;
    // float f = radius * radius - dist * dist;
    // float scale = -24 / (PI * pow(radius, 8));
    // return scale * dist * f * f;

    if (dist >= radius) return 0;
    float scale = 12 / (pow(radius, 4) * PI);
    return (dist - radius) * scale;
}