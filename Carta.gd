extends Control

signal carta_seleccionada(objeto)

var valor = 0
var palo = ""
var seleccionada = false
var color_mazo = "blue"
var boca_abajo = false

var carpetas_palos = {
	"Corazon": "hearts", "Trebol": "clubs", "Pica": "spades", "Diamante": "diamonds", "Joker": "joker"
}

var nombres_palos_archivo = {
	"Corazon": "hearts", "Trebol": "clubs", "Pica": "spades", "Diamante": "diamonds", "Joker": "joker"
}

func configurar(v, p, col = "blue", oculta = false):
	valor = v
	palo = p
	color_mazo = col
	boca_abajo = oculta
	actualizar_visual()

func actualizar_visual():
	if not is_inside_tree(): await ready
	var textura_display = get_node_or_null("Imagen")
	if textura_display == null: return

	var ruta = ""
	if boca_abajo:
		ruta = "res://cards/back_" + color_mazo + ".png"
	else:
		var carpeta = carpetas_palos.get(palo, "")
		var nombre_palo_file = nombres_palos_archivo.get(palo, "")
		var sufijo = "" if seleccionada else "_white"
		
		if palo == "Joker":
			ruta = "res://cards/joker/joker" + sufijo + ".png"
		else:
			var valor_string = str(valor)
			if valor == 1: valor_string = "ace"
			elif valor == 11: valor_string = "jack"
			elif valor == 12: valor_string = "queen"
			elif valor == 13: valor_string = "king"
			ruta = "res://cards/" + carpeta + "/" + valor_string + "_" + nombre_palo_file + sufijo + ".png"

	if FileAccess.file_exists(ruta):
		textura_display.texture = load(ruta)
		textura_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		textura_display.visible = true

func alternar_seleccion():
	if boca_abajo: return 
	seleccionada = !seleccionada
	
	var tween = create_tween().set_parallel(true)
	var img = get_node("Imagen")
	
	if seleccionada:
		# Animación de Salto y Escala
		tween.tween_property(self, "position:y", -30, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
		
		# Animación de Temblor (Solo en la imagen para no romper el layout)
		var shake = create_tween()
		for i in range(3):
			shake.tween_property(img, "position:x", 4, 0.03)
			shake.tween_property(img, "position:x", -4, 0.03)
		shake.tween_property(img, "position:x", 0, 0.03)
	else:
		# Regreso suave
		tween.tween_property(self, "position:y", 0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	actualizar_visual()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			carta_seleccionada.emit(self)
