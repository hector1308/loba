extends Control

signal carta_seleccionada(objeto)

var valor = 0
var palo = ""
var seleccionada = false

# Diccionarios para carpetas y nombres de palos
var carpetas_palos = {
	"Corazon": "hearts",
	"Trebol": "clubs",
	"Pica": "spades",
	"Diamante": "diamonds",
	"Joker": "joker"
}

var nombres_palos_archivo = {
	"Corazon": "hearts",
	"Trebol": "clubs",
	"Pica": "spades",
	"Diamante": "diamonds",
	"Joker": "joker"
}

func configurar(v, p):
	valor = v
	palo = p
	actualizar_visual()

func actualizar_visual():
	if not is_inside_tree(): await ready
	
	var textura_display = get_node_or_null("Imagen")
	if textura_display == null: return

	var carpeta = carpetas_palos.get(palo, "")
	var nombre_palo_file = nombres_palos_archivo.get(palo, "")
	var sufijo = "" if seleccionada else "_white"
	var ruta = ""

	# --- LÓGICA DE TRADUCCIÓN DE VALORES ---
	if palo == "Joker":
		# Ruta: res://cards/joker/joker.png o joker_white.png
		ruta = "res://cards/joker/joker" + sufijo + ".png"
	else:
		var valor_string = str(valor)
		if valor == 1: valor_string = "ace"
		elif valor == 11: valor_string = "jack"
		elif valor == 12: valor_string = "queen"
		elif valor == 13: valor_string = "king"
		
		# Ruta: res://cards/palo/ace_palo_white.png
		ruta = "res://cards/" + carpeta + "/" + valor_string + "_" + nombre_palo_file + sufijo + ".png"

	# Carga de la imagen
	if FileAccess.file_exists(ruta):
		textura_display.texture = load(ruta)
		textura_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		print("--- CARTA NO ENCONTRADA ---")
		print("Ruta buscada: ", ruta)

func alternar_seleccion():
	seleccionada = !seleccionada
	actualizar_visual()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			carta_seleccionada.emit(self)
