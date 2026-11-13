class_name MainMenu
extends Control

const SoundEffectsScript = preload("res://scripts/sound_effects.gd")

var sfx: SoundEffects = null

@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_continue: Button = %BtnContinue
@onready var btn_records: Button = %BtnRecords
@onready var btn_options: Button = %BtnOptions
@onready var btn_quit: Button = %BtnQuit

@onready var txt_profile: RichTextLabel = %TxtProfile
@onready var txt_lore: RichTextLabel = %TxtLore

# Modais
@onready var modal_options: Control = %ModalOptions
@onready var modal_records: Control = %ModalRecords

# Controles de Opções
@onready var btn_vol_down: Button = %BtnVolDown
@onready var btn_vol_up: Button = %BtnVolUp
@onready var lbl_vol_val: Label = %LblVolVal
@onready var btn_toggle_crt: Button = %BtnToggleCRT
@onready var btn_toggle_scanlines: Button = %BtnToggleScanlines
@onready var btn_toggle_haptics: Button = %BtnToggleHaptics
@onready var btn_reset_save: Button = %BtnResetSave
@onready var btn_close_options: Button = %BtnCloseOptions

# Controles de Recordes
@onready var txt_records_list: RichTextLabel = %TxtRecordsList
@onready var btn_close_records: Button = %BtnCloseRecords

@onready var crt_overlay: ColorRect = %CRTOverlay

func _ready() -> void:
	sfx = SoundEffectsScript.new()
	add_child(sfx)
	
	_apply_audio_volume()
	_apply_crt_settings()
	
	_setup_buttons()
	_update_profile_display()
	_update_lore_display()
	_update_options_ui()
	
	# Foco inicial no botão de Novo Jogo
	btn_new_game.grab_focus()

func _setup_buttons() -> void:
	btn_new_game.pressed.connect(_on_new_game)
	btn_continue.pressed.connect(_on_continue)
	btn_records.pressed.connect(_open_records_modal)
	btn_options.pressed.connect(_open_options_modal)
	btn_quit.pressed.connect(_on_quit)
	
	# Som de foco / hover nos botões
	for btn in [btn_new_game, btn_continue, btn_records, btn_options, btn_quit]:
		btn.mouse_entered.connect(_on_button_hover)
		btn.focus_entered.connect(_on_button_hover)
		
	# Modal Opções
	btn_vol_down.pressed.connect(_on_vol_down)
	btn_vol_up.pressed.connect(_on_vol_up)
	btn_toggle_crt.pressed.connect(_on_toggle_crt)
	btn_toggle_scanlines.pressed.connect(_on_toggle_scanlines)
	btn_toggle_haptics.pressed.connect(_on_toggle_haptics)
	btn_reset_save.pressed.connect(_on_reset_save)
	btn_close_options.pressed.connect(_close_options_modal)
	
	# Modal Recordes
	btn_close_records.pressed.connect(_close_records_modal)
	
	# Estado do botão Continuar (se já tem simulações ou naves liberadas)
	if GameState.total_runs == 0 and GameState.unlocked_ships.size() <= 1 and GameState.pha == 150:
		btn_continue.text = "[ 2 // CONTINUAR (SEM DADOS SALVOS) ]"
		btn_continue.modulate = Color(0.7, 0.7, 0.7)
	else:
		btn_continue.text = "[ 2 // CONTINUAR (HANGAR // %d PHA) ]" % GameState.pha
		btn_continue.modulate = Color(0.4, 1.0, 0.6)

func _on_button_hover() -> void:
	if sfx:
		sfx.play_beep(880.0, 0.02, 0.04)

func _trigger_haptic(ms: int = 15) -> void:
	if GameState.haptics_enabled:
		Input.vibrate_handheld(ms)

func _on_new_game() -> void:
	_trigger_haptic(30)
	sfx.play_click()
	# Inicia o fluxo de missão escolhendo a tripulação e a nave
	get_tree().change_scene_to_file("res://scenes/crew_selection.tscn")

func _on_continue() -> void:
	_trigger_haptic(30)
	sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/crew_selection.tscn")

