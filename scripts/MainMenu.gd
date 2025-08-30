# scripts/MainMenu.gd
extends Control

# Preload the options menu so we can instance it.
var options_menu_scene = preload("res://scenes/OptionsMenu.tscn")
var options_menu_instance = null

@onready var practice_button = $MarginContainer/VBoxContainer/MenuButtons/PracticeButton
@onready var multiplayer_button = $MarginContainer/VBoxContainer/MenuButtons/MultiplayerButton
@onready var options_button = $MarginContainer/VBoxContainer/MenuButtons/OptionsButton
@onready var quit_button = $MarginContainer/VBoxContainer/MenuButtons/QuitButton

func _ready():
	# Connect the button signals to our functions.
	practice_button.pressed.connect(_on_practice_pressed)
	multiplayer_button.disabled = false # Enable the button
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_practice_pressed():
	# This function will load the main game world.
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://scenes/MultiplayerMenu.tscn")

func _on_options_pressed():
	# Create and show the options menu if it doesn't already exist.
	if not is_instance_valid(options_menu_instance):
		options_menu_instance = options_menu_scene.instantiate()
		add_child(options_menu_instance)

func _on_quit_pressed():
	# This function closes the game.
	get_tree().quit()
