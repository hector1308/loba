extends Control

signal carta_seleccionada(referencia_carta)

var valor: int = 1
var palo: String = ""
var seleccionada: bool = false

# Esta es la función clave que cambia el texto
func configurar(nuevo_valor: int, nuevo_palo: String):
	valor = nuevo_valor
	palo = nuevo_palo
	
	var texto_v = str(valor)
	if valor == 1: texto_v = "A"
	elif valor == 11: texto_v = "J"
	elif valor == 12: texto_v = "Q"
	elif valor == 13: texto_v = "K"
	elif valor == 0: texto_v = "JK"
	
	# Cambiamos los textos. 
	# IMPORTANTE: Asegúrate de que los nodos se llamen igual en la escena.
	$NumeroLabel.text = texto_v
	$PaloLabel.text = nuevo_palo
	
	# OPCIONAL: Poner color rojo a Corazones y Diamantes
	if palo == "Corazon" or palo == "Diamante":
		$NumeroLabel.modulate = Color.RED
		$PaloLabel.modulate = Color.RED
	else:
		$NumeroLabel.modulate = Color.BLACK
		$PaloLabel.modulate = Color.BLACK

func alternar_seleccion():
	seleccionada = !seleccionada
	if seleccionada:
		position.y -= 30 
		modulate = Color(0.8, 1, 0.8) 
	else:
		position.y += 30 
		modulate = Color.WHITE

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			carta_seleccionada.emit(self)
