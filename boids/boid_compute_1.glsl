#[compute]
#version 450

#define BOID_INDEX  (gl_GlobalInvocationID.x)

struct Boid {
    vec2 position;
    vec2 velocity;
    int boid_type;
};

// Invocations in the (x, y, z) dimension
layout(local_size_x = 2, local_size_y = 1, local_size_z = 1) in;

// Uniform bindings
layout(set = 0, binding = 0, std430) restrict buffer BoidBuffer {
    Boid boids[];
} boid_buffer;
layout(set = 0, binding = 1, std430) restrict uniform GlobalInfoUniformBlock {
    int num_boids;
} info_uniforms;

void main() {
    boid_buffer.boids[BOID_INDEX].position += boid_buffer.boids[BOID_INDEX].velocity;
}