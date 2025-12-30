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
	animar_movimiento_seleccion()

# === NUEVA FUNCIÓN: Forzar deselección con animación de retorno ===
func deseleccionar():
	if not seleccionada: return
	seleccionada = false
	animar_movimiento_seleccion()

func animar_movimiento_seleccion():
	var tween = create_tween().set_parallel(true)
	if seleccionada:
		tween.tween_property(self, "position:y", -30, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)
	else:
		# Animación de "rebote" suave al volver a la mano
		tween.tween_property(self, "position:y", 0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	actualizar_visual()

# === DETECTAR SI EL ARRASTRE FALLÓ (DROP EN EL VACÍO) ===
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# is_drag_successful() es falso si soltaste la carta fuera de una zona válida
		if not is_drag_successful() and seleccionada:
			deseleccionar()
			# Si la mesa tiene esta carta en la lista de seleccionadas, hay que avisarle que la quite
			# (Esto se maneja mejor desde Mesa.gd, pero visualmente la carta ya baja)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			carta_seleccionada.emit(self)

func _get_drag_data(_at_position):
	if get_parent().name == "MazoVisual":
		var preview = _crear_preview()
		set_drag_preview(preview)
		return { "origen": "mazo" }
	
	if not boca_abajo and get_parent().name == "ManoJugador":
		if not seleccionada:
			carta_seleccionada.emit(self)
		var preview = _crear_preview()
		set_drag_preview(preview)
		return { "origen": "mano", "carta": self }
	return null

func _crear_preview():
	var preview_control = Control.new()
	preview_control.z_index = 4096 
	
	var img = TextureRect.new()
	img.texture = get_node("Imagen").texture
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.size = Vector2(70, 95)
	img.position = Vector2(-35, -47.5)
	img.modulate.a = 0.9
	img.rotation_degrees = 5
	
	preview_control.add_child(img)
	return preview_control
