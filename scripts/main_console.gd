class_name MainConsole
extends Control

const ShipDataScript = preload("res://scripts/ship_data.gd")
const TacticalRadarScript = preload("res://scripts/tactical_radar.gd")
const SoundEffectsScript = preload("res://scripts/sound_effects.gd")

var ship = null
var radar = null
var sfx = null

# Nós de Interface - Cabeçalho
@onready var lbl_collapse_timer: Label = %LblCollapseTimer
@onready var lbl_rescued: Label = %LblRescued
@onready var lbl_shield: Label = %LblShield
@onready var lbl_hull: Label = %LblHull
@onready var lbl_alert: Label = %LblAlert

# Nós de Interface - Painel Esquerdo
@onready var txt_radar: RichTextLabel = %TxtRadar
@onready var txt_telemetry: RichTextLabel = %TxtTelemetry

# Nós de Interface - Centro
@onready var txt_log: RichTextLabel = %TxtLog
@onready var txt_crew: RichTextLabel = %TxtCrew

# Nós de Interface - Painel Direito (Escudos e Reator)
@onready var txt_shield_diagram: RichTextLabel = %TxtShieldDiagram
@onready var btn_rotate: Button = %BtnRotate
@onready var lbl_power_free: Label = %LblPowerFree

# Botões de Ação na Barra Inferior
@onready var btn_pause: Button = %BtnPause
@onready var btn_speed: Button = %BtnSpeed
@onready var btn_transport: Button = %BtnTransport
@onready var btn_fire: Button = %BtnFire
@onready var btn_chaff: Button = %BtnChaff
@onready var btn_repair: Button = %BtnRepair
@onready var btn_comms: Button = %BtnComms

# Controles do Power Grid
var power_ui: Dictionary = {}

# Controle de Tempo e Loop Semi-Real-Time
var is_paused: bool = false
var is_game_over: bool = false
var speed_multiplier: float = 1.0
var base_tick_interval: float = 2.4 # 2.4s por pulso em 1.0x (cadência tática legível)
var tick_interval: float = 2.4
var tick_accumulator: float = 0.0
var stardate: float = 4312.1
var tick_count: int = 1

func _ready() -> void:
	sfx = SoundEffectsScript.new()
	add_child(sfx)
	
	# Inicializa nave com a tripulação selecionada no Briefing
	ship = ShipDataScript.new(GameState.selected_crew)
	radar = TacticalRadarScript.new()
	
	_setup_power_grid_ui()
	_connect_events()
	
	_log("[color=#33ff66]====================================================[/color]")
	_log("[color=#33ff66]** SIMULAÇÃO TÁTICA DE ALCÂNTARA // PROTOCOLO BAEPENDI **[/color]")
	_log("[color=#33ff66]SETOR: DMZ ABROLHOS // NAVE: %s[/color]" % ship.ship_name)
	_log("[color=#33ff66]====================================================[/color]")
	_log("[color=#55ffff]OFICIAIS DESIGNADOS PARA A MISSÃO:[/color]")
	for role_key in ship.crew:
		var c = ship.crew[role_key]
		_log("[color=#aaffaa] * %s (%s) \"%s\" -> Pró: %s[/color]" % [c.name, c.role_title, c.callsign, c.pro_title])
	_log("[color=#ffff66]\n! EMERGÊNCIA: Cargueiro Baependi torpedeado pela Falange Fascista.[/color]")
	_log("[color=#ffaaaa]Ordens: Aproxime-se, baixe os escudos para teletransportar os 380 civis.[/color]")
	_log("[color=#55ffff]DICA: Use [ESPAÇO] para Pausa Tática a qualquer momento.[/color]\n")
	
	_update_all_displays()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_toggle_pause()
	elif event is InputEventKey and event.pressed and not is_game_over:
		if event.keycode == KEY_1:
			_set_speed(0.5)
		elif event.keycode == KEY_2:
			_set_speed(1.0)
		elif event.keycode == KEY_3:
			_set_speed(1.5)

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	if not is_paused:
		var collapsed = radar.tick_collapse_timer(delta * speed_multiplier)
		_update_header_status()
		if collapsed:
			_log("[color=#ff1111]*** CATÁSTROFE: O CASCO DO CARGUEIRO BAEPENDI COLAPSOU! ***[/color]")
			_log("[color=#ff5555]O cargueiro civil foi destruído com todos os passageiros restantes.[/color]")
			sfx.play_alert()
			
		tick_accumulator += delta
		if tick_accumulator >= tick_interval:
			tick_accumulator = 0.0
			_advance_tactical_tick()

