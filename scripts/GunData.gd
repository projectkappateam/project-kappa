# GunData.gd
class_name GunData
extends Resource

@export var gun_name: String = "Gun"
@export_enum("Pistol", "SMG", "Assault Rifle") var category: String = "Pistol"
@export var cost: int = 0
@export var damage: float = 10.0
@export var fire_rate: float = 5.0 # Shots per second
@export var weight: float = 1.0

@export var mag_size: int = 30
@export var total_ammo: int = 90
@export var reload_time: float = 1.5 # in seconds

@export var recoil_climb: float = 0.01
