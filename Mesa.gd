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

func _ready():
	randomize()
	generar_mazo_loba()
	mazo.shuffle()
	
	if not has_node("%ManoJugador"): return

	repartir_manos()
	preparar_pozo_inicial()
	
	configurar_interfaz_visual()
	
	# Solo desbloqueamos los inputs, NO movemos nodos de lugar
	call_deferred("desbloquear_botones")
	
	if not %BotonMazo.pressed.is_connected(_on_boton_mazo_pressed):
		%BotonMazo.pressed.connect(_on_boton_mazo_pressed)
	if not %BotonAccion.pressed.is_connected(_on_boton_accion_pressed):
		%BotonAccion.pressed.connect(_on_boton_accion_pressed)
	
	actualizar_estado_botones()

# --- SEGURIDAD DE INPUTS (Simplificada y Segura) ---
func desbloquear_botones():
	# Forzamos a los botones a ser la capa más alta visualmente
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.disabled = false
			b.z_index = 100 # Flotar sobre todo
			# Asegurar que el padre inmediato no los bloquee
			if b.get_parent() is Control:
				b.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE

func configuring_layout_order(principal):
	# Esta función asegura que el orden vertical sea correcto: Rival -> Centro -> Espacio -> Jugador
	var orden_deseado = []
	
	if has_node("LadoRival"): orden_deseado.append(get_node("LadoRival"))
	if has_node("%ZonaCentral"): orden_deseado.append(%ZonaCentral)
	
	# Si existe el espacio intermedio, lo ponemos
	if has_node("LadoJugador"): orden_deseado.append(get_node("LadoJugador"))
	
	# La mano siempre al final
	orden_deseado.append(%ManoJugador)
	
	# Aplicamos el orden
	for i in range(orden_deseado.size()):
		var nodo = orden_deseado[i]
		if nodo.get_parent() == principal:
			principal.move_child(nodo, i)

func configurar_interfaz_visual():
	var principal = %ManoJugador.get_parent()
	
	if principal is BoxContainer:
		principal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		principal.add_theme_constant_override("separation", 10)
		principal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# IMPORTANTE: Reordenar correctamente para que el centro no caiga
		configuring_layout_order(principal)

	# 1. LADO RIVAL (Pan de Arriba - SE EXPANDE)
	if has_node("LadoRival"):
		var lr = get_node("LadoRival")
		lr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lr.size_flags_stretch_ratio = 1.0
		lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Configuración de zonas internas (Anclajes)
		if zona_rival_izq:
			zona_rival_izq.layout_mode = 1 
			zona_rival_izq.anchor_left = 0.0; zona_rival_izq.anchor_right = 0.33
			zona_rival_izq.anchor_top = 0.0; zona_rival_izq.anchor_bottom = 1.0
			zona_rival_izq.offset_left = 0; zona_rival_izq.offset_right = 0
			if zona_rival_izq is BoxContainer: zona_rival_izq.alignment = BoxContainer.ALIGNMENT_CENTER

		if zona_rival_arriba:
			zona_rival_arriba.layout_mode = 1
			zona_rival_arriba.anchor_left = 0.33; zona_rival_arriba.anchor_right = 0.66
			zona_rival_arriba.anchor_top = 0.0; zona_rival_arriba.anchor_bottom = 1.0
			zona_rival_arriba.offset_left = 0; zona_rival_arriba.offset_right = 0
			if zona_rival_arriba is BoxContainer: zona_rival_arriba.alignment = BoxContainer.ALIGNMENT_CENTER

		if zona_rival_der:
			zona_rival_der.layout_mode = 1
			zona_rival_der.anchor_left = 0.66; zona_rival_der.anchor_right = 1.0
			zona_rival_der.anchor_top = 0.0; zona_rival_der.anchor_bottom = 1.0
			zona_rival_der.offset_left = 0; zona_rival_der.offset_right = 0
			if zona_rival_der is BoxContainer: zona_rival_der.alignment = BoxContainer.ALIGNMENT_CENTER

	# 2. ZONA CENTRAL (Jamón del medio - NO SE EXPANDE)
	%ZonaCentral.custom_minimum_size.y = 140 
	%ZonaCentral.alignment = BoxContainer.ALIGNMENT_CENTER
	# CLAVE: Shrink Center evita que ocupe espacio vertical extra y caiga
	%ZonaCentral.size_flags_vertical = Control.SIZE_SHRINK_CENTER 
	%ZonaCentral.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 3. LADO JUGADOR (Pan de Abajo - SE EXPANDE)
	# Este nodo es vital. Si no existe, lo creamos para que empuje el centro hacia arriba.
	var lj
	if has_node("LadoJugador"):
		lj = get_node("LadoJugador")
	else:
		# Si no existe, creamos un espaciador invisible seguro
		lj = Control.new()
		lj.name = "LadoJugador"
		principal.add_child(lj)
		principal.move_child(lj, principal.get_child_count() - 2) # Justo antes de la mano
	
	lj.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lj.size_flags_stretch_ratio = 1.0 
	lj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lj is BoxContainer: 
		lj.alignment = BoxContainer.ALIGNMENT_CENTER
		lj.add_theme_constant_override("separation", 50)

	# 4. TU MANO
	%ManoJugador.custom_minimum_size.y = 130
	%ManoJugador.size_flags_vertical = Control.SIZE_SHRINK_END
	%ManoJugador.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 5. BOTONES (Tamaño)
	var botones = [%BotonMazo, %BotonAccion]
	for b in botones: b.custom_minimum_size = Vector2(170, 50)

func preparar_pozo_inicial():
	if mazo.size() > 0: actualizar_pozo_visual(mazo.pop_back())

