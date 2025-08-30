# multiplayer_world.gd
extends Node3D

# Preload the player scene that you want to spawn.
var player_scene = preload("res://scenes/player.tscn")

func _ready():
	# This function is called when the node enters the scene tree.
	# We connect the 'peer_connected' signal to our spawning function for clients.
	multiplayer.peer_connected.connect(_on_player_connected)

	# Check if the current instance is the server (the host).
	if multiplayer.is_server():
		# Spawn a player for the host. The peer ID for the server is always 1.
		spawn_player(1)

# This function will spawn a player instance.
func spawn_player(peer_id):
	# Create a new instance of the player scene.
	var player = player_scene.instantiate()
	
	# Set the name of the node to the player's unique peer ID.
	# This is crucial for the MultiplayerSpawner and for identifying players.
	player.name = str(peer_id)
	
	# Add the newly created player as a child of the PlayersContainer node.
	# This will trigger the MultiplayerSpawner to replicate the player to all clients.
	$PlayersContainer.add_child(player)

# This function is called automatically when a new client connects.
func _on_player_connected(peer_id):
	# Spawn a player for the newly connected client.
	spawn_player(peer_id)
