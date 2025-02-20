class_name PlayerCoroutines extends Node

const ATTACK_LUNGE_SPEED := 1300.0

const DIVE_SPEED := 1500.0
const DIVE_LAND_SPEED := 1500.0
const DIVE_MAX_SLIDE_TIME := 0.5

var player: Player

func main_attack() -> void:
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction == null: direction = player.velocity.normalized()
	
	if player.velocity.y > 0: player.velocity.y = 0
	player.velocity += direction * ATTACK_LUNGE_SPEED	
	#player.gravity_scale = 0.0
	
	var t = create_tween()
	t.tween_property(player, "velocity", player.velocity * 0.2, 0.2)
	await t.finished
	
	player.gravity_scale = 1.0

func dive_attack() -> void:
	var lr = Input.get_axis("move_left", "move_right")
	var direction = Vector2(lr, 2)
	player.velocity = direction * DIVE_SPEED
	player.gravity_scale = 0.0
	
	while not player.is_on_floor():
		await get_tree().process_frame
		player.velocity.x = lr * DIVE_LAND_SPEED
	
	var slide_time = 0.0
	while Input.is_action_pressed("move_down") and slide_time < DIVE_MAX_SLIDE_TIME:
		player.velocity.x = lr * DIVE_LAND_SPEED
		await get_tree().process_frame
		slide_time += get_process_delta_time()
	
	player.gravity_scale = 1.0
