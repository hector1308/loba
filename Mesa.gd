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
	
	configurar_botones_visual()
	$ManoJugador.add_theme_constant_override("separation", 15)
	
	if not %BotonMazo.pressed.is_connected(_on_boton_mazo_pressed):
		%BotonMazo.pressed.connect(_on_boton_mazo_pressed)
	if not %BotonAccion.pressed.is_connected(_on_boton_accion_pressed):
		%BotonAccion.pressed.connect(_on_boton_accion_pressed)
	
	actualizar_estado_botones()

func configurar_botones_visual():
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones:
		b.custom_minimum_size = Vector2(160, 50)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func generar_mazo_loba():
	var palos = ["Corazon", "Diamante", "Trebol", "Pica"]
	mazo.clear() 
	for m in range(2):
		for p in palos:
			for v in range(1, 14):
				mazo.append({"valor": v, "palo": p})
		mazo.append({"valor": 0, "palo": "Joker"})
		mazo.append({"valor": 0, "palo": "Joker"})

func repartir_manos():
	for i in range(9):
		var datos = mazo.pop_back()
		crear_carta_en_contenedor(datos, $ManoJugador)

func crear_carta_en_contenedor(datos, contenedor):
	var nueva_carta = ESCENA_CARTA.instantiate()
	contenedor.add_child(nueva_carta)
	nueva_carta.configurar(datos.valor, datos.palo)
	nueva_carta.custom_minimum_size = Vector2(100, 140)
	
	if contenedor == $ManoJugador:
		if not nueva_carta.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			nueva_carta.carta_seleccionada.connect(_on_carta_tocada_en_mano)

func preparar_pozo_inicial():
	if mazo.size() > 0:
		actualizar_pozo_visual(mazo.pop_back())

func actualizar_pozo_visual(datos):
	for hijo in $ZonaCentral/Pozo.get_children(): hijo.queue_free()
	var carta_en_pozo = ESCENA_CARTA.instantiate()
	$ZonaCentral/Pozo.add_child(carta_en_pozo)
	carta_en_pozo.configurar(datos.valor, datos.palo)

func _on_boton_mazo_pressed():
	if not ya_robo and mazo.size() > 0:
		var datos = mazo.pop_back()
		crear_carta_en_contenedor(datos, $ManoJugador)
		ya_robo = true
		actualizar_estado_botones()

func _on_boton_accion_pressed():
	var cant = cartas_seleccionadas.size()
	if cant == 1:
		var carta = cartas_seleccionadas[0]
		actualizar_pozo_visual({"valor": carta.valor, "palo": carta.palo})
		carta.queue_free()
		cartas_seleccionadas.clear()
		ya_robo = false
		actualizar_estado_botones()
	elif cant >= 3:
		if es_jugada_valida(cartas_seleccionadas):
			bajar_jugada_distribuida(cartas_seleccionadas)
		else:
			for c in cartas_seleccionadas:
				c.modulate = Color.WHITE
				c.scale = Vector2(1, 1)
				if c.seleccionada: c.alternar_seleccion()
			cartas_seleccionadas.clear()
			actualizar_estado_botones()

func _on_carta_tocada_en_mano(carta_objeto):
	if ya_robo:
		if carta_objeto in cartas_seleccionadas:
			cartas_seleccionadas.erase(carta_objeto)
			carta_objeto.modulate = Color.WHITE
			carta_objeto.scale = Vector2(1, 1)
		else:
			cartas_seleccionadas.append(carta_objeto)
			carta_objeto.modulate = Color(0, 1, 1) 
			carta_objeto.scale = Vector2(1.1, 1.1)
		
		carta_objeto.alternar_seleccion()
		actualizar_estado_botones()

func bajar_jugada_distribuida(lista):
	var containers = [%Jugadas_Arriba, %Jugadas_Izquierda, %Jugadas_Derecha]
	var destino = containers[0]
	for c in containers:
		if c.get_child_count() < destino.get_child_count():
			destino = c
	
	var contenedor_individual = HBoxContainer.new()
	contenedor_individual.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor_individual.add_theme_constant_override("separation", 10) 
	contenedor_individual.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	contenedor_individual.mouse_filter = Control.MOUSE_FILTER_STOP
	contenedor_individual.gui_input.connect(_on_jugada_mesa_clicked.bind(contenedor_individual))
	destino.add_child(contenedor_individual)

	# --- LÓGICA DE ORDENAMIENTO ESPECIAL PARA JOKERS ---
	var lista_ordenada = ordenar_con_joker(lista)
	
	for c in lista_ordenada:
		c.get_parent().remove_child(c)
		contenedor_individual.add_child(c)
		c.seleccionada = false
		c.modulate = Color.WHITE
		c.scale = Vector2(0.75, 0.75) 
		c.custom_minimum_size = Vector2(85, 120) 
		
		if c.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			c.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		if not c.carta_seleccionada.is_connected(_on_jugada_mesa_clicked_desde_carta):
			c.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)

	cartas_seleccionadas.clear()
	actualizar_estado_botones()

