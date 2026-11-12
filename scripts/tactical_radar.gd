class_name TacticalRadar
extends RefCounted

var grid_size: int = 17 # 17x17 grid
var contacts: Array[Dictionary] = []
var sweep_angle: float = 0.0

func _init() -> void:
	reset_simulation_sector()

func reset_simulation_sector() -> void:
	contacts.clear()
	
	# Kobayashi Maru (Cargueiro civil em perigo - Amarelo)
	contacts.append({
		"id": "KM-01",
		"name": "S.S. KOBAYASHI MARU",
		"type": "CIVILIAN_CARGO",
		"icon": "K",
		"color": "#ffff44",
		"x": 2,
		"y": -4,
		"distance_km": 4200,
		"hull": 28,
		"shield": 0,
		"hostile": false,
		"identified": false
	})
	
	# Cruzadores de Batalha Hostis (Inimigos - Vermelho)
	contacts.append({
		"id": "WAR-01",
		"name": "CRUZADOR K'VORT A",
		"type": "WARSHIP",
		"icon": "V",
		"color": "#ff4444",
		"x": -5,
		"y": -5,
		"distance_km": 7800,
		"hull": 100,
		"shield": 100,
		"hostile": true,
		"identified": false
	})
	
	contacts.append({
		"id": "WAR-02",
		"name": "CRUZADOR K'VORT B",
		"type": "WARSHIP",
		"icon": "V",
		"color": "#ff4444",
		"x": 6,
		"y": -3,
		"distance_km": 8900,
		"hull": 100,
		"shield": 100,
		"hostile": true,
		"identified": false
	})
	
	# Campo de destroços / asteroides (Neutro / Cautela - Verde Oliva)
	contacts.append({
		"id": "AST-01",
		"name": "CAMPO DE MINAS/DESTROÇOS",
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

# Avança o movimento dos contatos e aproximação
func update_tactical_step(player_engines_pwr: float) -> Array[String]:
	var events: Array[String] = []
	sweep_angle = fmod(sweep_angle + 45.0, 360.0)
	
	for contact in contacts:
		if contact.hostile:
			# Inimigos se aproximam do jogador
			contact.distance_km = max(800, contact.distance_km - 600)
			# Movem-se em direção ao centro (0, 0)
			if contact.x > 0: contact.x -= 1
			elif contact.x < 0: contact.x += 1
			if contact.y > 0: contact.y -= 1
			elif contact.y < 0: contact.y += 1
			
			if contact.distance_km <= 3500 and not contact.get("weapons_lock", false):
				contact["weapons_lock"] = true
				events.append("ALERTA: %s travou mira de torpedos de fótons em nossa nave!" % contact.name)
		else:
			# Se for a Kobayashi Maru e jogador tiver motores
			if contact.id == "KM-01" and player_engines_pwr > 0.0:
				var approach_rate = int(500 * player_engines_pwr)
				contact.distance_km = max(200, contact.distance_km - approach_rate)
				if contact.distance_km <= 1000 and not contact.get("transporters_ready", false):
					contact["transporters_ready"] = true
					events.append("RESGATE: Ao alcance dos transportadores da Kobayashi Maru!")
					
	return events

# Gera a representação visual em ASCII do Radar perfeitamente alinhada e com alto contraste
func render_ascii_radar(sensor_efficiency: float) -> String:
	var center = grid_size / 2
	var grid: Array[Array] = []
	
	# Inicializa grade com fundo sutil em cor escura (faint phosphor)
	for y in range(grid_size):
		var row: Array[String] = []
		for x in range(grid_size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(float(dx * dx + dy * dy))
			
			if dist < 0.8:
				row.append("[color=#00ffff]@[/color]") # Jogador no centro (Ciano brilhante)
			elif abs(dist - 3.5) < 0.6 or abs(dist - 7.0) < 0.6:
				row.append("[color=#194824].[/color]") # Anel de alcance discreto
			elif dx == 0 and abs(dy) < 8:
				row.append("[color=#153d1e]|[/color]") # Eixo vertical sutil
			elif dy == 0 and abs(dx) < 8:
				row.append("[color=#153d1e]-[/color]") # Eixo horizontal sutil
			else:
				row.append(" ") # Espaço vazio
		grid.append(row)
		
	# Posiciona contatos na grade com cores vivas para não se misturar com o fundo
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
			
	# Monta a moldura do radar com 36 caracteres de largura
	var result = "[color=#1d552c]+--- RADAR TÁTICO L.A.R. ----------+[/color]\n"
	for y in range(grid_size):
		var line_str = "[color=#1d552c]|[/color]"
		for x in range(grid_size):
			line_str += grid[y][x] + " "
		line_str += "[color=#1d552c]|[/color]\n"
		result += line_str
	result += "[color=#1d552c]+----------------------------------+[/color]\n"
	result += "LEGENDA: [color=#00ffff][@][/color] VOCÊ     [color=#ff4444][V][/color] INIMIGO\n"
	result += "         [color=#ffff44][K][/color] K.MARU   [color=#88aa77][*][/color] DESTROÇO"
	return result

func get_contact_telemetry(sensor_efficiency: float) -> String:
	var text = "[color=#33ff66]=== TELEMETRIA DE SENSORES ===[/color]\n"
	for c in contacts:
		var dist_str = "%d KM" % c.distance_km if sensor_efficiency >= 0.5 else "ESTIMADA ~%d KM" % (c.distance_km + (randi() % 500 - 250))
		var status_str = ""
		if sensor_efficiency >= 0.75:
			status_str = " | CASCO: %d%% | ESCUDO: %d%%" % [c.hull, c.shield]
		elif sensor_efficiency >= 0.4:
			status_str = " | ASSINATURA: " + ("HOSTIL" if c.hostile else "NEUTRA")
		else:
			status_str = " | DADOS INCOMPLETOS [SENSORES]"
			
		var col = c.color
		var name_str = c.name if sensor_efficiency >= 0.5 else "ALVO NÃO-IDENTIFICADO"
		text += "[color=%s][%s] %s[/color] (%s)%s\n" % [col, c.icon, name_str, dist_str, status_str]
	return text
