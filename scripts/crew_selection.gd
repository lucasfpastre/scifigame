class_name CrewSelection
extends Control

const CrewMemberScript = preload("res://scripts/crew_member.gd")
const SoundEffectsScript = preload("res://scripts/sound_effects.gd")

var roster: Dictionary = {}
var selected_indices: Dictionary = {
	"PILOT": 0,
	"ENGINEER": 0,
	"MEDICAL": 0,
	"TACTICAL": 0
}

var sfx = null

# Nós do Cabeçalho e Meta-Progressão
@onready var lbl_pha: Label = %LblPHA
@onready var btn_ship_select: Button = %BtnShipSelect
@onready var btn_ship_unlock: Button = %BtnShipUnlock
@onready var btn_scores: Button = %BtnScores
@onready var txt_ship_info: RichTextLabel = %TxtShipInfo

@onready var btn_launch: Button = %BtnLaunch

# Painéis dos Oficiais
@onready var txt_pilot: RichTextLabel = %TxtPilot
@onready var btn_pilot_0: Button = %BtnPilot0
@onready var btn_pilot_1: Button = %BtnPilot1

@onready var txt_eng: RichTextLabel = %TxtEng
@onready var btn_eng_0: Button = %BtnEng0
@onready var btn_eng_1: Button = %BtnEng1

@onready var txt_med: RichTextLabel = %TxtMed
@onready var btn_med_0: Button = %BtnMed0
@onready var btn_med_1: Button = %BtnMed1

@onready var txt_tac: RichTextLabel = %TxtTac
@onready var btn_tac_0: Button = %BtnTac0
@onready var btn_tac_1: Button = %BtnTac1

var available_ship_ids = ["SHIP_CANDIDO", "SHIP_GUARANI", "SHIP_TAMANDARE"]
var current_ship_idx = 0

func _ready() -> void:
	sfx = SoundEffectsScript.new()
	add_child(sfx)
	
	GameState.load_save()
	roster = CrewMemberScript.get_available_roster()
	
	current_ship_idx = available_ship_ids.find(GameState.selected_ship_id)
	if current_ship_idx == -1:
		current_ship_idx = 0
		
	_setup_buttons()
	_update_ship_ui()
	_update_all_cards()

func _setup_buttons() -> void:
	btn_pilot_0.pressed.connect(func(): _select_officer("PILOT", 0))
	btn_pilot_1.pressed.connect(func(): _select_officer("PILOT", 1))
	
	btn_eng_0.pressed.connect(func(): _select_officer("ENGINEER", 0))
	btn_eng_1.pressed.connect(func(): _select_officer("ENGINEER", 1))
	
	btn_med_0.pressed.connect(func(): _select_officer("MEDICAL", 0))
	btn_med_1.pressed.connect(func(): _select_officer("MEDICAL", 1))
	
	btn_tac_0.pressed.connect(func(): _select_officer("TACTICAL", 0))
	btn_tac_1.pressed.connect(func(): _select_officer("TACTICAL", 1))
	
	btn_ship_select.pressed.connect(_on_cycle_ship)
	btn_ship_unlock.pressed.connect(_on_unlock_ship)
	btn_scores.pressed.connect(_on_scores_pressed)
	btn_launch.pressed.connect(_on_launch_pressed)

func _on_cycle_ship() -> void:
	sfx.play_click()
	current_ship_idx = (current_ship_idx + 1) % available_ship_ids.size()
	var new_id = available_ship_ids[current_ship_idx]
	if GameState.unlocked_ships.has(new_id):
		GameState.selected_ship_id = new_id
		GameState.save_game()
	_update_ship_ui()

func _on_unlock_ship() -> void:
	var target_id = available_ship_ids[current_ship_idx]
	if GameState.unlock_ship(target_id):
		sfx.play_alert()
		_update_ship_ui()
	else:
		sfx.play_error()

func _on_scores_pressed() -> void:
	sfx.play_click()
	get_tree().change_scene_to_file("res://scenes/debriefing.tscn")

