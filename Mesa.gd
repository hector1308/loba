extends CanvasLayer

@onready var ESCENA_CARTA = preload("res://Carta.tscn")

var mazo = []
var ya_robo = false
var cartas_seleccionadas = []

func _ready():
	generar_mazo_loba()
	mazo.shuffle()
	
	if not has_node("%ManoJugador"): return

	repartir_manos()
	preparar_pozo_inicial()
	configurar_interfaz_visual()
	
	if not %BotonMazo.pressed.is_connected(_on_boton_mazo_pressed):
		%BotonMazo.pressed.connect(_on_boton_mazo_pressed)
	if not %BotonAccion.pressed.is_connected(_on_boton_accion_pressed):
		%BotonAccion.pressed.connect(_on_boton_accion_pressed)
	
	actualizar_estado_botones()

func configurar_interfaz_visual():
	var padre = %ZonaCentral.get_parent()
	if padre is BoxContainer: padre.alignment = BoxContainer.ALIGNMENT_CENTER

	# Zona central fija para que el pozo no se mueva
	%ZonaCentral.custom_minimum_size = Vector2(520, 160)
	%ZonaCentral.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	if %ZonaCentral is BoxContainer:
		%ZonaCentral.alignment = BoxContainer.ALIGNMENT_CENTER
		%ZonaCentral.add_theme_constant_override("separation", 30)

	# Botones con tamaño fijo
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones:
		b.custom_minimum_size = Vector2(175, 50)
		b.clip_text = true 

	var containers = [%Jugadas_Arriba, %Jugadas_Izquierda, %Jugadas_Derecha]
	for c in containers:
		c.add_theme_constant_override("separation", 15)
		c.alignment = BoxContainer.ALIGNMENT_CENTER

	%ManoJugador.alignment = BoxContainer.ALIGNMENT_CENTER
	%ManoJugador.add_theme_constant_override("separation", 10)

func generar_mazo_loba():
	var palos = ["Corazon", "Diamante", "Trebol", "Pica"]
	mazo.clear() 
	for m in range(2):
		for p in palos:
			for v in range(1, 14): mazo.append({"valor": v, "palo": p})
		mazo.append({"valor": 0, "palo": "Joker"})
		mazo.append({"valor": 0, "palo": "Joker"})

func repartir_manos():
	for i in range(9):
		if mazo.size() > 0: crear_carta_en_contenedor(mazo.pop_back(), %ManoJugador)

func crear_carta_en_contenedor(datos, contenedor):
	var nueva_carta = ESCENA_CARTA.instantiate()
	contenedor.add_child(nueva_carta)
	nueva_carta.modulate = Color.WHITE 
	nueva_carta.configurar(datos.valor, datos.palo)
	
	if contenedor == %ManoJugador:
		nueva_carta.custom_minimum_size = Vector2(70, 95)
		if not nueva_carta.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			nueva_carta.carta_seleccionada.connect(_on_carta_tocada_en_mano)
	else:
		nueva_carta.custom_minimum_size = Vector2(55, 80)
		nueva_carta.scale = Vector2(0.6, 0.6)

func preparar_pozo_inicial():
	if mazo.size() > 0: actualizar_pozo_visual(mazo.pop_back())

func actualizar_pozo_visual(datos):
	var pozo_node = %ZonaCentral.find_child("Pozo", true, false)
	if pozo_node:
		pozo_node.custom_minimum_size = Vector2(70, 95)
		for hijo in pozo_node.get_children(): hijo.queue_free()
		var carta_en_pozo = ESCENA_CARTA.instantiate()
		pozo_node.add_child(carta_en_pozo)
		carta_en_pozo.configurar(datos.valor, datos.palo)

func _on_boton_mazo_pressed():
	if not ya_robo and mazo.size() > 0:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoJugador)
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
				c.scale = Vector2(1.0, 1.0)
				c.position.y = 0
				if c.seleccionada: c.alternar_seleccion()
			cartas_seleccionadas.clear()
			actualizar_estado_botones()

func _on_carta_tocada_en_mano(carta_objeto):
	if ya_robo:
		carta_objeto.alternar_seleccion() 
		if carta_objeto in cartas_seleccionadas:
			cartas_seleccionadas.erase(carta_objeto)
			carta_objeto.scale = Vector2(1.0, 1.0)
			carta_objeto.position.y = 0
		else:
			cartas_seleccionadas.append(carta_objeto)
			carta_objeto.scale = Vector2(1.1, 1.1)
			carta_objeto.position.y = -25
		actualizar_estado_botones()

func bajar_jugada_distribuida(lista):
	var containers = [%Jugadas_Arriba, %Jugadas_Izquierda, %Jugadas_Derecha]
	var destino = containers[0]
	for c in containers:
		if c.get_child_count() < destino.get_child_count(): destino = c
	
	# Contenedor invisible para facilitar el click de moje
	var area_click = PanelContainer.new()
	area_click.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	area_click.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var grupo_jugada = HBoxContainer.new()
	grupo_jugada.alignment = BoxContainer.ALIGNMENT_CENTER
	grupo_jugada.add_theme_constant_override("separation", 2)
	grupo_jugada.mouse_filter = Control.MOUSE_FILTER_PASS
	
	area_click.add_child(grupo_jugada)
	destino.add_child(area_click)
	
	area_click.gui_input.connect(_on_jugada_mesa_clicked.bind(grupo_jugada))
	
	var lista_ordenada = ordenar_con_joker(lista)
	
	for c in lista_ordenada:
		if c.get_parent(): c.get_parent().remove_child(c)
		grupo_jugada.add_child(c)
		c.seleccionada = false
		c.actualizar_visual() 
		c.scale = Vector2(0.6, 0.6)
		c.position.y = 0
		if c.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			c.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		c.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)

	cartas_seleccionadas.clear()
	actualizar_estado_botones()

