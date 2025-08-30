# scripts/MultiplayerMenu.gd
extends Control

@onready var ip_address_edit = $VBoxContainer/IPAddressEdit
@onready var join_button = $VBoxContainer/JoinButton
@onready var host_button = $VBoxContainer/HostButton
@onready var back_button = $VBoxContainer/BackButton

func _ready():
	join_button.pressed.connect(_on_join_pressed)
	host_button.pressed.connect(_on_host_pressed)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))

func _on_join_pressed():
	var ip = ip_address_edit.text
	if ip.is_valid_ip_address():
		get_node("/root/NetworkManager").join_game(ip)
		# The transition to the game scene will be handled by the server
		# For now, we'll do it manually on the client as well.
		get_node("/root/NetworkManager").start_game()
	else:
		print("Invalid IP address")

func _on_host_pressed():
	get_node("/root/NetworkManager").host_game()
	get_node("/root/NetworkManager").start_game()
