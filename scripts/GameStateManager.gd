# scripts/GameStateManager.gd
extends Node

signal round_restarted

var player_scores = {} # peer_id: { kills: 0, deaths: 0 }
var spawn_points = []
var current_spawn_index = 0

const ROUND_END_WAIT_TIME = 15.0

func _ready():
	# This manager is only active in the multiplayer world
	if not get_tree().get_root().has_node("MultiplayerWorld"):
		set_process(false)

func register_player(peer_id):
	if not player_scores.has(peer_id):
		player_scores[peer_id] = { "kills": 0, "deaths": 0 }

func get_spawn_point():
	if spawn_points.is_empty():
		# Find spawn points in the scene tree
		var spawn_point_nodes = get_tree().get_nodes_in_group("spawn_points")
		for sp in spawn_point_nodes:
			spawn_points.append(sp.global_transform)

	if spawn_points.is_empty():
		return Transform3D() # Return default transform if no spawn points found

	var spawn_transform = spawn_points[current_spawn_index]
	current_spawn_index = (current_spawn_index + 1) % spawn_points.size()
	return spawn_transform

@rpc("call_local", "any_peer", "reliable")
func record_kill(killer_id, victim_id):
	if player_scores.has(killer_id):
		player_scores[killer_id].kills += 1
	if player_scores.has(victim_id):
		player_scores[victim_id].deaths += 1

	check_round_over()

func check_round_over():
	#var alive_players = 0 # Commented out as it's not used yet
	#var players_in_game = multiplayer.get_peers().size() + 1 # Commented out as it's not used yet

	# Simple check: if only one player is left with 0 deaths, or some other condition
	# For a simple deathmatch, we'll just restart on a timer after a death for now.
	# A more robust solution would track teams or alive players.

	# For now, we'll trigger the scoreboard on every death and have it be temporary.
	# This is a simplification for this example.
	#get_tree().call_group("ui_layer", "show_scoreboard", player_scores) # We don't have this UI yet, so we'll disable this for now.

	#var timer = get_tree().create_timer(5.0, true)
	#await timer.timeout
	#get_tree().call_group("ui_layer", "hide_scoreboard")
	pass # The function will just do nothing for now.


func restart_round():
	# In a real game, you'd reset scores or load a new map. Here we just respawn everyone.
	print("Restarting Round...")
	player_scores.clear()
	for peer_id in get_tree().get_multiplayer().get_peers():
		register_player(peer_id)
	register_player(1) # Register host

	round_restarted.emit()


@rpc("call_local", "any_peer", "reliable")
func broadcast_scoreboard(scores):
	# Logic to display scoreboard on all clients
	var scoreboard = find_child("Scoreboard", true, false) # You'd instance a scene here
	if scoreboard:
		scoreboard.update_scores(scores)
		scoreboard.show()

		var timer = get_tree().create_timer(ROUND_END_WAIT_TIME)
		await timer.timeout
		restart_round()
