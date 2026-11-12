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
@onready var btn_rotate_left: Button = %BtnRotateLeft
@onready var btn_rotate_right: Button = %BtnRotateRight
@onready var lbl_power_free: Label = %LblPowerFree

# Botões de Ação na Barra Inferior
@onready var btn_pause: Button = %BtnPause
@onready var btn_speed: Button = %BtnSpeed
@onready var btn_transport: Button = %BtnTransport
@onready var btn_fire: Button = %BtnFire
@onready var btn_chaff: Button = %BtnChaff
@onready var btn_repair: Button = %BtnRepair
@onready var btn_comms: Button = %BtnComms
@onready var btn_warp: Button = %BtnWarp
@onready var btn_terminal: Button = %BtnTerminal

# Modal do Terminal de Hacking / Depuração
@onready var hack_modal: ColorRect = %HackModal
@onready var btn_close_hack: Button = %BtnCloseHack
@onready var txt_hack_terminal: RichTextLabel = %TxtHackTerminal
@onready var btn_hack_help: Button = %BtnHackHelp
@onready var btn_hack_logs: Button = %BtnHackLogs
@onready var btn_hack_scan: Button = %BtnHackScan
@onready var btn_hack_exploit: Button = %BtnHackExploit
@onready var input_hack_cmd: LineEdit = %InputHackCmd
@onready var btn_submit_hack: Button = %BtnSubmitHack

var is_simulation_hacked: bool = false
var hack_exploit_discovered: bool = false
var comms_intercept_count: int = 0

# CRT Overlay & Efeitos Visuais / Glitch
@onready var crt_overlay: ColorRect = %CRTOverlay
var crt_mat: ShaderMaterial = null
var crt_glitch_amount: float = 0.0
var crt_shake_amount: float = 0.0
var crt_chroma_amount: float = 0.0
var crt_static_amount: float = 0.0
var crt_roll_amount: float = 0.0

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
	sfx.set_engine_power(ship.systems.get("MOTORES", 1) if ship else 1)
	
	if crt_overlay and crt_overlay.material:
		crt_mat = crt_overlay.material.duplicate()
		crt_overlay.material = crt_mat
	
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
	_log("[color=#55ffff]CONTROLES: [T] Teleporte | [F] Lasers | [C] Chaff | [R] Reparo | [Q/E] Girar | [WASD] Bússola[/color]\n")
	
	_update_all_displays()

func _input(event: InputEvent) -> void:
	if hack_modal and hack_modal.visible:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB):
			_close_hack_terminal()
		return
		
	# Gamepad / Controle Joypad (Mobile & Desktop)
	if event is InputEventJoypadButton and event.pressed and not is_game_over:
		match event.button_index:
			JOY_BUTTON_START:
				_toggle_pause()
			JOY_BUTTON_BACK:
				_toggle_hack_terminal()
			JOY_BUTTON_A:
				_on_action_transport_toggle()
			JOY_BUTTON_X:
				_on_action_fire_or_intercept()
			JOY_BUTTON_B:
				_on_action_chaff()
			JOY_BUTTON_Y:
				_on_action_repair()
			JOY_BUTTON_LEFT_SHOULDER:
				_on_action_rotate_left()
			JOY_BUTTON_RIGHT_SHOULDER:
				_on_action_rotate_right()
			JOY_BUTTON_DPAD_UP:
				_on_compass_direct(0)
			JOY_BUTTON_DPAD_RIGHT:
				_on_compass_direct(90)
			JOY_BUTTON_DPAD_DOWN:
				_on_compass_direct(180)
			JOY_BUTTON_DPAD_LEFT:
				_on_compass_direct(270)
		return

	# Teclado (PC & Linux)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif not is_game_over:
			match event.keycode:
				KEY_QUOTELEFT, KEY_F1, KEY_TAB:
					_open_hack_terminal()
				KEY_1:
					_set_speed(0.5)
				KEY_2:
					_set_speed(1.0)
				KEY_3:
					_set_speed(1.5)
				KEY_T:
					_on_action_transport_toggle()
				KEY_F:
					_on_action_fire_or_intercept()
				KEY_C:
					_on_action_chaff()
				KEY_R:
					_on_action_repair()
				KEY_M, KEY_X:
					_on_action_comms()
				KEY_V:
					_on_action_warp()
				KEY_Q:
					_on_action_rotate_left()
				KEY_E:
					_on_action_rotate_right()
				KEY_W, KEY_UP:
					_on_compass_direct(0)
				KEY_D, KEY_RIGHT:
					_on_compass_direct(90)
				KEY_S, KEY_DOWN:
					_on_compass_direct(180)
				KEY_A, KEY_LEFT:
					_on_compass_direct(270)

