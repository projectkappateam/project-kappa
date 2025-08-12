# HUD.gd
extends Control

# Get references to our new labels
@onready var current_ammo_label = $PanelContainer/HBoxContainer/CurrentAmmoLabel
@onready var reserve_ammo_label = $PanelContainer/HBoxContainer/ReserveAmmoLabel

# This function will be called by the player to update the UI
func update_ammo_display(current_ammo: int, reserve_ammo: int):
	current_ammo_label.text = str(current_ammo)
	reserve_ammo_label.text = " / " + str(reserve_ammo)
