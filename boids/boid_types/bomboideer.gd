extends Boid
class_name BombBoid

# Bomboideers!
# how do bomboideers behave:
#     a flock of N bomboideers will try to form in the mesosphere-thermosphere.
#     once N bomboideers are flocked together, they will no longer accept new
#     flockmates, and will attempt to flock above the player in the thermosphere.
#     once they do this, they number themselves and, every X seconds, launch
#     straight at the player at max speed. this is their attack. they go boom!

static var max_speed: float = 280.0
static var separation_radius: float = 40
static var separation_weight: float = 30
static var alignment_radius: float = 125
static var alignment_weight: float = 0.2
static var cohesion_radius: float = 250
static var cohesion_weight: float = 0.15
static var discriminatory: bool = true
static var critical_mass: int = 3
static var goal_weight: float = 25

static var class_id = 2
static var boid_scene = preload("res://boids/boid_types/bomboideer.tscn")

var bomb_stage: int = 0
var prev_bomb_stage: int = -1

const ATTACK_RANGE = 80.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if Player.instance.global_position.distance_to(self.global_position) <= ATTACK_RANGE:
		#Player.instance.hurt(3)
		die()

func _exit_tree() -> void:
	print("something freed me!")

func on_overlord_removed():
	print("the overlord removed me!")
	self.queue_free()
