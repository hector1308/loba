extends CanvasLayer

@onready var ESCENA_CARTA = preload("res://Carta.tscn")

# REFERENCIAS UI
@onready var zona_rival_arriba = %JugadasRival_Arriba
@onready var zona_rival_izq = %JugadasRival_Izquierda
@onready var zona_rival_der = %JugadasRival_Derecha

# VARIABLES DE JUEGO
var mazo = []
var ya_robo = false
var cartas_seleccionadas = []
var turno_jugador = true
var indice_rotacion_rival = 0 
var juego_terminado = false
var datos_carta_pozo_actual = null 

func _ready():
	randomize()
	if not has_node("%ManoJugador"): return
	
	# Bloqueo inicial
	%BotonMazo.disabled = true
	%BotonAccion.disabled = true
	
	configurar_interfaz_visual()
	
	if not %BotonMazo.pressed.is_connected(_on_boton_mazo_pressed):
		%BotonMazo.pressed.connect(_on_boton_mazo_pressed)
	if not %BotonAccion.pressed.is_connected(_on_boton_accion_pressed):
		%BotonAccion.pressed.connect(_on_boton_accion_pressed)
	
	iniciar_secuencia_juego()

# ================================================================
# 1. SECUENCIA DE INICIO Y ANIMACIONES
# ================================================================

func iniciar_secuencia_juego():
	generar_mazo_loba()
	mazo.shuffle()
	
	# No mostramos el mazo aún, la animación lo hará aparecer
	
	await animar_mezcla()
	await animar_reparto()
	await animar_pozo_inicial()
	
	call_deferred("desbloquear_botones")
	actualizar_estado_botones()

