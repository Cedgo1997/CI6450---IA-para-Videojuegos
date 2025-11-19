extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("npc") or body.is_in_group("enemy"):
		pickup(body)

func pickup(collector):
	print(collector)
	queue_free()
