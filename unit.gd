extends CharacterBody2D

@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D

@export var movement_speed = 200.0

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var player_position = player.global_position if player else global_position
	navigation_agent_2d.target_position = player_position
	
	var current_agent_position = global_position
	var next_path_position = navigation_agent_2d.get_next_path_position()
	var new_velocity = current_agent_position.direction_to(next_path_position) * movement_speed
	
	if navigation_agent_2d.is_navigation_finished():
		return
	
	if navigation_agent_2d.avoidance_enabled:
		navigation_agent_2d.set_velocity(new_velocity)
	else:
		_on_navigation_agent_2d_velocity_computed(new_velocity)
	move_and_slide()

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
