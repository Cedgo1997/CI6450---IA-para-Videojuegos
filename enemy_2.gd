extends RigidBody2D

enum SteeringAlgorithm {
	STEERING_SEEK,   # Persigue usando aceleración (puede orbitar)
	STEERING_FLEE    # Huye usando aceleración
}

@export var algorithm: SteeringAlgorithm = SteeringAlgorithm.STEERING_SEEK
@export var max_speed = 200.0
@export var max_acceleration = 100.0
@export var rotation_speed = 8.0

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
	
	# Obtener el steering (aceleración) según el algoritmo
	var steering_output = Vector2.ZERO
	
	match algorithm:
		SteeringAlgorithm.STEERING_SEEK:
			steering_output = steering_seek()
		SteeringAlgorithm.STEERING_FLEE:
			steering_output = steering_flee()
	
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
	
	# Obtener la dirección OPUESTA al objetivo (invertir el signo)
	result = global_position - target.global_position
	
	# Normalizar y aplicar aceleración máxima
	if result.length() > 0:
		result = result.normalized()
	
	result *= max_acceleration
	
	return result
