#[compute]
#version 450

layout(push_constant, std430) uniform Params {
    int OP_MODE;
    int _num_entries;
    int _lookup_table_size;
    int _group_width;
    int _group_height;
    int _step_index;
    float _smoothing_radius;
    int _padding[1];
};

struct SortEntry {
    int particle_index;
    uint hash;
};

layout(set = 0, binding = 0, std430) restrict buffer ToSortBuffer {
    SortEntry _entries[];
};

layout(set = 0, binding = 1, std430) restrict buffer OffsetBuffer {
    int _offsets[];
};

layout(set = 0, binding = 2, std430) restrict buffer PositionBuffer {
    vec2 _position[];
};

void handle_update_spatial_hash() {
    int i = int(gl_GlobalInvocationID.x);

    if (i >= _num_entries) {
        return;
    }

    vec2 pos = _position[i];
    int xx = int(pos.x / _smoothing_radius);
    int yy = int(pos.y / _smoothing_radius);
    uint a = uint(xx * 15823);
    uint b = uint(yy * 9737333);
    uint hash = a + b;

    _entries[i].particle_index = i;
    _entries[i].hash = hash;
}

void handle_sorting() {
    uint i = uint(gl_GlobalInvocationID.x);
    uint h = i & (_group_width - 1);
    uint index_low = h + (_group_height + 1) * (i / _group_width);
    uint index_high = index_low + (_step_index == 0 ? _group_height - 2 * h : (_group_height + 1) / 2);

    if (index_high >= _num_entries) {
        return;
    }

    uint value_low = _entries[index_low].hash % _lookup_table_size;
    uint value_high = _entries[index_high].hash % _lookup_table_size;

    if (value_low > value_high) {
        SortEntry temp = _entries[index_low];
        _entries[index_low] = _entries[index_high];
        _entries[index_high] = temp;
    }
}

void handle_compute_offsets() {
    // this is STILL our entry index
    // we will then compute the offset based on current thign
    int i = int(gl_GlobalInvocationID.x);

    if (i >= _num_entries) {
        return;
    }

    uint null = _num_entries;
    uint key = _entries[i].hash % _lookup_table_size;
    uint key_prev = (i == 0 ? null : _entries[i - 1].hash % _lookup_table_size);

    if (key != key_prev) {
        _offsets[key] = i;
    }
}

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    switch (OP_MODE) {
        case 0:
            handle_update_spatial_hash();
            break;
        case 1:
            handle_sorting();
            break;
        case 2:
            handle_compute_offsets();
            break;
    }
}