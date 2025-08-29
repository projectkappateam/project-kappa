# BuyMenu.gd
extends Control

signal gun_purchased(gun_data)
signal gun_sold(gun_data)
signal shield_purchased(shield_data)

var player_ref # Player reference will be set by the player script

# Node references
@onready var pistol_grid = $"MarginContainer/VBoxContainer/TabContainer/Pistols/PistolGrid"
@onready var smg_grid = $"MarginContainer/VBoxContainer/TabContainer/SMGs/SMGGrid"
@onready var ar_grid = $"MarginContainer/VBoxContainer/TabContainer/Assault Rifles/ARGrid"
@onready var shield_grid = $"MarginContainer/VBoxContainer/TabContainer/Shields/ShieldGrid"
@onready var cash_label = $"MarginContainer/VBoxContainer/Header/HBoxContainer/CashLabel"

const GUN_CARD_SCENE = preload("res://scenes/GunCard.tscn")
const SHIELD_CARD_SCENE = preload("res://scenes/GunCard.tscn")

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
	for child in pistol_grid.get_children(): child.queue_free()
	for child in smg_grid.get_children(): child.queue_free()
	for child in ar_grid.get_children(): child.queue_free()
	for child in shield_grid.get_children(): child.queue_free()

	populate_menu()
	cash_label.text = "Cash: $%d" % player_ref.cash

func populate_menu():
	# Populate Guns (existing logic)
	populate_guns() # Keep the gun population logic in its own function
	# Populate Shields
	populate_shields()

func populate_guns():
	# Define where to find the grid for each category
	var grids = {
		"Pistol": pistol_grid,
		"SMG": smg_grid,
		"Assault Rifle": ar_grid
	}

	# Statically load all gun data resources. This ensures they are included in the export.
	var all_gun_data = [
		# Pistols
		load("res://resources/guns/pistols/Brat-10.tres"),
		load("res://resources/guns/pistols/Carbon-2.tres"),
		load("res://resources/guns/pistols/Duster-6X.tres"),
		load("res://resources/guns/pistols/Shiv.tres"),
		# SMGs
		load("res://resources/guns/smgs/Buzzsaw-40.tres"),
		load("res://resources/guns/smgs/Hornet-25.tres"),
		# Assault Rifles
		load("res://resources/guns/ars/Blackout.tres"),
		load("res://resources/guns/ars/Crusader.tres"),
		load("res://resources/guns/ars/Cyclone.tres"),
		load("res://resources/guns/ars/Ravager-67.tres")
	]

	# Loop through the preloaded gun data to populate the menu
	for gun_data in all_gun_data:
		# Ensure the resource loaded correctly and has a valid category
		if gun_data and gun_data.category in grids:
			var grid = grids[gun_data.category]

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

func populate_shields():
	var all_shield_data = [
		load("res://resources/shields/light_shield.tres"),
		load("res://resources/shields/heavy_shield.tres"),
	]

	for shield_data in all_shield_data:
		if shield_data:
			var card = SHIELD_CARD_SCENE.instantiate()
			card.get_node("VBoxContainer/GunNameLabel").text = shield_data.shield_name
			card.get_node("VBoxContainer/CostLabel").text = "$%d" % shield_data.cost

			var button = card.get_node("VBoxContainer/BuyButton")
			button.text = "Buy"

			if player_ref.cash < shield_data.cost or player_ref.armor >= shield_data.armor_amount:
				button.disabled = true

			button.pressed.connect(func(): _on_shield_buy_pressed(shield_data))

			shield_grid.add_child(card)

func _on_gun_buy_pressed(gun_data: GunData):
	# Tell the player which gun was purchased
	gun_purchased.emit(gun_data)


func _on_gun_sell_pressed(gun_data: GunData):
	gun_sold.emit(gun_data)

func _on_shield_buy_pressed(shield_data: ShieldData): # ADD THIS ENTIRE FUNCTION
	shield_purchased.emit(shield_data)


func close_menu():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
