uint djb2Hash(vec2 key) {
    uint hash = 5381u;
    uint x = uint(key.x * 1000.0);
    uint y = uint(key.y * 1000.0);

    hash = ((hash << 5) + hash) ^ x;
    hash = ((hash << 5) + hash) ^ y;

    return hash;
}

uint xorshiftHash(vec2 key) {
    uint s0 = uint(key.x * 1000.0);
    uint s1 = uint(key.y * 1000.0);

    s1 ^= s1 << 23;
    s1 ^= s1 >> 17;
    s1 ^= s0;
    s1 ^= s0 >> 26;

    uint result = s1 + s0;
    return result;
}

uint hash(vec2 key, uint tableSize) {
    uint h1 = djb2Hash(key);
    uint h2 = xorshiftHash(key);
    uint h = h1 ^ (h2 * 0x27d4eb2f);
    return h % tableSize;
}

#define TABLE_SIZE 1024
#define MAX_CHAIN_LENGTH 5

struct ParticleEntry {
    uint particleIndex;
    uint next;
};

void insertParticle(uint particleIndex, vec2 position) {
    uint tableIndex = hash(position, TABLE_SIZE);
    uint entryIndex = tableIndex * MAX_CHAIN_LENGTH;

    for (int i = 0; i < MAX_CHAIN_LENGTH; ++i) {
        uint currentIndex = entryIndex + uint(i);
        if (table[currentIndex].next == -1) {
            table[currentIndex].particleIndex = particleIndex;
            table[currentIndex].next = -1;
            break;
        }
    }
}
