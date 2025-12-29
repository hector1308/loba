extends CanvasLayer

@onready var ESCENA_CARTA = preload("res://Carta.tscn")

# REFERENCIAS AL RIVAL
@onready var zona_rival_arriba = %JugadasRival_Arriba
@onready var zona_rival_izq = %JugadasRival_Izquierda
@onready var zona_rival_der = %JugadasRival_Derecha

var mazo = []
var ya_robo = false
var cartas_seleccionadas = []
var turno_jugador = true
var indice_rotacion_rival = 0 
var juego_terminado = false

var datos_carta_pozo_actual = null 

func _ready():
	randomize()
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
	var principal = %ManoJugador.get_parent()
	if principal is BoxContainer:
		principal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		principal.add_theme_constant_override("separation", 20)
		principal.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if has_node("%ManoRival"):
		%ManoRival.custom_minimum_size.y = 100
		%ManoRival.alignment = BoxContainer.ALIGNMENT_CENTER
		%ManoRival.add_theme_constant_override("separation", -45)
		%ManoRival.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if has_node("LadoRival"):
		var lr = get_node("LadoRival")
		lr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lr.size_flags_stretch_ratio = 1.0
		lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		if zona_rival_izq:
			zona_rival_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			zona_rival_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if zona_rival_arriba:
			zona_rival_arriba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			zona_rival_arriba.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if zona_rival_der:
			zona_rival_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			zona_rival_der.size_flags_vertical = Control.SIZE_EXPAND_FILL

	%ZonaCentral.custom_minimum_size.y = 140 
	%ZonaCentral.alignment = BoxContainer.ALIGNMENT_CENTER
	%ZonaCentral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	%ZonaCentral.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if has_node("LadoJugador"):
		var lj = get_node("LadoJugador")
		lj.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lj.size_flags_stretch_ratio = 1.0 
		if lj is BoxContainer: 
			lj.alignment = BoxContainer.ALIGNMENT_CENTER
			lj.add_theme_constant_override("separation", 50)
		lj.mouse_filter = Control.MOUSE_FILTER_IGNORE

		for zona in [%Jugadas_Arriba, %Jugadas_Izquierda, %Jugadas_Derecha]:
			if zona: 
				zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
				zona.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				zona.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if principal.has_node("GranEspaciador"):
		principal.get_node("GranEspaciador").queue_free()

	%ManoJugador.custom_minimum_size.y = 130
	%ManoJugador.size_flags_vertical = Control.SIZE_SHRINK_END
	%ManoJugador.alignment = BoxContainer.ALIGNMENT_CENTER
	%ManoJugador.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	%ManoJugador.z_index = 50 
	
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones: 
		b.custom_minimum_size = Vector2(170, 50)
		b.mouse_filter = Control.MOUSE_FILTER_STOP 
		b.z_index = 100 

func preparar_pozo_inicial():
	if mazo.size() > 0: actualizar_pozo_visual(mazo.pop_back())

func actualizar_pozo_visual(datos):
	datos_carta_pozo_actual = datos 
	
	var pozo_node = %ZonaCentral.find_child("Pozo", true, false)
	if pozo_node:
		pozo_node.mouse_filter = Control.MOUSE_FILTER_STOP 
		for h in pozo_node.get_children(): h.queue_free()
		var carta_p = ESCENA_CARTA.instantiate()
		pozo_node.add_child(carta_p)
		carta_p.configurar(datos.valor, datos.palo, datos.color, false)
		carta_p.scale = Vector2(1.0, 1.0) 
		carta_p.custom_minimum_size = Vector2(70, 95)
		pozo_node.custom_minimum_size = Vector2(70, 95)
		
		if not carta_p.gui_input.is_connected(_on_carta_pozo_input):
			carta_p.gui_input.connect(_on_carta_pozo_input)

# --- ROBAR DEL POZO ---

func _on_carta_pozo_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if turno_jugador and not ya_robo and cartas_seleccionadas.size() >= 2:
			intentar_robar_pozo()

func intentar_robar_pozo():
	if datos_carta_pozo_actual == null: return
	
	var carta_temp = ESCENA_CARTA.instantiate()
	carta_temp.configurar(datos_carta_pozo_actual.valor, datos_carta_pozo_actual.palo, datos_carta_pozo_actual.color, false)
	
	var lista_candidata = cartas_seleccionadas.duplicate()
	lista_candidata.append(carta_temp)
	
	if es_jugada_valida(lista_candidata):
		realizar_robo_y_bajada(carta_temp)
	else:
		print("No puedes robar: La combinación no es válida")
		carta_temp.queue_free()

