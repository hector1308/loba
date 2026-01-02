extends Control

signal carta_seleccionada(objeto)

var valor = 0
var palo = ""
var seleccionada = false
var color_mazo = "blue"
var boca_abajo = false
var debug_label: Label 

func _ready():
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.add_theme_color_override("font_color", Color.RED)
	debug_label.position = Vector2(0, 20)
	debug_label.z_index = 10
	add_child(debug_label)

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
	
	debug_label.text = "" 

	var ruta = ""
	
	var p_min = palo.to_lower()
	if p_min == "corazon": p_min = "hearts"
	elif p_min == "diamante": p_min = "diamonds"
	elif p_min == "trebol": p_min = "clubs"
	elif p_min == "pica": p_min = "spades"
	
	var nombre_carpeta = p_min
	var nombre_archivo = p_min
	
	if boca_abajo:
		ruta = "res://cards/back_" + color_mazo + ".png"
	elif p_min == "joker":
		ruta = "res://cards/joker/joker.png"
	else:
		var v_str = str(valor)
		var es_figura = false
		
		if valor == 1: v_str = "ace"
		elif valor == 11: 
			v_str = "jack"
			es_figura = true
		elif valor == 12: 
			v_str = "queen"
			es_figura = true
		elif valor == 13: 
			v_str = "king"
			es_figura = true
		
		# --- SELECCIÓN DE IMAGEN ---
		if es_figura:
			# Para J, Q, K seguimos buscando la versión "_ok" (si así las nombraste)
			# Si tus figuras TAMBIÉN son "_white", cambia "_ok.png" por "_white.png" aquí abajo
			ruta = "res://cards/" + nombre_carpeta + "/" + v_str + "_" + nombre_archivo + "_ok.png"
		else:
			# Para los números (2, 3... 10, Ace), ahora buscamos la versión WHITE
			ruta = "res://cards/" + nombre_carpeta + "/" + v_str + "_" + nombre_archivo + "_white.png"

	var textura_cargada = load(ruta)
	
	if textura_cargada:
		textura_display.texture = textura_cargada
		textura_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		textura_display.visible = true
		textura_display.modulate = Color(1,1,1)
	else:
		# Fallback por seguridad: intentamos cargar sin _white ni _ok si falla
		var ruta_backup = ruta.replace("_white.png", ".png").replace("_ok.png", ".png")
		textura_cargada = load(ruta_backup)
		
		if textura_cargada:
			textura_display.texture = textura_cargada
			textura_display.visible = true
		else:
			textura_display.texture = load("res://icon.svg")
			debug_label.text = "Falta: " + ruta.replace("res://cards/", "") 
			print("ERROR: No se encontró ", ruta)

	if not boca_abajo and seleccionada:
		textura_display.modulate = Color(1, 1, 1)
	elif not boca_abajo:
		textura_display.modulate = Color(0.9, 0.9, 0.9)

func alternar_seleccion():
	if boca_abajo: return 
	seleccionada = !seleccionada
	animar_movimiento_seleccion()

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
		tween.tween_property(self, "position:y", 0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if not is_drag_successful() and seleccionada:
			deseleccionar()

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
	img.size = Vector2(120, 170) 
	img.position = Vector2(-60, -85) 
	img.rotation_degrees = 5
	preview_control.add_child(img)
	return preview_control
