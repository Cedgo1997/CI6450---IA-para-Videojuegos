extends CharacterBody2D
@export var speed = 300.0
@export var rotation_speed = 10.0

signal enemy_entered
signal enemy_exited
var screen_size

func _ready():
	screen_size = get_viewport_rect().size

func _physics_process(delta):
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_action_pressed("move_up"):
		velocity.y -= 1
	
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		var target_rotation = velocity.angle()
		rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)
	
	move_and_slide()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		enemy_entered.emit()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		enemy_exited.emit()
