extends Boid
class_name SimpleBoid

# NOTE: these all need to be defined in any class that extends Boid
# there's 10000% a better way to do this, fix that lol
static var max_speed: float = 300.0
static var separation_radius: float = 40
static var separation_weight: float = 30
static var alignment_radius: float = 125
static var alignment_weight: float = 0.2
static var cohesion_radius: float = 250
static var cohesion_weight: float = 0.15
static var discriminatory: bool = true
static var critical_mass: int = 4
static var goal_weight: float = 12

static var class_id = 0
static var boid_scene = preload("res://boids/boid_types/boid_simple.gd")

const ATTACK_RANGE := 80.0
@onready var anim: AnimationPlayer = %Anim

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if Player.instance.global_position.distance_to(self.global_position) <= ATTACK_RANGE:
		anim.play("attack")