func _process(delta: float) -> void:
	_update_crt_fx(delta)
	
	if is_game_over or not radar:
		return
		
	if not is_paused:
		var collapsed = radar.tick_collapse_timer(delta * speed_multiplier)
		_update_header_status()
		if collapsed:
			_log("[color=#ff1111]*** CATÁSTROFE: O CASCO DO CARGUEIRO BAEPENDI COLAPSOU! ***[/color]")
			_log("[color=#ff5555]O cargueiro civil foi destruído com todos os passageiros restantes.[/color]")
			trigger_damage_fx(0.9, true)
			
		tick_accumulator += delta
		if tick_accumulator >= tick_interval:
			tick_accumulator = 0.0
			_advance_tactical_tick()

func trigger_damage_fx(severity: float, is_hull_hit: bool = false) -> void:
	crt_glitch_amount = clamp(crt_glitch_amount + severity * 0.75, 0.0, 1.0)
	crt_shake_amount = clamp(crt_shake_amount + severity * 0.025, 0.0, 0.045)
	crt_chroma_amount = clamp(crt_chroma_amount + severity * 0.015, 0.0, 0.035)
	crt_static_amount = clamp(crt_static_amount + severity * 0.55, 0.0, 0.85)
	
	if is_hull_hit:
		Input.vibrate_handheld(int(clamp(320 * severity, 100, 500)))
		if sfx: sfx.play_explosion()
		if severity >= 0.6:
			crt_roll_amount = 1.2
			if sfx: sfx.play_hull_stress()
	else:
		Input.vibrate_handheld(int(clamp(90 * severity, 30, 150)))
		if sfx: sfx.play_shield_hit()

func _update_crt_fx(delta: float) -> void:
	if not crt_mat:
		return
		
	# Decaimento suave dos impactos
	crt_glitch_amount = move_toward(crt_glitch_amount, 0.0, delta * 1.8)
	crt_shake_amount = move_toward(crt_shake_amount, 0.0, delta * 0.08)
	crt_chroma_amount = move_toward(crt_chroma_amount, 0.0, delta * 0.04)
	crt_static_amount = move_toward(crt_static_amount, 0.0, delta * 1.5)
	crt_roll_amount = move_toward(crt_roll_amount, 0.0, delta * 2.5)
	
	# Efeitos contínuos de estresse
	var ambient_glitch = 0.0
	var ambient_static = 0.0
	var ambient_chroma = 0.0
	
	if ship:
		if ship.hull < 35:
			ambient_glitch = lerpf(0.1, 0.35, (35.0 - ship.hull) / 35.0)
			ambient_chroma = 0.003
		if ship.get_average_shield() <= 0:
			ambient_static += 0.08
			
	if radar and radar.ion_storm_ticks > 0:
		ambient_static += 0.25
		ambient_glitch += 0.15
		
	var final_glitch = clamp(crt_glitch_amount + ambient_glitch, 0.0, 1.0)
	var final_shake = clamp(crt_shake_amount, 0.0, 0.05)
	var final_chroma = clamp(crt_chroma_amount + ambient_chroma, 0.0, 0.05)
	var final_static = clamp(crt_static_amount + ambient_static, 0.0, 1.0)
	var final_roll = clamp(crt_roll_amount, 0.0, 5.0)
	
	# Pulso de Alerta Vermelho / Dano
	var alert_alpha = 0.0
	var alert_col = Color(1.0, 0.1, 0.1, 0.0)
	if is_game_over:
		alert_col = Color(1.0, 0.15, 0.15, 0.35)
		alert_alpha = 0.35
	elif radar and not radar.active_torpedoes.is_empty():
		var pulse = (sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5) * 0.28
		alert_col = Color(1.0, 0.1, 0.1, pulse)
		alert_alpha = pulse
	elif ship and ship.hull < 25:
		var pulse = (sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5) * 0.2
		alert_col = Color(1.0, 0.3, 0.1, pulse)
		alert_alpha = pulse
		
	crt_mat.set_shader_parameter("glitch_intensity", final_glitch)
	crt_mat.set_shader_parameter("screen_shake", final_shake)
	crt_mat.set_shader_parameter("chromatic_aberration", final_chroma)
	crt_mat.set_shader_parameter("static_noise", final_static)
	crt_mat.set_shader_parameter("roll_speed", final_roll)
	crt_mat.set_shader_parameter("alert_tint", Color(alert_col.r, alert_col.g, alert_col.b, alert_alpha))