func _on_jugada_mesa_clicked_desde_carta(carta_en_mesa):
	if ya_robo and cartas_seleccionadas.size() == 1:
		intentar_moje(cartas_seleccionadas[0], carta_en_mesa.get_parent())

func _on_jugada_mesa_clicked(event, contenedor_jugada):
	if event is InputEventMouseButton and event.pressed:
		if ya_robo and cartas_seleccionadas.size() == 1:
			intentar_moje(cartas_seleccionadas[0], contenedor_jugada)

func intentar_moje(carta_mano, contenedor):
	var cartas_en_mesa = contenedor.get_children()
	if cartas_en_mesa.size() < 1: return
	
	var normales_en_mesa = []
	for c in cartas_en_mesa:
		if c.valor != 0: normales_en_mesa.append(c)
	
	if normales_en_mesa.size() == 0: return 

	var v_ref = normales_en_mesa[0].valor
	var es_pierna = true
	for c in normales_en_mesa:
		if c.valor != v_ref: es_pierna = false; break
	
	var exito = false
	if es_pierna:
		# REGLA: No Joker en pierna. Solo mismo valor y palo ya existente (doblar).
		if carta_mano.valor != 0 and carta_mano.valor == v_ref:
			var palos_en_mesa = []
			for c in normales_en_mesa: palos_en_mesa.append(c.palo)
			if carta_mano.palo in palos_en_mesa: exito = true
	else:
		# Escalera: mismo palo, correlativas, permite Joker.
		var lista_temp = []
		for c in cartas_en_mesa: lista_temp.append(c)
		lista_temp.append(carta_mano)
		if es_jugada_valida(lista_temp): exito = true

	if exito:
		carta_mano.get_parent().remove_child(carta_mano)
		contenedor.add_child(carta_mano)
		var lista_final = ordenar_con_joker(contenedor.get_children())
		for i in range(lista_final.size()):
			contenedor.move_child(lista_final[i], i)
		
		carta_mano.seleccionada = false
		carta_mano.actualizar_visual()
		carta_mano.scale = Vector2(0.6, 0.6)
		carta_mano.position.y = 0
		if carta_mano.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			carta_mano.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		carta_mano.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)
			
		cartas_seleccionadas.clear()
		ya_robo = true 
		actualizar_estado_botones()

func es_jugada_valida(lista):
	var normales = []
	var jokers = 0
	for c in lista:
		if c.valor == 0: jokers += 1
		else: normales.append(c)
	if normales.size() == 0: return false
	
	var v_ref = normales[0].valor
	var es_pierna_p = true
	var palos = []
	for c in normales:
		if c.valor != v_ref: es_pierna_p = false; break
		if not c.palo in palos: palos.append(c.palo)
	
	if es_pierna_p:
		# Al bajar piernas: sin jokers y palos distintos.
		if jokers > 0: return false
		return normales.size() >= 3 and normales.size() == palos.size()
	
	# Escalera: mismo palo, sin repetir número, huecos cubiertos por jokers.
	normales.sort_custom(func(a, b): return a.valor < b.valor)
	var p_ref = normales[0].palo
	var huecos = 0
	for i in range(normales.size()):
		if normales[i].palo != p_ref: return false
		if i > 0:
			var d = normales[i].valor - normales[i-1].valor
			if d == 0: return false
			huecos += (d - 1)
	return jokers >= huecos

func ordenar_con_joker(lista):
	var normales = []
	var jokers = []
	for c in lista:
		if c.valor == 0: jokers.append(c)
		else: normales.append(c)
	normales.sort_custom(func(a, b): return a.valor < b.valor)
	
	if normales.size() > 1 and normales[0].valor == normales[-1].valor:
		return normales + jokers # Pierna
	
	if normales.size() > 0:
		var resultado = []
		var v_esp = normales[0].valor
		var i = 0
		while i < normales.size() or jokers.size() > 0:
			if i < normales.size() and normales[i].valor == v_esp:
				resultado.append(normales[i]); i += 1
			elif jokers.size() > 0:
				resultado.append(jokers.pop_back())
			else:
				if i < normales.size(): resultado.append(normales[i]); i += 1
				else: break
			v_esp += 1
		return resultado
	return normales + jokers

func actualizar_estado_botones():
	%BotonMazo.disabled = ya_robo
	var cant = cartas_seleccionadas.size()
	if not ya_robo:
		%BotonAccion.text = "ROBÁ"
		%BotonAccion.disabled = true
	else:
		if cant == 0: %BotonAccion.text = "ELEGÍ DESCARTAR"; %BotonAccion.disabled = true
		elif cant == 1: %BotonAccion.text = "DESCARTAR"; %BotonAccion.disabled = false
		elif cant >= 3: %BotonAccion.text = "BAJAR JUGADA"; %BotonAccion.disabled = false
		else: %BotonAccion.text = "FALTAN"; %BotonAccion.disabled = true
