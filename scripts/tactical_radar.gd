class_name TacticalRadar
extends RefCounted

var grid_size: int = 17 # 17x17 grid
var contacts: Array[Dictionary] = []
var active_torpedoes: Array[Dictionary] = []

# Relógio de Colapso do Baependi
var km_collapse_seconds: float = 180.0
var km_is_destroyed: bool = false
var sweep_phase: int = 0

# Fases da Emboscada Fascista
# 0: Silêncio / Busca inicial (Apenas Baependi e Minas)
# 1: Falange A emerge do hiperespaço
# 2: Falange B flanqueia o setor
var ambush_stage: int = 0
var ambush_ticks: int = 0

# Baralho de Eventos Aleatórios
var next_event_cooldown: int = 5
var ion_storm_ticks: int = 0
var bonus_beam_civilians: int = 0

func _init() -> void:
	reset_simulation_sector()

func reset_simulation_sector() -> void:
	contacts.clear()
	active_torpedoes.clear()
	km_collapse_seconds = 180.0
	km_is_destroyed = false
	ambush_stage = 0
	ambush_ticks = 0
	next_event_cooldown = randi_range(4, 7)
	ion_storm_ticks = 0
	bonus_beam_civilians = 0
	
	# O setor inicia SILENCIOSO: apenas a nave civil em perigo e os destroços
	contacts.append({
		"id": "BAE-01",
		"name": "CARGUEIRO CIVIL BAEPENDI",
		"type": "CIVILIAN_CARGO",
		"icon": "B",
		"color": "#ffff44",
		"x": 2,
		"y": -3,
		"distance_km": 3400,
		"hull": 40,
		"shield": 0,
		"hostile": false,
		"identified": false
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
		return true
	return false

# Avança o ciclo tático / tick do radar com estágios de emboscada e eventos
func update_tactical_tick(player_engines_eff: float, player_heading: int, is_transporting: bool) -> Dictionary:
	var tick_result = {
		"events": [] as Array[String],
		"torpedo_hits": [] as Array[Dictionary],
		"new_torpedoes_launched": false,
		"ambush_event": false
	}
	sweep_phase = (sweep_phase + 1) % 4
	
	# 1. Controle da Emboscada Escalonada
	var bae_contact = _get_contact("BAE-01")
	var bae_distance = bae_contact.distance_km if bae_contact else 9999
	
	if ambush_stage == 0:
		# Dispara a Fase 1 quando o teletransporte é ativado ou a nave se aproxima
		if is_transporting or bae_distance <= 1200:
			ambush_stage = 1
			ambush_ticks = 0
			_spawn_falange_a()
			tick_result["events"].append("!! DISTORÇÃO HIPERESPACIAL: NAVE HOSTIL DETECTADA! FALANGE A SAIU DE DOBRA !!")
			tick_result["ambush_event"] = true
	elif ambush_stage == 1:
		ambush_ticks += 1
		# 4 a 5 pulsos depois, o segundo cruzador surge flanqueando!
		if ambush_ticks >= 4:
			ambush_stage = 2
			_spawn_falange_b()
			tick_result["events"].append("!! EMBOSCADA TOTAL: SEGUNDA NAVE FASCISTA DETECTADA! FALANGE B FECHA O CERCO A LESTE !!")
			tick_result["ambush_event"] = true

	# 2. Movimentação e disparo dos inimigos
	for contact in contacts:
		if contact.hostile:
			contact.distance_km = max(1200, contact.distance_km - 350)
			if contact.x > 0 and randf() < 0.5: contact.x -= 1
			elif contact.x < 0 and randf() < 0.5: contact.x += 1
			if contact.y > 0 and randf() < 0.5: contact.y -= 1
			elif contact.y < 0 and randf() < 0.5: contact.y += 1
			
			contact["torpedo_cooldown"] = contact.get("torpedo_cooldown", 6) - 1
			if contact["torpedo_cooldown"] <= 0 and contact.distance_km <= 8500:
				contact["torpedo_cooldown"] = randi_range(6, 9)
				_launch_torpedo_from(contact)
				tick_result["events"].append("ALERTA TÁTICO: %s DISPAROU TORPEDO DE FÓTONS!" % contact.name)
				tick_result["new_torpedoes_launched"] = true
		else:
			if contact.id == "BAE-01" and player_engines_eff > 0.0:
				var approach_rate = int(350 * player_engines_eff)
				contact.distance_km = max(200, contact.distance_km - approach_rate)
				if contact.distance_km <= 1200 and not contact.get("transporters_ready", false):
					contact["transporters_ready"] = true
					tick_result["events"].append("TELETRANSPORTE PRONTO: Ao alcance dos civis do Baependi!")
	
	# 3. Atualização dos Torpedos em vôo
	var surviving_torps: Array[Dictionary] = []
	for torp in active_torpedoes:
		torp.distance_km -= torp.speed_km
		if torp.x > 0: torp.x -= 1
		elif torp.x < 0: torp.x += 1
		if torp.y > 0: torp.y -= 1
		elif torp.y < 0: torp.y += 1
		
		if torp.distance_km <= 300 or (torp.x == 0 and torp.y == 0):
			var impact_quadrant = _calculate_impact_quadrant(torp.origin_dx, torp.origin_dy, player_heading)
			tick_result["torpedo_hits"].append({
				"id": torp.id,
				"damage": randi_range(18, 28),
				"quadrant": impact_quadrant
			})
			tick_result["events"].append("! IMPACTO DE TORPEDO no setor [%s] !" % impact_quadrant)
		else:
			surviving_torps.append(torp)
	active_torpedoes = surviving_torps
	
	# 4. Sorteio de Eventos Aleatórios Procedurais
	if ambush_stage > 0:
		next_event_cooldown -= 1
		if next_event_cooldown <= 0:
			next_event_cooldown = randi_range(5, 8)
			var ev_msg = _trigger_procedural_event(player_engines_eff)
			if ev_msg != "":
				tick_result["events"].append(ev_msg)
				
	if ion_storm_ticks > 0:
		ion_storm_ticks -= 1
		
	return tick_result

func _spawn_falange_a() -> void:
	contacts.append({
		"id": "FAL-01",
		"name": "CRUZADOR FASCISTA FALANGE A",
		"type": "WARSHIP",
		"icon": "V",
		"color": "#ff4444",
		"x": -7,
		"y": -6,
		"distance_km": 10500,
		"hull": 100,
		"shield": 100,
		"hostile": true,
		"identified": false,
		"torpedo_cooldown": 5
	})

func _spawn_falange_b() -> void:
	contacts.append({
		"id": "FAL-02",
		"name": "CRUZADOR FASCISTA FALANGE B",
		"type": "WARSHIP",
		"icon": "V",
		"color": "#ff4444",
		"x": 7,
		"y": -4,
		"distance_km": 11800,
		"hull": 100,
		"shield": 100,
		"hostile": true,
		"identified": false,
		"torpedo_cooldown": 6
	})

func _trigger_procedural_event(player_engines_eff: float) -> String:
	var event_roll = randi() % 5
	match event_roll:
		0:
			# Vazamento de antimatéria acelera colapso
			km_collapse_seconds = max(15.0, km_collapse_seconds - 25.0)
			return "INCIDENTE NO BAEPENDI: Vazamento de antimatéria! Tempo de colapso reduzido em 25s!"
		1:
			# Tempestade de íons cega sensores
			ion_storm_ticks = 3
			return "ANOMALIA: Tempestade magnética de Abrolhos detectada! Sensores com interferência severa por 3 pulsos."
		2:
			# Fluxo heróico de civis: bônus de acolhimento
			bonus_beam_civilians = 20
			return "TRANSMISSÃO CIVIL: Equipe do Baependi abriu uma escotilha de vácuo auxiliar! Próximo resgate trará +20 civis extras!"
		3:
			# Mina espacial puxada pelo vetor gravitacional
			if player_engines_eff < 0.25:
				return "PERIGO DE DERIVA: Uma mina do campo de Abrolhos arranhou nossos defletores por falta de propulsão!"
			else:
				return "MANOBRA EVASIVA: Piloto desviou com sucesso de estilhaços de mina espacial à deriva."
		4:
			# Sobrecarga nos cruzadores fascistas
			var fal = _get_contact("FAL-01")
			if fal:
				fal["torpedo_cooldown"] += 3
				return "FALHA FASCISTA: Interceptamos telemetria da Falange A: capacitores deles superaqueceram (+3 pulsos de recarga)!"
	return ""

func _get_contact(p_id: String) -> Dictionary:
	for c in contacts:
		if c.id == p_id:
			return c
	return {}

func _launch_torpedo_from(source: Dictionary) -> void:
	var torp_id = "TORP-%02d" % (randi() % 90 + 10)
	active_torpedoes.append({
		"id": torp_id,
		"x": source.x,
		"y": source.y,
		"origin_dx": source.x,
		"origin_dy": source.y,
		"distance_km": min(6000, source.distance_km),
		"speed_km": 900
	})

func _calculate_impact_quadrant(origin_dx: int, origin_dy: int, heading: int) -> String:
	var angle_rad = atan2(float(origin_dy), float(origin_dx))
	var angle_deg = int(rad_to_deg(angle_rad)) + 90
	if angle_deg < 0: angle_deg += 360
	
	var rel_angle = (angle_deg - heading) % 360
	if rel_angle < 0: rel_angle += 360
	
	if rel_angle >= 315 or rel_angle < 45: return "FWD"
	elif rel_angle >= 45 and rel_angle < 135: return "STBD"
	elif rel_angle >= 135 and rel_angle < 225: return "AFT"
	else: return "PORT"

func intercept_nearest_torpedo(laser_efficiency: float) -> Dictionary:
	if active_torpedoes.is_empty():
		return { "success": false, "message": "Nenhum torpedo hostil em trajetória!" }
		
	var nearest_torp = active_torpedoes[0]
	for t in active_torpedoes:
		if t.distance_km < nearest_torp.distance_km:
			nearest_torp = t
			
	var hit_chance = 0.55 + (laser_efficiency * 0.35)
	if randf() < hit_chance:
		active_torpedoes.erase(nearest_torp)
		return { "success": true, "message": "Feixe laser interceptou e detonou %s antes do impacto!" % nearest_torp.id }
	else:
		return { "success": false, "message": "Disparo dos feixes errou o torpedo em aproximação!" }

func deploy_chaff_countermeasure() -> bool:
	if active_torpedoes.is_empty():
		return false
	active_torpedoes.remove_at(0)
	return true

func render_ascii_radar(sensor_efficiency: float) -> String:
	# Aplica penalidade se houver tempestade de íons
	var effective_sensors = sensor_efficiency * 0.5 if ion_storm_ticks > 0 else sensor_efficiency
	
	var center = grid_size / 2
	var grid: Array[Array] = []
	
	for y in range(grid_size):
		var row: Array[String] = []
		for x in range(grid_size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(float(dx * dx + dy * dy))
			
			if dist < 0.8:
				row.append("[color=#00ffff]@[/color]")
			elif abs(dist - 3.5) < 0.6 or abs(dist - 7.0) < 0.6:
				row.append("[color=#194824].[/color]")
			elif dx == 0 and abs(dy) < 8:
				row.append("[color=#153d1e]|[/color]")
			elif dy == 0 and abs(dx) < 8:
				row.append("[color=#153d1e]-[/color]")
			else:
				row.append(" ")
		grid.append(row)
		
	for contact in contacts:
		var cx = center + contact.x
		var cy = center + contact.y
		if cx >= 0 and cx < grid_size and cy >= 0 and cy < grid_size:
			var icon_char = contact.icon
			var icon_col = contact.color
			if effective_sensors < 0.4:
				icon_char = "?"
				icon_col = "#ffaa00"
			grid[cy][cx] = "[color=%s]%s[/color]" % [icon_col, icon_char]
			
	for torp in active_torpedoes:
		var tx = center + torp.x
		var ty = center + torp.y
		if tx >= 0 and tx < grid_size and ty >= 0 and ty < grid_size:
			grid[ty][tx] = "[color=#ff1111][b]![/b][/color]"
			
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
	var effective_sensors = sensor_efficiency * 0.5 if ion_storm_ticks > 0 else sensor_efficiency
	var text = "[color=#33ff66]=== TELEMETRIA DE SENSORES ===[/color]\n"
	
	if ion_storm_ticks > 0:
		text += "[color=#ffaa33]** INTERFERÊNCIA MAGNÉTICA ATIVA (%d pulsos) **[/color]\n" % ion_storm_ticks
		
	if not active_torpedoes.is_empty():
		text += "[color=#ff2222]!! ALERTA: %d TORPEDO(S) EM CURSO DE COLISÃO !![/color]\n" % active_torpedoes.size()
		for t in active_torpedoes:
			text += "[color=#ff4444] >> %s: DIST %d KM[/color]\n" % [t.id, t.distance_km]
			
	for c in contacts:
		var dist_str = "%d KM" % c.distance_km if effective_sensors >= 0.5 else "ESTIMADA ~%d KM" % (c.distance_km + (randi() % 500 - 250))
		var status_str = ""
		if c.id == "BAE-01":
			status_str = " | COLAPSO EM: %ds" % int(km_collapse_seconds) if not km_is_destroyed else " | DESTRUÍDA"
		elif effective_sensors >= 0.75:
			status_str = " | CASCO: %d%% | ESCUDO: %d%%" % [c.hull, c.shield]
		elif effective_sensors >= 0.4:
			status_str = " | HOSTIL" if c.hostile else " | NEUTRO"
			
		text += "[color=%s][%s] %s[/color] (%s)%s\n" % [c.color, c.icon, c.name, dist_str, status_str]
	return text