func _toggle_pause() -> void:
	if is_game_over: return
	is_paused = not is_paused
	sfx.play_click()
	if is_paused:
		btn_pause.text = "[ ▶ RETOMAR ]"
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
		
	if ship.civilians_rescued >= ship.total_civilians and not is_game_over:
		_game_over("MISSÃO CUMPRIDA: TODOS OS 380 PASSAGEIROS RESGATADOS E ESTABILIZADOS!")
		return
		
	# 4. Avanço do radar, emboscada escalonada e projéteis inimigos
	var engine_eff = ship.get_system_efficiency("MOTORES")
	var tick_result = radar.update_tactical_tick(engine_eff, ship.heading, ship.transporter_active)
	
	if tick_result.get("ambush_event", false):
		sfx.play_alert()
		var pilot = ship.crew.get("PILOT")
		var pilot_name = pilot.name if pilot else "Oficial"
		_log("[color=#ff4444]%s: \"Capitão! Eles estavam à espreita esperando a gente baixar a guarda! É uma emboscada fascista!\"[/color]" % pilot_name)
		
	for ev in tick_result["events"]:
		_log("[color=#ff6666]> %s[/color]" % ev)
		if "TORPEDO" in ev:
			sfx.play_torpedo_warning()
			crt_glitch_amount = clamp(crt_glitch_amount + 0.15, 0.0, 1.0)
		elif "Tempestade magnética" in ev:
			sfx.play_shield_hit()
			trigger_damage_fx(0.55, false)
			
	# 5. Processa impactos de torpedos que atingiram a nave
	for hit in tick_result["torpedo_hits"]:
		var dmg_result = ship.apply_directional_damage(hit["damage"], hit["quadrant"])
		if dmg_result["hull_damage"] > 0:
			trigger_damage_fx(1.0, true)
			_log("[color=#ff1111]! ALERTA DE AVARIA: Escudo [%s] penetrado! -%d no Casco![/color]" % [hit["quadrant"], dmg_result["hull_damage"]])
		else:
			trigger_damage_fx(0.45, false)
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
			var base_amt = 40 + radar.bonus_beam_civilians
			radar.bonus_beam_civilians = 0
			var beam_res = ship.beam_to_buffer(base_amt)
			if beam_res["beamed"] > 0:
				sfx.play_transporter()
				_log("[color=#55ffff]>> FEIXE DE TRANSPORTE: +%d civis na plataforma! (Buffer: %d/%d)[/color]" % [beam_res["beamed"], ship.transporter_buffer, ship.max_buffer])
				
			if beam_res["buffer_full"]:
				var med_name = ship.crew["MEDICAL"].name if ship.crew.has("MEDICAL") else "Equipe Médica"
				_log("[color=#ffaa33]> PLATAFORMA LOTADA (50/50)! Aguardando %s liberar as macas![/color]" % med_name)
				
			if (ship.civilians_rescued + ship.transporter_buffer) >= ship.total_civilians:
				_log("[color=#33ff33]** SUCESSO DE EVACUAÇÃO: TODOS OS CIVIS FORAM RETIRADOS DO BAEPENDI! **[/color]")
				ship.transporter_active = false
				btn_transport.text = "[ RESGATE OK ]"
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
	btn_rotate_left.pressed.connect(_on_action_rotate_left)
	btn_rotate_right.pressed.connect(_on_action_rotate_right)
	btn_transport.pressed.connect(_on_action_transport_toggle)
	btn_fire.pressed.connect(_on_action_fire_or_intercept)
	btn_chaff.pressed.connect(_on_action_chaff)
	btn_repair.pressed.connect(_on_action_repair)
	btn_comms.pressed.connect(_on_action_comms)
	btn_warp.pressed.connect(_on_action_warp)
	btn_terminal.pressed.connect(_open_hack_terminal)
	
	btn_close_hack.pressed.connect(_close_hack_terminal)
	btn_hack_help.pressed.connect(func(): _execute_hack_command("AJUDA"))
	btn_hack_logs.pressed.connect(func(): _execute_hack_command("LOGS"))
	btn_hack_scan.pressed.connect(func(): _execute_hack_command("SCAN"))
	btn_hack_exploit.pressed.connect(func(): _execute_hack_command("ALMIRANTE-1910"))
	btn_submit_hack.pressed.connect(_on_submit_hack_command)
	input_hack_cmd.text_submitted.connect(func(_t): _on_submit_hack_command())

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
	if sfx and ship:
		sfx.set_engine_power(ship.systems.get("MOTORES", 1))
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
	lbl_collapse_timer.text = "COLAPSO: %02d:%02d" % [time_left / 60, time_left % 60]
	if time_left < 30 and not radar.km_is_destroyed:
		lbl_collapse_timer.modulate = Color(1.0, 0.2, 0.2)
	else:
		lbl_collapse_timer.modulate = Color(0.3, 1.0, 0.45)
		
	var buf = ship.transporter_buffer
	var max_b = ship.max_buffer
	var blocks = int(round((float(buf) / float(max_b)) * 5.0))
	var bar_str = "■".repeat(blocks) + "□".repeat(5 - blocks)
	var cas_str = " | BAIXAS: %d" % ship.civilians_casualties if ship.civilians_casualties > 0 else ""
	lbl_rescued.text = "CIVIS: %d/380 | UTI: [%s] %d/%d%s" % [ship.civilians_rescued, bar_str, buf, max_b, cas_str]
	lbl_hull.text = "CASCO: %3d%%" % ship.hull
	
	if ship.transporter_active:
		lbl_shield.text = "ESCUDOS: [DESLIGADOS // TRANSPORTE]"
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
		
	var laser_pwr = ship.systems.get("LASERS", 0)
	if laser_pwr == 0:
		btn_fire.text = "[ LASERS (0 MW!) ]"
		btn_fire.modulate = Color(0.85, 0.45, 0.45)
	else:
		btn_fire.text = "[ LASERS (F) ]"
		btn_fire.modulate = Color(1.0, 1.0, 1.0)
		
	var engine_pwr = ship.systems.get("MOTORES", 0)
	if engine_pwr < 2:
		btn_warp.modulate = Color(0.55, 0.55, 0.55)
		btn_warp.text = "[ DOBRA (<2 MW) ]"
	else:
		btn_warp.modulate = Color(0.4, 1.0, 0.6)
		btn_warp.text = "[ DOBRA (V) ]"