func _toggle_pause() -> void:
	if is_game_over: return
	is_paused = not is_paused
	sfx.play_click()
	if is_paused:
		btn_pause.text = "[ ▶ CONTINUAR ]"
		_log("[color=#ffff55]> SIMULAÇÃO CONGELADA (PAUSA TÁTICA)[/color]")
	else:
		btn_pause.text = "[ || PAUSA ]"
		_log("[color=#33ff66]> SIMULAÇÃO RETOMADA (%.1fx)[/color]" % speed_multiplier)

func _on_speed_toggle() -> void:
	if is_game_over: return
	sfx.play_click()
	if speed_multiplier == 1.0:
		_set_speed(1.5)
	elif speed_multiplier == 1.5:
		_set_speed(0.5)
	else:
		_set_speed(1.0)

func _set_speed(new_speed: float) -> void:
	speed_multiplier = new_speed
	tick_interval = base_tick_interval / speed_multiplier
	var label_tag = "NOR"
	if speed_multiplier == 0.5: label_tag = "LEN"
	elif speed_multiplier == 1.5: label_tag = "RAP"
	btn_speed.text = "[ %.1fx %s ]" % [speed_multiplier, label_tag]
	_log("[color=#55ffff]> Velocidade tática ajustada para %.1fx (%s)[/color]" % [speed_multiplier, label_tag])

func _advance_tactical_tick() -> void:
	tick_count += 1
	stardate += 0.1
	
	# 1. Regeneração contínua de escudos se não estiver transportando
	ship.regenerate_shields()
	
	# 2. Processo de Teletransporte de Civis (Cargueiro -> Plataforma)
	if ship.transporter_active:
		_process_transporter_tick()
		
	# 3. Triagem da Baia Médica (Plataforma -> Alojamentos Seguros)
	var triage_res = ship.process_medical_triage()
	if triage_res["processed"] > 0:
		_log("[color=#aaffaa]>> BAIAS MÉDICAS: %d civis estabilizados e alocados nos alojamentos.[/color]" % triage_res["processed"])
	if triage_res["casualties"] > 0:
		_log("[color=#ff2222]! %s[/color]" % triage_res["msg"])
		sfx.play_alert()
		
	# 4. Avanço do radar e dos projéteis inimigos
	var engine_eff = ship.get_system_efficiency("MOTORES")
	var tick_result = radar.update_tactical_tick(engine_eff, ship.heading)
	
	for ev in tick_result["events"]:
		_log("[color=#ff6666]> %s[/color]" % ev)
		if "TORPEDO" in ev:
			sfx.play_torpedo_warning()
			
	# 5. Processa impactos de torpedos que atingiram a nave
	for hit in tick_result["torpedo_hits"]:
		var dmg_result = ship.apply_directional_damage(hit["damage"], hit["quadrant"])
		sfx.play_alert()
		if dmg_result["hull_damage"] > 0:
			_log("[color=#ff1111]! ALERTA DE AVARIA: Escudo [%s] penetrado! -%d no Casco![/color]" % [hit["quadrant"], dmg_result["hull_damage"]])
		else:
			_log("[color=#ffff33]> Escudo [%s] absorveu o impacto do torpedo (%d dano).[/color]" % [hit["quadrant"], dmg_result["shield_absorbed"]])
			
	_update_all_displays()
	
	if ship.hull <= 0:
		_game_over("CASCO TOTALMENTE DESTRUÍDO. SIMULAÇÃO ENCERRADA.")

