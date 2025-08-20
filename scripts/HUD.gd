# scripts/HUD.gd
extends CanvasLayer

# Get references to our new labels
@onready var current_ammo_label = $PanelContainer/HBoxContainer/CurrentAmmoLabel
@onready var reserve_ammo_label = $PanelContainer/HBoxContainer/ReserveAmmoLabel
@onready var health_label = $PanelContainer/HBoxContainer/HealthLabel # NEW
@onready var buy_prompt_label = $BuyPromptLabel

# This function will be called by the player to update the UI
func update_ammo_display(current_ammo: int, reserve_ammo: int):
	current_ammo_label.text = str(current_ammo)
	reserve_ammo_label.text = " / " + str(reserve_ammo)

func update_health_display(new_health: float):
	health_label.text = "HP: " + str(new_health)

func update_cash_display(_cash_amount: int):
	# This function is ready for when a cash label is added to the main HUD
	pass

func update_buy_prompt(time_left: float):
	buy_prompt_label.text = "Open buy menu (B) -- %.1f secs" % time_left
	buy_prompt_label.show()

func hide_buy_prompt():
	buy_prompt_label.hide()
