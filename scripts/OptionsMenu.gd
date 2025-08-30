# scripts/OptionsMenu.gd
extends Control

@onready var window_mode_option = $Panel/MarginContainer/VBoxContainer/GridContainer/WindowModeOption
@onready var resolution_option = $Panel/MarginContainer/VBoxContainer/GridContainer/ResolutionOption
@onready var apply_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ApplyButton
@onready var back_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/BackButton

# Define available resolutions.
const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

func _ready():
	# Connect button signals.
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Populate the Window Mode dropdown.
	window_mode_option.add_item("Windowed", DisplayServer.WINDOW_MODE_WINDOWED)
	window_mode_option.add_item("Borderless Window", DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	window_mode_option.add_item("Fullscreen", DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Select the current window mode in the dropdown.
	window_mode_option.select(DisplayServer.window_get_mode())

	# Populate the Resolution dropdown.
	for res in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])

	# Find and select the current resolution in the dropdown.
	var current_res = DisplayServer.window_get_size()
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_res:
			resolution_option.select(i)
			break

func _on_apply_pressed():
	# Apply the selected window mode.
	var selected_mode = window_mode_option.get_selected_id()
	DisplayServer.window_set_mode(selected_mode)

	# Apply the selected resolution.
	var selected_res_index = resolution_option.get_selected_id()
	var new_res = RESOLUTIONS[selected_res_index]
	DisplayServer.window_set_size(new_res)

	# Center the window after changing the resolution.
	var screen_size = DisplayServer.screen_get_size()
	var window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_size / 2 - window_size / 2)


func _on_back_pressed():
	# Close the options menu.
	queue_free()
