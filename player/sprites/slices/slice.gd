extends Node2D

@export var index: int
@export var direction: Vector2

@onready var sprite: Sprite2D = %Sprite2D

func _ready() -> void:
	# set rotation / flip
	if direction.x < 0:
		sprite.flip_h = true
		direction *= -1
	sprite.rotation = direction.angle()
	
	# set sprite by index
	if index % 2 == 0:
		sprite.texture = preload("res://player/sprites/slices/slice1.png")
	else:
		sprite.texture = preload("res://player/sprites/slices/slice2.png")
	
	# fade out and destroy
	var tween = create_tween()
	tween.tween_method(
		func(t: float):
			modulate.a = round(t * 3.0) / 3.0,
		1.0, 0.0, 0.3
		)
	await tween.finished
	
	queue_free()
	
