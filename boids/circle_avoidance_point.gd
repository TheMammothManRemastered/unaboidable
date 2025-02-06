class_name CircleAvoidancePoint extends Node2D

var minor_radius: float
var major_radius: float

@export var weight: float = 20.0

func _ready() -> void:
	minor_radius = ($MinorRadius.shape as CircleShape2D).radius
	major_radius = ($MajorRadius.shape as CircleShape2D).radius
