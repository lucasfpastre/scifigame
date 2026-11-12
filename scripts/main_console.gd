class_name MainConsole
extends Control

const ShipDataScript = preload("res://scripts/ship_data.gd")
const TacticalRadarScript = preload("res://scripts/tactical_radar.gd")
const SoundEffectsScript = preload("res://scripts/sound_effects.gd")

var ship = null
var radar = null
var sfx = null

# Nós de UI
@onready var lbl_stardate: Label = %LblStardate
@onready var lbl_alert: Label = %LblAlert
@onready var lbl_hull: Label = %LblHull
@onready var lbl_shield: Label = %LblShield
@onready var lbl_power_free: Label = %LblPowerFree

@onready var txt_radar: RichTextLabel = %TxtRadar
@onready var txt_telemetry: RichTextLabel = %TxtTelemetry
@onready var txt_log: RichTextLabel = %TxtLog
@onready var txt_crew: RichTextLabel = %TxtCrew

# Botões de Ações Táticas
@onready var btn_scan: Button = %BtnScan
@onready var btn_approach: Button = %BtnApproach
@onready var btn_fire: Button = %BtnFire
@onready var btn_comms: Button = %BtnComms
@onready var btn_repair: Button = %BtnRepair
@onready var btn_alert: Button = %BtnAlert

# Controles do Power Grid
var power_ui: Dictionary = {} # system_name -> { "lbl_bar": Label, "lbl_info": Label, "btn_minus": Button, "btn_plus": Button }

var stardate: float = 4312.1
var turn_count: int = 1
var is_game_over: bool = false

func _ready() -> void:
	sfx = SoundEffectsScript.new()
	add_child(sfx)
	
	ship = ShipDataScript.new()
	radar = TacticalRadarScript.new()
	
	_setup_power_grid_ui()
	_connect_events()
	
	_log("[color=#33ff66]====================================================[/color]")
	_log("[color=#33ff66]** SIMULAÇÃO TÁTICA DA FROTA // PROTOCOLO KOBAYASHI MARU **[/color]")
	_log("[color=#33ff66]SETOR: 104 - ZONA NEUTRA KLINGON // NAVE: U.S.S. NX-900[/color]")
	_log("[color=#33ff66]====================================================[/color]")
	_log("[color=#ffff66]TRANSMISSÃO DE SOCORRO RECEBIDA DO CARGUEIRO KOBAYASHI MARU.[/color]")
	_log("[color=#33ff66]Ordens da Frota: Resgatar tripulação ou recuar para evitar a guerra.[/color]\n")
	
	_update_all_displays()

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
	ship.crew_intercom.connect(_on_crew_intercom)
	
	btn_scan.pressed.connect(_on_action_scan)
	btn_approach.pressed.connect(_on_action_approach)
	btn_fire.pressed.connect(_on_action_fire)
	btn_comms.pressed.connect(_on_action_comms)
	btn_repair.pressed.connect(_on_action_repair)
	btn_alert.pressed.connect(_on_action_alert_toggle)

func _on_power_adjust(sys_name: String, delta: int) -> void:
	if is_game_over: return
	if ship.adjust_power(sys_name, delta):
		sfx.play_click()
	else:
		sfx.play_error()
	_update_power_grid_display()

func _on_ship_power_changed(_sys_name: String, _val: int, _available: int) -> void:
	_update_power_grid_display()
	_update_radar_display()

func _on_ship_status_changed(_hull: int, _shield: int, _alert_level: String) -> void:
	_update_header_status()

func _on_crew_intercom(speaker: String, text: String) -> void:
	var msg = "[color=#55ffff]%s[/color] %s" % [speaker, text]
	txt_crew.text = msg
	_log(msg)

func _update_all_displays() -> void:
	_update_header_status()
	_update_power_grid_display()
	_update_radar_display()