func actualizar_pozo_visual(datos):
	var pozo_node = %ZonaCentral.find_child("Pozo", true, false)
	if pozo_node:
		pozo_node.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		for h in pozo_node.get_children(): h.queue_free()
		var carta_p = ESCENA_CARTA.instantiate()
		pozo_node.add_child(carta_p)
		carta_p.configurar(datos.valor, datos.palo, datos.color, false)
		carta_p.scale = Vector2(1.0, 1.0) 
		carta_p.custom_minimum_size = Vector2(70, 95)
		pozo_node.custom_minimum_size = Vector2(70, 95)

# --- IA DEL RIVAL ---

func iniciar_turno_rival():
	turno_jugador = false
	actualizar_estado_botones()
	
	await get_tree().create_timer(1.0).timeout
	if mazo.size() > 0:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoRival, true)
	
	await get_tree().create_timer(0.8).timeout
	
	var pudo_bajar = true
	while pudo_bajar:
		pudo_bajar = ia_analizar_y_bajar()
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
	
	ya_robo = false
	turno_jugador = true
	actualizar_estado_botones()

func ia_analizar_y_bajar():
	var cartas = %ManoRival.get_children()
	var jugada_encontrada = []
	var jokers = []
	var normales = []
	for c in cartas:
		if c.valor == 0: jokers.append(c)
		else: normales.append(c)
	
	# PIERNAS
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
			jugada_encontrada = candidatos
			bajar_jugada_rival(jugada_encontrada)
			return true
	
	# ESCALERAS
	var grupos_palo = {}
	for c in normales:
		if not c.palo in grupos_palo: grupos_palo[c.palo] = []
		grupos_palo[c.palo].append(c)
	for p in grupos_palo:
		var lista = grupos_palo[p]
		lista.sort_custom(func(a,b): return a.valor < b.valor)
		var secuencia_temp = [lista[0]]
		for i in range(1, lista.size()):
			if lista[i].valor == lista[i-1].valor + 1:
				secuencia_temp.append(lista[i])
			elif lista[i].valor == lista[i-1].valor: pass
			else:
				if secuencia_temp.size() >= 3:
					jugada_encontrada = secuencia_temp
					bajar_jugada_rival(jugada_encontrada)
					return true
				secuencia_temp = [lista[i]]
		if secuencia_temp.size() >= 3:
			jugada_encontrada = secuencia_temp
			bajar_jugada_rival(jugada_encontrada)
			return true

		# JOKER
		if jokers.size() > 0:
			var joker_usar = jokers[0]
			if lista.size() >= 2:
				for i in range(lista.size() - 1):
					var c1 = lista[i]
					var c2 = lista[i+1]
					var diff = c2.valor - c1.valor
					if diff == 1 or diff == 2:
						jugada_encontrada = [c1, c2, joker_usar]
						bajar_jugada_rival(jugada_encontrada)
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

func intentar_moje(carta_mano, contenedor):
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
				if carta_mano.valor > min_mesa and carta_mano.valor < max_mesa:
					bloqueado = true
					print("Joker encerrado")
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
				else: print("Solo mojar palos existentes")

	if exito: ejecutar_movimiento_moje(carta_mano, contenedor)

func ejecutar_movimiento_moje(carta_mano, contenedor):
	if carta_mano.get_parent(): carta_mano.get_parent().remove_child(carta_mano)
	contenedor.add_child(carta_mano)
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
	return palos.size() <= 1

func ordenar_con_joker(lista):
	var normales = []; var jokers = []
	for c in lista:
		if c.valor == 0: jokers.append(c)
		else: normales.append(c)
	normales.sort_custom(func(a, b): return a.valor < b.valor)
	if normales.size() > 1 and normales[0].valor == normales[-1].valor: return normales + jokers
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
	if ya_robo and turno_jugador: 
		carta_objeto.alternar_seleccion() 
		if carta_objeto in cartas_seleccionadas:
			cartas_seleccionadas.erase(carta_objeto)
			carta_objeto.scale = Vector2(1.0, 1.0); carta_objeto.position.y = 0
		else:
			cartas_seleccionadas.append(carta_objeto)
			carta_objeto.scale = Vector2(1.1, 1.1); carta_objeto.position.y = -25
		actualizar_estado_botones()

func _on_boton_mazo_pressed():
	if turno_jugador and not ya_robo and mazo.size() > 0:
		crear_carta_en_contenedor(mazo.pop_back(), %ManoJugador, false)
		ya_robo = true; actualizar_estado_botones()

func _on_boton_accion_pressed():
	if not turno_jugador: return
	if cartas_seleccionadas.size() == 1:
		var c = cartas_seleccionadas[0]
		actualizar_pozo_visual({"valor": c.valor, "palo": c.palo, "color": c.color_mazo})
		c.queue_free(); cartas_seleccionadas.clear(); iniciar_turno_rival()
	elif cartas_seleccionadas.size() >= 3:
		if es_jugada_valida(cartas_seleccionadas):
			var copias = cartas_seleccionadas.duplicate()
			cartas_seleccionadas.clear()
			actualizar_estado_botones()
			bajar_jugada_distribuida(copias)

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
	if turno_jugador and ya_robo and cartas_seleccionadas.size() == 1: 
		intentar_moje(cartas_seleccionadas[0], carta_en_mesa.get_parent())

func _on_jugada_mesa_clicked(event, contenedor_jugada):
	if event is InputEventMouseButton and event.pressed:
		if turno_jugador and ya_robo and cartas_seleccionadas.size() == 1: 
			intentar_moje(cartas_seleccionadas[0], contenedor_jugada)

func actualizar_estado_botones():
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