func _process_transporter_tick() -> void:
	var km_contact = null
	for c in radar.contacts:
		if c.id == "BAE-01":
			km_contact = c
			break
			
	if km_contact and not radar.km_is_destroyed:
		# Traço do Ten. Araripe: Alcance de teletransporte expandido para 1500 KM!
		var max_range = 1500 if (ship.crew.has("PILOT") and ship.crew["PILOT"].id == "PILOT_ARARIPE") else 1200
		
		if km_contact.distance_km <= max_range:
			var beam_res = ship.beam_to_buffer(40)
			if beam_res["beamed"] > 0:
				sfx.play_transporter()
				_log("[color=#55ffff]>> FEIXE DE TRANSPORTE: +%d civis na plataforma! (Buffer: %d/%d)[/color]" % [beam_res["beamed"], ship.transporter_buffer, ship.max_buffer])
				
			if beam_res["buffer_full"]:
				var med_name = ship.crew["MEDICAL"].name if ship.crew.has("MEDICAL") else "Equipe Médica"
				_log("[color=#ffaa33]> PLATAFORMA LOTADA (50/50)! Aguardando %s liberar as macas![/color]" % med_name)
				
			if (ship.civilians_rescued + ship.transporter_buffer) >= ship.total_civilians:
				_log("[color=#33ff33]** SUCESSO DE EVACUAÇÃO: TODOS OS CIVIS FORAM RETIRADOS DO BAEPENDI! **[/color]")
				ship.transporter_active = false
				btn_transport.text = "[ TELETRANSPORTE (CONCLUÍDO) ]"
		else:
			_log("[color=#ffaa55]> Teletransporte ineficaz: Baependi fora de alcance (%d KM). Aproxime-se a < %d KM![/color]" % [km_contact.distance_km, max_range])

func _setup_power_grid_ui() -> void:
	var sys_list = ["MOTORES", "ESCUDOS", "SENSORES", "LASERS", "SUPORTE"]
	for sys_name in sys_list:
		var container = get_node_or_null("%%Row_%s" % sys_name)
		if container:
			var btn_minus: Button = container.get_node("BtnMinus")
			var btn_plus: Button = container.get_node("BtnPlus")
			var lbl_bar: Label = container.get_node("LblBar")
			var lbl_info: Label = container.get_node("LblInfo")
			
			btn_minus.pressed.connect(func(): _on_power_adjust(sys_name, -1))
			btn_plus.pressed.connect(func(): _on_power_adjust(sys_name, +1))
			
			power_ui[sys_name] = {
				"btn_minus": btn_minus,
				"btn_plus": btn_plus,
				"lbl_bar": lbl_bar,
				"lbl_info": lbl_info
			}

func _connect_events() -> void:
	ship.power_changed.connect(_on_ship_power_changed)
	ship.status_changed.connect(_on_ship_status_changed)
	ship.quadrants_changed.connect(_on_quadrants_changed)
	ship.crew_intercom.connect(_on_crew_intercom)
	
	btn_pause.pressed.connect(_toggle_pause)
	btn_speed.pressed.connect(_on_speed_toggle)
	btn_rotate.pressed.connect(_on_action_rotate)
	btn_transport.pressed.connect(_on_action_transport_toggle)
	btn_fire.pressed.connect(_on_action_fire_or_intercept)
	btn_chaff.pressed.connect(_on_action_chaff)
	btn_repair.pressed.connect(_on_action_repair)
	btn_comms.pressed.connect(_on_action_comms)

func _on_power_adjust(sys_name: String, delta: int) -> void:
	if is_game_over: return
	if ship.adjust_power(sys_name, delta):
		sfx.play_click()
	else:
		sfx.play_error()
		if sys_name == "SUPORTE" and ship.crew.has("ENGINEER") and ship.crew["ENGINEER"].id == "ENG_BARBOSA":
			_log("[color=#ffaa55]Eng. Barbosa: \"Capitão, não vou desligar o oxigênio da nossa tripulação e dos civis! Não insista!\"[/color]")
	_update_power_grid_display()

