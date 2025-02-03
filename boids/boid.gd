extends Area2D
class_name Boid

var radii: Array[float] = []
var radii_colors: Array[Color] = []
var velocity: Vector2 = Vector2.from_angle(PI / 4.0) * 50.0

func add_colored_radius(radius: float, color: Color) -> void:
	radii.append(radius)
	radii_colors.append(color)

func draw_colored_radii() -> void:
	pass

func _physics_process(delta: float) -> void:
	self.rotation = self.velocity.normalized().angle() + (PI / 2.0)

func _draw() -> void:
	for i in range(radii.size()):
		draw_circle(Vector2(0, 0), radii[i], radii_colors[i], false, 2.0)

func distance_to_boid(other: Boid) -> float:
	return absf(self.global_position.distance_to(other.global_position))

func vector_to_boid(other: Boid, normalize: bool = false) -> Vector2:
	var v = other.global_position - self.global_position
	return v.normalized() if normalize else v
