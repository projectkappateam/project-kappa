# scripts/Bullet.gd
extends Area3D

var speed = 75.0
var damage = 10.0 # This will be overwritten by the gun that fires it

@onready var timer = $Timer

func _ready():
	# Connect signals for lifetime and hit detection
	timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	timer.start()

func _physics_process(delta):
	# Move the bullet forward based on its own local Z-axis.
	# The firing entity will set this node's rotation when it's fired.
	position += -transform.basis.z * speed * delta

func _on_body_entered(body):
	# --- ADDED FOR DEBUGGING ---
	# This line prints the name of the physics body the bullet collided with.
	# We expect to see "Player" or "Target" here. If we don't, there might be a collision layer issue.
	print("Bullet hit: ", body.name)
	# --- END OF DEBUGGING CODE ---

	# Check if the body we hit can take damage
	if body.has_method("take_damage"):
		body.take_damage(damage)

	# Destroy the bullet on impact with any non-bullet physics body
	if not body is Area3D:
		queue_free()
