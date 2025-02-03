#[compute]
#version 450

#define BOID_INDEX  (gl_GlobalInvocationID.x)

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

// Uniform bindings
layout(set = 0, binding = 0, std430) buffer PositionBuffer {
    vec2 data[];
} boid_positions;
layout(set = 0, binding = 1, std430) buffer VelocityBuffer {
    vec2 data[];
} boid_velocities;

layout(set = 0, binding = 2, std430) buffer UniformsBuffer {
    float num_boids;
    float delta;
} uniforms;


void main() {
    // update position
    boid_positions.data[BOID_INDEX] += boid_velocities.data[BOID_INDEX] * uniforms.delta;
}