func realizar_robo_y_bajada(carta_pozo_obj):
	var pozo_node = %ZonaCentral.find_child("Pozo", true, false)
	if pozo_node:
		for h in pozo_node.get_children(): h.queue_free()
	
	var lista_final = cartas_seleccionadas.duplicate()
	lista_final.append(carta_pozo_obj)
	
	cartas_seleccionadas.clear()
	ya_robo = true 
	actualizar_estado_botones()
	
	bajar_jugada_distribuida(lista_final)
	
	datos_carta_pozo_actual = null
	verificar_ganador()

# --- IA DEL RIVAL ---

func iniciar_turno_rival():
	if juego_terminado: return
	
	turno_jugador = false
	actualizar_estado_botones()
	
	await get_tree().create_timer(1.0).timeout
	if mazo.size() > 0:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoRival, true)
	
	await get_tree().create_timer(0.8).timeout
	
	var pudo_bajar = true
	while pudo_bajar:
		pudo_bajar = ia_analizar_y_bajar()
		if verificar_ganador(): return
		if pudo_bajar:
			await get_tree().create_timer(1.0).timeout 
	
	var cartas_rival = %ManoRival.get_children()
	if cartas_rival.size() > 0:
		cartas_rival.sort_custom(func(a,b): return a.valor > b.valor)
		var carta_descarte = cartas_rival[0]
		if carta_descarte.valor == 0 and cartas_rival.size() > 1:
			carta_descarte = cartas_rival[1]

		actualizar_pozo_visual({"valor": carta_descarte.valor, "palo": carta_descarte.palo, "color": carta_descarte.color_mazo})
		carta_descarte.queue_free()
		
		await get_tree().process_frame
		if verificar_ganador(): return
	
	ya_robo = false
	turno_jugador = true
	actualizar_estado_botones()

func ia_analizar_y_bajar():
	if juego_terminado: return false
	var cartas = %ManoRival.get_children()
	var jokers = []
	var normales = []
	for c in cartas:
		if c.valor == 0: jokers.append(c)
		else: normales.append(c)
	
	var grupos_valor = {}
	for c in normales:
		if not c.valor in grupos_valor: grupos_valor[c.valor] = []
		grupos_valor[c.valor].append(c)
	for val in grupos_valor:
		var lista = grupos_valor[val]
		var palos_unicos = []
		var candidatos = []
		for c in lista:
			if not c.palo in palos_unicos:
				palos_unicos.append(c.palo)
				candidatos.append(c)
		if candidatos.size() >= 3:
			bajar_jugada_rival(candidatos)
			return true
	
	var grupos_palo = {}
	for c in normales:
		if not c.palo in grupos_palo: grupos_palo[c.palo] = []
		grupos_palo[c.palo].append(c)
	
	for p in grupos_palo:
		var lista = grupos_palo[p]
		lista.sort_custom(func(a,b): return a.valor < b.valor)
		
		var tiene_Q = false; var tiene_K = false; var tiene_A = false
		var carta_Q; var carta_K; var carta_A
		
		for c in lista:
			if c.valor == 12: tiene_Q = true; carta_Q = c
			if c.valor == 13: tiene_K = true; carta_K = c
			if c.valor == 1:  tiene_A = true; carta_A = c
		
		if tiene_Q and tiene_K and tiene_A:
			bajar_jugada_rival([carta_Q, carta_K, carta_A])
			return true
		
		if jokers.size() > 0 and tiene_Q and tiene_K:
			bajar_jugada_rival([carta_Q, carta_K, jokers[0]])
			return true

		var secuencia_temp = [lista[0]]
		for i in range(1, lista.size()):
			if lista[i].valor == lista[i-1].valor + 1:
				secuencia_temp.append(lista[i])
			elif lista[i].valor == lista[i-1].valor: pass
			else:
				if secuencia_temp.size() >= 3:
					bajar_jugada_rival(secuencia_temp)
					return true
				secuencia_temp = [lista[i]]
		
		if secuencia_temp.size() >= 3:
			bajar_jugada_rival(secuencia_temp)
			return true

		if jokers.size() > 0:
			var joker_usar = jokers[0]
			if lista.size() >= 2:
				for i in range(lista.size() - 1):
					var c1 = lista[i]
					var c2 = lista[i+1]
					var diff = c2.valor - c1.valor
					if diff == 1 or diff == 2: 
						bajar_jugada_rival([c1, c2, joker_usar])
						return true
	return false

