class_name ShipData
extends RefCounted

const CrewMemberScript = preload("res://scripts/crew_member.gd")

signal power_changed(system_name: String, value: int, available_power: int)
signal status_changed(hull: int, shield: int, alert_level: String)
signal quadrants_changed(quadrants: Dictionary, heading: int)
signal rescue_progress(rescued: int, buffer: int, total: int, casualties: int)
signal crew_intercom(speaker: String, text: String)

var ship_id: String = "SHIP_CANDIDO"
var ship_name: String = "CCS JOÃO CÂNDIDO // NX-900"
var total_power: int = 10
var hull: int = 100
var max_hull: int = 100
var max_quad_shield: int = 100
var alert_state: String = "NORMAL"
var speed_factor: float = 1.0

# Escudos Direcionais em 4 Quadrantes
var quadrants: Dictionary = {
	"FWD": 100,
	"AFT": 100,
	"PORT": 100,
	"STBD": 100
}

# Orientação da nave: 0 = Norte (Proa aponta para cima), 90 = Leste, 180 = Sul, 270 = Oeste
var heading: int = 0

# Mecânica de Resgate e Buffer da Baia Médica
var transporter_buffer: int = 0
var max_buffer: int = 50
var civilians_rescued: int = 0
var civilians_casualties: int = 0
var total_civilians: int = 380
var transporter_active: bool = false
var chaff_count: int = 3
var life_support_zero_ticks: int = 0

# Estatísticas de combate da partida
var torpedoes_intercepted_count: int = 0
var cruisers_destroyed_count: int = 0

# Sistemas e energia alocada
var systems: Dictionary = {
	"MOTORES": 2,
	"ESCUDOS": 2,
	"SENSORES": 2,
	"LASERS": 2,
	"SUPORTE": 1
}

# Tripulação da nave
var crew: Dictionary = {}

func _init(custom_crew: Dictionary = {}, p_ship_id: String = "") -> void:
	if p_ship_id == "":
		p_ship_id = GameState.selected_ship_id
	ship_id = p_ship_id
	
	var ship_defs = GameState.get_ship_definitions()
	var def = ship_defs.get(ship_id, ship_defs["SHIP_CANDIDO"])
	
	ship_name = def["name"]
	hull = def["hull"]
	max_hull = def["hull"]
	max_quad_shield = def["shield_per_quad"]
	max_buffer = def["buffer_max"]
	total_power = def["power"]
	
	if ship_id == "SHIP_GUARANI":
		speed_factor = 1.4
	elif ship_id == "SHIP_TAMANDARE":
		speed_factor = 0.7
	else:
		speed_factor = 1.0
		
	quadrants = {
		"FWD": max_quad_shield,
		"AFT": max_quad_shield,
		"PORT": max_quad_shield,
		"STBD": max_quad_shield
	}

	if not custom_crew.is_empty():
		crew = custom_crew
	else:
		var roster = CrewMemberScript.get_available_roster()
		crew["PILOT"] = roster["PILOT"][0]       # Ten. Moreira
		crew["ENGINEER"] = roster["ENGINEER"][0] # Eng. Barbosa
		crew["MEDICAL"] = roster["MEDICAL"][0]   # Dr. Vital
		crew["TACTICAL"] = roster["TACTICAL"][0] # Ten. Tibúrcio

	# Traço do Engenheiro Barbosa: Milagreiro (+2 MW extras em qualquer nave!)
	if crew.has("ENGINEER") and crew["ENGINEER"].id == "ENG_BARBOSA":
		total_power += 2

func get_used_power() -> int:
	var total = 0
	for key in systems:
		total += systems[key]
	return total

func get_available_power() -> int:
	return total_power - get_used_power()

func can_increase_power(sys_name: String) -> bool:
	if not systems.has(sys_name):
		return false
	return get_available_power() > 0 and systems[sys_name] < 4

func can_decrease_power(sys_name: String) -> bool:
	if not systems.has(sys_name):
		return false
	# Traço do Eng. Barbosa: Recusa-se a desligar o Suporte de Vida (mínimo 1 MW)
	if sys_name == "SUPORTE" and crew.has("ENGINEER") and crew["ENGINEER"].id == "ENG_BARBOSA":
		return systems["SUPORTE"] > 1
	return systems[sys_name] > 0

func adjust_power(sys_name: String, delta: int) -> bool:
	if not systems.has(sys_name):
		return false
	
	if delta > 0 and can_increase_power(sys_name):
		systems[sys_name] += 1
	elif delta < 0 and can_decrease_power(sys_name):
		systems[sys_name] -= 1
	else:
		return false
		
	power_changed.emit(sys_name, systems[sys_name], get_available_power())
	_trigger_crew_power_reaction(sys_name, systems[sys_name])
	return true

func _trigger_crew_power_reaction(sys_name: String, new_val: int) -> void:
	var member = null
	match sys_name:
		"MOTORES": member = crew.get("PILOT")
		"ESCUDOS": member = crew.get("ENGINEER")
		"SUPORTE": member = crew.get("MEDICAL") if new_val == 0 else crew.get("ENGINEER")
		"SENSORES": member = crew.get("PILOT")
		"LASERS": member = crew.get("TACTICAL")
		
	if member:
		var reaction = member.get_power_reaction(sys_name, new_val)
		if reaction != "":
			crew_intercom.emit(member.avatar_ascii, reaction)

