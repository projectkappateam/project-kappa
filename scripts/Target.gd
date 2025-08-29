# scripts/Target.gd
extends CharacterBody3D

# --- Stats ---
var health: float = 150.0
const MAX_HEALTH: float = 150.0
const SPEED: float = 1.5
@export var can_shoot: bool = true

# --- Movement ---
@export var move_range: float = 10.0 # How far it moves from its start point
var start_position: Vector3
var target_position: Vector3
var direction: float = 1.0

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- OnReady Node References ---
@onready var gun_mount = $GunAttachment/GunMount
@onready var gun_attachment = $GunAttachment
@onready var model = $Model
@onready var shoot_timer = $ShootTimer

# --- Gun Mechanics ---
var gun_node: Node3D = null
var gun_data: GunData = null
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
const GUN_SCENE_PATH = "res://scenes/guns/ars/Crusader.tscn" # Hardcoded assault rifle

# --- Targetting ---
var player_node: Node3D = null


func _ready():
	# Configure the skeleton attachments, similar to the player
	await get_tree().process_frame
	var skeleton = model.find_child("Skeleton3D", true, false)
	if skeleton:
		gun_attachment.skeleton = skeleton.get_path()
		gun_attachment.bone_name = "hand.R"
	else:
		printerr("Target model's Skeleton3D not found!")

	# Set up movement
	start_position = global_position
	target_position = start_position + (global_transform.basis.x * move_range)

	# Try to find the player immediately on load.
	# If not found, _physics_process will handle finding it later.
	player_node = get_tree().get_root().find_child("Player", true, false)

	# Equip gun and connect shoot timer
	_equip_gun()

	if can_shoot:
		shoot_timer.timeout.connect(shoot)

func _physics_process(delta):
	# --- ADDED FOR ROBUSTNESS ---
	# If the player wasn't found at startup, keep looking for it on each frame.
	# This prevents the AI from being broken if the Target node loads before the Player.
	if not is_instance_valid(player_node):
		player_node = get_tree().get_root().find_child("Player", true, false)
		# If we still can't find the player, do nothing else this frame.
		if not is_instance_valid(player_node):
			return
	# --- END OF CHANGE ---

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Movement
	var move_direction_vec = global_position.direction_to(target_position)
	velocity.x = move_direction_vec.x * SPEED
	velocity.z = move_direction_vec.z * SPEED

	if global_position.distance_to(target_position) < 0.5:
		# Switch direction
		direction *= -1
		target_position = start_position + (global_transform.basis.x * move_range * direction)

	# --- MODIFIED ROTATION LOGIC ---
	# This section is changed to keep the enemy upright.
	var player_head_pos = player_node.global_position + Vector3(0, 1.7, 0)

	# Create a copy of the player's position but at the same height as the enemy.
	var look_at_position_horizontal = player_head_pos
	look_at_position_horizontal.y = global_position.y

	# Now, look at that flattened position. This makes the enemy turn left/right
	# but prevents it from tipping over backwards or forwards.
	look_at(look_at_position_horizontal, Vector3.UP)
	# --- END OF MODIFICATION ---

	move_and_slide()

func _equip_gun():
	var gun_scene = load(GUN_SCENE_PATH)
	if gun_scene:
		gun_node = gun_scene.instantiate()
		gun_data = gun_node.gun_data
		gun_mount.add_child(gun_node)

func shoot():
	if not is_instance_valid(gun_node) or not is_instance_valid(player_node):
		return

	# --- ADDED FOR DEBUGGING ---
	# This message will confirm in the output log that the timer is working and this function is being called.
	print("Target '%s' is shooting!" % self.name)
	# --- END OF DEBUGGING CODE ---

	if not bullet_scene: return
	var spawn_point = gun_node.find_child("BulletSpawnPoint", true, false)
	if not spawn_point: return

	var bullet_instance = bullet_scene.instantiate()
	bullet_instance.damage = gun_data.damage
	get_tree().root.add_child(bullet_instance)

	# Make the bullet's transform aim towards the player
	var bullet_start_pos = spawn_point.global_position
	var player_target_pos = player_node.global_position + Vector3(0, 1.5, 0) # Aim for center mass
	var bullet_direction = bullet_start_pos.direction_to(player_target_pos)

	# Use looking_at to create a rotation basis that aims at the player's center mass.
	# This allows the bullets to aim up/down even if the enemy's body stays upright.
	var bullet_rotation_basis = Basis().looking_at(bullet_direction, Vector3.UP)
	bullet_instance.global_transform = Transform3D(bullet_rotation_basis, bullet_start_pos)


func take_damage(damage_amount: float):
	print("HIT: Target '%s' took %.1f damage." % [self.name, damage_amount])
	health -= damage_amount
	print("HEALTH: Target '%s' has %.1f HP remaining." % [self.name, health])
	if health <= 0:
		die()

func die():
	print("DEATH: Target '%s' has been eliminated." % self.name)
	queue_free()