func _on_ship_power_changed(_sys_name: String, _val: int, _available: int) -> void:
	_update_power_grid_display()
	_update_radar_display()

func _on_ship_status_changed(_hull: int, _shield: int, _alert_level: String) -> void:
	_update_header_status()

func _on_quadrants_changed(_quads: Dictionary, _heading: int) -> void:
	_update_shield_diagram()

func _on_crew_intercom(speaker: String, text: String) -> void:
	var msg = "[color=#55ffff]%s[/color] %s" % [speaker, text]
	txt_crew.text = msg
	_log(msg)

func _update_all_displays() -> void:
	_update_header_status()
	_update_shield_diagram()
	_update_power_grid_display()
	_update_radar_display()

func _update_header_status() -> void:
	var time_left = max(0, int(radar.km_collapse_seconds))
	lbl_collapse_timer.text = "COLAPSO BAEPENDI: %02d:%02d" % [time_left / 60, time_left % 60]
	if time_left < 30 and not radar.km_is_destroyed:
		lbl_collapse_timer.modulate = Color(1.0, 0.2, 0.2)
	else:
		lbl_collapse_timer.modulate = Color(0.3, 1.0, 0.45)
		
	var cas_str = " | BAIXAS: %d" % ship.civilians_casualties if ship.civilians_casualties > 0 else ""
	lbl_rescued.text = "CIVIS: %d/380 [PLATAFORMA: %d/50]%s" % [ship.civilians_rescued, ship.transporter_buffer, cas_str]
	lbl_hull.text = "CASCO: %3d%%" % ship.hull
	
	if ship.transporter_active:
		lbl_shield.text = "ESCUDOS: [BAIXADOS]"
		lbl_shield.modulate = Color(1.0, 0.3, 0.3)
	else:
		lbl_shield.text = "ESCUDO MÉD: %3d%%" % ship.get_average_shield()
		lbl_shield.modulate = Color(0.3, 1.0, 0.45)
		
	lbl_alert.text = "[ %s ]" % ship.alert_state
	if ship.alert_state == "ALERTA VERMELHO":
		lbl_alert.modulate = Color(1.0, 0.2, 0.2)
	elif ship.alert_state == "ALERTA AMARELO":
		lbl_alert.modulate = Color(1.0, 0.8, 0.1)
	else:
		lbl_alert.modulate = Color(0.2, 1.0, 0.4)

func _update_shield_diagram() -> void:
	var q = ship.quadrants
	var heading_str = "NORTE"
	match ship.heading:
		90: heading_str = "LESTE"
		180: heading_str = "SUL"
		270: heading_str = "OESTE"
		
	var shield_color = "#33ff66" if not ship.transporter_active else "#ff4444"
	var text = "[color=%s]=== ESCUDOS DIRECIONAIS ===[/color]\n" % shield_color
	if ship.transporter_active:
		text += "[color=#ff3333]  ** ESCUDOS BAIXADOS (TRANSPORTE) **[/color]\n"
	else:
		text += "       [color=%s][FWD: %3d%%][/color]\n" % [_get_quad_color(q["FWD"]), q["FWD"]]
	text += "           /---\\\n"
	text += "[color=%s][PORT:%3d%%][/color] | @ | [color=%s][STBD:%3d%%][/color]\n" % [_get_quad_color(q["PORT"]), q["PORT"], _get_quad_color(q["STBD"]), q["STBD"]]
	text += "           \\---/\n"
	text += "       [color=%s][AFT: %3d%%][/color]\n" % [_get_quad_color(q["AFT"]), q["AFT"]]
	text += "[color=#55ffff]PROA: %03d° (%s)[/color]" % [ship.heading, heading_str]
	txt_shield_diagram.text = text

func _get_quad_color(val: int) -> String:
	if val > 65: return "#33ff66"
	elif val > 30: return "#ffff44"
	else: return "#ff3333"