func _open_options_modal() -> void:
	_trigger_haptic(20)
	sfx.play_click()
	_update_options_ui()
	modal_options.visible = true
	btn_close_options.grab_focus()

func _close_options_modal() -> void:
	_trigger_haptic(15)
	sfx.play_click()
	modal_options.visible = false
	GameState.save_game()
	btn_options.grab_focus()

func _open_records_modal() -> void:
	_trigger_haptic(20)
	sfx.play_click()
	_render_records_list()
	modal_records.visible = true
	btn_close_records.grab_focus()

func _close_records_modal() -> void:
	_trigger_haptic(15)
	sfx.play_click()
	modal_records.visible = false
	btn_records.grab_focus()

func _on_quit() -> void:
	_trigger_haptic(40)
	sfx.play_click()
	get_tree().quit()

func _update_profile_display() -> void:
	var defs = GameState.get_ship_definitions()
	var current_ship = defs.get(GameState.selected_ship_id, {}).get("name", "CCS João Cândido")
	
	var best_score = 0
	var best_rank = "Sem registros"
	if GameState.high_scores.size() > 0:
		best_score = GameState.high_scores[0].get("score", 0)
		best_rank = GameState.high_scores[0].get("rank", "Cadete")
		
	var text = "[color=#33ff66]====================================================[/color]\n"
	text += "[color=#55ffff]STATUS DO COMANDANTE:[/color] [color=#ffffff]Cadete Oficial de Alcântara[/color]\n"
	text += "[color=#55ffff]CRÉDITOS MILITARES (PHA):[/color] [color=#ffff33][b]%d PHA[/b][/color]\n" % GameState.pha
	text += "[color=#55ffff]BELONAVE EM PRONTIDÃO:[/color] [color=#aaffaa]%s[/color]\n" % current_ship
	text += "[color=#55ffff]NAVES DESBLOQUEADAS:[/color] [color=#ffffff]%d / %d belonaves[/color]\n" % [GameState.unlocked_ships.size(), defs.size()]
	text += "[color=#33ff66]----------------------------------------------------[/color]\n"
	text += "[color=#ffffff]Simulações Realizadas:[/color] %d missões\n" % GameState.total_runs
	text += "[color=#ffffff]Total de Civis Salvos:[/color] [color=#33ff33]%d sobreviventes[/color]\n" % GameState.lifetime_civilians_saved
	text += "[color=#ffffff]Total de Baixas:[/color] [color=#ff5555]%d baixas registradas[/color]\n" % GameState.lifetime_casualties
	text += "[color=#ffffff]Melhor Desempenho:[/color] [color=#ffff55]%d pts[/color] (%s)\n" % [best_score, best_rank]
	text += "[color=#33ff66]====================================================[/color]"
	txt_profile.text = text

func _update_lore_display() -> void:
	var text = "[color=#aaffaa]EMERGÊNCIA // ANO 2142 // DMZ ABROLHOS:[/color]\n"
	text += "O cargueiro civil [color=#ffff55]Baependi[/color] foi emboscado por cruzadores da [color=#ff5555]Falange Fascista[/color].\n\n"
	text += "Como capitão do [color=#55ffff]CCS João Cândido[/color], sua missão prioritária é avançar, estabilizar escudos e evacuar os [color=#ffffff]380 civis[/color] antes do colapso do núcleo de dobra.\n\n"
	text += "[color=#ffff77]\"Não há vitória honrosa sem a preservação da vida.\"[/color] - Diretiva Alcântara."
	txt_lore.text = text

func _render_records_list() -> void:
	if GameState.high_scores.is_empty():
		txt_records_list.text = "[color=#ffff55]Nenhuma simulação concluída registrada nos arquivos de Alcântara.[/color]\n\nInicie um [color=#33ff66]NOVO JOGO[/color] para registrar seu primeiro histórico oficial!"
		return
		
	var text = "[color=#55ffff]HISTÓRICO OFICIAL DE COMANDO // TOP 8 CLASSIFICAÇÕES:[/color]\n\n"
	var pos = 1
	for entry in GameState.high_scores:
		var medal = "★" if pos == 1 else " "
		var hack_flag = " [color=#55ffff][PROTOCOLO 1910][/color]" if entry.get("hacked", false) else ""
		text += "[color=#ffff33]%s #%d[/color] - [color=#33ff66]%d PONTOS[/color] | [color=#ffffff]%s[/color]%s\n" % [
			medal, pos, entry.get("score", 0), entry.get("rank", "Cadete"), hack_flag
		]
		text += "     [color=#aaffaa]Civis Salvos: %d[/color] | Data Estelar: %s\n\n" % [
			entry.get("civilians", 0), entry.get("date_run", "N/A")
		]
		pos += 1
	txt_records_list.text = text

