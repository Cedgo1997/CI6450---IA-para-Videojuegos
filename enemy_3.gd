extends RigidBody2D

enum SteeringAlgorithm {
	ALIGN,
	VELOCITY_MATCH,
	ALIGN_AND_VELOCITY_MATCH,
	PURSUE,
	EVADE,
	FACE,
	WANDER
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

@export_group("Pursue-Evade Settings")
@export var max_speed = 200.0
@export var max_prediction_time = 1.0
@export var arrive_target_radius = 20.0
@export var arrive_slow_radius = 120.0
@export var arrive_time_to_target = 0.1
@export var use_look_where_youre_going = false

@export_group("Wander Settings")
@export var wander_offset = 100.0  # Distancia del círculo de wandering
@export var wander_radius = 50.0   # Radio del círculo de wandering
@export var wander_rate = 3.0      # Velocidad de cambio de orientación
@export var wander_max_speed = 150.0  # Velocidad máxima en wander

var target: Node2D = null
var current_rotation_speed = 0.0
var previous_target_position = Vector2.ZERO
var target_velocity = Vector2.ZERO

# Variables para Wander
var wander_orientation = 0.0
var wander_target = Vector2.ZERO

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		previous_target_position = target.global_position
	
	lock_rotation = false
	linear_velocity = Vector2.ZERO
	wander_orientation = rotation

func _physics_process(delta):
	if target == null and algorithm != SteeringAlgorithm.WANDER:
		return
	
	if target and delta > 0:
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
		SteeringAlgorithm.PURSUE:
			steering_pursue(delta)
		SteeringAlgorithm.EVADE:
			steering_evade(delta)
		SteeringAlgorithm.FACE:
			steering_face(delta)
		SteeringAlgorithm.WANDER:
			steering_wander(delta)

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

func steering_pursue(delta: float) -> void:
	var direction = target.global_position - global_position
	var distance = direction.length()
	
	var speed = linear_velocity.length()
	
	var prediction = 0.0
	if speed <= distance / max_prediction_time:
		prediction = max_prediction_time
	else:
		prediction = distance / speed
	
	var predicted_position = target.global_position + target_velocity * prediction
	
	var steering_acceleration = steering_arrive_internal(predicted_position, delta)
	
	linear_velocity += steering_acceleration * delta
	
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	
	if use_look_where_youre_going:
		steering_look_where_youre_going(delta)
	elif linear_velocity.length() > 0.1:
		var target_rotation = linear_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, 8.0 * delta)

func steering_evade(delta: float) -> void:
	var direction = target.global_position - global_position
	var distance = direction.length()
	
	var speed = linear_velocity.length()
	
	var prediction = 0.0
	if speed <= distance / max_prediction_time:
		prediction = max_prediction_time
	else:
		prediction = distance / speed
	
	var predicted_position = target.global_position + target_velocity * prediction
	
	var steering_acceleration = steering_flee_internal(predicted_position)
	
	linear_velocity += steering_acceleration * delta
	
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	
	if use_look_where_youre_going:
		steering_look_where_youre_going(delta)
	elif linear_velocity.length() > 0.1:
		var target_rotation = linear_velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, 8.0 * delta)

func steering_face(delta: float) -> void:
	var direction = target.global_position - global_position
	if direction.length() == 0:
		return
	
	var target_orientation = atan2(direction.y, direction.x)
	steering_align_internal(target_orientation, delta)

func steering_wander(delta: float) -> void:
	# 1. Actualizar la orientación del wandering
	wander_orientation += randf_range(-1, 1) * wander_rate
	
	# 2. Calcular la orientación combinada (relativa al personaje)
	var target_orientation = wander_orientation + rotation
	
	# 3. Calcular el centro del círculo de wandering
	var wander_circle_center = global_position + wander_offset * Vector2(cos(rotation), sin(rotation))
	
	# 4. Calcular la posición objetivo en el círculo
	wander_target = wander_circle_center + wander_radius * Vector2(cos(target_orientation), sin(target_orientation))
	
	# 5. Usar Face para orientarse hacia el objetivo
	steering_face_wander(delta)
	
	# 6. Establecer aceleración lineal en la dirección de la orientación actual
	var direction = Vector2(cos(rotation), sin(rotation))
	linear_velocity += direction * max_linear_acceleration * delta
	
	if linear_velocity.length() > wander_max_speed:
		linear_velocity = linear_velocity.normalized() * wander_max_speed

func steering_face_wander(delta: float) -> void:
	var direction = wander_target - global_position
	if direction.length() == 0:
		return
	
	var target_orientation = atan2(direction.y, direction.x)
	steering_align_internal(target_orientation, delta)

func steering_look_where_youre_going(delta: float) -> void:
	if linear_velocity.length() == 0:
		return
	
	var target_orientation = atan2(linear_velocity.y, linear_velocity.x)
	steering_align_internal(target_orientation, delta)

func steering_align_internal(target_orientation: float, delta: float) -> void:
	var rotation_diff = target_orientation - rotation
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

func steering_arrive_internal(target_position: Vector2, delta: float) -> Vector2:
	var direction = target_position - global_position
	var distance = direction.length()
	
	if distance < arrive_target_radius:
		return -linear_velocity / arrive_time_to_target
	
	var target_speed = max_speed
	if distance < arrive_slow_radius:
		target_speed = max_speed * (distance / arrive_slow_radius)
	
	var target_velocity_vec = direction.normalized() * target_speed
	var acceleration = (target_velocity_vec - linear_velocity) / arrive_time_to_target
	
	if acceleration.length() > max_linear_acceleration:
		acceleration = acceleration.normalized() * max_linear_acceleration
	
	return acceleration

func steering_flee_internal(target_position: Vector2) -> Vector2:
	var result = global_position - target_position
	
	if result.length() > 0:
		result = result.normalized()
	
	result *= max_linear_acceleration
	
	return result

func map_to_range(angle: float) -> float:
	return fmod(angle + PI, 2 * PI) - PI