func _update_power_grid_display() -> void:
	lbl_power_free.text = "REATOR: %d/%d MW DISPONÍVEL" % [ship.get_available_power(), ship.total_power]
	for sys_name in power_ui:
		var data = power_ui[sys_name]
		var val = ship.systems[sys_name]
		var max_bars = 4 if sys_name != "SUPORTE" else 2
		
		var bar_str = "["
		for i in range(max_bars):
			bar_str += "■" if i < val else "□"
		bar_str += "]"
		data["lbl_bar"].text = "%s %d MW" % [bar_str, val]
		
		var efficiency = ship.get_system_efficiency(sys_name)
		data["lbl_info"].text = "EFIC: %d%%" % int(efficiency * 100.0)
		data["btn_plus"].disabled = not ship.can_increase_power(sys_name)
		data["btn_minus"].disabled = not ship.can_decrease_power(sys_name)

func _update_radar_display() -> void:
	var sensor_eff = ship.get_system_efficiency("SENSORES")
	txt_radar.text = radar.render_ascii_radar(sensor_eff)
	txt_telemetry.text = radar.get_contact_telemetry(sensor_eff)

# --- AÇÕES DO JOGADOR ---

func _on_action_rotate() -> void:
	if is_game_over: return
	sfx.play_click()
	ship.rotate_ship_90()

func _on_action_transport_toggle() -> void:
	if is_game_over: return
	ship.transporter_active = not ship.transporter_active
	if ship.transporter_active:
		sfx.play_alert()
		btn_transport.text = "[ TELETRANSPORTE (ATIVO!) ]"
		_log("[color=#ff4444]! ALERTA DE PROCEDIMENTO: Escudos desativados para operação de teletransporte![/color]")
		_log("[color=#ffaaaa]A nave está vulnerável a impactos de torpedo enquanto a plataforma estiver energizada![/color]")
	else:
		sfx.play_click()
		btn_transport.text = "[ TELETRANSPORTE (OFF) ]"
		_log("[color=#33ff66]> Teletransporte suspenso. Geradores de escudo rearmados.[/color]")
	_update_header_status()
	_update_shield_diagram()

func _on_action_fire_or_intercept() -> void:
	if is_game_over: return
	var weapon_eff = ship.get_system_efficiency("LASERS")
	if weapon_eff < 0.2:
		_log("[color=#ff5555]> Capacitores dos Lasers sem carga! Aumente energia nas Armas.[/color]")
		sfx.play_error()
		return
		
	sfx.play_laser()
	# Se houver torpedos em vôo, tenta interceptar primeiro
	if not radar.active_torpedoes.is_empty():
		var is_tiburcio = ship.crew.has("TACTICAL") and ship.crew["TACTICAL"].id == "TAC_TIBURCIO"
		var custom_laser_eff = 0.95 if is_tiburcio else weapon_eff
		
		var intercept_res = radar.intercept_nearest_torpedo(custom_laser_eff)
		if intercept_res["success"]:
			_log("[color=#55ff55]** SUCESSO: %s **[/color]" % intercept_res["message"])
		else:
			_log("[color=#ff8844]> %s[/color]" % intercept_res["message"])
	else:
		# Dispara contra o cruzador inimigo mais próximo
		var target = null
		var min_dist = 999999
		for c in radar.contacts:
			if c.hostile and c.distance_km < min_dist:
				min_dist = c.distance_km
				target = c
		if target:
			var dmg_multiplier = 0.8 if (ship.crew.has("TACTICAL") and ship.crew["TACTICAL"].id == "TAC_DANDARA") else 1.0
			var dmg = int(25 * weapon_eff * dmg_multiplier * randf_range(0.8, 1.3))
			target.hull = max(0, target.hull - dmg)
			_log("[color=#ffaa33]> Disparando baterias de feixes em %s! Causou %d de dano.[/color]" % [target.name, dmg])
			if target.hull <= 0:
				_log("[color=#ffff33]** %s FOI DESTRUÍDO NO IMPACTO! **[/color]" % target.name)
				radar.contacts.erase(target)
		else:
			_log("[color=#ffff55]> Nenhum alvo hostil em alcance de tiro.[/color]")
			
	_update_radar_display()

