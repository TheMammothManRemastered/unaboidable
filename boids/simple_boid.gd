extends Boid
class_name SimpleBoid

# NOTE: these all need to be defined in any class that extends Boid
# there's 10000% a better way to do this, fix that lol
static var max_speed: float = 500.0
static var separation_radius: float = 40
static var separation_weight: float = 30
static var alignment_radius: float = 75
static var alignment_weight: float = 0.2
static var cohesion_radius: float = 150
static var cohesion_weight: float = 0.15
static var discriminatory: bool = true

static var class_id = 0
static var boid_scene = preload("res://boids/simple_boid.tscn")
