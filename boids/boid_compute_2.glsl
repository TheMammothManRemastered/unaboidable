#[compute]
#version 450

#define BOID_POSITIONS_BINDING              (0)
#define BOID_VELOCITIES_BINDING             (1)
#define BOID_TYPES_BINDING                  (2)
#define STATIC_AVOIDANCE_OBJECTS_BINDING    (3)
#define UNIFORMS_BINDING                    (4)
#define IMMUTABLE_TYPE_DATA_BINDING         (5)
#define GLOBAL_GOALS_BINDING                (6)

#define BOID_POSITION(i)    (boid_positions.data[i])
#define BOID_VELOCITY(i)    (boid_velocities.data[i])
#define BOID_TYPE(i)        (boid_types.data[i])
#define CURR_BOID_INDEX     (gl_GlobalInvocationID.x)
#define CURR_BOID_POSITION  (BOID_POSITION(CURR_BOID_INDEX))
#define CURR_BOID_VELOCITY  (BOID_VELOCITY(CURR_BOID_INDEX))
#define CURR_BOID_TYPE      (BOID_TYPE(CURR_BOID_INDEX))

#define IMMUTABLE_TYPED(symbol) (immutable_type_data.data[CURR_BOID_TYPE].symbol)

// Invocations in the (x, y, z) dimension
// since we deal with a 1d array of boids, there's no real reason to 
// stray from a single dimension. 
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

// these are written back to and from the CPU every so often
layout(set = 0, binding = BOID_POSITIONS_BINDING, std430) buffer PositionBuffer {
    vec2 data[];
} boid_positions;
layout(set = 0, binding = BOID_VELOCITIES_BINDING, std430) buffer VelocityBuffer {
    vec2 data[];
} boid_velocities;
layout(set = 0, binding = BOID_TYPES_BINDING, std430) buffer TypeBuffer {
    int data[];
} boid_types;

struct AvoidanceObject {
    vec2 position;
    float major_radius;
    float minor_radius;
};
layout(set = 0, binding = STATIC_AVOIDANCE_OBJECTS_BINDING, std430) buffer StaticAvoidanceObjectBuffer {
    AvoidanceObject data[];
} static_avoidance_objects;

layout(set = 0, binding = UNIFORMS_BINDING, std430) buffer UniformsBuffer {
    float num_boids;
    float num_avoidance_objects;
    float boundary_x;
    float boundary_y;
    float boundary_origin_x;
    float boundary_origin_y;
    float boundary_weight;
    float delta;
} uniforms;

struct ImmutableTypeData {
    float max_speed;
    float separation_radius;
    float separation_weight;
    float alignment_radius;
    float alignment_weight;
    float cohesion_radius;
    float cohesion_weight;
    float discriminatory;
    float critical_mass;
    float goal_weight;
};
// TODO: there will eventually be MutableTypeData too (probably)
layout(set = 0, binding = IMMUTABLE_TYPE_DATA_BINDING, std430) buffer ImmutableTypeBuffer {
    ImmutableTypeData data[];
} immutable_type_data;

layout(set = 0, binding = GLOBAL_GOALS_BINDING, std430) buffer GlobalGoalsBuffer {
    vec2 data[];
} global_goals;



// GLOBALLY APPLICABLE CALCULATIONS -- these functions are usable by boids of any type

void cap_speed() { // caps a boid to its type's maximum
    if (length(CURR_BOID_VELOCITY) > IMMUTABLE_TYPED(max_speed)) {
        CURR_BOID_VELOCITY = normalize(CURR_BOID_VELOCITY) * IMMUTABLE_TYPED(max_speed);
    }
}

// TODO: refactor this so it works (sorta) like static avoidance objects, start turning away before we hit the border, don't even allow passing it
vec2 calculate_boundary_vector() { // gets a vector to move the boid away from the world boundary. 
    vec2 ret = vec2(0.0, 0.0);
    vec2 origin = vec2(uniforms.boundary_origin_x, uniforms.boundary_origin_y);
    vec2 boundary = vec2(uniforms.boundary_x, uniforms.boundary_y) / 2.0;

    if (CURR_BOID_POSITION.x > origin.x + boundary.x) {
        ret.x = -1.0;
    }
    else if (CURR_BOID_POSITION.y > origin.y + boundary.y) {
        ret.y = -1.0;
    }
    if (CURR_BOID_POSITION.x < origin.x - boundary.x) {
        ret.x = 1.0;
    }
    else if (CURR_BOID_POSITION.y < origin.y - boundary.y) {
        ret.y = 1.0;
    }

    if (ret.x == 0.0 && ret.y == 0.0) {
        return ret;
    }
    return normalize(ret) * uniforms.boundary_weight;
}