func bajar_jugada_rival(lista_cartas):
	var rotacion_contenedores = [zona_rival_izq, zona_rival_arriba, zona_rival_der]
	var destino = rotacion_contenedores[indice_rotacion_rival % 3]
	indice_rotacion_rival += 1
	
	var grupo = HBoxContainer.new()
	grupo.alignment = BoxContainer.ALIGNMENT_CENTER
	grupo.mouse_filter = Control.MOUSE_FILTER_STOP 
	grupo.add_theme_constant_override("separation", 2)
	grupo.custom_minimum_size = Vector2(100, 95) 
	grupo.z_index = 20

	destino.add_child(grupo)
	grupo.gui_input.connect(_on_jugada_mesa_clicked.bind(grupo))
	
	for c in ordenar_con_joker(lista_cartas):
		if c.get_parent(): c.get_parent().remove_child(c)
		grupo.add_child(c)
		c.boca_abajo = false 
		c.seleccionada = false
		c.actualizar_visual()
		c.scale = Vector2(0.6, 0.6); c.position.y = 0
		if c.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
			c.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		if not c.carta_seleccionada.is_connected(_on_jugada_mesa_clicked_desde_carta):
			c.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)

# --- JUEGO GENERAL ---

func verificar_ganador():
	if juego_terminado: return true
	var cartas_jugador = %ManoJugador.get_child_count()
	var cartas_rival = %ManoRival.get_child_count()
	
	if cartas_jugador == 0:
		mostrar_pantalla_final("¡GANASTE LA PARTIDA!")
		return true
	elif cartas_rival == 0:
		mostrar_pantalla_final("GANÓ DANILO")
		return true
	return false

func mostrar_pantalla_final(mensaje):
	juego_terminado = true
	turno_jugador = false
	actualizar_estado_botones()
	
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.z_index = 4000
	add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = mensaje
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 50)
	vbox.add_child(label)
	
	var btn_reset = Button.new()
	btn_reset.text = "JUGAR DE NUEVO"
	btn_reset.custom_minimum_size = Vector2(250, 60)
	btn_reset.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(btn_reset)
	
	var btn_salir = Button.new()
	btn_salir.text = "SALIR"
	btn_salir.custom_minimum_size = Vector2(250, 60)
	btn_salir.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_salir)

func intentar_moje(carta_mano, contenedor):
	if juego_terminado: return
	var cartas_en_mesa = contenedor.get_children()
	var es_escalera = es_jugada_escalera(cartas_en_mesa)
	var exito = false
	
	if es_escalera:
		var bloqueado = false
		if carta_mano.valor != 0: 
			var naturales = []
			for c in cartas_en_mesa:
				if c.valor != 0: naturales.append(c.valor)
			if naturales.size() >= 2:
				naturales.sort()
				var min_mesa = naturales[0]; var max_mesa = naturales[-1]
				
				if 12 in naturales and 13 in naturales and 1 in naturales:
					max_mesa = 14 
				elif 12 in naturales and 13 in naturales:
					if carta_mano.valor == 1: 
						exito = true; bloqueado = false
				
				if carta_mano.valor > min_mesa and carta_mano.valor < max_mesa:
					bloqueado = true
					print("Joker encerrado")
		
		var ultima_carta = cartas_en_mesa[-1]
		if ultima_carta.valor == 0 and es_joker_as_alto(cartas_en_mesa):
			bloqueado = true

		if not bloqueado:
			var lista_prueba = []
			for c in cartas_en_mesa: lista_prueba.append(c)
			lista_prueba.append(carta_mano)
			if es_jugada_valida(lista_prueba): exito = true
	else:
		if carta_mano.valor != 0: 
			var v_ref = 0; var palos_en_mesa = []
			for c in cartas_en_mesa:
				if c.valor != 0: v_ref = c.valor; palos_en_mesa.append(c.palo)
			if carta_mano.valor == v_ref:
				if carta_mano.palo in palos_en_mesa: exito = true

	if exito: ejecutar_movimiento_moje(carta_mano, contenedor)

func es_joker_as_alto(lista):
	var tiene_Q = false; var tiene_K = false
	for c in lista:
		if c.valor == 12: tiene_Q = true
		if c.valor == 13: tiene_K = true
	return tiene_Q and tiene_K

