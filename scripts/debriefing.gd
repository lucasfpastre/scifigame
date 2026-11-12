class_name Debriefing
extends Control

const SoundEffectsScript = preload("res://scripts/sound_effects.gd")

var sfx = null

@onready var lbl_header: Label = %LblHeader
@onready var txt_report: RichTextLabel = %TxtReport
@onready var btn_continue: Button = %BtnContinue
@onready var btn_scores: Button = %BtnScores

func _ready() -> void:
	sfx = SoundEffectsScript.new()
	add_child(sfx)
	
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_scores.pressed.connect(_on_scores_pressed)
	
	_render_debriefing()

func _render_debriefing() -> void:
	var d = GameState.last_debriefing
	if d.is_empty():
		txt_report.text = "[color=#ffff55]Nenhum dado recente de simulação encontrado.[/color]"
		return
		
	lbl_header.text = "[ RELATÓRIO OFICIAL DE COMANDO // SIMULAÇÃO #%02d ]" % d.get("run_number", 1)
	
	var text = "[color=#33ff66]====================================================[/color]\n"
	text += "[color=#55ffff]ACADEMIA ESPACIAL DE ALCÂNTARA // COMISSÃO DE AVALIAÇÃO[/color]\n"
	text += "[color=#aaffaa]BELONAVE: %s[/color]\n" % d.get("ship_name", "CCS João Cândido")
	text += "[color=#ffaaaa]DESFECHO: %s[/color]\n" % d.get("reason", "Simulação Concluída")
	text += "[color=#33ff66]====================================================[/color]\n\n"
	
	text += "[color=#ffffff]1. DESEMPENHO LOGÍSTICO & RESGATE:[/color]\n"
	text += "   - Civis Resgatados e Acolhidos: %d / 380 (+%d pts)\n" % [d.get("civilians_saved", 0), d.get("pts_civilians", 0)]
	if d.get("casualties", 0) > 0:
		text += "   - [color=#ff4444]Baixas Fatais na UTI/Hospital: %d (-%d pts)[/color]\n" % [d.get("casualties", 0), d.get("pts_penalties", 0)]
	if d.get("ethical_bonus", 0) > 0:
		text += "   - [color=#ffff44]Bônus de Mérito Humanitário: +%d pts[/color]\n" % d.get("ethical_bonus", 0)
	if d.get("is_hacked", false):
		text += "   - [color=#55ffff]★ ANOMALIA DE CÓDIGO: Sobrescrita do Mainframe (Protocolo 1910) (+1500 pts)[/color]\n"
	if d.get("warp_bonus", 0) > 0:
		text += "   - [color=#55ffff]★ MANOBRA DE DOBRA: Evasão Tática com Sobreviventes (+%d pts)[/color]\n" % d.get("warp_bonus", 0)
		
	text += "\n[color=#ffffff]2. ENFRENTAMENTO TÁTICO & COMBATE:[/color]\n"
	text += "   - Torpedos Hostis Interceptados: %d (+%d pts)\n" % [d.get("torpedoes_intercepted", 0), d.get("torpedoes_intercepted", 0) * 30]
	text += "   - Belonaves Fascistas Destruídas: %d (+%d pts)\n" % [d.get("cruisers_destroyed", 0), d.get("cruisers_destroyed", 0) * 250]
	text += "   - Tempo de Resistência: %d pulsos (+%d pts)\n" % [d.get("ticks_survived", 0), d.get("pts_ticks", 0)]
	
	text += "\n[color=#33ff66]----------------------------------------------------[/color]\n"
	text += "[color=#ffff55]PONTUAÇÃO DE COMANDO: %d PONTOS[/color]\n" % d.get("total_score", 0)
	text += "[color=#33ff66]PONTOS DE HONRA GANHOS (PHA): +%d PHA[/color]\n" % d.get("pha_earned", 0)
	text += "[color=#55ffff]SALDO DISPONÍVEL EM ALCÂNTARA: %d PHA[/color]\n" % GameState.pha
	text += "[color=#33ff66]----------------------------------------------------[/color]\n\n"
	
	text += "[color=#ffffff]PATENTE CONCEDIDA:[/color] [color=#ffff33][b]%s[/b][/color]\n" % d.get("rank_title", "Cadete")
	text += "[color=#ffffff]PARECER DOS INSTRUTORES:[/color]\n"
	text += "[color=#aaffaa]\"%s\"[/color]\n" % d.get("evaluation", "")
	text += "[color=#33ff66]====================================================[/color]"
	
	txt_report.text = text

func _on_continue_pressed() -> void:
	sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/crew_selection.tscn")

func _on_scores_pressed() -> void:
	sfx.play_click()
	var text = "[color=#55ffff]=== MURAL DE RECORDES // HISTÓRICO DE COMANDANTES ===[/color]\n\n"
	if GameState.high_scores.is_empty():
		text += "[color=#ffff55]Nenhum registro anterior localizado.[/color]\n"
	else:
		var pos = 1
		for entry in GameState.high_scores:
			var hack_tag = " [color=#55ffff][HACK][/color]" if entry.get("hacked", false) else ""
			text += "[color=#33ff66]#%02d[/color] | [color=#ffff44]%d PTS[/color]%s | [color=#ffffff]%s[/color] | Civis: %d\n" % [
				pos, entry.get("score", 0), hack_tag, entry.get("rank", "Oficial"), entry.get("civilians", 0)
			]
			pos += 1
	text += "\n[color=#33ff66]Total de Simulações Realizadas: %d[/color]\n" % GameState.total_runs
	text += "[color=#33ff66]Total Histórico de Civis Salvos: %d[/color]\n" % GameState.lifetime_civilians_saved
	txt_report.text = text