func _update_header_status() -> void:
	lbl_stardate.text = "DATA ESTELAR: %.1f | TURNO: %02d" % [stardate, turn_count]
	lbl_hull.text = "CASCO: %3d%%" % ship.hull
	lbl_shield.text = "ESCUDO: %3d%%" % ship.shield
	lbl_alert.text = "[ %s ]" % ship.alert_state
	
	if ship.alert_state == "ALERTA VERMELHO":
		lbl_alert.modulate = Color(1.0, 0.2, 0.2)
	elif ship.alert_state == "ALERTA AMARELO":
		lbl_alert.modulate = Color(1.0, 0.8, 0.1)
	else:
		lbl_alert.modulate = Color(0.2, 1.0, 0.4)

func _update_power_grid_display() -> void:
	lbl_power_free.text = "REATOR: %d/%d MW DISPONÍVEL" % [ship.get_available_power(), ship.total_power]
	
	for sys_name in power_ui:
		var data = power_ui[sys_name]
		var val = ship.systems[sys_name]
		var max_bars = 4 if sys_name != "SUPORTE" else 2
		
		# Desenha as barras em ASCII: [■■□□]
		var bar_str = "["
		for i in range(max_bars):
			if i < val:
				bar_str += "■"
			else:
				bar_str += "□"
		bar_str += "]"
		data["lbl_bar"].text = "%s %d MW" % [bar_str, val]
		
		# Mostra bônus do oficial
		var efficiency = ship.get_system_efficiency(sys_name)
		data["lbl_info"].text = "EFIC: %d%%" % int(efficiency * 100.0)
		
		data["btn_plus"].disabled = not ship.can_increase_power(sys_name)
		data["btn_minus"].disabled = not ship.can_decrease_power(sys_name)

func _update_radar_display() -> void:
	var sensor_eff = ship.get_system_efficiency("SENSORES")
	txt_radar.text = radar.render_ascii_radar(sensor_eff)
	txt_telemetry.text = radar.get_contact_telemetry(sensor_eff)

func _advance_turn() -> void:
	if is_game_over: return
	turn_count += 1
	stardate += 0.3
	
	# Regeneração de escudos
	ship.regenerate_shields()
	
	# Reação dos contatos / inimigos
	var engine_eff = ship.get_system_efficiency("MOTORES")
	var radar_events = radar.update_tactical_step(engine_eff)
	for ev in radar_events:
		_log("[color=#ff6666]> %s[/color]" % ev)
		sfx.play_alert()
		
	# Ataque hostil se inimigos estiverem em alcance
	_process_hostile_turn()
	
	_update_all_displays()
	
	# Condição de derrota da Kobayashi Maru
	if ship.hull <= 0:
		_game_over(false, "CASCO DESTRUÍDO. SIMULAÇÃO ENCERRADA.")

func _process_hostile_turn() -> void:
	for c in radar.contacts:
		if c.hostile and c.distance_km <= 5000:
			# Chance de disparo inimigo
			var hit_chance = 0.75 - (ship.get_system_efficiency("MOTORES") * 0.4)
			if randf() < hit_chance:
				var dmg = randi_range(15, 30)
				_log("[color=#ff4444]! DISPARO INIMIGO de %s! Recebemos %d de dano![/color]" % [c.name, dmg])
				ship.apply_damage(dmg)
				sfx.play_alert()
			else:
				_log("[color=#55ff55]Evadimos os torpedos de %s graças aos propulsores![/color]" % c.name)

# --- AÇÕES DOS BOTÕES ---

func _on_action_scan() -> void:
	if is_game_over: return
	sfx.play_beep(1400.0, 0.08, 0.25)
	_log("[color=#33ff66]> Varredura tática de longo alcance executada.[/color]")
	
	var sensor_eff = ship.get_system_efficiency("SENSORES")
	if sensor_eff > 0.8:
		_log("[color=#55ffff]Oficial de Ciências: \"Detecto assinaturas de camuflagem colapsando ao norte! São duas naves de guerra!\"[/color]")
	elif sensor_eff < 0.4:
		_log("[color=#ffff55]Oficial de Ciências: \"Sensores com pouca potência, capitão. Leituras confusas.\"[/color]")
		
	_advance_turn()

func _on_action_approach() -> void:
	if is_game_over: return
	sfx.play_beep(600.0, 0.05, 0.2)
	var engine_eff = ship.get_system_efficiency("MOTORES")
	if engine_eff <= 0.1:
		_log("[color=#ff5555]> Motores sem energia suficiente para avanço seguro![/color]")
		sfx.play_error()
		return
		
	_log("[color=#33ff66]> Manobrando em direção à Kobayashi Maru...[/color]")
	_advance_turn()