vec2 calculate_cohesion_vector() { // cohesion stage - boids tend to approach their neighbors
    vec2 cohesion_vector = vec2(0.0, 0.0);
    vec2 target_position = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == CURR_BOID_INDEX) {
            continue;
        }

        float distance = distance(boid_positions.data[i], boid_positions.data[CURR_BOID_INDEX]);
        if (distance < IMMUTABLE_TYPED(cohesion_radius)) {
            target_position += boid_positions.data[i];
            n++;
        }
    }

    if (n > 0) {
        target_position /= float(n);
        cohesion_vector = target_position - boid_positions.data[CURR_BOID_INDEX];
        cohesion_vector = normalize(cohesion_vector);
    }

    return cohesion_vector * IMMUTABLE_TYPED(cohesion_weight);
}

vec2 calculate_alignment_vector() { // alignment stage - boids tend to match the velocities of their neighbors
    vec2 alignment_vector = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == CURR_BOID_INDEX) {
            continue;
        }
        

        float distance = distance(boid_positions.data[CURR_BOID_INDEX], boid_positions.data[i]);
        if (distance < IMMUTABLE_TYPED(alignment_radius)) {
            alignment_vector += boid_velocities.data[i];
            n++;
        }
    }

    if (n > 0) {
        alignment_vector /= float(n);
    }

    return alignment_vector * IMMUTABLE_TYPED(alignment_weight);
}

vec2 calculate_separation_vector() { // separation stage - boids don't want to run into each other
    vec2 separation_vector = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == CURR_BOID_INDEX) {
            continue;
        }
        // NOTE: this stage does not discriminate, boids should never want to run into eachother no matter what type they are

        float distance = distance(CURR_BOID_POSITION, BOID_POSITION(i));
        if (distance < IMMUTABLE_TYPED(separation_radius)) {
            vec2 direction_away = CURR_BOID_POSITION - BOID_POSITION(i);
            separation_vector += direction_away / distance;
            n++;
        }
    }

    if (n > 0) {
        separation_vector /= float(n);
    }

    return separation_vector * IMMUTABLE_TYPED(separation_weight);
}

vec2 calculate_avoidance_object_vector() { // avoidance stage - boids don't want to run into obstacles
    vec2 avoidance_object_vector = vec2(0.0, 0.0);
    int n = 0;

    for (int i = 0; i < uniforms.num_avoidance_objects; i++) {
        float distance = distance(CURR_BOID_POSITION, static_avoidance_objects.data[i].position);
        if (distance < static_avoidance_objects.data[i].minor_radius) {
            vec2 direction_away = static_avoidance_objects.data[i].position - CURR_BOID_POSITION;
            avoidance_object_vector += direction_away / (max(static_avoidance_objects.data[i].major_radius, 0.01) - distance);
            n++;
        }
    }

    if (n > 0) {
        avoidance_object_vector /= float(n);
    }

    return avoidance_object_vector * 20.0; // TODO: this should be a uniform
}

vec2 calculate_goal_vector() { // goal-seeking - boids want to go somewhere specific
    vec2 goal_vector = vec2(0.0, 0.0);
    vec2 flock_average = vec2(0.0, 0.0);
    int n = 0;

    // get our number of flockmates and the average position of the flock
    for (int i = 0; i < uniforms.num_boids; i++) {
        if (i == CURR_BOID_INDEX) {
            continue;
        }

        float distance = distance(CURR_BOID_POSITION, BOID_POSITION(i));
        if (distance < IMMUTABLE_TYPED(alignment_radius)) { // NOTE: this should be tunable i think
            flock_average += BOID_POSITION(i);
            n++;
        }
    }

    if (n < IMMUTABLE_TYPED(critical_mass)) {
        return goal_vector;
    }

    // calculate direction from flock center to current goal and set sail
    flock_average /= float(n);
    goal_vector = normalize(global_goals.data[0] - flock_average);

    return goal_vector * IMMUTABLE_TYPED(goal_weight);
}





void main() {
    // specific typed stuff

    // common to all boids
    CURR_BOID_VELOCITY += calculate_boundary_vector() + calculate_cohesion_vector()
        + calculate_alignment_vector() + calculate_separation_vector()
        + calculate_avoidance_object_vector() + calculate_goal_vector();
    cap_speed();

    // update position
    CURR_BOID_POSITION += CURR_BOID_VELOCITY * uniforms.delta;
}