func get_system_efficiency(sys_name: String) -> float:
	var power_val = float(systems.get(sys_name, 0))
	var member = null
	match sys_name:
		"MOTORES": member = crew.get("PILOT")
		"ESCUDOS": member = crew.get("ENGINEER")
		"SENSORES": member = crew.get("PILOT")
		"LASERS": member = crew.get("TACTICAL")
		"SUPORTE": member = crew.get("MEDICAL")
		
	var crew_factor = member.get_efficiency_factor() if member else 1.0
	
	if power_val == 0.0 and member and member.trust >= 75:
		return 0.35 * crew_factor
		
	return (power_val * 0.25) * crew_factor

func get_average_shield() -> int:
	var total = quadrants["FWD"] + quadrants["AFT"] + quadrants["PORT"] + quadrants["STBD"]
	var max_total = float(max_quad_shield * 4)
	return int((total / max_total) * 100.0)

# Dano direcionado ao quadrante atingido
func apply_directional_damage(amount: int, target_quadrant: String) -> Dictionary:
	var result = {
		"quadrant": target_quadrant,
		"shield_absorbed": 0,
		"hull_damage": 0,
		"shield_collapsed": false
	}
	
	if transporter_active:
		hull = max(0, hull - amount)
		result["hull_damage"] = amount
		alert_state = "ALERTA VERMELHO"
	else:
		var q_shield = quadrants.get(target_quadrant, 0)
		var absorption_multiplier = 1.25 if (crew.has("TACTICAL") and crew["TACTICAL"].id == "TAC_DANDARA") else 1.0
		var effective_shield = int(q_shield * absorption_multiplier)
		
		var absorbed = min(effective_shield, amount)
		var actual_shield_loss = int(absorbed / absorption_multiplier)
		quadrants[target_quadrant] = max(0, quadrants[target_quadrant] - actual_shield_loss)
		result["shield_absorbed"] = absorbed
		
		var leftover = amount - absorbed
		if leftover > 0:
			hull = max(0, hull - leftover)
			result["hull_damage"] = leftover
			result["shield_collapsed"] = true
			
	if hull < int(max_hull * 0.4):
		alert_state = "ALERTA VERMELHO"
	elif hull < int(max_hull * 0.75) and alert_state == "NORMAL":
		alert_state = "ALERTA AMARELO"
		
	status_changed.emit(hull, get_average_shield(), alert_state)
	quadrants_changed.emit(quadrants, heading)
	
	var keys = crew.keys()
	var random_officer = crew[keys[randi() % keys.size()]]
	crew_intercom.emit(random_officer.avatar_ascii, random_officer.get_damage_reaction())
	return result

func rotate_ship_90() -> void:
	heading = (heading + 90) % 360
	quadrants_changed.emit(quadrants, heading)
	var pilot = crew.get("PILOT")
	if pilot:
		crew_intercom.emit(pilot.avatar_ascii, "%s: \"Executando manobra de giro! Proa alinhada para %d°.\"" % [pilot.name, heading])

func regenerate_shields() -> void:
	var shield_pwr = systems.get("ESCUDOS", 0)
	if shield_pwr > 0 and not transporter_active:
		var regen_pool = int(shield_pwr * 4.0 * get_system_efficiency("ESCUDOS"))
		for q in ["FWD", "AFT", "PORT", "STBD"]:
			if quadrants[q] < max_quad_shield and regen_pool > 0:
				var needed = max_quad_shield - quadrants[q]
				var grant = min(needed, regen_pool)
				quadrants[q] += grant
				regen_pool -= grant
		status_changed.emit(hull, get_average_shield(), alert_state)
		quadrants_changed.emit(quadrants, heading)

# Transfere civis do Baependi para a Plataforma de Teletransporte
func beam_to_buffer(amount: int) -> Dictionary:
	var space_in_buffer = max_buffer - transporter_buffer
	if space_in_buffer <= 0:
		return { "beamed": 0, "buffer_full": true }
		
	var remaining_in_baependi = total_civilians - (civilians_rescued + transporter_buffer + civilians_casualties)
	var to_beam = min(space_in_buffer, min(remaining_in_baependi, amount))
	transporter_buffer += to_beam
	rescue_progress.emit(civilians_rescued, transporter_buffer, total_civilians, civilians_casualties)
	return { "beamed": to_beam, "buffer_full": transporter_buffer >= max_buffer }

# Baia Médica processa civis do buffer e os transfere para os alojamentos seguros
func process_medical_triage() -> Dictionary:
	var med: CrewMember = crew.get("MEDICAL")
	var pwr_support = systems.get("SUPORTE", 1)
	
	var rate = 20
	if med:
		if med.id == "MED_VITAL":
			rate = 40
		elif med.id == "MED_NABUCO":
			rate = 15
			
	if pwr_support == 0:
		rate = max(5, int(rate * 0.3))
		life_support_zero_ticks += 1
	else:
		life_support_zero_ticks = 0
		
	var processed = min(transporter_buffer, rate)
	transporter_buffer -= processed
	civilians_rescued += processed
	
	var casualties = 0
	var msg = ""
	
	if pwr_support == 0:
		if med and med.id == "MED_VITAL":
			casualties = randi_range(3, 8)
		elif med and med.id == "MED_NABUCO":
			if life_support_zero_ticks > 3:
				casualties = randi_range(2, 5)
		else:
			casualties = randi_range(2, 6)
			
	if casualties > 0:
		casualties = min(civilians_rescued, casualties)
		civilians_rescued -= casualties
		civilians_casualties += casualties
		msg = "ALERTA MÉDICO: A Baia Médica perdeu %d civis por falta de oxigênio/temperatura!" % casualties
		
	rescue_progress.emit(civilians_rescued, transporter_buffer, total_civilians, civilians_casualties)
	return { "processed": processed, "casualties": casualties, "msg": msg }
