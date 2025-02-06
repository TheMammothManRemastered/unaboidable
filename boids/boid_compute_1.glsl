#[compute]
#version 450

// TODO: extract more stuff into macros
#define BOID_INDEX          (gl_GlobalInvocationID.x)
#define BOID_POSITION(i)    (boid_positions.data[i])
#define BOID_VELOCITY(i)    (boid_velocities.data[i])
#define CURR_BOID_POSITION  (BOID_POSITION(BOID_INDEX))
#define CURR_BOID_VELOCITY  (BOID_VELOCITY(BOID_INDEX))

// how to approach multiple boid types?
// i think they should all be done here, but use different weights/code
// which one they use can be determined by using an SSBO to store each boid's type
// which can just be an integer

// Invocations in the (x, y, z) dimension
// since we deal with a 1d array of boids, there's no real reason to 
// stray from a single dimension. 
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

// the CPU updates this infrequently
layout(set = 0, binding = 0, std430) buffer PositionBuffer {
    vec2 data[];
} boid_positions;
layout(set = 0, binding = 1, std430) buffer VelocityBuffer {
    vec2 data[];
} boid_velocities;

struct AvoidanceObject {
    vec2 position;
    float major_radius;
    float minor_radius;
};
layout(set = 0, binding = 2, std430) buffer AvoidanceObjectBuffer {
    AvoidanceObject data[];
} avoidance_objects;

// honestly a majority of this never changes, yet we resend the whole thing every frame
// I'm not experienced enough in GPU programming to know if this is actually a major
// performance impact (I suspect it isn't), but splitting this up might not be a bad idea.
// maybe put the immutable stuff in set 1?
layout(set = 0, binding = 3, std430) buffer UniformsBuffer {
    float num_boids;
    float num_avoidance_objects;
    float max_speed;
    float boundary_x;
    float boundary_y;
    float boundary_weight;
    float separation_radius;
    float separation_weight;
    float alignment_radius;
    float alignment_weight;
    float cohesion_radius;
    float cohesion_weight;
    float delta;
} uniforms;

void cap_speed() {
    if (length(boid_velocities.data[BOID_INDEX]) > uniforms.max_speed) {
        boid_velocities.data[BOID_INDEX] = normalize(boid_velocities.data[BOID_INDEX]) * uniforms.max_speed;
    }
}

vec2 calculate_boundary_vector() {
    vec2 ret = vec2(0.0, 0.0);

    if (boid_positions.data[BOID_INDEX].x > uniforms.boundary_x) {
        ret.x = -1.0;
    }
    else if (boid_positions.data[BOID_INDEX].y > uniforms.boundary_y) {
        ret.y = -1.0;
    }
    if (boid_positions.data[BOID_INDEX].x < -uniforms.boundary_x) {
        ret.x = 1.0;
    }
    else if (boid_positions.data[BOID_INDEX].y < -uniforms.boundary_y) {
        ret.y = 1.0;
    }

    if (ret.x == 0.0 && ret.y == 0.0) {
        return ret;
    }
    return normalize(ret) * uniforms.boundary_weight;
}

vec2 calculate_cohesion_vector() {
    vec2 cohesion_vector = vec2(0.0, 0.0);
    vec2 target_position = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == BOID_INDEX) {
            continue;
        }

        float distance = distance(boid_positions.data[i], boid_positions.data[BOID_INDEX]);
        if (distance < uniforms.cohesion_radius) {
            target_position += boid_positions.data[i];
            n++;
        }
    }

    if (n > 0) {
        target_position /= float(n);
        cohesion_vector = target_position - boid_positions.data[BOID_INDEX];
        cohesion_vector = normalize(cohesion_vector);
    }

    return cohesion_vector * uniforms.cohesion_weight;
}

vec2 calculate_alignment_vector() {
    vec2 alignment_vector = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == BOID_INDEX) {
            continue;
        }

        float distance = distance(boid_positions.data[BOID_INDEX], boid_positions.data[i]);
        if (distance < uniforms.alignment_radius) {
            alignment_vector += boid_velocities.data[i];
            n++;
        }
    }

    if (n > 0) {
        alignment_vector /= float(n);
    }

    return alignment_vector * uniforms.alignment_weight;
}

vec2 calculate_separation_vector() {
    vec2 separation_vector = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == BOID_INDEX) {
            continue;
        }

        float distance = distance(boid_positions.data[BOID_INDEX], boid_positions.data[i]);
        if (distance < uniforms.separation_radius) {
            vec2 direction_away = boid_positions.data[BOID_INDEX] - boid_positions.data[i];
            separation_vector += direction_away / distance;
            n++;
        }
    }

    if (n > 0) {
        separation_vector /= float(n);
    }

    return separation_vector * uniforms.separation_weight;
}

vec2 calculate_avoidance_object_vector() {
    vec2 avoidance_object_vector = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_avoidance_objects; i++) {
        float distance = distance(CURR_BOID_POSITION, avoidance_objects.data[i].position);
        if (distance < avoidance_objects.data[i].minor_radius) {
            vec2 direction_away = CURR_BOID_POSITION - avoidance_objects.data[i].position;
            avoidance_object_vector += direction_away / (max(avoidance_objects.data[i].major_radius, 0.0) - CURR_BOID_POSITION);
            n++;
        }
    }

    if (n > 0) {
        avoidance_object_vector /= float(n);
    }

    return avoidance_object_vector * 20.0;
}

void main() {
    boid_velocities.data[BOID_INDEX] += calculate_boundary_vector() + calculate_cohesion_vector()
        + calculate_alignment_vector() + calculate_separation_vector()
        + calculate_avoidance_object_vector();

    cap_speed();

    // update position
    boid_positions.data[BOID_INDEX] += boid_velocities.data[BOID_INDEX] * uniforms.delta;
}