func ejecutar_movimiento_moje(carta_mano, contenedor):
	if carta_mano.get_parent(): carta_mano.get_parent().remove_child(carta_mano)
	contenedor.add_child(carta_mano)
	
	# AL MOJAR TAMBIÉN FORZAMOS EL TAMAÑO PEQUEÑO
	carta_mano.custom_minimum_size = Vector2(55, 80)
	
	var lista_ordenada = ordenar_con_joker(contenedor.get_children())
	for i in range(lista_ordenada.size()):
		contenedor.move_child(lista_ordenada[i], i)
	carta_mano.seleccionada = false; carta_mano.actualizar_visual()
	carta_mano.scale = Vector2(0.6, 0.6); carta_mano.position.y = 0
	if carta_mano.carta_seleccionada.is_connected(_on_carta_tocada_en_mano):
		carta_mano.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
	if not carta_mano.carta_seleccionada.is_connected(_on_jugada_mesa_clicked_desde_carta):
		carta_mano.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)
	cartas_seleccionadas.clear(); ya_robo = true; actualizar_estado_botones()
	
	verificar_ganador()

func es_jugada_valida(lista):
	if lista.size() < 3: return false
	var normales = []; var jokers = 0
	for c in lista:
		if c.valor == 0: jokers += 1
		else: normales.append(c)
	if normales.size() == 0: return jokers >= 3
	
	var v_ref = normales[0].valor
	var mismo_valor = true; var mismo_palo = true; var p_ref = normales[0].palo
	for c in normales:
		if c.valor != v_ref: mismo_valor = false
		if c.palo != p_ref: mismo_palo = false
	
	if mismo_valor:
		if jokers > 0: return false
		var palos_unicos = []
		for c in normales:
			if not c.palo in palos_unicos: palos_unicos.append(c.palo)
		return palos_unicos.size() >= 3
	
	if mismo_palo:
		var valores_mat = []
		var tiene_K = false; var tiene_Q = false
		for c in normales:
			if c.valor == 13: tiene_K = true
			if c.valor == 12: tiene_Q = true
		for c in normales:
			if c.valor == 1 and (tiene_K or tiene_Q): valores_mat.append(14)
			else: valores_mat.append(c.valor)
		valores_mat.sort()
		var huecos = 0
		for i in range(1, valores_mat.size()):
			var diff = valores_mat[i] - valores_mat[i-1]
			if diff == 0: return false 
			huecos += (diff - 1)
		return jokers >= huecos
	return false

func es_jugada_escalera(lista):
	var palos = []
	for c in lista:
		if c.valor != 0 and not c.palo in palos: palos.append(c.palo)
	return palos.size() <= 1

func ordenar_con_joker(lista):
	var normales = []; var jokers = []
	var tiene_K = false; var tiene_Q = false
	
	for c in lista:
		if c.valor == 0: jokers.append(c)
		else: 
			normales.append(c)
			if c.valor == 13: tiene_K = true
			if c.valor == 12: tiene_Q = true
	
	normales.sort_custom(func(a, b): 
		var val_a = a.valor; var val_b = b.valor
		if val_a == 1 and (tiene_K or tiene_Q): val_a = 14
		if val_b == 1 and (tiene_K or tiene_Q): val_b = 14
		return val_a < val_b
	)
	
	if normales.size() > 1 and normales[0].valor == normales[-1].valor: return normales + jokers
	
	var resultado = []
	if normales.size() > 0:
		var v_min = normales[0].valor
		if v_min == 1 and (tiene_K or tiene_Q): v_min = 14
		
		var v_max = normales[-1].valor
		if v_max == 1 and (tiene_K or tiene_Q): v_max = 14
		
		var puntero = v_min; var idx_norm = 0
		while puntero <= v_max:
			var val_actual = normales[idx_norm].valor
			if val_actual == 1 and (tiene_K or tiene_Q): val_actual = 14
			if idx_norm < normales.size() and val_actual == puntero:
				resultado.append(normales[idx_norm]); idx_norm += 1
			elif jokers.size() > 0: resultado.append(jokers.pop_back())
			puntero += 1
		while jokers.size() > 0:
			if v_max < 14: resultado.append(jokers.pop_back()); v_max += 1
			elif v_min > 1: resultado.push_front(jokers.pop_back()); v_min -= 1
			else: resultado.append(jokers.pop_back())
	return resultado

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
		nueva_carta.mouse_filter = Control.MOUSE_FILTER_STOP
		nueva_carta.custom_minimum_size = Vector2(70, 95)
		nueva_carta.carta_seleccionada.connect(_on_carta_tocada_en_mano)
	else:
		nueva_carta.custom_minimum_size = Vector2(55, 80)
		nueva_carta.scale = Vector2(0.6, 0.6)