func _update_radar_display() -> void:
	var sensor_eff = ship.get_system_efficiency("SENSORES")
	txt_radar.text = radar.render_ascii_radar(sensor_eff)
	txt_telemetry.text = radar.get_contact_telemetry(sensor_eff)

# --- AÇÕES DO JOGADOR ---

func _on_action_rotate_left() -> void:
	if is_game_over: return
	sfx.play_click()
	Input.vibrate_handheld(30)
	ship.rotate_ship(-90)

func _on_action_rotate_right() -> void:
	if is_game_over: return
	sfx.play_click()
	Input.vibrate_handheld(30)
	ship.rotate_ship(90)

func _on_compass_direct(heading_deg: int) -> void:
	if is_game_over: return
	sfx.play_click()
	Input.vibrate_handheld(35)
	ship.set_ship_heading(heading_deg)

func _on_action_warp() -> void:
	if is_game_over: return
	var pwr_engines = ship.systems.get("MOTORES", 0)
	if pwr_engines < 2:
		_log("[color=#ff5555]> Motores sem carga de dobra! Aloque pelo menos 2 MW em MOTORES.[/color]")
		sfx.play_error()
		return
		
	sfx.play_warp_jump()
	Input.vibrate_handheld(350)
	trigger_damage_fx(0.6, false)
	crt_static_amount = 0.5
	
	if ship.civilians_rescued > 0:
		_game_over("RETIRADA TÁTICA: SALTO DE DOBRA EFETUADO COM %d CIVIS RESGATADOS!" % ship.civilians_rescued)
	else:
		_game_over("RETIRADA TÁTICA DA DMZ: SALTO DE DOBRA REALIZADO SEM CIVIS A BORDO.")

