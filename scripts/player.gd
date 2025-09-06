# scripts/player.gd
extends CharacterBody3D

# --- Signals ---
signal ammo_updated(current_ammo, reserve_ammo)
signal cash_updated(new_cash_amount)
signal health_updated(new_health)
signal armor_updated(new_armor)
signal player_died

# --- Constants ---
const PRIMARY_SLOT = 0
const SECONDARY_SLOT = 1
const ADS_DURATION = 0.1

# --- Player Stats ---
var health: float = 150.0
var armor: int = 0
const MAX_HEALTH: float = 150.0
const STAND_SPEED = 5.0
const CROUCH_SPEED = 2.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const STAND_CAMERA_POS_Y = 0.0
const CROUCH_CAMERA_POS_Y = -0.4
const CROUCH_LERP_SPEED = 10.0
const BUY_PHASE_DURATION = 10.0

# --- Head Bob ---
const BOB_FREQUENCY = 0.0
const BOB_AMPLITUDE = 0.00
var bob_time = 0.0

# --- Physics ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Exported Properties ---
var buy_menu_scene: PackedScene
var hud_scene: PackedScene
var bullet_scene: PackedScene
var death_screen_scene: PackedScene

# --- OnReady Node References ---
@onready var collision_shape = $CollisionShape3D
@onready var head_check_raycast = $RayCast3D
@onready var reload_timer = $ReloadTimer
@onready var buy_phase_timer = $BuyPhaseTimer
@onready var camera = $HeadAttachment/Camera3D
@onready var shooting_raycast = $HeadAttachment/Camera3D/ShootingRaycast
@onready var gun_mount = $GunAttachment/GunMount
@onready var head_attachment = $HeadAttachment
@onready var gun_attachment = $GunAttachment
@onready var model = $Model
@onready var ads_camera_position = $GunAttachment/GunMount/ADSCameraPosition
@onready var multiplayer_synchronizer = $MultiplayerSynchronizer

# --- State Variables ---
var is_crouching = false
var hud: CanvasLayer
var initial_camera_transform: Transform3D
var ads_tween: Tween
var is_dead: bool = false

# --- Decoupled Aim Variables ---
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0

# --- Gun Mechanics State ---
var gun_inventory: Array[GunData] = [null, null]
var gun_nodes: Array[Node3D] = [null, null]
var active_gun_index: int = SECONDARY_SLOT
var fire_cooldown = 0.0
var current_mag_ammo: int = 0
var current_reserve_ammo: int = 0
var is_reloading: bool = false

# --- Economy and Buy Phase ---
var cash: int = 9000
var is_buy_phase: bool = true
var buy_menu_instance: Control = null

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
	await get_tree().process_frame
	set_multiplayer_authority(str(name).to_int())

	if not is_multiplayer_authority():
			camera.enabled = false
			if hud:
				hud.queue_free() # Remove the UI for remote players
			return

	var skeleton = model.find_child("Skeleton3D", true, false)
	if skeleton:
		head_attachment.skeleton = skeleton.get_path()
		head_attachment.bone_name = "Head"
		gun_attachment.skeleton = skeleton.get_path()
		gun_attachment.bone_name = "hand.R"
	else:
		printerr("Player model's Skeleton3D not found!")

	reload_timer.timeout.connect(_on_reload_finished)
	_target_yaw = self.rotation.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
		self.ammo_updated.connect(hud.update_ammo_display)
		self.cash_updated.connect(hud.update_cash_display)
		self.health_updated.connect(hud.update_health_display)
		self.armor_updated.connect(hud.update_armor_display)

	buy_phase_timer.wait_time = BUY_PHASE_DURATION
	buy_phase_timer.timeout.connect(_on_buy_phase_ended)
	buy_phase_timer.start()

	initial_camera_transform = camera.transform

	var free_pistol_data = load("res://resources/guns/pistols/Carbon-2.tres")
	_equip_gun(free_pistol_data, SECONDARY_SLOT, true)
	cash = 9000
	cash_updated.emit(cash)
	health_updated.emit(health)
	armor_updated.emit(armor)


func _unhandled_input(event):
	if not multiplayer_synchronizer.is_multiplayer_authority():
		return # Do not process input if this is not our character

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_target_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_target_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_target_pitch = clamp(_target_pitch, deg_to_rad(-90.0), deg_to_rad(90.0))

	if Input.is_action_just_pressed("crouch"):
		set_crouch_state(not is_crouching)

	if Input.is_action_just_pressed("reload"):
		reload()

	if Input.is_action_just_pressed("aim"):
		_toggle_ads(true)
	if Input.is_action_just_released("aim"):
		_toggle_ads(false)

	if Input.is_action_just_pressed("open_buy_menu") and is_buy_phase:
		toggle_buy_menu()

	if Input.is_action_just_pressed("switch_primary"):
		switch_gun(PRIMARY_SLOT)
	if Input.is_action_just_pressed("switch_secondary"):
		switch_gun(SECONDARY_SLOT)

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var next_slot = 1 - active_gun_index
			switch_gun(next_slot)


