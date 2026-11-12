class_name CrewMember
extends RefCounted

enum Role { PILOT, ENGINEER, SCIENCE, TACTICAL, MEDICAL }

var id: String
var role: Role
var name: String
var callsign: String
var role_title: String
var trust: int = 70 # 0-100
var stress: int = 10 # 0-100

var pro_title: String = ""
var pro_desc: String = ""
var con_title: String = ""
var con_desc: String = ""

var avatar_ascii: String = ""
var portrait_ascii: String = ""

func _init(p_id: String, p_role: Role, p_name: String, p_callsign: String, p_role_title: String,
		p_pro_title: String, p_pro_desc: String, p_con_title: String, p_con_desc: String,
		p_portrait: String, p_trust: int = 70) -> void:
	id = p_id
	role = p_role
	name = p_name
	callsign = p_callsign
	role_title = p_role_title
	pro_title = p_pro_title
	pro_desc = p_pro_desc
	con_title = p_con_title
	con_desc = p_con_desc
	portrait_ascii = p_portrait
	avatar_ascii = "[%s]" % p_name.to_upper()
	trust = clamp(p_trust, 0, 100)

func get_efficiency_factor() -> float:
	var trust_mod = (trust - 50.0) / 100.0
	var stress_penalty = (stress / 200.0)
	return clamp(1.0 + trust_mod - stress_penalty, 0.6, 1.6)

# Fábrica de Cadetes e Oficiais da Academia de Alcântara
static func get_available_roster() -> Dictionary:
	var roster = {
		"PILOT": [] as Array[CrewMember],
		"ENGINEER": [] as Array[CrewMember],
		"MEDICAL": [] as Array[CrewMember],
		"TACTICAL": [] as Array[CrewMember]
	}
	
	# --- PILOTOS ---
	roster["PILOT"].append(CrewMember.new(
		"PILOT_MOREIRA", Role.PILOT, "Ten. Moreira", "Ás de Corumbá", "PILOTO / MANOBRA",
		"+50% EVASÃO DE TORPEDO", "Manobras arrojadas têm chance dobrada de desviar de projéteis hostis.",
		"IMPRUDENTE", "Giro brusco drena temporariamente 1 MW dos motores por 1 pulso.",
		"  .-.\n (o.o)\n =| |=  [Ás]\n", 75
	))
	roster["PILOT"].append(CrewMember.new(
		"PILOT_ARARIPE", Role.PILOT, "Ten. Araripe", "O Metódico", "PILOTO / NAVEGAÇÃO",
		"ALCANCE EXPANDIDO (1500 KM)", "Consegue travar o feixe de teletransporte a 1.500 KM (300 KM a mais de distância segura).",
		"HESITANTE SOB FOGO", "Se o casco estiver abaixo de 50%, a manobra de giro demora 1 pulso a mais.",
		"  .-.\n [o_o]\n /|_|\\  [Met]\n", 70
	))
	
	# --- ENGENHARIA ---
	roster["ENGINEER"].append(CrewMember.new(
		"ENG_BARBOSA", Role.ENGINEER, "Eng. Barbosa", "Milagreiro", "ENGENHARIA-CHEFE",
		"+2 MW NO REATOR", "Modifica os capacitores para fornecer 12 MW no total em vez de 10 MW.",
		"HUMANITÁRIO RÍGIDO", "Recusa-se a zerar o Suporte de Vida (bloqueia redução para 0 MW).",
		"  /¯\\\n (•_•)\n [###]  [Eng]\n", 80
	))
	roster["ENGINEER"].append(CrewMember.new(
		"ENG_CLARA", Role.ENGINEER, "Ten. Clara", "Veterana de Solda", "ENGENHARIA DE AVARIAS",
		"REPARO EM DOBRO", "Ação de reparo de casco restaura o dobro de integridade estrutural.",
		"TRAUMA DE VÁCUO", "Se a nave for atingida por 2 torpedos seguidos, o estresse sobe 25%.",
		"  .-.\n {•.•}\n <|>   [Vet]\n", 75
	))
	
	# --- MÉDICOS & ACOLHIMENTO ---
	roster["MEDICAL"].append(CrewMember.new(
		"MED_VITAL", Role.MEDICAL, "Dr. Vital", "Cirurgião de Trauma", "MÉDICO-CHEFE / UTI",
		"TRIAGEM ULTRA-RÁPIDA", "Processa e esvazia o buffer de teletransporte no dobro da velocidade.",
		"DEPENDENTE DE UTI", "Se o Suporte de Vida for 0 MW, civis na baia médica sofrem baixas imediatas.",
		"  (+)\n (•_•)\n /|*|\\  [Med]\n", 80
	))
	roster["MEDICAL"].append(CrewMember.new(
		"MED_NABUCO", Role.MEDICAL, "Dra. Nabuco", "Bioquímica", "MÉDICA DE QUARENTENA",
		"SORO DE ESTABILIZAÇÃO", "Civis toleram até 3 pulsos com Suporte de Vida em zero sem nenhuma baixa.",
		"TRIAGEM METÓDICA", "Esvazia o buffer de teletransporte 25% mais devagar que o normal.",
		"  .-.\n (o_o)\n [ + ]  [Bio]\n", 75
	))
	
	# --- TÁTICO & COMBATE ---
	roster["TACTICAL"].append(CrewMember.new(
		"TAC_TIBURCIO", Role.TACTICAL, "Ten. Tibúrcio", "Gatilho Rápido", "TÁTICO / DEFESA",
		"85% INTERCEPTAÇÃO DE TORPEDO", "Mira cirúrgica: lasers abatem torpedos hostis em aproximação com facilidade.",
		"OBSESSÃO OFENSIVA", "Disparos consom 10% a mais de energia dos capacitores.",
		"  ,-.\n (õ.õ)\n /|!|\\  [Tác]\n", 75
	))
	roster["TACTICAL"].append(CrewMember.new(
		"TAC_DANDARA", Role.TACTICAL, "Ten. Dandara", "Guardiã", "TÁTICO / ESCUDOS",
		"+25% BLINDAGEM DE ESCUDO", "Campos de força absorvem 25% mais dano em todos os 4 quadrantes.",
		"DANO OFENSIVO REDUZIDO", "Dano dos lasers contra os cascos dos cruzadores fascistas é 20% menor.",
		"  .-.\n (•_•)\n [|=|]  [Def]\n", 80
	))
	
	return roster

