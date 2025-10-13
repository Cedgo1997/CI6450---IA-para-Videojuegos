extends RigidBody2D

enum SteeringAlgorithm {
	STEERING_SEEK,
	STEERING_FLEE,
	STEERING_ARRIVE
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.STEERING_SEEK
@export var max_speed = 200.0
@export var max_acceleration = 100.0
@export var rotation_speed = 8.0

@export_group('Wandering Settings')
@export var target_radius = 20.0
@export var slow_radius = 120.0
@export var time_to_target = 0.1

var target: Node2D = null
var current_velocity = Vector2.ZERO

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
	
	lock_rotation = false
	linear_damp = 0.5

func _physics_process(delta):
	if target == null:
		return
	
	var steering_output = Vector2.ZERO
	
	match algorithm:
		SteeringAlgorithm.STEERING_SEEK:
			if target:
				steering_output = steering_seek()
		SteeringAlgorithm.STEERING_FLEE:
			steering_output = steering_flee()
		SteeringAlgorithm.STEERING_ARRIVE:
			if target:
				steering_output = steering_arrive()
	
	current_velocity += steering_output * delta
	
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed
	
	linear_velocity = current_velocity
	
	if current_velocity.length() > 0:
		var target_rotation = current_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
func steering_seek() -> Vector2:
	var result = Vector2.ZERO
	
	result = target.global_position - global_position
	
	if result.length() > 0:
		result = result.normalized()
	
	result *= max_acceleration
	
	return result

func steering_flee() -> Vector2:
	var result = Vector2.ZERO
	result = global_position - target.global_position
	if result.length() > 0:
		result = result.normalized()
	
	result *= max_acceleration
	
	return result

func steering_arrive() -> Vector2:
	if target == null:
		return Vector2.ZERO

	var direction = target.global_position - global_position
	var distance = direction.length()

	if distance < target_radius:
		current_velocity = Vector2.ZERO
		return Vector2.ZERO

	var target_speed = max_speed
	if distance < slow_radius:
		target_speed = max_speed * (distance / slow_radius)

	var target_velocity = direction.normalized() * target_speed

	var acceleration = (target_velocity - current_velocity) / time_to_target
	if acceleration.length() > max_acceleration:
		acceleration = acceleration.normalized() * max_acceleration

	return acceleration
