extends Node3D

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

	# Alternate between spawn points
	if spawn_index == 0:
		player_instance.global_position = spawn_point_1.global_position
		spawn_index = 1
	else:
		player_instance.global_position = spawn_point_2.global_position
		spawn_index = 0

	add_child(player_instance)
