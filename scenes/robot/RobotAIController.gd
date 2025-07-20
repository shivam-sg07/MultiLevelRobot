extends AIController3D
class_name RobotAIController

@onready var robot: Robot = get_parent()
@onready var sensors: Array[Node] = $"../Sensors".get_children()
@onready var level_manager = robot.level_manager

var goal_threshold = 1.0  # Adjust based on your environment's scale

var closest_goal_position
var last_num_coins = 0

func reset():
	super.reset()
	closest_goal_position = xz_distance(robot.global_position, robot.current_goal_transform.origin)
	last_num_coins = level_manager.get_num_active_coins(robot.current_level)

func _physics_process(_delta):
	n_steps += 1
	if n_steps > reset_after:
		needs_reset = true
		done = true
		# Per-episode penalty for taking too long
		# This should NOT be included in per-step reward, handled at episode end

func get_obs() -> Dictionary:
	var velocity: Vector3 = robot.get_real_velocity().limit_length(20.0) / 20.0

	var current_goal_position: Vector3 = robot.current_goal_transform.origin
	var local_goal_position = robot.to_local(current_goal_position).limit_length(40.0) / 40.0

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

#func get_reward() -> float:
	#var current_goal_position = xz_distance(robot.global_position, robot.current_goal_transform.origin)
	#var velocity: Vector3 = robot.get_real_velocity()
	#var reward_delta = 0.0
#
	#if not closest_goal_position:
		#closest_goal_position = current_goal_position
#
	## --- 1. Reward for collecting coins ---
	#var current_num_coins = level_manager.get_num_active_coins(robot.current_level)
	#if current_num_coins < last_num_coins:
		#reward_delta += 1.0  # Big reward for each coin collected (adjust if too large/small)
		#last_num_coins = current_num_coins
#
	## --- 2. Reward for getting closer to the goal, only if all coins collected ---
	#if level_manager.check_all_coins_collected(robot.current_level):
		#if current_goal_position < closest_goal_position:
			#reward_delta += (closest_goal_position - current_goal_position) / 10.0
			#closest_goal_position = current_goal_position
#
		## --- 3. Big reward for reaching the goal (only if all coins collected) ---
		#if current_goal_position < goal_threshold:
			#reward_delta += 2.0
#
	## --- 4. Penalty for standing still ---
	#reward_delta -= (1.0 - clamp(velocity.length() / 2.0, 0.0, 1.0)) * 0.01
#
	## --- 5. Penalty for not making progress for N steps ---
	#if n_steps % 50 == 0 and current_goal_position >= closest_goal_position:
		#reward_delta -= 0.1
	#
	#return reward_delta

	
var last_distance_to_goal = null
var last_distance_to_nearest_coin = null

func get_reward() -> float:
	var reward = 0.0
	var log_str = "\nREWARD DEBUG:\n"
	
	# --- 0. Set up last_num_coins for first step ---
	if last_num_coins == null:
		last_num_coins = level_manager.get_num_active_coins(robot.current_level)
	
	# --- 1. Coin Collection ---
	var num_coins = level_manager.get_num_active_coins(robot.current_level)
	if num_coins < last_num_coins:
		reward += 2.0
		log_str += "Coin collected! +2.0\n"
	last_num_coins = num_coins

	# --- 2. Progress toward nearest coin ---
	if num_coins > 0:
		var nearest_coin_pos = get_nearest_coin_position()
		var dist_to_coin = xz_distance(robot.global_position, nearest_coin_pos)
		if last_distance_to_nearest_coin != null:
			var progress = last_distance_to_nearest_coin - dist_to_coin
			if progress > 0:
				reward += progress * 0.2
				log_str += "Progress toward nearest coin: +" + str(progress * 0.2) + "\n"
			else:
				# This helps debug dithering/going backward
				reward += progress * 0.2
				log_str += "Moved away from nearest coin: " + str(progress * 0.2) + "\n"
		last_distance_to_nearest_coin = dist_to_coin
	else:
		last_distance_to_nearest_coin = null

	# --- 3. Progress toward goal (only after all coins) ---
	if num_coins == 0:
		var goal_dist = xz_distance(robot.global_position, robot.current_goal_transform.origin)
		if last_distance_to_goal != null:
			var progress = last_distance_to_goal - goal_dist
			if progress > 0:
				reward += progress * 0.3
				log_str += "Progress toward goal: +" + str(progress * 0.3) + "\n"
			else:
				reward += progress * 0.3
				log_str += "Moved away from goal: " + str(progress * 0.3) + "\n"
		last_distance_to_goal = goal_dist

		if goal_dist < goal_threshold:
			reward += 4.0
			log_str += "GOAL REACHED! +4.0\n"
	else:
		last_distance_to_goal = null

	# --- 4. Standing Still Penalty ---
	var vel = robot.get_real_velocity().length()
	if vel < 0.05:
		reward -= 0.01
		log_str += "Penalized for standing still: -0.01\n"

	# --- 5. Small Step Penalty ---
	reward -= 0.001
	log_str += "Default step penalty: -0.001\n"

	# --- Final reward logging ---
	log_str += "TOTAL STEP REWARD: " + str(reward) + "\n"
	print(log_str)
	
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
