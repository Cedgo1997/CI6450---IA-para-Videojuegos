extends RigidBody2D

enum SteeringAlgorithm {
	ALIGN,
	VELOCITY_MATCH,
	ALIGN_AND_VELOCITY_MATCH
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.ALIGN

@export var max_angular_acceleration = 10.0
@export var max_rotation_speed = 5.0
@export var angular_time_to_target = 0.1

@export_group("Align Settings")
@export var target_radius = deg_to_rad(5.0)
@export var slow_radius = deg_to_rad(45.0)

@export_group("Velocity Match Settings")
@export var max_linear_acceleration = 100.0
@export var linear_time_to_target = 0.1

var target: Node2D = null
var current_rotation_speed = 0.0
var previous_target_position = Vector2.ZERO
var target_velocity = Vector2.ZERO

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		previous_target_position = target.global_position
	
	lock_rotation = false
	linear_velocity = Vector2.ZERO

func _physics_process(delta):
	if target == null:
		return
	
	if delta > 0:
		var current_target_position = target.global_position
		target_velocity = (current_target_position - previous_target_position) / delta
		previous_target_position = current_target_position
	
	match algorithm:
		SteeringAlgorithm.ALIGN:
			steering_align(delta)
		SteeringAlgorithm.VELOCITY_MATCH:
			steering_velocity_match(delta)
		SteeringAlgorithm.ALIGN_AND_VELOCITY_MATCH:
			steering_align(delta)
			steering_velocity_match(delta)

func steering_align(delta: float) -> void:
	var rotation_diff = target.rotation - rotation
	rotation_diff = map_to_range(rotation_diff)
	var rotation_size = abs(rotation_diff)
	
	if rotation_size < target_radius:
		angular_velocity = 0
		return
	
	var target_rotation_speed = max_rotation_speed
	if rotation_size < slow_radius:
		target_rotation_speed = max_rotation_speed * rotation_size / slow_radius
	
	target_rotation_speed *= sign(rotation_diff)
	
	var angular_acceleration = (target_rotation_speed - angular_velocity) / angular_time_to_target
	
	if abs(angular_acceleration) > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration
	
	angular_velocity += angular_acceleration * delta

func steering_velocity_match(delta: float) -> void:
	var linear_acceleration = (target_velocity - linear_velocity) / linear_time_to_target
	
	if linear_acceleration.length() > max_linear_acceleration:
		linear_acceleration = linear_acceleration.normalized() * max_linear_acceleration
	
	linear_velocity += linear_acceleration * delta

func map_to_range(angle: float) -> float:
	return fmod(angle + PI, 2 * PI) - PI
