extends RigidBody2D

@onready var tree_sprite = $Sprite2D
@onready var drop_timer = $DropTimer
@onready var recharge_timer = $RechargeTimer
@onready var apple_ripe_timer = $AppleRipeTimer

var apple = preload("res://scenes/apple.tscn")
var current_apple = null

func _on_drop_timer_timeout() -> void:
	tree_sprite.region_rect = Rect2(88, 2.026, 25, 32.837)
	current_apple = apple.instantiate()
	get_parent().add_child(current_apple)
	
	current_apple.global_position = position + Vector2(50, 45)
	apple_ripe_timer.start()
	
	drop_timer.stop()
	recharge_timer.start()

func _on_recharge_timer_timeout() -> void:
	tree_sprite.region_rect = Rect2(48, 2.026, 25, 32.837)
	recharge_timer.stop()
	drop_timer.start()

func _on_apple_ripe_timer_timeout() -> void:
	if current_apple:
		current_apple.queue_free()
		current_apple = null
