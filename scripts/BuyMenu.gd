# BuyMenu.gd
extends Control

# This signal now emits the GunData resource directly
signal gun_purchased(gun_data)

@export var buy_time: float = 20.0

# Node references
@onready var timer = $Timer
# --- FIX: Node paths with spaces must be quoted. Quoting all for safety. ---
@onready var timer_label = $"MarginContainer/VBoxContainer/Header/HBoxContainer/TimerLabel"
@onready var pistol_grid = $"MarginContainer/VBoxContainer/TabContainer/Pistols/PistolGrid"
@onready var smg_grid = $"MarginContainer/VBoxContainer/TabContainer/SMGs/SMGGrid"
@onready var ar_grid = $"MarginContainer/VBoxContainer/TabContainer/Assault Rifles/ARGrid"

const GUN_CARD_SCENE = preload("res://scenes/GunCard.tscn")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	timer.wait_time = buy_time
	timer.timeout.connect(close_menu)
	timer.start()

	populate_guns()

func _process(_delta):
	# Update the label with the time remaining
	timer_label.text = "Time Remaining: %.1f" % timer.time_left

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

						# Connect the button on the card to the purchase function
						var button = card.get_node("VBoxContainer/BuyButton")
						button.pressed.connect(func(): _on_gun_buy_pressed(gun_data))

						grid.add_child(card)
				file_name = dir.get_next()

func _on_gun_buy_pressed(gun_data: GunData):
	# Tell the player which gun was purchased
	gun_purchased.emit(gun_data)
	close_menu()

func close_menu():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()