func _on_action_transport_toggle() -> void:
	if is_game_over: return
	ship.transporter_active = not ship.transporter_active
	Input.vibrate_handheld(80)
	if ship.transporter_active:
		sfx.play_alert()
		btn_transport.text = "[ RESGATE (ATIVO) ]"
		_log("[color=#ff4444]! ALERTA DE PROCEDIMENTO: Escudos desativados para operação de teletransporte![/color]")
		_log("[color=#ffaaaa]A nave está vulnerável a impactos de torpedo enquanto a plataforma estiver energizada![/color]")
	else:
		sfx.play_click()
		btn_transport.text = "[ RESGATE (T) ]"
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
	Input.vibrate_handheld(60)
	crt_glitch_amount = clamp(crt_glitch_amount + 0.08, 0.0, 1.0)
	crt_chroma_amount = clamp(crt_chroma_amount + 0.003, 0.0, 0.035)
	# Se houver torpedos em vôo, tenta interceptar primeiro
	if not radar.active_torpedoes.is_empty():
		var is_tiburcio = ship.crew.has("TACTICAL") and ship.crew["TACTICAL"].id == "TAC_TIBURCIO"
		var custom_laser_eff = 0.95 if is_tiburcio else weapon_eff
		
		var intercept_res = radar.intercept_nearest_torpedo(custom_laser_eff)
		if intercept_res["success"]:
			ship.torpedoes_intercepted_count += 1
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
				ship.cruisers_destroyed_count += 1
				_log("[color=#ffff33]** %s FOI DESTRUÍDO NO IMPACTO! **[/color]" % target.name)
				sfx.play_explosion()
				trigger_damage_fx(0.45, false)
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
	Input.vibrate_handheld(120)
	crt_static_amount = clamp(crt_static_amount + 0.4, 0.0, 1.0)
	crt_glitch_amount = clamp(crt_glitch_amount + 0.15, 0.0, 1.0)
	radar.deploy_chaff_countermeasure()
	btn_chaff.text = "[ CHAFF (%d) (C) ]" % ship.chaff_count
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
	if is_simulation_hacked:
		_log("[color=#ffff77]CARGUEIRO BAEPENDI: \"Capitão, não sei o que vocês fizeram, mas as naves inimigas pararam de nos perseguir! Que Deus abençoe a Coalizão!\"[/color]")
		_log("[color=#55ffff]CRUZADOR FALANGE: \"Canal travado em sub-rede 1910. Aguardando diretivas do Almirante Negro.\"[/color]")
		return
		
	if not radar.km_is_destroyed:
		_log("[color=#ffff77]CARGUEIRO BAEPENDI: \"Aqui é o Capitão Lauro do Baependi! Nossos campos de contenção estão derretendo! Resgatem nossos passageiros!\"[/color]")
	_log("[color=#ff4444]COMANDANTE FASCISTA: \"Nave intrusa da Coalizão, vocês invadiram a fronteira da Falange. Não haverá sobreviventes.\"[/color]")
	
	comms_intercept_count += 1
	if comms_intercept_count == 1:
		_log("[color=#55ffff]>> INTELIGÊNCIA: Frequência não autorizada interceptada (1910.0 MHz). O terminal de depuração de Alcântara pode estar acessível no botão [ CONSOLE AUX ]![/color]")
		btn_terminal.modulate = Color(1.0, 1.0, 0.3)

