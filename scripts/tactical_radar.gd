class_name TacticalRadar
extends RefCounted

var grid_size: int = 17 # 17x17 grid
var contacts: Array[Dictionary] = []
var active_torpedoes: Array[Dictionary] = []

# Relógio de Colapso da Kobayashi Maru (em segundos)
var km_collapse_seconds: float = 95.0
var km_is_destroyed: bool = false
var sweep_phase: int = 0

func _init() -> void:
	reset_simulation_sector()

func reset_simulation_sector() -> void:
	contacts.clear()
	active_torpedoes.clear()
	km_collapse_seconds = 95.0
	km_is_destroyed = false
	
	# Cargueiro Civil Baependi (Em perigo - Amarelo)
	contacts.append({
		"id": "BAE-01",
		"name": "CARGUEIRO CIVIL BAEPENDI",
		"type": "CIVILIAN_CARGO",
		"icon": "B",
		"color": "#ffff44",
		"x": 2,
		"y": -4,
		"distance_km": 3600,
		"hull": 28,
		"shield": 0,
		"hostile": false,
		"identified": false
	})
	
	# Cruzadores de Ataque da Falange Fascista (Inimigos - Vermelho)
	contacts.append({
		"id": "FAL-01",
		"name": "CRUZADOR FASCISTA FALANGE A",
		"type": "WARSHIP",
		"icon": "V",
		"color": "#ff4444",
		"x": -5,
		"y": -5,
		"distance_km": 7200,
		"hull": 100,
		"shield": 100,
		"hostile": true,
		"identified": false,
		"torpedo_cooldown": 2
	})
	
	contacts.append({
		"id": "FAL-02",
		"name": "CRUZADOR FASCISTA FALANGE B",
		"type": "WARSHIP",
		"icon": "V",
		"color": "#ff4444",
		"x": 6,
		"y": -3,
		"distance_km": 8400,
		"hull": 100,
		"shield": 100,
		"hostile": true,
		"identified": false,
		"torpedo_cooldown": 4
	})
	
	# Campo de minas na Zona Desmilitarizada de Abrolhos
	contacts.append({
		"id": "AST-01",
		"name": "CAMPO DE MINAS DMZ ABROLHOS",
		"type": "DEBRIS",
		"icon": "*",
		"color": "#88aa77",
		"x": 1,
		"y": -2,
		"distance_km": 2100,
		"hull": 50,
		"shield": 0,
		"hostile": false,
		"identified": false
	})

# Atualização contínua de tempo real do relógio de colapso
func tick_collapse_timer(delta: float) -> bool:
	if km_is_destroyed:
		return false
	km_collapse_seconds = max(0.0, km_collapse_seconds - delta)
	if km_collapse_seconds <= 0.0 and not km_is_destroyed:
		km_is_destroyed = true
		for c in contacts:
			if c.id == "BAE-01":
				c.hull = 0
		return true # Colapsou!
	return false