func get_power_reaction(system_name: String, new_power: int) -> String:
	match role:
		Role.PILOT:
			if system_name == "MOTORES":
				if new_power >= 3:
					return "%s: \"Propulsores no máximo! Desvio de torpedos otimizado.\"" % name
				elif new_power == 0:
					return "%s: \"Motores zerados! Estamos flutuando feito alvo fácil!\"" % name
		Role.ENGINEER:
			if system_name == "ESCUDOS":
				if new_power >= 3:
					return "%s: \"Bobinas magnéticas em carga plena! Escudos reforçados!\"" % name
				elif new_power == 0:
					return "%s: \"Sem escudos! Qualquer fragmento agora rasga o casco!\"" % name
			elif system_name == "SUPORTE":
				if new_power == 0:
					return "%s: \"Suporte de vida desligado! A temperatura da nave está despencando!\"" % name
		Role.MEDICAL:
			if system_name == "SUPORTE":
				if new_power == 0:
					return "%s: \"ALERTA MÉDICO: A UTI perdeu energia! Os feridos graves correm risco de morte!\"" % name
				elif new_power >= 2:
					return "%s: \"Suporte pleno na Baia Médica. Triagem de civis operando com eficiência máxima.\"" % name
		Role.TACTICAL:
			if system_name == "LASERS":
				if new_power >= 3:
					return "%s: \"Capacitores carregados! Prontos para interceptar torpedos e rebentar cruzadores!\"" % name
	return ""

func get_damage_reaction() -> String:
	stress = clamp(stress + 12, 0, 100)
	if trust > 70:
		trust = clamp(trust + 2, 0, 100)
		return "%s: \"Impacto absorvido! Mantendo o posto, ordens Capitão?!\"" % name
	else:
		trust = clamp(trust - 4, 0, 100)
		return "%s: \"Estrutura avariada! Não vamos aguentar muitos desses!\"" % name