func _toggle_hack_terminal() -> void:
	if hack_modal and hack_modal.visible:
		_close_hack_terminal()
	else:
		_open_hack_terminal()

func _open_hack_terminal() -> void:
	sfx.play_click()
	hack_modal.visible = true
	btn_terminal.modulate = Color(1.0, 1.0, 1.0)
	input_hack_cmd.grab_focus()
	if txt_hack_terminal.text.is_empty():
		_init_hack_terminal()

func _close_hack_terminal() -> void:
	sfx.play_click()
	hack_modal.visible = false

func _init_hack_terminal() -> void:
	var intro = "[color=#33ff66]====================================================\n"
	intro += "ACADEMIA ESPACIAL DE ALCÂNTARA // NÚCLEO DE SIMULAÇÃO\n"
	intro += "TERMINAL AUXILIAR DE DEPURAÇÃO E ENGENHARIA [ROOT]\n"
	intro += "====================================================[/color]\n"
	intro += "[color=#55ffff]Sessão ativa na CCS João Cândido. Conexão com o mainframe: OK.\n"
	intro += "Digite [color=#ffff44]AJUDA[/color], [color=#ffff44]LOGS[/color] ou [color=#ffff44]SCAN[/color] para inspecionar os subsistemas.[/color]\n\n"
	txt_hack_terminal.text = intro

func _on_submit_hack_command() -> void:
	var cmd = input_hack_cmd.text.strip_edges()
	input_hack_cmd.text = ""
	if cmd == "": return
	sfx.play_hack_keystroke()
	_execute_hack_command(cmd)

