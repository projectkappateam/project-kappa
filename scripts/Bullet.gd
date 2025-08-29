# scripts/Bullet.gd
extends Area3D

# This script now handles a purely cosmetic tracer effect.
# It has no physics or collision logic of its own. Hit detection is handled
# instantly by the shooter's raycast.

# This function is called by the shooter (e.g., the player) to fire the tracer.
func fly_to(start_position: Vector3, target_position: Vector3):
	# Set the starting position and aim the bullet model at the target.
	global_position = start_position
	look_at(target_position)

	# We'll calculate the duration of the flight based on distance to simulate
	# a constant speed. This makes tracers look more realistic over all ranges.
	var distance = start_position.distance_to(target_position)
	var tracer_speed = 150.0 # A good, fast speed for a visual effect.
	var duration = distance / tracer_speed

	# Create a tween to handle the movement. A tween animates a property over time.
	var tween = create_tween()
	# Tell the tween to animate our 'global_position' property to the target position over the calculated duration.
	tween.tween_property(self, "global_position", target_position, duration)
	# Once the tween animation is finished, tell it to call the queue_free method, which destroys the bullet.
	tween.tween_callback(queue_free)
