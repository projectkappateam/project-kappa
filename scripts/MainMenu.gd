# scripts/MainMenu.gd
extends Control

var options_menu_scene = preload("res://scenes/OptionsMenu.tscn")
var options_menu_instance = null

@onready var practice_button = $MarginContainer/VBoxContainer/MenuButtons/PracticeButton
@onready var multiplayer_button = $MarginContainer/VBoxContainer/MenuButtons/MultiplayerButton # ADD THIS
@onready var options_button = $MarginContainer/VBoxContainer/MenuButtons/OptionsButton
@onready var quit_button = $MarginContainer/VBoxContainer/MenuButtons/QuitButton

func _ready():
	practice_button.pressed.connect(_on_practice_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed) # ADD THIS
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_practice_pressed():
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_multiplayer_pressed(): # ADD THIS ENTIRE FUNCTION
	# Change this path to where you saved your multiplayer lobby scene
	get_tree().change_scene_to_file("res://scenes/MultiplayerLobby.tscn")

func _on_options_pressed():
	if not is_instance_valid(options_menu_instance):
		options_menu_instance = options_menu_scene.instantiate()
		add_child(options_menu_instance)

func _on_quit_pressed():
	get_tree().quit()
