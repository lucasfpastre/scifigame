class_name ShipData
extends RefCounted

const CrewMemberScript = preload("res://scripts/crew_member.gd")

signal power_changed(system_name: String, value: int, available_power: int)
signal status_changed(hull: int, shield: int, alert_level: String)
signal quadrants_changed(quadrants: Dictionary, heading: int)
signal rescue_progress(rescued: int, total: int)
signal crew_intercom(speaker: String, text: String)

var ship_name: String = "CCS JOÃO CÂNDIDO // NX-900"
var total_power: int = 10
var hull: int = 100
var max_hull: int = 100
var alert_state: String = "NORMAL"

# Escudos Direcionais em 4 Quadrantes (0-100% cada)
var quadrants: Dictionary = {
	"FWD": 100,  # Proa / Frente
	"AFT": 100,  # Popa / Traseira
	"PORT": 100, # Bombordo / Esquerda
	"STBD": 100  # Boreste / Direita
}

# Orientação da nave: 0 = Norte (Proa aponta para cima), 90 = Leste, 180 = Sul, 270 = Oeste
var heading: int = 0

# Mecânica de Resgate da Kobayashi Maru
var civilians_rescued: int = 0
var total_civilians: int = 380
var transporter_active: bool = false
var chaff_count: int = 3

# Sistemas e energia alocada (0 a 4)
var systems: Dictionary = {
	"MOTORES": 2,
	"ESCUDOS": 2,
	"SENSORES": 2,
	"LASERS": 2,
	"SUPORTE": 1
}

# Tripulação da nave
var crew: Dictionary = {}

func _init() -> void:
	crew["PILOT"] = CrewMemberScript.new(CrewMemberScript.Role.PILOT, "Ten. Moreira", 75)
	crew["ENGINEER"] = CrewMemberScript.new(CrewMemberScript.Role.ENGINEER, "Eng. Barbosa", 80)
	crew["SCIENCE"] = CrewMemberScript.new(CrewMemberScript.Role.SCIENCE, "Dra. Dandara", 65)
	crew["TACTICAL"] = CrewMemberScript.new(CrewMemberScript.Role.TACTICAL, "Ten. Araripe", 70)

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
		"ESCUDOS", "SUPORTE": member = crew.get("ENGINEER")
		"SENSORES": member = crew.get("SCIENCE")
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
		"SENSORES": member = crew.get("SCIENCE")
		"LASERS": member = crew.get("TACTICAL")
		
	var crew_factor = member.get_efficiency_factor() if member else 1.0
	
	if power_val == 0.0 and member and member.trust >= 75:
		return 0.35 * crew_factor
		
	return (power_val * 0.25) * crew_factor

func get_average_shield() -> int:
	var total = quadrants["FWD"] + quadrants["AFT"] + quadrants["PORT"] + quadrants["STBD"]
	return int(total / 4.0)

# Dano direcionado ao quadrante atingido (se escudos estiverem baixados pelo teletransporte, vai direto pro casco!)
func apply_directional_damage(amount: int, target_quadrant: String) -> Dictionary:
	var result = {
		"quadrant": target_quadrant,
		"shield_absorbed": 0,
		"hull_damage": 0,
		"shield_collapsed": false
	}
	
	if transporter_active:
		# Teletransporte ativo: escudos estão baixados! Dano penetra integralmente no casco!
		hull = max(0, hull - amount)
		result["hull_damage"] = amount
		alert_state = "ALERTA VERMELHO"
	else:
		var q_shield = quadrants.get(target_quadrant, 0)
		var absorbed = min(q_shield, amount)
		quadrants[target_quadrant] -= absorbed
		result["shield_absorbed"] = absorbed
		
		var leftover = amount - absorbed
		if leftover > 0:
			hull = max(0, hull - leftover)
			result["hull_damage"] = leftover
			result["shield_collapsed"] = true
			
	if hull < 40:
		alert_state = "ALERTA VERMELHO"
	elif hull < 75 and alert_state == "NORMAL":
		alert_state = "ALERTA AMARELO"
		
	status_changed.emit(hull, get_average_shield(), alert_state)
	quadrants_changed.emit(quadrants, heading)
	
	var keys = crew.keys()
	var random_officer = crew[keys[randi() % keys.size()]]
	crew_intercom.emit(random_officer.avatar_ascii, random_officer.get_damage_reaction())
	return result

# Gira a nave em 90 graus (manobra de leme do piloto)
func rotate_ship_90() -> void:
	heading = (heading + 90) % 360
	quadrants_changed.emit(quadrants, heading)
	var pilot = crew.get("PILOT")
	if pilot:
		crew_intercom.emit(pilot.avatar_ascii, "%s: \"Executando manobra de giro! Proa alinhada para %d°.\"" % [pilot.name, heading])

# Regenera escudos nos quadrantes danificados
func regenerate_shields() -> void:
	var shield_pwr = systems.get("ESCUDOS", 0)
	if shield_pwr > 0 and not transporter_active:
		var regen_pool = int(shield_pwr * 4.0 * get_system_efficiency("ESCUDOS"))
		for q in ["FWD", "AFT", "PORT", "STBD"]:
			if quadrants[q] < 100 and regen_pool > 0:
				var needed = 100 - quadrants[q]
				var grant = min(needed, regen_pool)
				quadrants[q] += grant
				regen_pool -= grant
		status_changed.emit(hull, get_average_shield(), alert_state)
		quadrants_changed.emit(quadrants, heading)

# Transfere civis da Kobayashi Maru
func beam_civilians(amount: int) -> int:
	var remaining = total_civilians - civilians_rescued
	var to_beam = min(remaining, amount)
	civilians_rescued += to_beam
	rescue_progress.emit(civilians_rescued, total_civilians)
	return to_beam
