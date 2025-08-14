# BuyMenu.gd
extends Control

signal gun_purchased(gun_data)
signal gun_sold(gun_data)

var player_ref # Player reference will be set by the player script

# Node references
@onready var pistol_grid = $"MarginContainer/VBoxContainer/TabContainer/Pistols/PistolGrid"
@onready var smg_grid = $"MarginContainer/VBoxContainer/TabContainer/SMGs/SMGGrid"
@onready var ar_grid = $"MarginContainer/VBoxContainer/TabContainer/Assault Rifles/ARGrid"
@onready var cash_label = $"MarginContainer/VBoxContainer/Header/HBoxContainer/CashLabel"

const GUN_CARD_SCENE = preload("res://scenes/GunCard.tscn")

func _ready():
	if not is_instance_valid(player_ref):
		print("ERROR: BuyMenu requires a player reference!")
		queue_free()
		return

	refresh_display()
	player_ref.cash_updated.connect(func(new_cash): cash_label.text = "Cash: $%d" % new_cash)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if is_instance_valid(player_ref):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player_ref.buy_menu_instance = null


func refresh_display():
	# Clear existing cards to prevent duplicates
	for child in pistol_grid.get_children():
		child.queue_free()
	for child in smg_grid.get_children():
		child.queue_free()
	for child in ar_grid.get_children():
		child.queue_free()

	populate_guns()
	cash_label.text = "Cash: $%d" % player_ref.cash


func populate_guns():
	# Define where to find gun resources and which grid to put them in
	var gun_folders = {
		"Pistol": "res://resources/guns/pistols",
		"SMG": "res://resources/guns/smgs",
		"Assault Rifle": "res://resources/guns/ars"
	}

	var grids = {
		"Pistol": pistol_grid,
		"SMG": smg_grid,
		"Assault Rifle": ar_grid
	}

	# Loop through each category to find and display guns
	for category in gun_folders:
		var path = gun_folders[category]
		var grid = grids[category]
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var gun_data = load(path.path_join(file_name))
					if gun_data:
						# Create a visual card for the gun
						var card = GUN_CARD_SCENE.instantiate()
						card.get_node("VBoxContainer/GunNameLabel").text = gun_data.gun_name
						card.get_node("VBoxContainer/CostLabel").text = "$%d" % gun_data.cost

						var button = card.get_node("VBoxContainer/BuyButton")

						var is_owned = gun_data in player_ref.gun_inventory
						var has_empty_slot = null in player_ref.gun_inventory

						if is_owned:
							button.text = "Sell"
							button.pressed.connect(func(): _on_gun_sell_pressed(gun_data))

							# Prevent selling the last gun
							var owned_gun_count = player_ref.gun_inventory.filter(func(g): return g != null).size()
							if owned_gun_count <= 1:
								button.disabled = true
						else:
							button.text = "Buy"
							button.pressed.connect(func(): _on_gun_buy_pressed(gun_data))

							if player_ref.cash < gun_data.cost or not has_empty_slot:
								button.disabled = true

						grid.add_child(card)
				file_name = dir.get_next()


func _on_gun_buy_pressed(gun_data: GunData):
	# Tell the player which gun was purchased
	gun_purchased.emit(gun_data)


func _on_gun_sell_pressed(gun_data: GunData):
	gun_sold.emit(gun_data)


func close_menu():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
