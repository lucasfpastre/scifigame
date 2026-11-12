class_name CrewMember
extends RefCounted

enum Role { PILOT, ENGINEER, SCIENCE, TACTICAL }

var role: Role
var name: String
var role_title: String
var trust: int = 65 # 0-100 (Confiança no Capitão)
var stress: int = 15 # 0-100 (Nível de Estresse)
var avatar_ascii: String = ""

func _init(p_role: Role, p_name: String, p_trust: int = 65) -> void:
	role = p_role
	name = p_name
	trust = clamp(p_trust, 0, 100)
	
	match role:
		Role.PILOT:
			role_title = "PILOTO / NAVEGAÇÃO"
			avatar_ascii = "[TEN. MOREIRA - NAV]"
		Role.ENGINEER:
			role_title = "ENGENHARIA-CHEFE"
			avatar_ascii = "[ENG. BARBOSA]"
		Role.SCIENCE:
			role_title = "CIÊNCIAS / SENSORES"
			avatar_ascii = "[DRA. DANDARA]"
		Role.TACTICAL:
			role_title = "TÁTICO / DEFESA"
			avatar_ascii = "[TEN. ARARIPE]"

# Retorna a eficiência bônus baseada em confiança e estresse (0.7 a 1.5)
func get_efficiency_factor() -> float:
	var trust_mod = (trust - 50.0) / 100.0 # -0.5 a +0.5
	var stress_penalty = (stress / 200.0)  # 0 a 0.5
	return clamp(1.0 + trust_mod - stress_penalty, 0.6, 1.6)

# Mensagens de voz/rádio do tripulante de acordo com o contexto
func get_power_reaction(system_name: String, new_power: int) -> String:
	match role:
		Role.PILOT:
			if system_name == "MOTORES":
				if new_power >= 3:
					return "%s: \"Propulsores no máximo, Capitão! Estamos manobrando feito um caça.\"" % name
				elif new_power == 0:
					if trust >= 70:
						return "%s: \"Sem energia nos motores! Deixa comigo, vou compensar nos propulsores de atitude!\"" % name
					else:
						return "%s: \"Estamos à deriva, Capitão! Não consigo desviar de nada assim!\"" % name
		Role.ENGINEER:
			if system_name == "ESCUDOS":
				if new_power >= 3:
					return "%s: \"Geradores de campo em 120%%! Os escudos vão aguentar chumbo grosso!\"" % name
				elif new_power == 0:
					return "%s: \"Escudos desativados! Qualquer fragmento agora arranha nosso casco direto!\"" % name
			elif system_name == "SUPORTE":
				if new_power == 0:
					return "%s: \"Desligando suporte de vida?! A temperatura vai cair, mas liberamos potência pro reator!\"" % name
		Role.SCIENCE:
			if system_name == "SENSORES":
				if new_power >= 3:
					return "%s: \"Resolução espectral quântica ativa. Identificando cada partícula no setor.\"" % name
				elif new_power == 0:
					return "%s: \"Sensores cegos! Estamos voando apenas pelo radar passivo de curto alcance.\"" % name
		Role.TACTICAL:
			if system_name == "LASERS":
				if new_power >= 3:
					return "%s: \"Capacitores de feixe carregados! Travando alvos nas coordenadas inimigas.\"" % name
				elif new_power == 0:
					return "%s: \"Lasers em standby. Esperando autorização para armar torpedos.\"" % name
	return ""

func get_damage_reaction() -> String:
	stress = clamp(stress + 10, 0, 100)
	if trust > 70:
		trust = clamp(trust + 2, 0, 100) # Confiança se fortalece no aperto se já era alta
		return "%s: \"Impacto absorvido! Mantendo meu posto, ordens Capitão?!\"" % name
	else:
		trust = clamp(trust - 4, 0, 100)
		return "%s: \"Alerta de avaria! A estrutura não vai aguentar muito disso!\"" % name
