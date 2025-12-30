extends Control

func _ready():
	%InputNombre.grab_focus()
	
	# El botón arranca apagado hasta que escribas algo
	%BotonIniciar.disabled = true

# Esta función se ejecuta cada vez que escribes una letra
func _on_input_nombre_text_changed(new_text):
	# strip_edges() quita los espacios al inicio y final.
	# Si el texto está vacío, disabled será true (botón apagado).
	# Si hay texto, disabled será false (botón prendido).
	%BotonIniciar.disabled = new_text.strip_edges().is_empty()

func _on_boton_iniciar_pressed():
	var nombre = %InputNombre.text.strip_edges()
	
	# Doble seguridad, aunque el botón debería impedirlo
	if nombre == "": return
	
	Global.nombre_jugador = nombre
	get_tree().change_scene_to_file("res://Mesa.tscn")

func _input(event):
	# Permitir iniciar con ENTER solo si el botón está habilitado
	if event.is_action_pressed("ui_accept"):
		if not %BotonIniciar.disabled:
			_on_boton_iniciar_pressed()
