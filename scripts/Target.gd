# scripts/Target.gd
extends CharacterBody3D

# --- Stats ---
var health: float = 150.0
const MAX_HEALTH: float = 150.0
const SPEED: float = 1.5
@export var can_shoot: bool = true

# --- Movement ---
@export var move_range: float = 10.0
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
const GUN_SCENE_PATH = "res://scenes/guns/ars/Crusader.tscn"

# --- Targetting ---
var player_node: Node3D = null


func _ready():
	await get_tree().process_frame
	var skeleton = model.find_child("Skeleton3D", true, false)
	if skeleton:
		gun_attachment.skeleton = skeleton.get_path()
		gun_attachment.bone_name = "hand.R"
	else:
		printerr("Target model's Skeleton3D not found!")

	start_position = global_position
	target_position = start_position + (global_transform.basis.x * move_range)

	player_node = get_tree().get_root().find_child("Player", true, false)

	_equip_gun()

	if can_shoot:
		shoot_timer.timeout.connect(shoot)

func _physics_process(delta):
	if not is_instance_valid(player_node):
		player_node = get_tree().get_root().find_child("Player", true, false)
		if not is_instance_valid(player_node):
			return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var move_direction_vec = global_position.direction_to(target_position)
	velocity.x = move_direction_vec.x * SPEED
	velocity.z = move_direction_vec.z * SPEED

	if global_position.distance_to(target_position) < 0.5:
		direction *= -1
		target_position = start_position + (global_transform.basis.x * move_range * direction)

	var player_head_pos = player_node.global_position + Vector3(0, 1.7, 0)
	var look_at_position_horizontal = player_head_pos
	look_at_position_horizontal.y = global_position.y
	look_at(look_at_position_horizontal, Vector3.UP)

	move_and_slide()

func _equip_gun():
	var gun_scene = load(GUN_SCENE_PATH)
	if gun_scene:
		gun_node = gun_scene.instantiate()
		gun_data = gun_node.gun_data
		gun_mount.add_child(gun_node)


# --- REWORKED SHOOT FUNCTION for ENEMY ---
# This function is updated to use the new tracer system and deal damage instantly.
func shoot():
	if not is_instance_valid(gun_node) or not is_instance_valid(player_node):
		return

	# Deal damage to the player instantly. This makes the enemy a "hitscan" attacker.
	# For a more advanced game, you might use a raycast here to check for cover.
	if player_node.has_method("take_damage"):
		player_node.take_damage(gun_data.damage)

	# Now, fire the cosmetic tracer using the new system.
	if not bullet_scene: return
	var spawn_point = gun_node.find_child("BulletSpawnPoint", true, false)
	if not is_instance_valid(spawn_point): return

	var bullet_instance = bullet_scene.instantiate()
	get_tree().root.add_child(bullet_instance)

	# Determine start and end points for the tracer.
	var start_pos = spawn_point.global_position
	var target_pos = player_node.global_position + Vector3(0, 1.5, 0) # Aim for center mass

	# Tell the bullet to fly between these two points.
	bullet_instance.fly_to(start_pos, target_pos)


func take_damage(damage_amount: float):
	health -= damage_amount
	if health <= 0:
		die()

func die():
	queue_free()
