class_name ShipData
extends RefCounted

const CrewMemberScript = preload("res://scripts/crew_member.gd")

signal power_changed(system_name: String, value: int, available_power: int)
signal status_changed(hull: int, shield: int, alert_level: String)
signal crew_intercom(speaker: String, text: String)
signal game_event(title: String, desc: String)

var ship_name: String = "U.S.S. KOBAYASHI-TEST // NX-900"
var total_power: int = 10
var hull: int = 100
var max_hull: int = 100
var shield: int = 100
var max_shield: int = 100
var alert_state: String = "NORMAL" # NORMAL, ALERTA AMARELO, ALERTA VERMELHO

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
	# Inicializa tripulação padrão da simulação
	crew["PILOT"] = CrewMemberScript.new(CrewMemberScript.Role.PILOT, "Ten. Vega", 75)
	crew["ENGINEER"] = CrewMemberScript.new(CrewMemberScript.Role.ENGINEER, "Ch. O'Malley", 80)
	crew["SCIENCE"] = CrewMemberScript.new(CrewMemberScript.Role.SCIENCE, "Dra. T'Serra", 65)
	crew["TACTICAL"] = CrewMemberScript.new(CrewMemberScript.Role.TACTICAL, "Ten. Thorne", 70)

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
	
	# Verifica se algum tripulante tem comentário sobre a alteração
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

# Retorna a eficiência combinada de um módulo (Energia + Habilidade/Confiança do Tripulante)
func get_system_efficiency(sys_name: String) -> float:
	var power_val = float(systems.get(sys_name, 0))
	var member = null
	match sys_name:
		"MOTORES": member = crew.get("PILOT")
		"ESCUDOS": member = crew.get("ENGINEER")
		"SENSORES": member = crew.get("SCIENCE")
		"LASERS": member = crew.get("TACTICAL")
		
	var crew_factor = member.get_efficiency_factor() if member else 1.0
	
	# Se a confiança for alta (> 75%), mesmo com 0 de energia você tem uma margem de reserva
	if power_val == 0.0 and member and member.trust >= 75:
		return 0.35 * crew_factor
		
	return (power_val * 0.25) * crew_factor

func apply_damage(amount: int) -> void:
	if shield > 0:
		var absorbed = min(shield, amount)
		shield -= absorbed
		amount -= absorbed
		
	if amount > 0:
		hull = max(0, hull - amount)
		
	if shield <= 0 and alert_state != "ALERTA VERMELHO":
		alert_state = "ALERTA VERMELHO"
	elif hull < 60 and alert_state == "NORMAL":
		alert_state = "ALERTA AMARELO"
		
	status_changed.emit(hull, shield, alert_state)
	
	# Reação aleatória de um tripulante ao impacto
	var keys = crew.keys()
	var random_officer = crew[keys[randi() % keys.size()]]
	crew_intercom.emit(random_officer.avatar_ascii, random_officer.get_damage_reaction())

func regenerate_shields() -> void:
	var shield_pwr = systems.get("ESCUDOS", 0)
	if shield_pwr > 0 and shield < max_shield:
		var regen_rate = int(shield_pwr * 6.0 * get_system_efficiency("ESCUDOS"))
		shield = min(max_shield, shield + regen_rate)
		status_changed.emit(hull, shield, alert_state)
