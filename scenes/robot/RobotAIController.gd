@tool
extends AIController3D
class_name RobotAIController

@onready var robot: Robot = get_parent()
@onready var sensors: Array[Node] = $"../Sensors".get_children()
@onready var level_manager = robot.level_manager

var goal_threshold = 1.0  # Adjust based on your environment's scale

var closest_goal_position = 0
var last_num_coins = 0
var closest_goal_distance := INF
var _last_goal_distance := -1.00
var goal_reached = false

func _process(delta):
	
	# goal position
	var goal_pos = robot.current_goal_transform.origin
	DebugDraw3D.draw_sphere(goal_pos, 0.5, Color.GREEN)
	DebugDraw3D.draw_line(robot.global_position, goal_pos, Color.GREEN)
	DebugDraw2D.set_text("GoalDistance", "Goal Distance: %.2f" % robot.global_position.distance_to(goal_pos))
	
	# path to nearest coin
	var closest_coin = level_manager.get_closest_active_coin(robot.global_position, robot.current_level)
	if closest_coin:
		var coin_distance = robot.global_position.distance_to(closest_coin.global_position)
		DebugDraw3D.draw_sphere(closest_coin.global_position, 0.3, Color.GOLD)
		DebugDraw3D.draw_line(robot.global_position, closest_coin.global_position, Color.GOLD)
		DebugDraw2D.set_text("CoinDistance", "Closest Coin: %.2f" % coin_distance)
	else:
		DebugDraw2D.set_text("CoinDistance", "No coins")
		
	# closest enemy
	var closest_enemy = level_manager.get_closest_enemy(robot.global_position)
	var closest_enemy_position: Vector3 = Vector3.ZERO
	if closest_enemy:
		closest_enemy_position = robot.to_local(closest_enemy.global_position)
		if closest_enemy_position.length() < 20.0:
			DebugDraw3D.draw_sphere(closest_enemy.global_position, 0.4, Color.RED)
			DebugDraw3D.draw_line(robot.global_position, closest_enemy.global_position, Color.RED)
	
	# Draw velocity vector
	var velocity = robot.velocity * 0.5  # Scale down for visualization
	var velocity_end = robot.global_position + velocity
	DebugDraw3D.draw_arrow(robot.global_position, velocity_end, Color.BLUE, 0.2)
	DebugDraw2D.set_text("Velocity", "Speed: %.2f" % robot.velocity.length())
		
	# Draw sensor rays (Comment this fun if you don't want to see white rays) 
	#_draw_sensor_rays()
	
func _draw_sensor_rays():
	for sensor in sensors:
		if sensor is RayCastSensor3D:
			# Draw the debug lines from the sensor's immediate mesh if available
			if sensor.geo:
				sensor.display()
			# Draw individual raycasts with collision points
			for ray in sensor.get_children():
				if ray is RayCast3D:
					var start = ray.global_position
					var end = start + ray.target_position
					var color = Color.WHITE
					
					if ray.is_colliding():
						color = Color.RED
						# Draw collision point
						DebugDraw3D.draw_sphere(ray.get_collision_point(), 0.1, Color.PURPLE)
						# Draw normal at collision point
						DebugDraw3D.draw_line(ray.get_collision_point(),
							ray.get_collision_point() + ray.get_collision_normal(),
							Color.MAGENTA
						)
						
					DebugDraw3D.draw_line(start, end, color)
					

func reset():
	super.reset()
	closest_goal_distance = INF
	_last_goal_distance = -1.00
	#closest_goal_position = xz_distance(robot.global_position, robot.current_goal_transform.origin)
	last_num_coins = level_manager.get_num_active_coins(robot.current_level)
	#print("Reset closest_goal_position to: ", closest_goal_position)
	print("___Reset____")
	
	
func _physics_process(_delta):
	n_steps += 1
	if n_steps > reset_after:
		needs_reset = true
		done = true
		# Per-episode penalty for taking too long
		# This should NOT be included in per-step reward, handled at episode end

func get_obs() -> Dictionary:
	var velocity: Vector3 = robot.get_real_velocity().limit_length(20.0) / 20.0

	var current_goal_position1: Vector3 = robot.current_goal_transform.origin
	var local_goal_position = robot.to_local(current_goal_position1).limit_length(40.0) / 40.0

	var closest_coin = level_manager.get_closest_active_coin(robot.global_position, robot.current_level)
	var closest_coin_position: Vector3 = Vector3.ZERO

	if closest_coin:
		closest_coin_position = robot.to_local(closest_coin.global_position)
		if closest_coin_position.length() > 30.0:
			closest_coin_position = Vector3.ZERO

	var closest_enemy: Enemy = level_manager.get_closest_enemy(robot.global_position)
	var closest_enemy_position: Vector3 = Vector3.ZERO
	var closest_enemy_direction: float = 0.0

	if closest_enemy:
		closest_enemy_position = robot.to_local(closest_enemy.global_position)
		closest_enemy_direction = float(closest_enemy.movement_direction)
		if closest_enemy_position.length() > 30.0:
			closest_enemy_position = Vector3.ZERO
			closest_enemy_direction = 0.0

	var observations: Array[float] = [
		float(n_steps) / reset_after,
		local_goal_position.x,
		local_goal_position.y,
		local_goal_position.z,
		closest_coin_position.x,
		closest_coin_position.y,
		closest_coin_position.z,
		closest_enemy_position.x,
		closest_enemy_position.y,
		closest_enemy_position.z,
		closest_enemy_direction,
		velocity.x,
		velocity.y,
		velocity.z,
		float(level_manager.check_all_coins_collected(robot.current_level))
	]
	observations.append_array(get_raycast_sensor_obs())

	return {"obs": observations}