func _update_ship_ui() -> void:
	lbl_pha.text = "SALDO: %d PHA" % GameState.pha
	var ship_id = available_ship_ids[current_ship_idx]
	var ship_defs = GameState.get_ship_definitions()
	var def = ship_defs[ship_id]
	var is_unlocked = GameState.unlocked_ships.has(ship_id)
	
	btn_ship_select.text = "[ BELONAVE: %s ]" % def["name"]
	
	if is_unlocked:
		btn_ship_unlock.visible = false
		btn_launch.disabled = false
		btn_launch.text = "[ INICIAR SIMULAÇÃO // DESDOBRAR %s ]" % def["name"].to_upper()
	else:
		btn_ship_unlock.visible = true
		btn_launch.disabled = true
		btn_launch.text = "[ BELONAVE BLOQUEADA - DESBLOQUEIE ACIMA ]"
		if GameState.pha >= def["cost"]:
			btn_ship_unlock.disabled = false
			btn_ship_unlock.text = "[ DESBLOQUEAR (%d PHA) ]" % def["cost"]
			btn_ship_unlock.modulate = Color(1.0, 1.0, 0.3)
		else:
			btn_ship_unlock.disabled = true
			btn_ship_unlock.text = "[ BLOQUEADO (%d PHA) ]" % def["cost"]
			btn_ship_unlock.modulate = Color(0.8, 0.4, 0.4)
			
	var info_text = "[color=#55ffff]%s[/color] \"%s\" | Reator: %d MW | Casco: %d | Escudos: %d%%\n" % [
		def["class_type"], def["callsign"], def["power"], def["hull"], def["shield_per_quad"]
	]
	info_text += "[color=#33ff66][+] %s[/color] | [color=#ffaaaa][-] %s[/color]" % [def["pro"], def["con"]]
	txt_ship_info.text = info_text

func _select_officer(role_str: String, index: int) -> void:
	selected_indices[role_str] = index
	sfx.play_click()
	_update_all_cards()

func _update_all_cards() -> void:
	_update_card("PILOT", txt_pilot, btn_pilot_0, btn_pilot_1)
	_update_card("ENGINEER", txt_eng, btn_eng_0, btn_eng_1)
	_update_card("MEDICAL", txt_med, btn_med_0, btn_med_1)
	_update_card("TACTICAL", txt_tac, btn_tac_0, btn_tac_1)

func _update_card(role_str: String, txt_display: RichTextLabel, btn0: Button, btn1: Button) -> void:
	var list: Array[CrewMember] = roster[role_str]
	var chosen_idx = selected_indices[role_str]
	var officer = list[chosen_idx]
	
	var text = "[color=#55ffff]%s[/color]\n" % officer.role_title
	text += "[color=#33ff66]%s[/color] \"%s\"\n\n" % [officer.name, officer.callsign]
	text += "[color=#33ff66][+] PRÓ:[/color] %s\n" % officer.pro_title
	text += "[color=#aaffaa]    %s[/color]\n\n" % officer.pro_desc
	text += "[color=#ff6666][-] CONTRA:[/color] %s\n" % officer.con_title
	text += "[color=#ffaaaa]    %s[/color]\n" % officer.con_desc
	txt_display.text = text
	
	btn0.text = "[ %s: %s ]" % [("ATIVO" if chosen_idx == 0 else "ESCOLHER"), list[0].name]
	btn1.text = "[ %s: %s ]" % [("ATIVO" if chosen_idx == 1 else "ESCOLHER"), list[1].name]
	
	btn0.modulate = Color(0.4, 1.0, 0.6) if chosen_idx == 0 else Color(0.7, 0.7, 0.7)
	btn1.modulate = Color(0.4, 1.0, 0.6) if chosen_idx == 1 else Color(0.7, 0.7, 0.7)

func _on_launch_pressed() -> void:
	sfx.play_alert()
	var final_crew: Dictionary = {}
	for role_str in selected_indices:
		var list = roster[role_str]
		var idx = selected_indices[role_str]
		final_crew[role_str] = list[idx]
		
	GameState.selected_crew = final_crew
	get_tree().change_scene_to_file("res://scenes/main_console.tscn")