func animar_mezcla():
	# 1. Ocultar mazo estático
	var mazo_vis = %ZonaCentral.find_child("MazoVisual", true, false)
	if mazo_vis:
		for h in mazo_vis.get_children(): h.queue_free()
	
	var centro = get_viewport().get_visible_rect().size / 2
	var cartas_temp = []
	
	# 2. Crear cartas voladoras (colores mezclados)
	for i in range(5):
		var c = TextureRect.new()
		var color_dorso = "blue"
		if randi() % 2 == 0: color_dorso = "red"
		
		c.texture = load("res://cards/back_" + color_dorso + ".png") 
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.size = Vector2(70, 95)
		c.pivot_offset = Vector2(35, 47.5)
		c.position = centro - (Vector2(70, 95) / 2)
		c.z_index = 100 + i
		add_child(c)
		cartas_temp.append(c)
	
	# 3. Animar agitación
	var tiempo_inicio = Time.get_ticks_msec()
	while Time.get_ticks_msec() - tiempo_inicio < 3000:
		var tween = create_tween().set_parallel(true)
		for i in range(cartas_temp.size()):
			var c = cartas_temp[i]
			var offset_x = randf_range(-50, 50)
			var offset_y = randf_range(-30, 30)
			var rot = randf_range(-20, 20)
			tween.tween_property(c, "position", centro - (Vector2(70, 95) / 2) + Vector2(offset_x, offset_y), 0.2)
			tween.tween_property(c, "rotation_degrees", rot, 0.2)
		await tween.finished
	
	# 4. Regresar al origen
	var pos_mazo = mazo_vis.global_position if mazo_vis else Vector2(100, 300)
	var tween_final = create_tween().set_parallel(true)
	for c in cartas_temp:
		tween_final.tween_property(c, "global_position", pos_mazo, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween_final.tween_property(c, "rotation", 0, 0.4)
	await tween_final.finished
	
	for c in cartas_temp: c.queue_free()
	actualizar_mazo_visual()

func animar_reparto():
	var mazo_vis = %ZonaCentral.find_child("MazoVisual", true, false)
	var origen = mazo_vis.global_position if mazo_vis else get_viewport().get_visible_rect().size / 2
	
	for i in range(9):
		# JUGADOR
		if mazo.size() > 0:
			var datos = mazo.pop_back()
			# Reparto inicial: Al centro de la mano
			var destino_jugador = %ManoJugador.global_position + Vector2(%ManoJugador.size.x / 2, 0)
			await animar_carta_volando(origen, destino_jugador, false, datos.color)
			crear_carta_en_contenedor(datos, %ManoJugador, false)
		
		# RIVAL
		if mazo.size() > 0:
			var datos_r = mazo.pop_back()
			var pos_rival = %ManoRival.global_position + Vector2(%ManoRival.size.x / 2, 0) if has_node("%ManoRival") else Vector2(500, 50)
			await animar_carta_volando(origen, pos_rival, true, datos_r.color)
			crear_carta_en_contenedor(datos_r, %ManoRival, true)
	
	actualizar_mazo_visual()

func animar_pozo_inicial():
	if mazo.size() > 0:
		var datos = mazo.pop_back()
		var mazo_vis = %ZonaCentral.find_child("MazoVisual", true, false)
		var origen = mazo_vis.global_position if mazo_vis else Vector2(0,0)
		var pozo_node = %ZonaCentral.find_child("Pozo", true, false)
		var destino = pozo_node.global_position if pozo_node else Vector2(200, 300)
		
		await animar_carta_volando(origen, destino, false, datos.color)
		actualizar_pozo_visual(datos)
		actualizar_mazo_visual()

func animar_carta_volando(desde_pos, hasta_pos, es_rival, color_dorso = "blue"):
	var voladora = TextureRect.new()
	voladora.texture = load("res://cards/back_" + color_dorso + ".png")
	voladora.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	voladora.size = Vector2(70, 95)
	voladora.position = desde_pos
	voladora.z_index = 200 
	if es_rival: voladora.scale = Vector2(0.6, 0.6)
	add_child(voladora)
	
	var tween = create_tween()
	tween.tween_property(voladora, "global_position", hasta_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	voladora.queue_free()

# ================================================================
# 2. LOGICA CORE (DEBE ESTAR ANTES DE LOS INPUTS)
# ================================================================

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

func iniciar_turno_rival():
	if juego_terminado: return
	
	turno_jugador = false
	actualizar_estado_botones()
	
	await get_tree().create_timer(1.0).timeout
	if mazo.size() > 0:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoRival, true)
		actualizar_mazo_visual()
	
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
	
	# Logica Piernas
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
	
	# Logica Escaleras
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

func es_joker_as_alto(lista):
	var tiene_Q = false; var tiene_K = false
	for c in lista:
		if c.valor == 12: tiene_Q = true
		if c.valor == 13: tiene_K = true
	return tiene_Q and tiene_K

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

func ejecutar_movimiento_moje(carta_mano, contenedor):
	if carta_mano.get_parent(): carta_mano.get_parent().remove_child(carta_mano)
	contenedor.add_child(carta_mano)
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

# ================================================================
# 3. INPUT HANDLERS Y UTILIDADES UI
# ================================================================

func desbloquear_botones():
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.disabled = false
			b.z_index = 100 
			if b.get_parent() is Control:
				b.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE

func configuring_layout_order(principal):
	var orden_deseado = []
	if has_node("LadoRival"): orden_deseado.append(get_node("LadoRival"))
	if has_node("%ZonaCentral"): orden_deseado.append(%ZonaCentral)
	if has_node("LadoJugador"): orden_deseado.append(get_node("LadoJugador"))
	orden_deseado.append(%ManoJugador)
	for i in range(orden_deseado.size()):
		var nodo = orden_deseado[i]
		if nodo.get_parent() == principal: principal.move_child(nodo, i)

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
			zona_rival_izq.layout_mode = 1 
			zona_rival_izq.anchor_left = 0.0; zona_rival_izq.anchor_right = 0.3
			zona_rival_izq.anchor_top = 0.0; zona_rival_izq.anchor_bottom = 1.0
			zona_rival_izq.offset_left = 0; zona_rival_izq.offset_right = 0
			if zona_rival_izq is BoxContainer: zona_rival_izq.alignment = BoxContainer.ALIGNMENT_CENTER

		if zona_rival_arriba:
			zona_rival_arriba.layout_mode = 1
			zona_rival_arriba.anchor_left = 0.3; zona_rival_arriba.anchor_right = 0.7
			zona_rival_arriba.anchor_top = 0.0; zona_rival_arriba.anchor_bottom = 1.0
			zona_rival_arriba.offset_left = 0; zona_rival_arriba.offset_right = 0
			if zona_rival_arriba is BoxContainer: zona_rival_arriba.alignment = BoxContainer.ALIGNMENT_CENTER

		if zona_rival_der:
			zona_rival_der.layout_mode = 1
			zona_rival_der.anchor_left = 0.7; zona_rival_der.anchor_right = 1.0
			zona_rival_der.anchor_top = 0.0; zona_rival_der.anchor_bottom = 1.0
			zona_rival_der.offset_left = 0; zona_rival_der.offset_right = 0
			if zona_rival_der is BoxContainer: zona_rival_der.alignment = BoxContainer.ALIGNMENT_CENTER

	%ZonaCentral.custom_minimum_size.y = 140 
	%ZonaCentral.alignment = BoxContainer.ALIGNMENT_CENTER
	%ZonaCentral.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	%ZonaCentral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%ZonaCentral.add_theme_constant_override("separation", 50) 
	
	var mazo_vis = %ZonaCentral.find_child("MazoVisual", true, false)
	if not mazo_vis:
		mazo_vis = Control.new()
		mazo_vis.name = "MazoVisual"
		mazo_vis.custom_minimum_size = Vector2(70, 95)
		mazo_vis.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		%ZonaCentral.add_child(mazo_vis)
		%ZonaCentral.move_child(mazo_vis, 0)

	if has_node("LadoJugador"):
		var lj = get_node("LadoJugador")
		lj.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lj.size_flags_stretch_ratio = 1.0 
		if lj is BoxContainer: 
			lj.alignment = BoxContainer.ALIGNMENT_CENTER
			lj.add_theme_constant_override("separation", 50)
		lj.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if has_node("%Jugadas_Izquierda"):
			var z = get_node("%Jugadas_Izquierda")
			z.mouse_filter = Control.MOUSE_FILTER_IGNORE
			z.layout_mode = 1 
			z.anchor_left = 0.0; z.anchor_right = 0.3
			z.anchor_top = 0.0; z.anchor_bottom = 1.0
			z.offset_left = 0; z.offset_right = 0
			z.custom_minimum_size = Vector2(100, 100)
			if z is BoxContainer: z.alignment = BoxContainer.ALIGNMENT_CENTER

		if has_node("%Jugadas_Arriba"):
			var z = get_node("%Jugadas_Arriba")
			z.mouse_filter = Control.MOUSE_FILTER_IGNORE
			z.layout_mode = 1 
			z.anchor_left = 0.3; z.anchor_right = 0.7
			z.anchor_top = 0.0; z.anchor_bottom = 1.0
			z.offset_left = 0; z.offset_right = 0
			z.custom_minimum_size = Vector2(100, 100)
			if z is BoxContainer: z.alignment = BoxContainer.ALIGNMENT_CENTER

		if has_node("%Jugadas_Derecha"):
			var z = get_node("%Jugadas_Derecha")
			z.mouse_filter = Control.MOUSE_FILTER_IGNORE
			z.layout_mode = 1 
			z.anchor_left = 0.7; z.anchor_right = 1.0
			z.anchor_top = 0.0; z.anchor_bottom = 1.0
			z.offset_left = 0; z.offset_right = 0
			z.custom_minimum_size = Vector2(100, 100)
			if z is BoxContainer: z.alignment = BoxContainer.ALIGNMENT_CENTER

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
	pass 

func actualizar_mazo_visual():
	var mazo_vis = %ZonaCentral.find_child("MazoVisual", true, false)
	if not mazo_vis: return
	for h in mazo_vis.get_children(): h.queue_free()
	
	if mazo.size() > 0:
		var proxima_carta = mazo.back()
		var color_reverso = proxima_carta.color 
		
		var carta_dorso = ESCENA_CARTA.instantiate()
		carta_dorso.configurar(0, "", color_reverso, true)
		carta_dorso.custom_minimum_size = Vector2(70, 95)
		carta_dorso.scale = Vector2(1.0, 1.0)
		carta_dorso.mouse_filter = Control.MOUSE_FILTER_STOP
		carta_dorso.gui_input.connect(_on_mazo_visual_input)
		carta_dorso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		mazo_vis.add_child(carta_dorso)

func _on_mazo_visual_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not %BotonMazo.disabled:
			_on_boton_mazo_pressed()

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
	pass

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
		var mazo_vis = %ZonaCentral.find_child("MazoVisual", true, false)
		var origen = mazo_vis.global_position if mazo_vis else Vector2(0,0)
		
		# Animacion manual va a la derecha
		var destino = %ManoJugador.global_position + Vector2(%ManoJugador.size.x / 2, 0)
		if %ManoJugador.get_child_count() > 0:
			var ultima_carta = %ManoJugador.get_children().back()
			if ultima_carta and ultima_carta is Control:
				destino = ultima_carta.global_position + Vector2(40, 0)
		
		%BotonMazo.disabled = true 
		var datos = mazo.pop_back()
		
		await animar_carta_volando(origen, destino, false, datos.color)
		crear_carta_en_contenedor(datos, %ManoJugador, false)
		
		actualizar_mazo_visual()
		ya_robo = true
		actualizar_estado_botones()

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
