extends CanvasLayer

@onready var ESCENA_CARTA = preload("res://Carta.tscn")

var mazo = []
var ya_robo = false
var cartas_seleccionadas = []

func _ready():
	generar_mazo_loba()
	mazo.shuffle()
	repartir_manos()
	preparar_pozo_inicial()
	configurar_interfaz_visual()
	
	if not %BotonMazo.pressed.is_connected(_on_boton_mazo_pressed):
		%BotonMazo.pressed.connect(_on_boton_mazo_pressed)
	if not %BotonAccion.pressed.is_connected(_on_boton_accion_pressed):
		%BotonAccion.pressed.connect(_on_boton_accion_pressed)
	actualizar_estado_botones()

func configurar_interfaz_visual():
	var principal = %ManoJugador.get_parent()
	if principal is BoxContainer:
		principal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		principal.add_theme_constant_override("separation", 0)

	if has_node("%ManoRival"):
		%ManoRival.custom_minimum_size.y = 100
		%ManoRival.alignment = BoxContainer.ALIGNMENT_CENTER
		%ManoRival.add_theme_constant_override("separation", -45)

	if has_node("LadoRival"):
		get_node("LadoRival").size_flags_vertical = Control.SIZE_EXPAND_FILL
		get_node("LadoRival").size_flags_stretch_ratio = 1.0

	# ZONA CENTRAL: Ajustada para que el pozo grande quepa bien
	%ZonaCentral.custom_minimum_size.y = 140 
	%ZonaCentral.alignment = BoxContainer.ALIGNMENT_CENTER
	%ZonaCentral.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if has_node("LadoJugador"):
		var lj = get_node("LadoJugador")
		lj.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lj.size_flags_stretch_ratio = 1.0 
		if lj is BoxContainer: lj.alignment = BoxContainer.ALIGNMENT_CENTER

	# ESPACIADOR (El muro de seguridad)
	if not principal.has_node("GranEspaciador"):
		var esp = Control.new()
		esp.name = "GranEspaciador"
		esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		esp.size_flags_stretch_ratio = 4.0 
		principal.add_child(esp)
		principal.move_child(esp, principal.get_child_count() - 1)

	%ManoJugador.custom_minimum_size.y = 130
	%ManoJugador.size_flags_vertical = Control.SIZE_SHRINK_END
	%ManoJugador.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones: b.custom_minimum_size = Vector2(170, 50)

# --- LÓGICA DE ACTUALIZACIÓN DEL POZO (CAMBIO AQUÍ) ---

func actualizar_pozo_visual(datos):
	var pozo_node = %ZonaCentral.find_child("Pozo", true, false)
	if pozo_node:
		for h in pozo_node.get_children(): h.queue_free()
		var carta_p = ESCENA_CARTA.instantiate()
		pozo_node.add_child(carta_p)
		# Sincronizamos con el tamaño de tu mano (1.0 escala y 70x95)
		carta_p.configurar(datos.valor, datos.palo, datos.color, false)
		carta_p.scale = Vector2(1.0, 1.0) 
		carta_p.custom_minimum_size = Vector2(70, 95)
		pozo_node.custom_minimum_size = Vector2(70, 95)

# --- LÓGICA DE MOJE Y REGLAS (PRESERVADA) ---

func intentar_moje(carta_mano, contenedor):
	var cartas_en_mesa = contenedor.get_children()
	var es_escalera = es_jugada_escalera(cartas_en_mesa)
	var exito = false
	
	if es_escalera:
		var lista_prueba = []
		for c in cartas_en_mesa: lista_prueba.append(c)
		lista_prueba.append(carta_mano)
		if es_jugada_valida(lista_prueba): exito = true
	else:
		if carta_mano.valor != 0:
			var v_ref = 0
			var palos_en_mesa = []
			for c in cartas_en_mesa:
				if c.valor != 0: 
					v_ref = c.valor
					palos_en_mesa.append(c.palo)
			if carta_mano.valor == v_ref and carta_mano.palo in palos_en_mesa:
				exito = true

	if exito:
		ejecutar_movimiento_moje(carta_mano, contenedor)

func ejecutar_movimiento_moje(carta_mano, contenedor):
	if carta_mano.get_parent(): carta_mano.get_parent().remove_child(carta_mano)
	contenedor.add_child(carta_mano)
	var lista_ordenada = ordenar_con_joker(contenedor.get_children())
	for i in range(lista_ordenada.size()):
		contenedor.move_child(lista_ordenada[i], i)
	
	carta_mano.seleccionada = false
	carta_mano.actualizar_visual()
	carta_mano.scale = Vector2(0.6, 0.6)
	carta_mano.position.y = 0
	
	if carta_mano.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
		carta_mano.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
	if not carta_mano.carta_seleccionada.is_connected(_on_jugada_mesa_clicked_desde_carta):
		carta_mano.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)
	cartas_seleccionadas.clear()
	actualizar_estado_botones()

func es_jugada_valida(lista):
	if lista.size() < 3: return false
	var normales = []; var jokers = 0
	for c in lista:
		if c.valor == 0: jokers += 1
		else: normales.append(c)
	if normales.size() == 0: return jokers >= 3
	
	var v_ref = normales[0].valor
	var mismo_valor = true; var misma_palo = true; var p_ref = normales[0].palo
	for c in normales:
		if c.valor != v_ref: mismo_valor = false
		if c.palo != p_ref: misma_palo = false
	
	if mismo_valor: return jokers <= 1 
	if misma_palo:
		normales.sort_custom(func(a, b): return a.valor < b.valor)
		var huecos = 0
		for i in range(1, normales.size()):
			var diff = normales[i].valor - normales[i-1].valor
			if diff == 0: return false
			huecos += (diff - 1)
		return jokers >= huecos
	return false