func ordenar_con_joker(lista):
	var normales = []
	var jokers = []
	for c in lista:
		if c.valor == 0: jokers.append(c)
		else: normales.append(c)
	
	normales.sort_custom(func(a, b): return a.valor < b.valor)
	
	# Si no hay jokers, devolvemos la lista normal ordenada
	if jokers.size() == 0: return normales
	
	# Es pierna (todos mismo valor): el joker va al final
	if normales.size() > 0 and normales[0].valor == normales[-1].valor:
		return normales + jokers
	
	# Es escalera: buscar el hueco para el joker
	var resultado = []
	if normales.size() > 0:
		var v_actual = normales[0].valor
		var i_norm = 0
		
		while i_norm < normales.size() or jokers.size() > 0:
			if i_norm < normales.size() and normales[i_norm].valor == v_actual:
				resultado.append(normales[i_norm])
				i_norm += 1
			elif jokers.size() > 0:
				resultado.append(jokers.pop_back())
			else:
				break
			v_actual += 1
	return resultado

func _on_jugada_mesa_clicked_desde_carta(carta_en_mesa):
	var contenedor = carta_en_mesa.get_parent()
	if ya_robo and cartas_seleccionadas.size() == 1:
		intentar_moje(cartas_seleccionadas[0], contenedor)

func _on_jugada_mesa_clicked(event, contenedor_jugada):
	if event is InputEventMouseButton and event.pressed:
		if ya_robo and cartas_seleccionadas.size() == 1:
			intentar_moje(cartas_seleccionadas[0], contenedor_jugada)

func intentar_moje(carta_mano, contenedor):
	var cartas_en_mesa = contenedor.get_children()
	if cartas_en_mesa.size() < 2: return
	
	var es_pierna = (cartas_en_mesa[0].valor == cartas_en_mesa[1].valor and cartas_en_mesa[0].valor != 0)
	var exito = false
	
	if es_pierna:
		if carta_mano.valor == cartas_en_mesa[0].valor:
			var palos_p = []
			for i in range(min(cartas_en_mesa.size(), 3)):
				if cartas_en_mesa[i].valor != 0: palos_p.append(cartas_en_mesa[i].palo)
			if carta_mano.palo in palos_p: exito = true
	else:
		# Lógica Moje Escalera (considerando Joker en la mesa)
		var palo_ref = ""
		for c in cartas_en_mesa:
			if c.valor != 0: palo_ref = c.palo; break
		
		if carta_mano.palo == palo_ref:
			var lista_temp = cartas_en_mesa + [carta_mano]
			if es_jugada_valida(lista_temp): exito = true
			
	if exito:
		carta_mano.get_parent().remove_child(carta_mano)
		contenedor.add_child(carta_mano)
		var lista_final = ordenar_con_joker(contenedor.get_children())
		for i in range(lista_final.size()):
			contenedor.move_child(lista_final[i], i)
		
		carta_mano.seleccionada = false
		carta_mano.modulate = Color.WHITE
		carta_mano.scale = Vector2(0.75, 0.75)
		carta_mano.custom_minimum_size = Vector2(85, 120)
		
		if carta_mano.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			carta_mano.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		if not carta_mano.carta_seleccionada.is_connected(_on_jugada_mesa_clicked_desde_carta):
			carta_mano.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)
		cartas_seleccionadas.clear()
		actualizar_estado_botones()

func es_jugada_valida(lista):
	var normales = []
	var cantidad_jokers = 0
	for c in lista:
		if c.valor == 0: cantidad_jokers += 1
		else: normales.append(c)
	if normales.size() == 0: return false
	
	# Pierna
	var es_pierna_potencial = true
	var v_ref = normales[0].valor
	var palos_en_jugada = []
	for c in normales:
		if c.valor != v_ref: es_pierna_potencial = false; break
		if not c.palo in palos_en_jugada: palos_en_jugada.append(c.palo)
	
	if es_pierna_potencial:
		if cantidad_jokers > 0: return false 
		if palos_en_jugada.size() > 3: return false
		if palos_en_jugada.size() < 3: return false
		return true

	# Escalera
	normales.sort_custom(func(a, b): return a.valor < b.valor)
	var p_ref = normales[0].palo
	var huecos = 0
	for i in range(normales.size()):
		if normales[i].palo != p_ref: return false
		if i > 0:
			var d = normales[i].valor - normales[i-1].valor
			if d == 0: return false
			huecos += (d - 1)
	return cantidad_jokers >= huecos

func actualizar_estado_botones():
	if not has_node("%BotonMazo") or not has_node("%BotonAccion"): return
	%BotonMazo.disabled = ya_robo
	var cant = cartas_seleccionadas.size()
	if not ya_robo:
		%BotonAccion.text = "ROBÁ"
		%BotonAccion.disabled = true
	else:
		if cant == 0: %BotonAccion.text = "ELEGÍ"; %BotonAccion.disabled = true
		elif cant == 1: %BotonAccion.text = "DESCARTAR"; %BotonAccion.disabled = false
		elif cant >= 3: %BotonAccion.text = "BAJAR JUGADA"; %BotonAccion.disabled = false
		else: %BotonAccion.text = "FALTAN"; %BotonAccion.disabled = true
