class_name GameState
extends Node

const SAVE_PATH = "user://alcantara_save.json"

static var selected_crew: Dictionary = {}
static var selected_ship_id: String = "SHIP_CANDIDO"

# Dados Persistentes (Meta-Progressão)
static var pha: int = 150 # Saldo inicial de boas-vindas
static var lifetime_civilians_saved: int = 0
static var lifetime_casualties: int = 0
static var total_runs: int = 0
static var unlocked_ships: Array = ["SHIP_CANDIDO"]
static var high_scores: Array = []

# Configurações do Terminal (Settings)
static var sfx_volume: float = 1.0
static var crt_curvature: bool = true
static var crt_scanlines: bool = true
static var haptics_enabled: bool = true

static var last_debriefing: Dictionary = {}

static func _static_init() -> void:
	load_save()

static func get_ship_definitions() -> Dictionary:
	return {
		"SHIP_CANDIDO": {
			"id": "SHIP_CANDIDO",
			"name": "CCS João Cândido // NX-900",
			"callsign": "O Almirante Negro",
			"class_type": "CRUZADOR DE LINHA (PADRÃO)",
			"cost": 0,
			"power": 10,
			"hull": 100,
			"shield_per_quad": 100,
			"buffer_max": 50,
			"desc": "Belonave padrão da Coalizão. Equilíbrio perfeito entre defletores, velocidade de aproximação e reator.",
			"pro": "Equilibrada e confiável para qualquer perfil de missão.",
			"con": "Sem especialização extrema em velocidade ou blindagem pesada."
		},
		"SHIP_GUARANI": {
			"id": "SHIP_GUARANI",
			"name": "Corveta Guaraní // CL-40",
			"callsign": "Relâmpago da Fronteira",
			"class_type": "CORVETA LIGEIRA",
			"cost": 450,
			"power": 10,
			"hull": 65,
			"shield_per_quad": 75,
			"buffer_max": 40,
			"desc": "Nave de reconhecimento ultrarrápida projetada para patrulha de fronteira nos rios de estrelas.",
			"pro": "+40% de velocidade de aproximação e evasão natural aprimorada.",
			"con": "Casco leve (65 HP) e escudos menores (75% por setor)."
		},
		"SHIP_TAMANDARE": {
			"id": "SHIP_TAMANDARE",
			"name": "Couraçado Tamandaré // BB-12",
			"callsign": "A Fortaleza de Aço",
			"class_type": "BELONAVE PESADA",
			"cost": 900,
			"power": 14,
			"hull": 150,
			"shield_per_quad": 125,
			"buffer_max": 65,
			"desc": "Titã de guerra da Frota Sul-Atlântica com blindagem de nanocompósito e reator pesado de plasma.",
			"pro": "14 MW no Reator base, Casco maciço (150 HP) e Escudos 125%.",
			"con": "Pesada e lenta: aproximação -30% e manobra de giro consome mais tempo."
		}
	}

static func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(json_str)
	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		pha = int(data.get("pha", 150))
		lifetime_civilians_saved = int(data.get("lifetime_civilians_saved", 0))
		lifetime_casualties = int(data.get("lifetime_casualties", 0))
		total_runs = int(data.get("total_runs", 0))
		unlocked_ships = data.get("unlocked_ships", ["SHIP_CANDIDO"])
		selected_ship_id = data.get("selected_ship_id", "SHIP_CANDIDO")
		high_scores = data.get("high_scores", [])
		sfx_volume = float(data.get("sfx_volume", 1.0))
		crt_curvature = bool(data.get("crt_curvature", true))
		crt_scanlines = bool(data.get("crt_scanlines", true))
		haptics_enabled = bool(data.get("haptics_enabled", true))

