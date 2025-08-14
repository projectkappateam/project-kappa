# player.gd
extends CharacterBody3D

# --- Signals ---
signal ammo_updated(current_ammo, reserve_ammo)

# --- Player Stats ---
const STAND_SPEED = 5.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const STAND_CAMERA_POS_Y = 1.9
const CROUCH_CAMERA_POS_Y = 1.1
const STAND_COLLIDER_HEIGHT = 2.0
const CROUCH_COLLIDER_HEIGHT = 1.2
const CROUCH_LERP_SPEED = 10.0

# --- Head Bob ---
const BOB_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08
var bob_time = 0.0

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Exported Properties ---
@export var buy_menu_scene: PackedScene
@export var hud_scene: PackedScene
@export var bullet_scene: PackedScene

# --- OnReady Node References ---
@onready var camera = $Camera3D
@onready var collision_shape = $CollisionShape3D
@onready var mesh = $MeshInstance3D
@onready var head_check_raycast = $RayCast3D
@onready var gun_mount = $Camera3D/GunMount
@onready var reload_timer = $ReloadTimer

# --- State Variables ---
var is_crouching = false

# --- Decoupled Aim Variables ---
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

# --- Gun Mechanics State ---
var current_gun_data: GunData = null
var current_gun_node: Node3D = null
var fire_cooldown = 0.0
var current_mag_ammo: int = 0
var current_reserve_ammo: int = 0
var is_reloading: bool = false

var gun_scene_map = {
	# Pistols
	"Brat-10": "res://scenes/guns/pistols/Brat-10.tscn",
	"Carbon-2": "res://scenes/guns/pistols/Carbon-2.tscn",
	"Duster-6X": "res://scenes/guns/pistols/Duster-6X.tscn",
	"Shiv": "res://scenes/guns/pistols/Shiv.tscn",

	# SMGs
	"Buzzsaw-40": "res://scenes/guns/smgs/Buzzsaw-40.tscn",
	"Hornet-25": "res://scenes/guns/smgs/Hornet-25.tscn",
	"Whisper": "res://scenes/guns/smgs/Whisper.tscn",

	# Assault Rifles
	"Blackout": "res://scenes/guns/ars/Blackout.tscn",
	"Crusader": "res://scenes/guns/ars/Crusader.tscn",
	"Cyclone": "res://scenes/guns/ars/Cyclone.tscn",
	"Ravager-67": "res://scenes/guns/ars/Ravager-67.tscn"
}


func _ready():
	camera.position.y = STAND_CAMERA_POS_Y
	reload_timer.timeout.connect(_on_reload_finished)
	_target_yaw = self.rotation.y

	if buy_menu_scene:
		var menu = buy_menu_scene.instantiate()
		menu.gun_purchased.connect(_on_gun_purchased)
		add_child(menu)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if hud_scene:
		var hud = hud_scene.instantiate()
		add_child(hud)
		self.ammo_updated.connect(hud.update_ammo_display)


func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_target_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_target_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_target_pitch = clamp(_target_pitch, deg_to_rad(-90.0), deg_to_rad(90.0))

	if Input.is_action_just_pressed("crouch"):
		set_crouch_state(not is_crouching)

	if Input.is_action_just_pressed("reload"):
		reload()


