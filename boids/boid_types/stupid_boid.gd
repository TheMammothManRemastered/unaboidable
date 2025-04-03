extends Boid
class_name StupidBoid

# NOTE: these all need to be defined in any class that extends Boid
# there's 10000% a better way to do this, fix that lol
static var max_speed: float = 700.0
static var separation_radius: float = 40
static var separation_weight: float = 30
static var alignment_radius: float = 125
static var alignment_weight: float = 0.2
static var cohesion_radius: float = 250
static var cohesion_weight: float = 0.15
static var discriminatory: bool = true
static var critical_mass: int = 8
static var goal_weight: float = 25

static var class_id = 1
static var boid_scene = preload("res://boids/boid_types/stupid_boid.tscn")