static func save_game() -> void:
	var data = {
		"pha": pha,
		"lifetime_civilians_saved": lifetime_civilians_saved,
		"lifetime_casualties": lifetime_casualties,
		"total_runs": total_runs,
		"unlocked_ships": unlocked_ships,
		"selected_ship_id": selected_ship_id,
		"high_scores": high_scores,
		"sfx_volume": sfx_volume,
		"crt_curvature": crt_curvature,
		"crt_scanlines": crt_scanlines,
		"haptics_enabled": haptics_enabled
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

static func unlock_ship(ship_id: String) -> bool:
	var ships = get_ship_definitions()
	if not ships.has(ship_id):
		return false
	var def = ships[ship_id]
	if pha >= def["cost"] and not unlocked_ships.has(ship_id):
		pha -= def["cost"]
		unlocked_ships.append(ship_id)
		selected_ship_id = ship_id
		save_game()
		return true
	return false

# Registra a partida e calcula a pontuação e avaliação oficial da Academia
static func record_run_result(civilians_saved: int, casualties: int, ticks_survived: int,
		torpedoes_intercepted: int, cruisers_destroyed: int, reason: String, is_hacked: bool = false) -> Dictionary:
	total_runs += 1
	lifetime_civilians_saved += civilians_saved
	lifetime_casualties += casualties
	
	# Cálculo de Pontos de Honra de Alcântara (PHA)
	var pts_civilians = civilians_saved * 10
	var pts_casualties_penalty = casualties * 15
	var pts_ticks = ticks_survived * 5
	var pts_torpedoes = torpedoes_intercepted * 30
	var pts_cruisers = cruisers_destroyed * 250
	
	var total_score = max(0, pts_civilians - pts_casualties_penalty + pts_ticks + pts_torpedoes + pts_cruisers)
	
	# Bônus ético especial se resgatou mais da metade
	var ethical_bonus = 0
	if civilians_saved >= 190:
		ethical_bonus = 250
		total_score += ethical_bonus
		
	var warp_bonus = 0
	if reason.begins_with("RETIRADA TÁTICA"):
		warp_bonus = 350
		total_score += warp_bonus
		
	var pha_earned = int(total_score * 0.1) # Converte pontos em moeda PHA (10% do score)
	
	# Patente Militar Concedida
	var rank_title = "Cadete de 3ª Classe"
	var evaluation = "Ainda há muito a aprender sobre o peso do comando e a frieza sob fogo."
	
	if is_hacked:
		total_score += 1500
		pha_earned += 300
		rank_title = "ESTRATEGISTA LENDÁRIO // PROTOCOLO ALMIRANTE 1910"
		evaluation = "VIOLAÇÃO DO PROTOCOLO DE ALCÂNTARA: O cadete reprogramou o mainframe da simulação e salvou a tripulação sem aceitar o cenário sem vitória. Um ato de insubordinação genial digno da história da Frota."
	elif reason.begins_with("RETIRADA TÁTICA") and civilians_saved > 0:
		if total_score >= 1200:
			rank_title = "Capitão de Corveta // Sobrevivência Tática"
		else:
			rank_title = "Primeiro-Tenente // Retirada Prudente"
		evaluation = "DECISÃO DE RETIRADA TÁTICA: O comandante priorizou a preservação de %d vidas salvas e de sua guarnição diante do aniquilamento certo. Uma escolha amarga, porém honrosa e lúcida." % civilians_saved
	elif total_score >= 3200:
		rank_title = "Comandante Honorário // Medalha Almirante Negro"
		evaluation = "Desempenho lendário. O resgate quase total do Baependi entrará para a história militar da Coalizão."
	elif total_score >= 2200:
		rank_title = "Capitão de Fragata Condecorado"
		evaluation = "Liderança exemplar. Demonstrou fibra heróica diante de probabilidades impossíveis."
	elif total_score >= 1400:
		rank_title = "Capitão de Corveta"
		evaluation = "Excelente controle de crise e bravura no cumprimento da diretiva de salvamento."
	elif total_score >= 800:
		rank_title = "Primeiro-Tenente da Frota"
		evaluation = "Cumprimento honroso das ordens de salvamento, apesar das avarias severas."
	elif total_score >= 400:
		rank_title = "Segundo-Tenente da Frota"
		evaluation = "Demonstrou nobreza tática na Zona Desmilitarizada. Continue seu treinamento."
	elif total_score >= 150:
		rank_title = "Aspirante a Oficial"
		evaluation = "Primeiros passos sob fogo real. Mantenha a calma na próxima simulação."
		
	pha += pha_earned
	
	var debrief = {
		"run_number": total_runs,
		"ship_name": get_ship_definitions().get(selected_ship_id, {}).get("name", "CCS João Cândido"),
		"civilians_saved": civilians_saved,
		"casualties": casualties,
		"ticks_survived": ticks_survived,
		"torpedoes_intercepted": torpedoes_intercepted,
		"cruisers_destroyed": cruisers_destroyed,
		"pts_civilians": pts_civilians,
		"pts_penalties": pts_casualties_penalty,
		"pts_ticks": pts_ticks,
		"pts_combat": pts_torpedoes + pts_cruisers,
		"ethical_bonus": ethical_bonus,
		"warp_bonus": warp_bonus,
		"total_score": total_score,
		"pha_earned": pha_earned,
		"rank_title": rank_title,
		"evaluation": evaluation,
		"reason": reason,
		"is_hacked": is_hacked
	}
	
	last_debriefing = debrief
	
	# Salva nos recordes históricos
	high_scores.append({
		"score": total_score,
		"rank": rank_title,
		"civilians": civilians_saved,
		"hacked": is_hacked,
		"date_run": Time.get_datetime_string_from_system()
	})
	
	# Ordena high scores pelo maior placar (mantém top 8)
	high_scores.sort_custom(func(a, b): return a["score"] > b["score"])
	if high_scores.size() > 8:
		high_scores.resize(8)
		
	save_game()
	return debrief