# === OPÇÕES & AJUSTES ===

func _update_options_ui() -> void:
	lbl_vol_val.text = "%d%%" % int(GameState.sfx_volume * 100.0)
	btn_toggle_crt.text = "[ CURVATURA CRT: %s ]" % ("LIGADA" if GameState.crt_curvature else "DESLIGADA")
	btn_toggle_scanlines.text = "[ SCANLINES: %s ]" % ("LIGADAS" if GameState.crt_scanlines else "DESLIGADAS")
	btn_toggle_haptics.text = "[ VIBRAÇÃO HÁPTICA: %s ]" % ("ATIVADA" if GameState.haptics_enabled else "DESATIVADA")

func _on_vol_down() -> void:
	_trigger_haptic(15)
	GameState.sfx_volume = clamp(GameState.sfx_volume - 0.1, 0.0, 1.0)
	_apply_audio_volume()
	_update_options_ui()
	sfx.play_beep(440.0, 0.05, 0.2)

func _on_vol_up() -> void:
	_trigger_haptic(15)
	GameState.sfx_volume = clamp(GameState.sfx_volume + 0.1, 0.0, 1.0)
	_apply_audio_volume()
	_update_options_ui()
	sfx.play_beep(520.0, 0.05, 0.2)

func _apply_audio_volume() -> void:
	if GameState.sfx_volume <= 0.02:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(GameState.sfx_volume))

func _on_toggle_crt() -> void:
	_trigger_haptic(20)
	sfx.play_click()
	GameState.crt_curvature = not GameState.crt_curvature
	_apply_crt_settings()
	_update_options_ui()

func _on_toggle_scanlines() -> void:
	_trigger_haptic(20)
	sfx.play_click()
	GameState.crt_scanlines = not GameState.crt_scanlines
	_apply_crt_settings()
	_update_options_ui()

func _on_toggle_haptics() -> void:
	GameState.haptics_enabled = not GameState.haptics_enabled
	_trigger_haptic(40)
	sfx.play_click()
	_update_options_ui()

func _apply_crt_settings() -> void:
	if not crt_overlay or not crt_overlay.material: return
	var mat = crt_overlay.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("curvature", 0.016 if GameState.crt_curvature else 0.0)
		mat.set_shader_parameter("scanline_intensity", 0.2 if GameState.crt_scanlines else 0.0)

func _on_reset_save() -> void:
	_trigger_haptic(60)
	sfx.play_alert()
	GameState.pha = 150
	GameState.lifetime_civilians_saved = 0
	GameState.lifetime_casualties = 0
	GameState.total_runs = 0
	GameState.unlocked_ships = ["SHIP_CANDIDO"]
	GameState.selected_ship_id = "SHIP_CANDIDO"
	GameState.high_scores = []
	GameState.save_game()
	_update_profile_display()
	_update_options_ui()
	btn_continue.text = "[ 2 // CONTINUAR (SEM DADOS SALVOS) ]"
	btn_continue.modulate = Color(0.7, 0.7, 0.7)

# === ATALHOS DE TECLADO & GAMEPAD ===

func _unhandled_input(event: InputEvent) -> void:
	if modal_options.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_options_modal()
			get_viewport().set_input_as_handled()
		return
		
	if modal_records.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_records_modal()
			get_viewport().set_input_as_handled()
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_on_new_game()
			KEY_2:
				_on_continue()
			KEY_3:
				_open_records_modal()
			KEY_4:
				_open_options_modal()
			KEY_5:
				_on_quit()
			KEY_ESCAPE:
				_on_quit()