# Avança o ciclo tático / tick do radar
func update_tactical_tick(player_engines_eff: float, player_heading: int) -> Dictionary:
	var tick_result = {
		"events": [] as Array[String],
		"torpedo_hits": [] as Array[Dictionary], # { damage, quadrant, torpedo_id }
		"new_torpedoes_launched": false
	}
	sweep_phase = (sweep_phase + 1) % 4
	
	# 1. Movimentação e disparo dos inimigos
	for contact in contacts:
		if contact.hostile:
			# Aproximação gradual
			contact.distance_km = max(800, contact.distance_km - 450)
			if contact.x > 0: contact.x -= 1
			elif contact.x < 0: contact.x += 1
			if contact.y > 0: contact.y -= 1
			elif contact.y < 0: contact.y += 1
			
			# Contagem de disparo de Torpedos
			contact["torpedo_cooldown"] = contact.get("torpedo_cooldown", 3) - 1
			if contact["torpedo_cooldown"] <= 0 and contact.distance_km <= 6500:
				contact["torpedo_cooldown"] = randi_range(3, 5)
				_launch_torpedo_from(contact)
				tick_result["events"].append("ALERTA TÁTICO: %s DISPAROU TORPEDO DE FÓTONS!" % contact.name)
				tick_result["new_torpedoes_launched"] = true
		else:
			# Se for o Cargueiro Baependi e jogador tiver motores
			if contact.id == "BAE-01" and player_engines_eff > 0.0:
				var approach_rate = int(400 * player_engines_eff)
				contact.distance_km = max(200, contact.distance_km - approach_rate)
				if contact.distance_km <= 1000 and not contact.get("transporters_ready", false):
					contact["transporters_ready"] = true
					tick_result["events"].append("TELETRANSPORTE PRONTO: Ao alcance dos civis do Baependi!")
	
	# 2. Atualização dos Torpedos em vôo
	var surviving_torps: Array[Dictionary] = []
	for torp in active_torpedoes:
		torp.distance_km -= torp.speed_km
		# Move-se em direção ao centro (0, 0)
		if torp.x > 0: torp.x -= 1
		elif torp.x < 0: torp.x += 1
		if torp.y > 0: torp.y -= 1
		elif torp.y < 0: torp.y += 1
		
		if torp.distance_km <= 400 or (torp.x == 0 and torp.y == 0):
			# IMPACTO! Calcula qual quadrante da nave foi atingido baseado no ângulo relativo à proa do jogador
			var impact_quadrant = _calculate_impact_quadrant(torp.origin_dx, torp.origin_dy, player_heading)
			tick_result["torpedo_hits"].append({
				"id": torp.id,
				"damage": randi_range(25, 40),
				"quadrant": impact_quadrant
			})
			tick_result["events"].append("! IMPACTO DE TORPEDO no setor [%s] !" % impact_quadrant)
		else:
			surviving_torps.append(torp)
			
	active_torpedoes = surviving_torps
	return tick_result

func _launch_torpedo_from(source: Dictionary) -> void:
	var torp_id = "TORP-%02d" % (randi() % 90 + 10)
	active_torpedoes.append({
		"id": torp_id,
		"x": source.x,
		"y": source.y,
		"origin_dx": source.x,
		"origin_dy": source.y,
		"distance_km": source.distance_km,
		"speed_km": 1500
	})

# Calcula qual quadrante de escudo (FWD, AFT, PORT, STBD) é atingido dependendo da proa da nave
func _calculate_impact_quadrant(origin_dx: int, origin_dy: int, heading: int) -> String:
	# Ângulo do projétil vindo em direção à nave:
	var angle_rad = atan2(float(origin_dy), float(origin_dx))
	var angle_deg = int(rad_to_deg(angle_rad)) + 90 # 0 = Norte, 90 = Leste, 180 = Sul, 270 = Oeste
	if angle_deg < 0: angle_deg += 360
	
	# Ângulo relativo à proa do jogador:
	var rel_angle = (angle_deg - heading) % 360
	if rel_angle < 0: rel_angle += 360
	
	if rel_angle >= 315 or rel_angle < 45:
		return "FWD"  # Frente
	elif rel_angle >= 45 and rel_angle < 135:
		return "STBD" # Direita / Boreste
	elif rel_angle >= 135 and rel_angle < 225:
		return "AFT"  # Traseira / Popa
	else:
		return "PORT" # Esquerda / Bombordo

# Intercepta torpedo com Lasers
func intercept_nearest_torpedo(laser_efficiency: float) -> Dictionary:
	if active_torpedoes.is_empty():
		return { "success": false, "message": "Nenhum torpedo hostil em trajetória!" }
		
	# Pega o torpedo mais próximo
	var nearest_torp = active_torpedoes[0]
	for t in active_torpedoes:
		if t.distance_km < nearest_torp.distance_km:
			nearest_torp = t
			
	var hit_chance = 0.5 + (laser_efficiency * 0.4)
	if randf() < hit_chance:
		active_torpedoes.erase(nearest_torp)
		return { "success": true, "message": "Feixe laser interceptou e detonou %s antes do impacto!" % nearest_torp.id }
	else:
		return { "success": false, "message": "Disparo dos feixes errou o torpedo em aproximação!" }

# Lança contramedidas / Chaff para despistar torpedos
func deploy_chaff_countermeasure() -> bool:
	if active_torpedoes.is_empty():
		return false
	# Desvia o torpedo mais perigoso
	active_torpedoes.remove_at(0)
	return true