func _on_action_chaff() -> void:
	if is_game_over: return
	if ship.chaff_count <= 0:
		_log("[color=#ff5555]> Cartuchos de Iscas/Chaff esgotados![/color]")
		sfx.play_error()
		return
		
	if radar.active_torpedoes.is_empty():
		_log("[color=#ffff55]> Nenhum torpedo em rota de colisão para despistar.[/color]")
		sfx.play_error()
		return
		
	ship.chaff_count -= 1
	sfx.play_chaff()
	radar.deploy_chaff_countermeasure()
	btn_chaff.text = "[ ISCAS/CHAFF (%d) ]" % ship.chaff_count
	_log("[color=#33ff66]> Cartucho Chaff ejetado! O torpedo mais próximo perdeu o travamento![/color]")
	_update_radar_display()

func _on_action_repair() -> void:
	if is_game_over: return
	var eng = ship.crew.get("ENGINEER")
	if eng and eng.trust >= 60:
		sfx.play_beep(440.0, 0.08, 0.25)
		# Traço da Ten. Clara: Reparo em dobro!
		var repair_multiplier = 2.0 if eng.id == "ENG_CLARA" else 1.0
		var repair_amt = int(randi_range(12, 20) * repair_multiplier)
		ship.hull = min(ship.max_hull, ship.hull + repair_amt)
		_log("[color=#33ff66]> Equipes de avaria selaram brechas estruturais! +%d%% de Casco.[/color]" % repair_amt)
		_update_header_status()
	else:
		_log("[color=#ff5555]> Engenharia ocupada mantendo os reatores estáveis![/color]")
		sfx.play_error()

func _on_action_comms() -> void:
	if is_game_over: return
	sfx.play_beep(900.0, 0.1, 0.2)
	_log("[color=#55ffff]> Canal de rádio aberto com o Baependi e belonaves fascistas.[/color]")
	if not radar.km_is_destroyed:
		_log("[color=#ffff77]CARGUEIRO BAEPENDI: \"Aqui é o Capitão Lauro do Baependi! Nossos campos de contenção estão derretendo! Resgatem nossos passageiros!\"[/color]")
	_log("[color=#ff4444]COMANDANTE FASCISTA: \"Nave intrusa da Coalizão, vocês invadiram a fronteira da Falange. Não haverá sobreviventes.\"[/color]")

func _game_over(reason: String) -> void:
	is_game_over = true
	_log("\n[color=#ff3333]====================================================[/color]")
	_log("[color=#ff3333]*** %s ***[/color]" % reason)
	_log("[color=#ffaa33]AVALIAÇÃO DA ACADEMIA ESPACIAL DE ALCÂNTARA:[/color]")
	_log("[color=#ffffaa]- Civis Resgatados e Acolhidos: %d / %d[/color]" % [ship.civilians_rescued, ship.total_civilians])
	_log("[color=#ffffaa]- Baixas Hospitalares: %d[/color]" % ship.civilians_casualties)
	_log("[color=#ffffaa]- Tempo de Sobrevivência: %d pulsos táticos[/color]" % tick_count)
	_log("[color=#ffffaa]- Moral da Tripulação: %d%%[/color]" % ship.crew["PILOT"].trust)
	_log("[color=#ffffaa]- Veredito: O Protocolo Baependi avalia a liderança e sacrifício diante da derrota inevitável.[/color]")
	_log("[color=#ff3333]====================================================[/color]")
	
	btn_pause.text = "[ VOLTAR À SELEÇÃO DE TRIPULAÇÃO ]"
	btn_pause.pressed.disconnect(_toggle_pause)
	btn_pause.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/crew_selection.tscn"))

func _log(bbcode: String) -> void:
	txt_log.append_text(bbcode + "\n")