func es_jugada_escalera(lista):
	var palos = []
	for c in lista:
		if c.valor != 0 and not c.palo in palos: palos.append(c.palo)
	return palos.size() == 1

func ordenar_con_joker(lista):
	var normales = []; var jokers = []
	for c in lista:
		if c.valor == 0: jokers.append(c)
		else: normales.append(c)
	normales.sort_custom(func(a, b): return a.valor < b.valor)
	if normales.size() > 1 and normales[0].valor == normales[-1].valor:
		return normales + jokers
	
	var resultado = []
	if normales.size() > 0:
		var v_min = normales[0].valor; var v_max = normales[-1].valor
		var puntero = v_min; var idx_norm = 0
		while puntero <= v_max:
			if idx_norm < normales.size() and normales[idx_norm].valor == puntero:
				resultado.append(normales[idx_norm]); idx_norm += 1
			elif jokers.size() > 0: resultado.append(jokers.pop_back())
			puntero += 1
		while jokers.size() > 0:
			if v_max < 13: resultado.append(jokers.pop_back()); v_max += 1
			elif v_min > 1: resultado.push_front(jokers.pop_back()); v_min -= 1
			else: resultado.append(jokers.pop_back())
	return resultado

# --- RESTO DE FUNCIONES ---

func generar_mazo_loba():
	mazo.clear() 
	for col in ["blue", "red"]:
		for p in ["Corazon", "Diamante", "Trebol", "Pica"]:
			for v in range(1, 14): mazo.append({"valor": v, "palo": p, "color": col})
		for j in range(2): mazo.append({"valor": 0, "palo": "Joker", "color": col})

func repartir_manos():
	for i in range(9):
		if mazo.size() > 0: crear_carta_en_contenedor(mazo.pop_back(), %ManoJugador, false)
	if has_node("%ManoRival"):
		for i in range(9):
			if mazo.size() > 0: crear_carta_en_contenedor(mazo.pop_back(), %ManoRival, true)

func crear_carta_en_contenedor(datos, contenedor, oculta = false):
	var nueva_carta = ESCENA_CARTA.instantiate()
	contenedor.add_child(nueva_carta)
	nueva_carta.configurar(datos.valor, datos.palo, datos.color, oculta)
	if contenedor == %ManoJugador:
		nueva_carta.custom_minimum_size = Vector2(70, 95)
		nueva_carta.carta_seleccionada.connect(_on_carta_tocada_en_mano)
	else:
		nueva_carta.custom_minimum_size = Vector2(55, 80)
		nueva_carta.scale = Vector2(0.6, 0.6)

func preparar_pozo_inicial():
	if mazo.size() > 0: actualizar_pozo_visual(mazo.pop_back())

func _on_carta_tocada_en_mano(carta_objeto):
	if ya_robo:
		carta_objeto.alternar_seleccion() 
		if carta_objeto in cartas_seleccionadas: cartas_seleccionadas.erase(carta_objeto)
		else: cartas_seleccionadas.append(carta_objeto)
		actualizar_estado_botones()

func _on_boton_mazo_pressed():
	if not ya_robo and mazo.size() > 0:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoJugador, false)
		ya_robo = true; actualizar_estado_botones()

func _on_boton_accion_pressed():
	if cartas_seleccionadas.size() == 1:
		var c = cartas_seleccionadas[0]
		actualizar_pozo_visual({"valor": c.valor, "palo": c.palo, "color": c.color_mazo})
		c.queue_free(); cartas_seleccionadas.clear(); ya_robo = false; actualizar_estado_botones()
	elif cartas_seleccionadas.size() >= 3:
		if es_jugada_valida(cartas_seleccionadas): bajar_jugada_distribuida(cartas_seleccionadas)

func bajar_jugada_distribuida(lista):
	var containers = [%Jugadas_Arriba, %Jugadas_Izquierda, %Jugadas_Derecha]
	var destino = containers[0]
	for c in containers:
		if c.get_child_count() < destino.get_child_count(): destino = c
	var grupo = HBoxContainer.new()
	grupo.alignment = BoxContainer.ALIGNMENT_CENTER
	destino.add_child(grupo)
	grupo.gui_input.connect(_on_jugada_mesa_clicked.bind(grupo))
	for c in ordenar_con_joker(lista):
		if c.get_parent(): c.get_parent().remove_child(c)
		grupo.add_child(c)
		c.seleccionada = false; c.actualizar_visual(); c.scale = Vector2(0.6, 0.6); c.position.y = 0
		if c.carta_seleccionada.is_connected(_on_carta_tocada_en_mano): c.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		c.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)
	cartas_seleccionadas.clear(); actualizar_estado_botones()

func _on_jugada_mesa_clicked_desde_carta(carta_en_mesa):
	if ya_robo and cartas_seleccionadas.size() == 1: intentar_moje(cartas_seleccionadas[0], carta_en_mesa.get_parent())

func _on_jugada_mesa_clicked(event, contenedor_jugada):
	if event is InputEventMouseButton and event.pressed:
		if ya_robo and cartas_seleccionadas.size() == 1: intentar_moje(cartas_seleccionadas[0], contenedor_jugada)

func actualizar_estado_botones():
	%BotonMazo.disabled = ya_robo
	var cant = cartas_seleccionadas.size()
	if not ya_robo: %BotonAccion.text = "ROBÁ"; %BotonAccion.disabled = true
	else:
		if cant == 1: %BotonAccion.text = "DESCARTAR"; %BotonAccion.disabled = false
		elif cant >= 3: %BotonAccion.text = "BAJAR"; %BotonAccion.disabled = false
		else: %BotonAccion.text = "ELEGÍ..."; %BotonAccion.disabled = true