func _on_carta_tocada_en_mano(carta_objeto):
	# AHORA SIEMPRE SE PUEDE SELECCIONAR EN TU TURNO (NO IMPORTA SI ROBASTE O NO)
	if turno_jugador and not juego_terminado: 
		carta_objeto.alternar_seleccion() 
		if carta_objeto in cartas_seleccionadas:
			cartas_seleccionadas.erase(carta_objeto)
			carta_objeto.scale = Vector2(1.0, 1.0); carta_objeto.position.y = 0
		else:
			cartas_seleccionadas.append(carta_objeto)
			carta_objeto.scale = Vector2(1.1, 1.1); carta_objeto.position.y = -25
		actualizar_estado_botones()

func _on_boton_mazo_pressed():
	if turno_jugador and not ya_robo and mazo.size() > 0 and not juego_terminado:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoJugador, false)
		ya_robo = true; actualizar_estado_botones()

func _on_boton_accion_pressed():
	if not turno_jugador or juego_terminado: return
	if cartas_seleccionadas.size() == 1:
		var c = cartas_seleccionadas[0]
		actualizar_pozo_visual({"valor": c.valor, "palo": c.palo, "color": c.color_mazo})
		c.queue_free(); cartas_seleccionadas.clear()
		
		await get_tree().process_frame 
		if verificar_ganador(): return
		
		iniciar_turno_rival()
	elif cartas_seleccionadas.size() >= 3:
		if es_jugada_valida(cartas_seleccionadas):
			var copias = cartas_seleccionadas.duplicate()
			cartas_seleccionadas.clear(); actualizar_estado_botones()
			bajar_jugada_distribuida(copias)
			verificar_ganador()

func bajar_jugada_distribuida(lista):
	var containers = [%Jugadas_Arriba, %Jugadas_Izquierda, %Jugadas_Derecha]
	var destino = containers[0]
	for c in containers:
		if c.get_child_count() < destino.get_child_count(): destino = c
	var grupo = HBoxContainer.new()
	grupo.alignment = BoxContainer.ALIGNMENT_CENTER
	grupo.mouse_filter = Control.MOUSE_FILTER_STOP 
	grupo.add_theme_constant_override("separation", 2)
	grupo.custom_minimum_size = Vector2(100, 95)
	
	grupo.z_index = 20
	
	destino.add_child(grupo)
	grupo.gui_input.connect(_on_jugada_mesa_clicked.bind(grupo))
	for c in ordenar_con_joker(lista):
		if c.get_parent(): c.get_parent().remove_child(c)
		grupo.add_child(c)
		c.seleccionada = false; c.actualizar_visual()
		
		# === AQUÍ FORZAMOS EL TAMAÑO PEQUEÑO ===
		c.scale = Vector2(0.6, 0.6)
		c.custom_minimum_size = Vector2(55, 80)
		c.position.y = 0
		
		if c.carta_seleccionada.is_connected(_on_carta_tocada_en_mano): c.carta_seleccionada.disconnect(_on_carta_tocada_en_mano)
		c.carta_seleccionada.connect(_on_jugada_mesa_clicked_desde_carta)
	
	cartas_seleccionadas.clear(); actualizar_estado_botones()

func _on_jugada_mesa_clicked_desde_carta(carta_en_mesa):
	if turno_jugador and ya_robo and cartas_seleccionadas.size() == 1 and not juego_terminado: 
		intentar_moje(cartas_seleccionadas[0], carta_en_mesa.get_parent())

func _on_jugada_mesa_clicked(event, contenedor_jugada):
	if event is InputEventMouseButton and event.pressed:
		if turno_jugador and ya_robo and cartas_seleccionadas.size() == 1 and not juego_terminado: 
			intentar_moje(cartas_seleccionadas[0], contenedor_jugada)

func actualizar_estado_botones():
	if juego_terminado:
		%BotonMazo.disabled = true
		%BotonAccion.disabled = true
		return

	%BotonMazo.disabled = (ya_robo or not turno_jugador)
	var cant = cartas_seleccionadas.size()
	if not turno_jugador:
		%BotonAccion.text = "ESPERANDO..."; %BotonAccion.disabled = true
	elif not ya_robo:
		%BotonAccion.text = "ROBÁ"; %BotonAccion.disabled = true
	else:
		if cant == 1: %BotonAccion.text = "DESCARTAR"; %BotonAccion.disabled = false
		elif cant >= 3: %BotonAccion.text = "BAJAR JUGADA"; %BotonAccion.disabled = false
		else: %BotonAccion.text = "ELEGÍ..."; %BotonAccion.disabled = true
