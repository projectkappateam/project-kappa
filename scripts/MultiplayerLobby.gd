extends Control

# CORRECTED: Use the full paths to the nodes within the scene structure
@onready var host_button = $CenterContainer/VBoxContainer/HostButton
@onready var join_button = $CenterContainer/VBoxContainer/JoinButton
@onready var back_button = $CenterContainer/VBoxContainer/BackButton
@onready var ip_address_edit = $CenterContainer/VBoxContainer/IPAddressEdit

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	# This connection is actually not needed right now because the NetworkManager's
	# start_game() function directly calls an RPC to change the scene for all players.
	# It's good practice to have only one place controlling scene changes to avoid confusion.
	# We can leave it commented out or remove it.
	# NetworkManager.game_started.connect(func(): get_tree().change_scene_to_file("res://scenes/multiplayer_world.tscn"))


func _on_host_button_pressed():
	NetworkManager.create_server()
	# The host calls start_game(), which then tells all clients (including itself) to load the world.
	NetworkManager.start_game()


func _on_join_button_pressed():
	var ip = ip_address_edit.text
	# Allow joining localhost if the IP field is empty
	if ip.is_empty():
		NetworkManager.join_server("127.0.0.1")
	elif ip.is_valid_ip_address():
		NetworkManager.join_server(ip)
	else:
		print("Invalid IP address entered.")


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