func _physics_process(delta):
	if not multiplayer_synchronizer.is_multiplayer_authority():
		return
	if is_buy_phase and is_instance_valid(hud):
		hud.update_buy_prompt(buy_phase_timer.time_left)

	self.rotation.y = _target_yaw
	camera.rotation.x = _target_pitch

	var crouch_delta = delta * CROUCH_LERP_SPEED
	var target_cam_y = STAND_CAMERA_POS_Y if not is_crouching else CROUCH_CAMERA_POS_Y

	var is_moving = is_on_floor() and velocity.length() > 0.1
	if is_moving:
		bob_time += delta * velocity.length() * BOB_FREQUENCY
		var bob_offset = sin(bob_time) * BOB_AMPLITUDE
		target_cam_y += bob_offset
	head_attachment.position.y = lerp(head_attachment.position.y, target_cam_y, crouch_delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	if fire_cooldown > 0:
		fire_cooldown -= delta

	var current_gun_data = gun_inventory[active_gun_index]
	if current_gun_data:
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


func _toggle_ads(is_aiming: bool):
	if ads_tween and ads_tween.is_running():
		ads_tween.kill()

	ads_tween = create_tween()
	ads_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	var target_transform: Transform3D
	if is_aiming and not is_reloading:
		target_transform = head_attachment.global_transform.affine_inverse() * ads_camera_position.global_transform
	else:
		target_transform = initial_camera_transform

	ads_tween.tween_property(camera, "transform", target_transform, ADS_DURATION)


func toggle_buy_menu():
	if buy_menu_instance:
		buy_menu_instance.queue_free()
	else:
		if buy_menu_scene:
			buy_menu_instance = buy_menu_scene.instantiate()
			buy_menu_instance.player_ref = self
			buy_menu_instance.gun_purchased.connect(_on_gun_purchased)
			buy_menu_instance.gun_sold.connect(_on_gun_sold)
			buy_menu_instance.shield_purchased.connect(_on_shield_purchased)
			add_child(buy_menu_instance)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_buy_phase_ended():
	is_buy_phase = false
	if is_instance_valid(hud):
		hud.hide_buy_prompt()
	if is_instance_valid(buy_menu_instance):
		buy_menu_instance.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_gun_purchased(gun_data: GunData):
	var target_slot = PRIMARY_SLOT if gun_data.category != "Pistol" else SECONDARY_SLOT
	var current_gun_in_slot = gun_inventory[target_slot]

	var refund = 0
	if is_instance_valid(current_gun_in_slot):
		refund = current_gun_in_slot.cost

	if cash + refund < gun_data.cost: return

	cash += refund
	cash -= gun_data.cost
	cash_updated.emit(cash)

	_equip_gun(gun_data, target_slot, true)

	if is_instance_valid(buy_menu_instance):
		buy_menu_instance.refresh_display()


func _on_gun_sold(gun_data: GunData):
	var slot_to_sell = gun_inventory.find(gun_data)
	if slot_to_sell == -1: return

	cash += gun_data.cost
	cash_updated.emit(cash)

	gun_inventory[slot_to_sell] = null
	if is_instance_valid(gun_nodes[slot_to_sell]):
		gun_nodes[slot_to_sell].queue_free()
		gun_nodes[slot_to_sell] = null

	if active_gun_index == slot_to_sell:
		var other_slot = 1 - slot_to_sell
		switch_gun(other_slot)

	if is_instance_valid(buy_menu_instance):
		buy_menu_instance.refresh_display()

func _on_shield_purchased(shield_data):
	if cash >= shield_data.cost and armor < shield_data.armor_amount:
		cash -= shield_data.cost
		armor = shield_data.armor_amount
		cash_updated.emit(cash)
		armor_updated.emit(armor)

		if is_instance_valid(buy_menu_instance):
			buy_menu_instance.refresh_display()

func _equip_gun(gun_data: GunData, slot: int, set_active: bool = true):
	if is_instance_valid(gun_nodes[slot]):
		gun_nodes[slot].queue_free()

	gun_inventory[slot] = gun_data
	var gun_scene_path = gun_scene_map.get(gun_data.gun_name)
	if gun_scene_path:
		var gun_scene = load(gun_scene_path)
		if gun_scene:
			var new_gun_node = gun_scene.instantiate()
			gun_nodes[slot] = new_gun_node
			gun_mount.add_child(new_gun_node)

			if set_active:
				switch_gun(slot)
			else:
				new_gun_node.hide()


func switch_gun(new_index: int):
	if new_index == active_gun_index or not is_instance_valid(gun_inventory[new_index]):
		return

	_toggle_ads(false)

	if is_instance_valid(gun_nodes[active_gun_index]):
		gun_nodes[active_gun_index].hide()

	active_gun_index = new_index
	if is_instance_valid(gun_nodes[active_gun_index]):
		gun_nodes[active_gun_index].show()

	_update_active_gun_stats(gun_inventory[active_gun_index])

func _update_active_gun_stats(gun_data: GunData):
	if not is_instance_valid(gun_data):
		ammo_updated.emit(0, 0)
		return
	current_mag_ammo = gun_data.mag_size
	current_reserve_ammo = gun_data.total_ammo
	is_reloading = false
	fire_cooldown = 0
	ammo_updated.emit(current_mag_ammo, current_reserve_ammo)


func shoot():
	if is_reloading: return
	var current_gun_data = gun_inventory[active_gun_index]
	if not current_gun_data: return

	if current_mag_ammo <= 0:
		reload()
		return

	shoot_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func shoot_rpc():
	if is_reloading: return
	var current_gun_data = gun_inventory[active_gun_index]
	if not current_gun_data: return

	# On the authority's machine, perform the actual logic
	if multiplayer_synchronizer.is_multiplayer_authority():
		if current_mag_ammo <= 0:
			# This check prevents a race condition where you might
			# fire an extra bullet while reloading over the network.
			return

		current_mag_ammo -= 1
		ammo_updated.emit(current_mag_ammo, current_reserve_ammo)
		fire_cooldown = 1.0 / current_gun_data.fire_rate

		_target_pitch += current_gun_data.recoil_climb
		_target_pitch = clamp(_target_pitch, deg_to_rad(-90.0), deg_to_rad(90.0))

		shooting_raycast.force_raycast_update()
		if shooting_raycast.is_colliding():
			var collider = shooting_raycast.get_collider()
			if collider.has_method("take_damage"):
				# IMPORTANT: Damage should be requested from the server for security
				# For now, we'll let the client do it for simplicity.
				collider.take_damage(current_gun_data.damage)

	# Visuals (like the bullet tracer) should run on all machines.
	if not bullet_scene: return
	var current_gun_node = gun_nodes[active_gun_index]
	if not is_instance_valid(current_gun_node): return
	var spawn_point = current_gun_node.find_child("BulletSpawnPoint", true, false)
	if not is_instance_valid(spawn_point): return

	var bullet_instance = bullet_scene.instantiate()
	get_tree().root.add_child(bullet_instance)

	var start_pos = spawn_point.global_position
	var target_pos
	if shooting_raycast.is_colliding():
		target_pos = shooting_raycast.get_collision_point()
	else:
		target_pos = shooting_raycast.to_global(shooting_raycast.target_position)

	bullet_instance.fly_to(start_pos, target_pos)


func reload():
	var current_gun_data = gun_inventory[active_gun_index]
	if not current_gun_data or is_reloading or current_reserve_ammo <= 0 or current_mag_ammo == current_gun_data.mag_size:
		return
	is_reloading = true
	_toggle_ads(false)
	reload_timer.wait_time = current_gun_data.reload_time
	reload_timer.start()

func _on_reload_finished():
	is_reloading = false
	var current_gun_data = gun_inventory[active_gun_index]
	if not current_gun_data: return

	var ammo_needed = current_gun_data.mag_size - current_mag_ammo
	var ammo_to_move = min(ammo_needed, current_reserve_ammo)
	current_mag_ammo += ammo_to_move
	current_reserve_ammo -= ammo_to_move
	ammo_updated.emit(current_mag_ammo, current_reserve_ammo)

func set_crouch_state(new_state: bool):
	if new_state == false and head_check_raycast.is_colliding():
		return
	is_crouching = new_state

func take_damage(damage_amount: float):
	if is_dead: return

	var damage_to_health = damage_amount
	var damage_to_armor = 0.0

	if armor > 0:
		var absorbed_damage = damage_amount * 0.33
		damage_to_health = damage_amount - absorbed_damage
		damage_to_armor = absorbed_damage

		if damage_to_armor > armor:
			var overflow = damage_to_armor - armor
			damage_to_health += overflow
			damage_to_armor = float(armor)

		armor -= int(damage_to_armor)

	health -= damage_to_health

	health_updated.emit(health)
	armor_updated.emit(armor)

	if health <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true
	player_died.emit()

	set_physics_process(false)
	set_process_unhandled_input(false)

	if death_screen_scene:
		var death_screen = death_screen_scene.instantiate()
		add_child(death_screen)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(hud):
		hud.hide()
