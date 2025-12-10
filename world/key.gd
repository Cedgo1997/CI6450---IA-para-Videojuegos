extends StaticBody2D

signal chest_opened

var key_taken = false
var in_chest_zone = false

func _ready():
	# Conectar la señal body_entered del Area2D para detectar CharacterBody2D
	var area_2d = $Area2D
	if area_2d:
		if not area_2d.body_entered.is_connected(_on_area_2d_body_entered):
			area_2d.body_entered.connect(_on_area_2d_body_entered)


func _on_area_2d_area_entered(area: Area2D) -> void:
	# Verificar que el área o su cuerpo padre pertenezca al grupo "player"
	var is_player = false
	if area.is_in_group("player"):
		is_player = true
	elif area.get_parent() and area.get_parent().is_in_group("player"):
		is_player = true
	
	if key_taken == false and is_player:
		key_taken = true
		$Sprite2D.queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	# Detectar cuando un CharacterBody2D (como el jugador) entra en el área
	if key_taken == false and body.is_in_group("player"):
		key_taken = true
		$Sprite2D.queue_free()

func _process(delta: float) -> void:
	if key_taken == true:
		if in_chest_zone == true:
			if Input.is_action_just_pressed("ui_accept"):
				print("Chest opened")
				emit_signal("chest_opened")


func _on_chest_zone_body_entered(body: PhysicsBody2D) -> void:
	in_chest_zone = true
	print("In chest zone")

func _on_chest_zone_body_exited(body: PhysicsBody2D) -> void:
	in_chest_zone = false
	print("Out chest zone")
