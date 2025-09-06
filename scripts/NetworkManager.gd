extends Node

signal player_connected(id)
signal player_disconnected(id)
signal game_started
signal game_ended

const PORT = 7777 # The default port for our server
var peer

# A dictionary to store player information, like name, score, etc.
# The key will be the player's unique network ID.
var players = {}

func _ready():
	# Connect signals for when players join or leave
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

func create_server():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		print("Cannot create server. Error: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Server created successfully. Waiting for players.")
	# Add the host player to the players list
	players[1] = {"name": "Host"}
	player_connected.emit(1)


func join_server(ip_address: String):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, PORT)
	if error != OK:
		print("Cannot connect to server. Error: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Joining server at ", ip_address)


func _on_player_connected(id):
	print("Player connected: ", id)
	# For now, we'll just add them. In the future, you could ask for a name.
	players[id] = {"name": "Player " + str(id)}
	player_connected.emit(id)

func _on_player_disconnected(id):
	print("Player disconnected: ", id)
	if players.has(id):
		players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Successfully connected to the server!")
	# The server will handle telling us what to do next.

func _on_connection_failed():
	print("Failed to connect to the server.")
	multiplayer.multiplayer_peer = null # Reset the peer

func get_player_list():
	return players

func start_game():
	# This RPC call tells all connected players (including the server) to start the game.
	rpc("load_game_world")

@rpc("any_peer", "call_local")
func load_game_world():
	var scene = "res://scenes/multiplayer_world.tscn"
	get_tree().change_scene_to_file(scene)
