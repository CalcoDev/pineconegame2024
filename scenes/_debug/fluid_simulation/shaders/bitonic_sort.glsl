#[compute]
#version 450

layout(push_constant, std430) uniform Params {
    int OP_MODE;
    int _num_entries;
    int _group_width;
    int _group_height;
    int _step_index;
    int _padding[3];
};

layout(set = 0, binding = 0, std430) restrict buffer ValueBuffer {
    int _values[];
};

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
    // if (OP_MODE == 0) {
    //     uint i = uint(gl_GlobalInvocationID.x);
    //     uint h = i & (_group_width - 1);
    //     uint index_low = h + (_group_height + 1) * (i / _group_width);
    //     uint index_high = index_low + (_step_index == 0 ? _group_height - 2 * h : (_group_height + 1) / 2);

    //     if (index_high >= _num_entries) {
    //         return;
    //     }

    //     int value_low = _values[index_low];
    //     int value_high = _values[index_high];

    //     if (value_low > value_high) {
    //         _values[index_low] = value_high;
    //         _values[index_high] = value_low;
    //     }
    // } else {
    //     int i = int(gl_GlobalInvocationID.x);
    //     _values[i] *= 2.0;
    // }
}