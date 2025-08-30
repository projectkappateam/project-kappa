# scripts/NetworkManager.gd
extends Node

var peer = ENetMultiplayerPeer.new()
var players = {} # peer_id: player_info

func host_game(port=7777):
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	print("Server created. Waiting for players.")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Add host player
	players[1] = { "name": "Host" }

func join_game(ip_address, port=7777):
	peer.create_client(ip_address, port)
	multiplayer.multiplayer_peer = peer
	print("Joining game at %s:%s" % [ip_address, port])

func _on_peer_connected(id):
	print("Player connected: " + str(id))
	players[id] = { "name": "Player_" + str(id) }

func _on_peer_disconnected(id):
	print("Player disconnected: " + str(id))
	players.erase(id)
	if get_tree().get_root().has_node("MultiplayerWorld"):
		var player_node = get_tree().get_root().get_node("MultiplayerWorld/PlayersContainer").get_node_or_null(str(id))
		if player_node:
			player_node.queue_free()

func get_player_list():
	return players

func start_game():
	get_tree().change_scene_to_file("res://scenes/multiplayer_world.tscn")
