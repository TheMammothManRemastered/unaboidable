extends CharacterBody2D
class_name Boid

func _physics_process(delta: float) -> void:
	self.rotation = self.velocity.normalized().angle() + (PI / 2.0)
