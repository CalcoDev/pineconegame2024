uint djb2Hash(ivec2 key) {
    uint hash = 5381u;
    uint x = uint(key.x * 1000);
    uint y = uint(key.y * 1000);

    hash = ((hash << 5) + hash) ^ x;
    hash = ((hash << 5) + hash) ^ y;

    return hash;
}

uint xorshiftHash(ivec2 key) {
    uint s0 = uint(key.x * 1000);
    uint s1 = uint(key.y * 1000);

    s1 ^= s1 << 23;
    s1 ^= s1 >> 17;
    s1 ^= s0;
    s1 ^= s0 >> 26;

    uint result = s1 + s0;
    return result;
}

int hash(ivec2 key, uint tableSize) {
    uint h1 = djb2Hash(key);
    uint h2 = xorshiftHash(key);
    uint h = h1 ^ (h2 * 0x27d4eb2f);
    return int(h % tableSize);
}

#define TABLE_SIZE int(50051)
#define GRID_CELL_SIZE int(32)

struct ParticleEntry {
    int particle_index;
    int next;
};

layout(set = 1, binding = 0) restrict buffer HashTableBuffer {
    ParticleEntry data[];
} _hashtable;

layout(set = 1, binding = 1) restrict buffer BucketIndicesBuffer {
    int data[];
} _bucket_indices;

layout(set = 1, binding = 2) restrict buffer Counters {
    int particle_counter;
} _counters;

ivec2 get_grid_cell(vec2 position) {
    return ivec2(floor(position / GRID_CELL_SIZE));
}

int hash_grid_cell(ivec2 gridCell) {
    return hash(gridCell, TABLE_SIZE);
}

void unset_old_position(int particle_index, vec2 position) {
    ivec2 grid_cell = get_grid_cell(position);
    int bucket_index = hash_grid_cell(grid_cell);

    // memory_barrier();
    barrier();
    int current_index = _bucket_indices.data[bucket_index];
    int prev_index = -1;

    while (current_index != -1) {
        if (_hashtable.data[current_index].particle_index == particle_index) {
            // unlink current entry
            if (prev_index == -1) {
                atomicExchange(_bucket_indices.data[bucket_index], _hashtable.data[current_index].next);
            } else {
                _hashtable.data[prev_index].next = _hashtable.data[current_index].next;
            }

            // invalidate entry
            _hashtable.data[current_index].particle_index = -1;
            _hashtable.data[current_index].next = -1;
        }

        prev_index = current_index;
        current_index = _hashtable.data[current_index].next;
    }

    // int entry_index = bucket_index * MAX_CHAIN_LENGTH;
    // int rewrite_index = -1;
    // for (int i = 0; i < MAX_CHAIN_LENGTH; ++i) {
    //     int current_index = entry_index + i;
    //     int pidx = _hashtable.data[current_index].particle_index;
    //     if (pidx < 0) {
    //         break;
    //     }
    //     if (pidx == particle_index) {
    //         rewrite_index = current_index;
    //         break;
    //     }
    // }

    // if (rewrite_index >= 0) {
    //     while (rewrite_index + 1 < entry_index + MAX_CHAIN_LENGTH && rewrite_index + 1 < TABLE_MAX_MAX_SIZE && _hashtable.data[rewrite_index + 1].particle_index != -1) {
    //         _hashtable.data[rewrite_index] = _hashtable.data[rewrite_index + 1];
    //         rewrite_index += 1;
    //     }
    //     if (rewrite_index == entry_index + MAX_CHAIN_LENGTH) {
    //         _hashtable.data[rewrite_index - 1].particle_index = -1;
    //     }
    // }
}

void set_new_position(int particle_index, vec2 position) {
    ivec2 grid_cell = get_grid_cell(position);
    int bucket_index = hash_grid_cell(grid_cell);

    int new_entry_index = atomicAdd(_counters.particle_counter, 1) % TABLE_SIZE;
    _hashtable.data[new_entry_index].particle_index = particle_index;
    _hashtable.data[new_entry_index].next = -1;

    int old_head = atomicExchange(_bucket_indices.data[bucket_index], new_entry_index);
    _hashtable.data[new_entry_index].next = old_head;

    // _hashtable.data[entry_index].particle_index = particle_index;

    // for (int i = 0; i < MAX_CHAIN_LENGTH; ++i) {
    //     uint current_index = entry_index + i;
    //     if (_hashtable.data[current_index].particle_index == -1) {
    //         _hashtable.data[current_index].particle_index = particle_index;
    //         break;
    //     }
    // }
}