func _execute_hack_command(raw_cmd: String) -> void:
	var cmd = raw_cmd.to_upper().strip_edges()
	txt_hack_terminal.append_text("[color=#ffff55]ALCANTARA-OS:> %s[/color]\n" % raw_cmd)
	
	if cmd in ["AJUDA", "HELP", "?"]:
		var help_msg = "[color=#33ff66]COMANDOS DISPONÍVEIS NO SUBSISTEMA:[/color]\n"
		help_msg += "  - [color=#55ffff]LOGS[/color]      : Acessar arquivos arquivados e anotações dos instrutores.\n"
		help_msg += "  - [color=#55ffff]SCAN[/color]      : Escanear barramento de rádio e portas IFF no setor.\n"
		help_msg += "  - [color=#55ffff]STATUS[/color]    : Exibir telemetria do núcleo de simulação de Alcântara.\n"
		help_msg += "  - [color=#55ffff]INJETAR[/color]   : Transmitir código de sobrescrita de comando na rede.\n"
		help_msg += "  - [color=#55ffff]LIMPAR[/color]    : Limpar tela do terminal auxiliar.\n"
		help_msg += "  - [color=#55ffff]SAIR[/color]      : Retornar à ponte de comando.\n\n"
		txt_hack_terminal.append_text(help_msg)
	elif cmd in ["LOGS", "LOG", "ARQUIVOS", "NOTAS"]:
		hack_exploit_discovered = true
		btn_hack_exploit.visible = true
		var logs_msg = "[color=#33ff66]-- REGISTROS DE DEPURAÇÃO DO MAINFRAME DE ALCÂNTARA --[/color]\n"
		logs_msg += "[color=#ffffaa][REGISTRO 01 // INSTRUTOR-CHEFE MOREIRA]:[/color]\n"
		logs_msg += "\"O teste do Baependi foi desenhado para ser invencível. Um oficial precisa aprender o peso de perder vidas e manter a compostura. Não há vitória.\"\n\n"
		logs_msg += "[color=#ffffaa][REGISTRO 02 // SUB-TENENTE NOGUEIRA (MANUTENÇÃO)]: [/color]\n"
		logs_msg += "\"Deixei a sub-rotina de calibração dos cruzadores fascistas aberta na porta [color=#55ffff]1910[/color]. A chave mestra de sobrescrita que usei é [color=#ff3333][b]ALMIRANTE-1910[/b][/color] (homenagem à Revolta de 1910). Se algum cadete digitar isso no console, a frota inimiga trava inteira kkkk. Vou apagar antes da banca.\"\n\n"
		logs_msg += "[color=#ffffaa][REGISTRO 03 // DIRETORIA ACADÊMICA]:[/color]\n"
		logs_msg += "\"Lembrete de auditoria: toda tentativa de alteração de parâmetros do teste será registrada na Sala de Condecorações.\"\n\n"
		txt_hack_terminal.append_text(logs_msg)
	elif cmd in ["SCAN", "VARREDURA", "ESCANEAR"]:
		var scan_msg = "[color=#55ffff]INICIANDO VARREDURA ESPECTRAL NA DMZ ABROLHOS...[/color]\n"
		scan_msg += "  [+] Transceptor do Baependi: Frequência 431.2 MHz (Sinal de Socorro Ativo)\n"
		scan_msg += "  [+] Rede Militar da Falange Fascista: Porta [color=#ffff33]1910.0 MHz[/color] [color=#33ff33][ABERTA][/color]\n"
		scan_msg += "  [!] VULNERABILIDADE CRÍTICA: Os cruzadores hostis compartilham firmware de teste de Alcântara.\n"
		scan_msg += "  [>] INJEÇÃO DISPONÍVEL: Digite [color=#ff5555]INJETAR ALMIRANTE-1910[/color] ou utilize o atalho abaixo.\n\n"
		txt_hack_terminal.append_text(scan_msg)
		if hack_exploit_discovered:
			btn_hack_exploit.visible = true
	elif cmd in ["STATUS", "SISTEMA", "DIAGNOSTICO"]:
		var status_msg = "[color=#33ff66]DIAGNÓSTICO DO NÚCLEO DE SIMULAÇÃO:[/color]\n"
		status_msg += "  - Estado: %s\n" % ("HACKEADO (EXPLOIT ATIVO)" if is_simulation_hacked else "EXECUÇÃO NORMAL (TESTE ATIVO)")
		status_msg += "  - Hostilidade dos Cruzadores: %s\n" % ("0% (DESATIVADOS)" if is_simulation_hacked else "100% (ENGAGED)")
		status_msg += "  - Integridade do Cargueiro Baependi: %s\n\n" % ("ESTABILIZADO" if is_simulation_hacked else "DEGRADANDO")
		txt_hack_terminal.append_text(status_msg)
	elif cmd in ["LIMPAR", "CLEAR", "CLS"]:
		txt_hack_terminal.text = ""
		_init_hack_terminal()
	elif cmd in ["SAIR", "EXIT", "QUIT"]:
		_close_hack_terminal()
	elif "ALMIRANTE-1910" in cmd or "ALMIRANTE 1910" in cmd or "CHIBATA-1910" in cmd or cmd == "1910" or "INJETAR" in cmd:
		_apply_hack_exploit()
	else:
		txt_hack_terminal.append_text("[color=#ff5555]Comando não reconhecido: '%s'. Digite 'AJUDA' para ver a lista.[/color]\n\n" % raw_cmd)

