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

func _ready() -> void:
	sfx = SoundEffectsScript.new()
	add_child(sfx)
	
	roster = CrewMemberScript.get_available_roster()
	_setup_buttons()
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
	
	btn_launch.pressed.connect(_on_launch_pressed)

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