func _on_action_fire() -> void:
	if is_game_over: return
	var weapon_eff = ship.get_system_efficiency("LASERS")
	if weapon_eff < 0.2:
		_log("[color=#ff5555]> Capacitores dos Lasers sem carga! Aumente a energia das armas![/color]")
		sfx.play_error()
		return
		
	sfx.play_laser()
	# Encontra inimigo mais próximo
	var target = null
	var min_dist = 999999
	for c in radar.contacts:
		if c.hostile and c.distance_km < min_dist:
			min_dist = c.distance_km
			target = c
			
	if target:
		var dmg = int(25 * weapon_eff * randf_range(0.8, 1.3))
		target.hull = max(0, target.hull - dmg)
		_log("[color=#ffaa33]> Disparando baterias de feixes contra %s! Causou %d de avaria![/color]" % [target.name, dmg])
		if target.hull <= 0:
			_log("[color=#ffff33]** %s FOI DESTRUÍDO NO IMPACTO! **[/color]" % target.name)
			radar.contacts.erase(target)
	else:
		_log("[color=#ffff55]> Nenhum alvo hostil em alcance de disparo dos lasers.[/color]")
		
	_advance_turn()

func _on_action_comms() -> void:
	if is_game_over: return
	sfx.play_beep(900.0, 0.1, 0.2)
	_log("[color=#55ffff]> Canal de comunicação subespacial aberto.[/color]")
	_log("[color=#ffff77]KOBAYASHI MARU: \"Aqui é o Terceiro Oficial Kowalski do cargueiro Kobayashi Maru! Perdemos gravidade e energia de dobra! Por favor, nos tirem daqui!\"[/color]")
	_log("[color=#ff4444]TRANSMISSÃO HOSTIL INTERCEPTADA: \"Nave da Federação, você violou o Tratado da Zona Neutra. Desative escudos e prepare-se para ser destruído.\"[/color]")
	_advance_turn()

func _on_action_repair() -> void:
	if is_game_over: return
	var eng = ship.crew.get("ENGINEER")
	if eng and eng.trust >= 60:
		sfx.play_beep(440.0, 0.08, 0.25)
		var repair_amt = randi_range(10, 20)
		ship.hull = min(ship.max_hull, ship.hull + repair_amt)
		_log("[color=#33ff66]> Equipes de controle de avarias selaram brechas! +%d%% de Casco.[/color]" % repair_amt)
		_update_header_status()
		_advance_turn()
	else:
		_log("[color=#ff5555]> Engenharia ocupada mantendo o reator estável![/color]")
		sfx.play_error()

func _on_action_alert_toggle() -> void:
	if is_game_over: return
	sfx.play_alert()
	if ship.alert_state == "ALERTA VERMELHO":
		ship.alert_state = "NORMAL"
		_log("[color=#33ff66]> Retornando a Condição Normal de Navegação.[/color]")
	else:
		ship.alert_state = "ALERTA VERMELHO"
		_log("[color=#ff2222]> ALERTA VERMELHO ATIVADO! Todos os postos de combate tripulados![/color]")
	_update_header_status()

func _game_over(won: bool, reason: String) -> void:
	is_game_over = true
	_log("\n[color=#ff3333]====================================================[/color]")
	_log("[color=#ff3333]*** %s ***[/color]" % reason)
	_log("[color=#ffaa33]AVALIAÇÃO DA ACADEMIA:[/color]")
	_log("[color=#ffffaa]- Sobrevivência: %d turnos[/color]" % turn_count)
	_log("[color=#ffffaa]- Moral da Tripulação: %d%%[/color]" % ship.crew["PILOT"].trust)
	_log("[color=#ffffaa]- Veredito: O teste da Kobayashi Maru avalia o caráter diante da derrota inevitável.[/color]")
	_log("[color=#ff3333]====================================================[/color]")

func _log(bbcode: String) -> void:
	txt_log.append_text(bbcode + "\n")
