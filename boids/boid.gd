extends StaticBody2D
class_name Boid

var radii: Array[float] = []
var radii_colors: Array[Color] = []
var velocity: Vector2 = Vector2.from_angle(PI / 4.0) * 50.0
var dead: bool = false
var health: int = 1

const ATTACK_RANGE := 80.0
@onready var anim: AnimationPlayer = %Anim

func _physics_process(delta: float) -> void:
	self.rotation = self.velocity.normalized().angle() + (PI / 2.0)
	

	if Player.instance.global_position.distance_to(self.global_position) <= ATTACK_RANGE:
		anim.play("attack")

func hurt(damage: int = 1) -> void:
	health -= damage
	
	if health <= 0:
		die()

func die() -> void:
	self.dead = true
	SwarmOverlord.instance.queue_remove_boid(self)

func on_overlord_added() -> void:
	pass

func on_overlord_removed() -> void:
	queue_free()

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body is Player:
		body.hurt()