func xz_distance(vector1: Vector3, vector2: Vector3):
	var vec1_xz := Vector2(vector1.x, vector1.z)
	var vec2_xz := Vector2(vector2.x, vector2.z)
	return vec1_xz.distance_to(vec2_xz)
	
func get_nearest_coin_position() -> Vector3:
	var robot_pos = robot.global_position
	var nearest_coin = null
	var nearest_dist = INF
	for coin in level_manager.coins_in_level[robot.current_level]:
		if not coin.visible:
			continue
		var dist = xz_distance(robot_pos, coin.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_coin = coin
	if nearest_coin:
		return nearest_coin.global_position
	else:
		return robot_pos
		
var last_distance_to_goal = null
var last_distance_to_nearest_coin = null

func get_reward() -> float:
	var current_goal_position = xz_distance(robot.global_position, robot.current_goal_transform.origin)
	var velocity: Vector3 = robot.get_real_velocity()
	var reward = 0.0
	
		# --- 1. Coin Collection ---
	var num_coins = level_manager.get_num_active_coins(robot.current_level)
	if num_coins < last_num_coins:
		reward += 2.0
		#log_str += str(last_num_coins - num_coins) + ("Coin collected! Reward :+2.0) \n"
		var total_coins = level_manager.initial_coin_count_per_level[robot.current_level]
		print("Coin ", (total_coins - num_coins), "/", total_coins, " collected")
	last_num_coins = num_coins
	
		# --- 2. Progress toward nearest coin ---
	if num_coins > 0:
		var nearest_coin_pos = get_nearest_coin_position()
		var dist_to_coin = xz_distance(robot.global_position, nearest_coin_pos)
		if last_distance_to_nearest_coin != null:
			var progress = last_distance_to_nearest_coin - dist_to_coin
			reward += progress * 0.2
			if progress > 0:
				print("Progress toward nearest coin: +", progress * 0.2)
			else:
				print("Penalty for moving away from nearest coin: ", progress * 0.2)
		last_distance_to_nearest_coin = dist_to_coin
	else:
		last_distance_to_nearest_coin = null
	
		# --- 3. Progress toward goal (only after all coins) ---
	if num_coins == 0:
		var goal_dist = xz_distance(robot.global_position, robot.current_goal_transform.origin)
		#print("DIST TO GOAL: ", goal_dist)
		if last_distance_to_goal != null:
			var progress = last_distance_to_goal - goal_dist
			reward += progress * 0.5
			if progress > 0:
				print("Progress toward goal: +", progress * 0.5)
			else:
				print("Penalty for moving away from goal: ", progress * 0.5)
		last_distance_to_goal = goal_dist
		
		if goal_dist < goal_threshold and not goal_reached:
			reward += 5.0
			print("Goal Reached: Reward +4" )
			goal_reached = true
			robot.end_episode(4.0)  # or your level reset logic
	else:
		last_distance_to_goal = null
		
		# --- 4. Standing Still Penalty ---
	var vel = robot.get_real_velocity().length()
	#if vel < 0.05:
	#	reward -= 0.01
	#	print("Moving slow in game: Penalty -0.01")
		
		# --- 5. Extra Idle Penalty near goal to prevent stalling ---
	if vel < 0.05 and num_coins == 0 and not goal_reached:
		reward -= 0.05
		print("Stalled near goal: Penalty -0.03")
		
	return reward

func get_action_space() -> Dictionary:
	return {
		"movement" : {
			"size": 2,
			"action_type": "continuous"
		}
	}

func set_action(action) -> void:	
	robot.requested_movement = Vector3(
		clampf(action.movement[0], -1.0, 1.0), 
		0.0, 
		clampf(action.movement[1], -1.0, 1.0)).limit_length(1.0)

func get_raycast_sensor_obs():
	var all_raycast_sensor_obs: Array[float] = []
	for raycast_sensor in sensors:
		all_raycast_sensor_obs.append_array(raycast_sensor.get_observation())
	return all_raycast_sensor_obs