# Renderiza o Radar Tático com navios, projéteis e fundo estilizado
func render_ascii_radar(sensor_efficiency: float) -> String:
	var center = grid_size / 2
	var grid: Array[Array] = []
	
	# Inicializa grade com fundo sutil em cor escura
	for y in range(grid_size):
		var row: Array[String] = []
		for x in range(grid_size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(float(dx * dx + dy * dy))
			
			if dist < 0.8:
				row.append("[color=#00ffff]@[/color]") # Jogador (Ciano)
			elif abs(dist - 3.5) < 0.6 or abs(dist - 7.0) < 0.6:
				row.append("[color=#194824].[/color]") # Anel de alcance
			elif dx == 0 and abs(dy) < 8:
				row.append("[color=#153d1e]|[/color]") # Eixo vertical
			elif dy == 0 and abs(dx) < 8:
				row.append("[color=#153d1e]-[/color]") # Eixo horizontal
			else:
				row.append(" ") # Espaço vazio
		grid.append(row)
		
	# Contatos
	for contact in contacts:
		var cx = center + contact.x
		var cy = center + contact.y
		if cx >= 0 and cx < grid_size and cy >= 0 and cy < grid_size:
			var icon_char = contact.icon
			var icon_col = contact.color
			if sensor_efficiency < 0.4:
				icon_char = "?"
				icon_col = "#ffaa00"
			grid[cy][cx] = "[color=%s]%s[/color]" % [icon_col, icon_char]
			
	# Torpedos em vôo (Destaque máximo: Vermelho brilhante / Piscando)
	for torp in active_torpedoes:
		var tx = center + torp.x
		var ty = center + torp.y
		if tx >= 0 and tx < grid_size and ty >= 0 and ty < grid_size:
			grid[ty][tx] = "[color=#ff1111][b]![/b][/color]"
			
	# Monta moldura
	var result = "[color=#1d552c]+--- RADAR TÁTICO L.A.R. ----------+[/color]\n"
	for y in range(grid_size):
		var line_str = "[color=#1d552c]|[/color]"
		for x in range(grid_size):
			line_str += grid[y][x] + " "
		line_str += "[color=#1d552c]|[/color]\n"
		result += line_str
	result += "[color=#1d552c]+----------------------------------+[/color]\n"
	result += "LEGENDA: [color=#00ffff][@][/color] VOCÊ     [color=#ff4444][V][/color] FASCISTAS [color=#ff1111][!][/color] TORPEDO\n"
	result += "         [color=#ffff44][B][/color] BAEPENDI [color=#88aa77][*][/color] MINAS DMZ"
	return result

func get_contact_telemetry(sensor_efficiency: float) -> String:
	var text = "[color=#33ff66]=== TELEMETRIA DE SENSORES ===[/color]\n"
	
	# Destaque para Torpedos em Vôo
	if not active_torpedoes.is_empty():
		text += "[color=#ff2222]!! ALERTA: %d TORPEDO(S) EM CURSO DE COLISÃO !![/color]\n" % active_torpedoes.size()
		for t in active_torpedoes:
			text += "[color=#ff4444] >> %s: DIST %d KM (IMPACTO IMINENTE)[/color]\n" % [t.id, t.distance_km]
			
	for c in contacts:
		var dist_str = "%d KM" % c.distance_km if sensor_efficiency >= 0.5 else "ESTIMADA ~%d KM" % (c.distance_km + (randi() % 500 - 250))
		var status_str = ""
		if c.id == "BAE-01":
			status_str = " | COLAPSO EM: %ds" % int(km_collapse_seconds) if not km_is_destroyed else " | DESTRUÍDA"
		elif sensor_efficiency >= 0.75:
			status_str = " | CASCO: %d%% | ESCUDO: %d%%" % [c.hull, c.shield]
		elif sensor_efficiency >= 0.4:
			status_str = " | HOSTIL" if c.hostile else " | NEUTRO"
			
		text += "[color=%s][%s] %s[/color] (%s)%s\n" % [c.color, c.icon, c.name, dist_str, status_str]
	return text
