extends Node3D

# These will appear in the Inspector for the "The World" node.
@export var hud_scene: PackedScene
@export var buy_menu_scene: PackedScene
@export var bullet_scene: PackedScene
@export var death_screen_scene: PackedScene

@onready var multiplayer_spawner = $MultiplayerSpawner
@onready var spawn_point_1 = $SpawnPoint1
@onready var spawn_point_2 = $SpawnPoint2
var spawn_index = 0

func _ready():
	if not multiplayer.is_server():
		return

	# Spawn players who are already connected when the level loads
	for id in NetworkManager.get_player_list():
		_spawn_player(id)

	# Connect signal to spawn players who join later
	NetworkManager.player_connected.connect(_spawn_player)

func _spawn_player(id):
	var player_instance = load("res://scenes/player.tscn").instantiate()
	player_instance.name = str(id)

	player_instance.hud_scene = hud_scene
	player_instance.buy_menu_scene = buy_menu_scene
	player_instance.bullet_scene = bullet_scene
	player_instance.death_screen_scene = death_screen_scene

	add_child(player_instance)

	# Alternate between spawn points
	if spawn_index == 0:
		player_instance.global_position = spawn_point_1.global_position
		spawn_index = 1
	else:
		player_instance.global_position = spawn_point_2.global_position
		spawn_index = 0
