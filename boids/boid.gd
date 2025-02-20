extends Area2D
class_name Boid

var radii: Array[float] = []
var radii_colors: Array[Color] = []
var velocity: Vector2 = Vector2.from_angle(PI / 4.0) * 50.0
var dead: bool = false
var health: int = 2

func _physics_process(delta: float) -> void:
	self.rotation = self.velocity.normalized().angle() + (PI / 2.0)

func distance_to_boid(other: Boid) -> float:
	return absf(self.global_position.distance_to(other.global_position))

func vector_to_boid(other: Boid, normalize: bool = false) -> Vector2:
	var v = other.global_position - self.global_position
	return v.normalized() if normalize else v


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not dead:
		self.dead = true
		SwarmOverlord.instance.queue_remove_boid(self)

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