func _physics_process(delta):
	self.rotation.y = _target_yaw
	camera.rotation.x = _target_pitch

	var crouch_delta = delta * CROUCH_LERP_SPEED
	var target_cam_y = STAND_CAMERA_POS_Y if not is_crouching else CROUCH_CAMERA_POS_Y
	var target_collider_h = STAND_COLLIDER_HEIGHT if not is_crouching else CROUCH_COLLIDER_HEIGHT
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_collider_h, crouch_delta)
	collision_shape.position.y = lerp(collision_shape.position.y, target_collider_h / 2.0, crouch_delta)
	mesh.mesh.height = lerp(mesh.mesh.height, target_collider_h, crouch_delta)
	mesh.position.y = lerp(mesh.position.y, target_collider_h / 2.0, crouch_delta)
	var is_moving = is_on_floor() and velocity.length() > 0.1
	if is_moving:
		bob_time += delta * velocity.length() * BOB_FREQUENCY
		var bob_offset = sin(bob_time) * BOB_AMPLITUDE
		target_cam_y += bob_offset
	camera.position.y = lerp(camera.position.y, target_cam_y, crouch_delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	# --- MODIFIED SHOOTING LOGIC ---
	if fire_cooldown > 0:
		fire_cooldown -= delta

	if current_gun_data:
		# Check which fire mode the current gun has
		match current_gun_data.fire_mode:
			"Automatic":
				if Input.is_action_pressed("shoot") and fire_cooldown <= 0:
					shoot()
			"Semi-Auto", "Bolt-Action":
				if Input.is_action_just_pressed("shoot") and fire_cooldown <= 0:
					shoot()

	var base_speed = STAND_SPEED if not is_crouching else CROUCH_SPEED
	if current_gun_data:
		base_speed = max(0.5, base_speed - current_gun_data.weight)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * base_speed
		velocity.z = direction.z * base_speed
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed)
		velocity.z = move_toward(velocity.z, 0, base_speed)
	move_and_slide()


func _on_gun_purchased(gun_data: GunData):
	if current_gun_node:
		current_gun_node.queue_free()

	# Look up the scene path from the dictionary using the gun's name
	var gun_scene_path = gun_scene_map.get(gun_data.gun_name)
	if gun_scene_path:
		var gun_scene = load(gun_scene_path)
		if gun_scene:
			# Create the gun's 3D instance
			current_gun_node = gun_scene.instantiate()
			current_gun_data = gun_data
			gun_mount.add_child(current_gun_node)

			# Set up ammo based on the purchased gun's data
			current_mag_ammo = current_gun_data.mag_size
			current_reserve_ammo = current_gun_data.total_ammo
			is_reloading = false # Ensure reloading state is reset
			fire_cooldown = 0 # Ensure fire cooldown is reset
			ammo_updated.emit(current_mag_ammo, current_reserve_ammo)
	else:
		print("ERROR: No scene path found in gun_scene_map for gun: ", gun_data.gun_name)


func shoot():
	if is_reloading: return
	if current_mag_ammo <= 0:
		reload() # Or play an empty click sound
		return

	current_mag_ammo -= 1
	ammo_updated.emit(current_mag_ammo, current_reserve_ammo)
	fire_cooldown = 1.0 / current_gun_data.fire_rate

	_target_pitch += current_gun_data.recoil_climb
	_target_pitch = clamp(_target_pitch, deg_to_rad(-90.0), deg_to_rad(90.0))

	if not bullet_scene: return
	var spawn_point = current_gun_node.find_child("BulletSpawnPoint")
	if not spawn_point: return

	var bullet_instance = bullet_scene.instantiate()
	bullet_instance.damage = current_gun_data.damage
	get_tree().root.add_child(bullet_instance)

	var new_transform = Transform3D(camera.global_transform.basis, spawn_point.global_position)
	bullet_instance.global_transform = new_transform


func reload():
	if not current_gun_data or is_reloading or current_reserve_ammo <= 0 or current_mag_ammo == current_gun_data.mag_size:
		return
	is_reloading = true
	reload_timer.wait_time = current_gun_data.reload_time
	reload_timer.start()
	print("Reloading...")


func _on_reload_finished():
	var ammo_needed = current_gun_data.mag_size - current_mag_ammo
	var ammo_to_move = min(ammo_needed, current_reserve_ammo)
	current_mag_ammo += ammo_to_move
	current_reserve_ammo -= ammo_to_move
	is_reloading = false
	ammo_updated.emit(current_mag_ammo, current_reserve_ammo)
	print("Reload finished.")


func set_crouch_state(new_state: bool):
	if new_state == false and head_check_raycast.is_colliding():
		return
	is_crouching = new_state
