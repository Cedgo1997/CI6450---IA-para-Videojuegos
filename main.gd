extends Node2D

@export var screen_width: float = 1280
@export var screen_height: float = 720

@onready var player = $Player  # Cambia esto al nodo de tu jugador

func _ready():
	$Music.play()

func _process(delta):
	if player:
		check_screen_wrapping()

func check_screen_wrapping():
	var viewport_size = get_viewport_rect().size
	var player_pos = player.global_position
	
	if player_pos.x > viewport_size.x:
		player.global_position.x = 0
	elif player_pos.x < 0:
		player.global_position.x = viewport_size.x
	
	if player_pos.y > viewport_size.y:
		player.global_position.y = 0
	elif player_pos.y < 0:
		player.global_position.y = viewport_size.y