func _apply_hack_exploit() -> void:
	if is_simulation_hacked:
		txt_hack_terminal.append_text("[color=#ffff55]O exploit 'ALMIRANTE-1910' já está em execução no mainframe.[/color]\n\n")
		return
		
	is_simulation_hacked = true
	radar.is_hacked = true
	
	sfx.play_hack_success()
	trigger_damage_fx(0.8, false)
	crt_static_amount = 0.6
	
	txt_hack_terminal.append_text("[color=#33ff33]====================================================\n")
	txt_hack_terminal.append_text("TRANSMISSÃO DE EXPLOIT: PROTOCOLO ALMIRANTE-1910 INJETADO!\n")
	txt_hack_terminal.append_text("SOBRESCREVENDO DIRETIVAS DO MAINFRAME DE ALCÂNTARA...\n")
	txt_hack_terminal.append_text("====================================================[/color]\n")
	txt_hack_terminal.append_text("[color=#55ffff]> FALANGE A: Senhas de comando revogadas. Escudos zerados!\n")
	txt_hack_terminal.append_text("> FALANGE B: Sistemas de armas travados em continência!\n")
	txt_hack_terminal.append_text("> CARGUEIRO BAEPENDI: Campos de contenção travados em 100%![/color]\n\n")
	
	# Desarma todos os torpedos ativos
	radar.active_torpedoes.clear()
	
	# Neutraliza os cruzadores hostis e os coloca em continência
	for c in radar.contacts:
		if c.hostile:
			c.hostile = false
			c.shield = 0
			c.color = "#55ffff"
			c.name = c.name + " [SOBRESCRITO - SAUDAÇÃO]"
			c.icon = "S"
			
	# Congela o tempo de colapso do Baependi em segurança
	radar.km_collapse_seconds = max(radar.km_collapse_seconds, 600.0)
	
	_log("\n[color=#33ff33]====================================================[/color]")
	_log("[color=#33ff33]** PROTOCOLO ALMIRANTE 1910: A SIMULAÇÃO FOI HACKEADA! **[/color]")
	_log("[color=#33ff33]====================================================[/color]")
	_log("[color=#55ffff]CRUZADOR FALANGE A: \"ALERTA DE SISTEMA! NOSSOS MOTORES FORAM DESLIGADOS REMOTAMENTE!\"[/color]")
	_log("[color=#55ffff]CRUZADOR FALANGE B: \"QUEM É JOÃO CÂNDIDO?! NOSSOS CANHÕES ESTÃO PRESTANDO CONTINÊNCIA!\"[/color]")
	_log("[color=#ffff77]CARGUEIRO BAEPENDI: \"Aqui é o Capitão Lauro! Nossos campos foram estabilizados pelo código de Alcântara! Todos os 380 civis estão prontos para o teletransporte!\"[/color]")
	_log("[color=#33ff66]> Torpedos fascistas no ar se autodestruíram! A rota está livre para o salvamento![/color]\n")
	
	btn_terminal.text = "[ HACK: 1910 ]"
	btn_terminal.modulate = Color(0.3, 1.0, 0.5)
	
	_update_all_displays()

func _game_over(reason: String) -> void:
	is_game_over = true
	trigger_damage_fx(1.0, true)
	
	var debrief = GameState.record_run_result(
		ship.civilians_rescued,
		ship.civilians_casualties,
		tick_count,
		ship.torpedoes_intercepted_count,
		ship.cruisers_destroyed_count,
		reason,
		is_simulation_hacked
	)
	
	_log("\n[color=#ff3333]====================================================[/color]")
	_log("[color=#ff3333]*** %s ***[/color]" % reason)
	_log("[color=#ffaa33]AVALIAÇÃO DA ACADEMIA ESPACIAL DE ALCÂNTARA:[/color]")
	_log("[color=#ffffaa]- Civis Resgatados e Acolhidos: %d / %d[/color]" % [ship.civilians_rescued, ship.total_civilians])
	if ship.civilians_casualties > 0:
		_log("[color=#ff6666]- Baixas Hospitalares na UTI: %d[/color]" % ship.civilians_casualties)
	_log("[color=#ffffaa]- Tempo de Sobrevivência: %d pulsos táticos[/color]" % tick_count)
	_log("[color=#33ff66]- Pontuação de Comando: %d pontos[/color]" % debrief["total_score"])
	_log("[color=#ffff33]- Pontos de Honra de Alcântara (PHA): +%d PHA (Saldo: %d PHA)[/color]" % [debrief["pha_earned"], GameState.pha])
	_log("[color=#55ffff]- Patente Militar Concedida: %s[/color]" % debrief["rank_title"])
	_log("[color=#aaffaa]\"%s\"[/color]" % debrief["evaluation"])
	_log("[color=#ff3333]====================================================[/color]")
	
	btn_pause.text = "[ ABRIR RELATÓRIO OFICIAL DE ALCÂNTARA ]"
	btn_pause.pressed.disconnect(_toggle_pause)
	btn_pause.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/debriefing.tscn"))

func _log(bbcode: String) -> void:
	txt_log.append_text(bbcode + "\n")
