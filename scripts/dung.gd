extends CharacterBody2D

@export var speed: float = 200
@export var waypoints: Array[Marker2D]

var current_index = 0

func _ready():
	motion_mode = MOTION_MODE_FLOATING

func _physics_process(_delta: float) -> void:
	var min_distance = 5.0
	var target_position = waypoints[current_index].global_position
	var direction = target_position - global_position
	var distance = direction.length()
	direction = direction.normalized()
	velocity = direction * speed
	
	if distance < min_distance:
		current_index += 1
		if current_index >= waypoints.size():
			current_index = 0
	
	# Mover sin ser afectado por colisiones de otros cuerpos
	move_and_slide()
