extends Node2D

func _ready() -> void:
	$opened.visible = false
	$closed.visible = true 
	
	# Crear el label del mensaje en un CanvasLayer para que esté en coordenadas de pantalla
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "MessageCanvasLayer"
	add_child(canvas_layer)
	
	var label = Label.new()
	label.name = "MessageLabel"
	label.text = "¡Tesoro conseguido!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(1, 1, 1, 0)
	
	# Configurar el label para que se adapte al ancho de la pantalla
	var viewport_size = get_viewport_rect().size
	label.position = Vector2(0, 50)  # 50 píxeles desde arriba
	label.size = Vector2(viewport_size.x, 0)  # Ancho completo de la pantalla
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	canvas_layer.add_child(label)


func _on_key_chest_opened() -> void:
	$opened.visible = true
	$closed.visible = false
	show_message()
	
func show_message():
	var canvas_layer = $MessageCanvasLayer
	if not canvas_layer:
		return
	
	var label = canvas_layer.get_node_or_null("MessageLabel")
	if label:
		# Actualizar tamaño y posición del label basándose en el tamaño de la pantalla
		var viewport_size = get_viewport_rect().size
		label.size = Vector2(viewport_size.x, 0)  # Ancho completo de la pantalla
		
		# Posición inicial (centrado horizontalmente, arriba)
		label.position = Vector2(0, 50)
		
		# Animación de aparición
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "modulate:a", 1.0, 0.3)
		tween.tween_property(label, "position:y", 30, 0.3)  # Se mueve ligeramente hacia abajo
		
		# Esperar 2 segundos y luego desaparecer
		await get_tree().create_timer(2.3).timeout
		
		# Animación de desaparición
		var tween_out = create_tween()
		tween_out.set_parallel(true)
		tween_out.tween_property(label, "modulate:a", 0.0, 0.3)
		tween_out.tween_property(label, "position:y", 10, 0.3)  # Se mueve ligeramente hacia arriba 
