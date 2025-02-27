class_name PlayerCoroutines extends Node

const ATTACK_LUNGE_SPEED := 1500.0
const ATTACK_LUNGE_TIME := 0.4

const DIVE_SPEED := 1500.0
const DIVE_LAND_SPEED := 1500.0
const DIVE_MAX_SLIDE_TIME := 0.5

var _buffered_action := ActionType.NONE
var _active_timer: SceneTreeTimer
var _p: Player

var control_lock := false
var gravity_scale := 1.0

func _init(player: Player):
	_p = player

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("primary"): _buffered_action = ActionType.PRIMARY
	elif event.is_action_pressed("special"): _buffered_action = ActionType.SPECIAL
	elif event.is_action_pressed("jump"): _buffered_action = ActionType.JUMP

func _nearest_homing_target(max_distance: float) -> Node2D:
	var boids = get_tree().get_nodes_in_group("boids")
	if boids.is_empty(): return null
	boids.sort_custom(func(a, b): return _p.global_position.distance_to(a.global_position) < _p.global_position.distance_to(b.global_position))
	if _p.global_position.distance_to(boids[0].global_position) > max_distance: return null
	return boids[0]

func _timer_step(seconds: float) -> bool:
	if _active_timer == null:
		_active_timer = get_tree().create_timer(seconds, false)
		return true
	else:
		await get_tree().process_frame
		if _active_timer.time_left == 0:
			_active_timer = null
			return false
		else:
			return true

func _set_player_position(position: Vector2) -> void:
	_p.move_and_collide(position - _p.position)

func main_attack(depth := 1) -> void:
	const MAX_HOME_DISTANCE := 500.0
	const SPEED_PER_PX := 200.0
	const LUNGE_DISTANCE := 200.0
	const HOMING_EXTRA_DISTANCE := 40.0
	const DECEL_TIME := 0.3
	const FIXED_TIME := 0.2
	const END_LAG := 0.1
	const MAX_DEPTH := 3
	
	control_lock = true
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var distance = LUNGE_DISTANCE
	if direction == Vector2.ZERO:
		var homing_target = _nearest_homing_target(MAX_HOME_DISTANCE)
		if homing_target != null:
			direction = _p.global_position.direction_to(homing_target.global_position)
			distance = _p.global_position.distance_to(homing_target.global_position) + HOMING_EXTRA_DISTANCE
		else:
			direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	_p.velocity = Vector2.ZERO
	
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_method(_set_player_position, _p.position, _p.position + direction * distance, DECEL_TIME)
	
	await get_tree().create_timer(FIXED_TIME, false).timeout
	
	while await _timer_step(END_LAG):
		if _buffered_action != ActionType.NONE: break
	
	if depth < MAX_DEPTH and _buffered_action == ActionType.PRIMARY:
		_p.new_coroutine().main_attack(depth + 1)
	
	t.kill()
	queue_free()

func dive_attack() -> void:
	gravity_scale = 0.0
	
	var lr = Input.get_axis("move_left", "move_right")
	var direction = Vector2(lr, 2)
	_p.velocity = direction * DIVE_SPEED
	
	while not _p.is_on_floor():
		await get_tree().process_frame
		_p.velocity.x = lr * DIVE_LAND_SPEED
	
	var slide_time = 0.0
	while Input.is_action_pressed("move_down") and slide_time < DIVE_MAX_SLIDE_TIME:
		_p.velocity.x = lr * DIVE_LAND_SPEED
		await get_tree().process_frame
		slide_time += get_process_delta_time()
	
	queue_free()

enum ActionType {
	NONE,
	PRIMARY,
	SPECIAL,
	JUMP,
}
