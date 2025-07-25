#extends Node3D
extends Enemy
class_name PatrolEnemy

#@export var speed: float = 5.0
@export var point_a: float # X position (e.g. -10)
@export var point_b: float # X position (e.g. 10)
@export var patrol_pause: float = 0.0

#var movement_direction := 1
var _target_x: float = 0.0
var _pause_timer := 0.0
#var wheels: Array[Node3D] = []

func _ready():
	wheels.append(find_child("Wheels*"))
	global_position.x = point_a
	_target_x = point_b
	movement_direction = 1

func _physics_process(delta):
	if _pause_timer > 0.0:
		_pause_timer -= delta
		return

	# Move only on X axis
	var step = speed * delta * movement_direction
	global_position.x += step

	# Wheels animation (optional)
	for wheel in wheels:
		if wheel:
			wheel.rotate_object_local(Vector3.LEFT, speed * delta)

	# Check if we've reached the target
	if (movement_direction == 1 and global_position.x >= _target_x) or (movement_direction == -1 and global_position.x <= _target_x):
		global_position.x = _target_x
		movement_direction *= -1
		print("rotate now")
		rotate_y(PI)
		# Swap destination
		_target_x = point_b if movement_direction == 1 else point_a
				   # Facing -X
		# Optional pause
		if patrol_pause > 0.0:
			_pause_timer = patrol_pause
			
	#print("pos: ", global_position, " dir: ", movement_direction, " speed: ", speed)
