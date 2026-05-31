# ==============================================================
#  Hunter AI — A* Pathfinding with Predictive Targeting
# ==============================================================
extends CharacterBody2D


# ──────────────────────────────────────────────────────────────
#  INNER CLASS: A* search node
# ──────────────────────────────────────────────────────────────
class AStarNode:
	var tile_pos : Vector2i
	var g        : float
	var h        : float
	var f        : float
	var parent

	func _init(pos: Vector2i, g_val: float, h_val: float, par = null) -> void:
		tile_pos = pos
		g        = g_val
		h        = h_val
		f        = g_val + h_val
		parent   = par


# ──────────────────────────────────────────────────────────────
#  INSPECTOR SETTINGS
# ──────────────────────────────────────────────────────────────

@export var move_speed              : float = 170.0
@export var lookahead_k             : float = 5.0
@export var repath_interval         : float = 0.50
@export var ema_alpha               : float = 0.35
@export var speed_boost_multiplier  : float = 1.40
@export var speed_boost_duration    : float = 2.00
@export var streak_boost_multiplier : float = 1.65
@export var streak_boost_duration   : float = 1.50
@export var panic_boost_multiplier  : float = 1.55
@export var panic_boost_duration    : float = 2.50
@export var stuck_repath_limit      : int   = 3

@export var player_node  : CharacterBody2D
@export var tilemap_node : TileMapLayer

@export var proximity_tile_threshold : int = 3


# ──────────────────────────────────────────────────────────────
#  PRIVATE STATE
# ──────────────────────────────────────────────────────────────
var _path             : Array[Vector2] = []
var _repath_timer     : float          = 0.0

const _MIN_REPATH_GAP       : float = 0.12
# FIX 2 — dedicated debounce for sharp-turn repaths; longer than the
# generic cooldown so player input jitter can't cascade.
const _SHARP_TURN_COOLDOWN  : float = 0.28
var _repath_cooldown        : float = 0.0
var _sharp_turn_timer       : float = 0.0   # FIX 2

var _is_active        : bool  = false

var _current_speed        : float = 0.0
var _speed_boost_timer    : float = 0.0
var _streak_boost_active  : bool  = false
var _panic_boost_timer    : float = 0.0
var _panic_boost_active   : bool  = false
var _prev_player_speed    : float = 0.0
const _SURGE_THRESHOLD    : float = 40.0

var _prev_player_pos     : Vector2 = Vector2.ZERO
var _smoothed_player_vel : Vector2 = Vector2.ZERO
var _time_since_repath   : float   = 0.0

var _prev_player_dir        : Vector2 = Vector2.ZERO
const _SHARP_TURN_THRESHOLD : float   = 0.30

var _prev_dist_to_player : float = INF
var _stuck_count         : int   = 0

# FIX 1 — raised from 6.0. Must be roughly tile_size / 2 so a body
# pressed against a wall can still pop the waypoint. Set dynamically
# in _ready() once the tilemap is known; this is the safe default.
var _waypoint_dist           : float = 14.0
# FIX 1 — safety valve: skip a waypoint after this many frames stuck on it.
const _WAYPOINT_STUCK_LIMIT  : int   = 14
var   _waypoint_stuck_frames : int   = 0

# FIX 4 — base budget; scaled up with tile distance in _recalculate_path().
const _MAX_ITERATIONS    : int = 800
# FIX 4 — beyond this tile distance, lookahead is tapered to avoid
# chasing a stale-EMA ghost far off the player's real position.
const _FAR_TILE_THRESHOLD: int = 20

var _chase_elapsed : float = 0.0


# ──────────────────────────────────────────────────────────────
#  LIFECYCLE
# ──────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("dog")
	_chase_elapsed = 0.0
	_current_speed = move_speed

	if not player_node:
		player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not tilemap_node:
		tilemap_node = get_tree().get_first_node_in_group("ground_layer") as TileMapLayer

	# FIX 1 — derive waypoint arrival distance from actual tile size so it
	# works regardless of tile_size set in the TileSet resource.
	if tilemap_node and tilemap_node.tile_set:
		_waypoint_dist = tilemap_node.tile_set.tile_size.x * 0.45

	if player_node:
		_prev_player_pos = player_node.global_position

	print("--- DOG DEBUG START ---")
	print("Player node found: ", player_node)
	print("Tilemap node found: ", tilemap_node)
	print("Waypoint dist set to: ", _waypoint_dist)
	print("--- DOG DEBUG END ---")


func _physics_process(delta: float) -> void:
	if not player_node:
		return

	if not _is_active:
		if player_node.velocity.length() > 1.0:
			_is_active = true
			_do_repath()
		return

	# ── Tick all timers ─────────────────────────────────────────
	_repath_timer      += delta
	_time_since_repath += delta
	_repath_cooldown    = max(0.0, _repath_cooldown   - delta)
	_speed_boost_timer  = max(0.0, _speed_boost_timer - delta)
	_panic_boost_timer  = max(0.0, _panic_boost_timer - delta)
	_sharp_turn_timer   = max(0.0, _sharp_turn_timer  - delta)   # FIX 2

	_chase_elapsed += delta

	# ── Speed: passive ramp is the floor; event boosts override upward ──
	var passive_mult : float = 1.0 + clamp(_chase_elapsed / 25.0, 0.0, 0.40)
	var active_mult  : float = passive_mult
	if _speed_boost_timer > 0.0:
		var surge_mult : float = streak_boost_multiplier if _streak_boost_active else speed_boost_multiplier
		active_mult = max(active_mult, surge_mult)
	if _panic_boost_timer > 0.0:
		active_mult = max(active_mult, panic_boost_multiplier)
	_current_speed = move_speed * active_mult

	if _speed_boost_timer <= 0.0:
		_streak_boost_active = false
	if _panic_boost_timer <= 0.0:
		_panic_boost_active  = false

	# ── Sharp-turn detection → emergency repath ─────────────────
	# FIX 2 — guard with _prev_player_dir.length() so the zero-initialised
	# vector on frame 1 never falsely triggers a repath, and use the
	# dedicated _sharp_turn_timer so rapid input jitter can't cascade.
	var current_dir : Vector2 = _get_player_dir()
	if _repath_cooldown <= 0.0 and _sharp_turn_timer <= 0.0 and current_dir.length() > 0.1:
		if _prev_player_dir.length() > 0.1 and _prev_player_dir.dot(current_dir) < _SHARP_TURN_THRESHOLD:
			_do_repath()
			_sharp_turn_timer = _SHARP_TURN_COOLDOWN
	_prev_player_dir = current_dir

	# ── Scheduled repath ────────────────────────────────────────
	if _repath_timer >= repath_interval:
		_do_repath()

	_follow_path()


# ──────────────────────────────────────────────────────────────
#  PUBLIC API
# ──────────────────────────────────────────────────────────────

func on_map_distortion() -> void:
	_trigger_speed_boost()
	if _repath_cooldown <= 0.0:
		_do_repath()


func on_player_sprint_streak(streak: int) -> void:
	var scaled_duration : float = streak_boost_duration * min(streak - 1, 4)
	if scaled_duration > _speed_boost_timer:
		_speed_boost_timer   = scaled_duration
		_streak_boost_active = true
	if _repath_cooldown <= 0.0:
		_do_repath()


func on_player_panic() -> void:
	_panic_boost_timer  = panic_boost_duration
	_panic_boost_active = true
	if _repath_cooldown <= 0.0:
		_do_repath()


# ──────────────────────────────────────────────────────────────
#  INTERNAL HELPERS
# ──────────────────────────────────────────────────────────────

func _trigger_speed_boost() -> void:
	_speed_boost_timer = speed_boost_duration


func _do_repath() -> void:
	_recalculate_path()
	_repath_timer      = 0.0
	_time_since_repath = 0.0
	_repath_cooldown   = _MIN_REPATH_GAP


func _get_player_dir() -> Vector2:
	if player_node.velocity.length() > 5.0:
		return player_node.velocity.normalized()
	var delta := player_node.global_position - _prev_player_pos
	return delta.normalized() if delta.length() > 0.5 else Vector2.ZERO


# ──────────────────────────────────────────────────────────────
#  PATH RECALCULATION
# ──────────────────────────────────────────────────────────────
func _recalculate_path() -> void:
	if not tilemap_node or not player_node:
		return

	# Step 1 | EMA velocity smoothing
	var elapsed : float   = max(_time_since_repath, 0.05)
	var raw_vel : Vector2 = (player_node.global_position - _prev_player_pos) / elapsed
	_smoothed_player_vel  = ema_alpha * raw_vel + (1.0 - ema_alpha) * _smoothed_player_vel
	_prev_player_pos      = player_node.global_position

	# Step 2 | Surge detection
	var cur_pspeed : float = player_node.velocity.length()
	if cur_pspeed - _prev_player_speed > _SURGE_THRESHOLD:
		_trigger_speed_boost()
	_prev_player_speed = cur_pspeed

	# Step 3 | Confidence-scaled lookahead
	var confidence : float = 0.0
	if raw_vel.length() > 1.0 and _smoothed_player_vel.length() > 1.0:
		confidence = (raw_vel.normalized().dot(_smoothed_player_vel.normalized()) + 1.0) * 0.5

	# Step 4 | Alongside / stuck guard
	var dist_now : float = global_position.distance_to(player_node.global_position)
	_stuck_count = (_stuck_count + 1) if dist_now >= _prev_dist_to_player else 0
	_prev_dist_to_player = dist_now

	var effective_k : float = lookahead_k * confidence if _stuck_count < stuck_repath_limit else 0.0

	# Step 5 | Tile positions
	var start_tile  : Vector2i = tilemap_node.local_to_map(tilemap_node.to_local(global_position))
	var player_tile : Vector2i = tilemap_node.local_to_map(tilemap_node.to_local(player_node.global_position))
	var tile_dist   : int = abs(start_tile.x - player_tile.x) + abs(start_tile.y - player_tile.y)

	# Step 6 | Proximity override
	if tile_dist <= proximity_tile_threshold:
		effective_k *= float(tile_dist) / float(proximity_tile_threshold)

	# FIX 4 — Far-range lookahead dampening.
	# When the player is far away the EMA velocity has more lag and any
	# prediction error is magnified, often producing a goal tile far off the
	# player's real path. Taper effective_k so the dog aims closer to the
	# player's actual tile instead of a wrong ghost position.
	if tile_dist > _FAR_TILE_THRESHOLD:
		effective_k *= float(_FAR_TILE_THRESHOLD) / float(tile_dist)

	# Step 7 | Predictive target
	var tile_size       : float   = float(tilemap_node.tile_set.tile_size.x)
	var time_lookahead  : float   = effective_k * tile_size / max(move_speed, 1.0)
	var predicted_world : Vector2 = player_node.global_position \
								  + _smoothed_player_vel * time_lookahead

	# Step 8 | World → tile + walkability snap
	var goal_tile : Vector2i = tilemap_node.local_to_map(tilemap_node.to_local(predicted_world))

	if not _is_walkable(goal_tile):
		goal_tile = _nearest_walkable(goal_tile)
	if goal_tile == start_tile:
		goal_tile = player_tile

	# FIX 4 — Scale the A* iteration budget with Manhattan tile distance so
	# long-range paths aren't truncated and returned as empty, which would
	# fall back to wall-hugging beelining. Cap at 2 500 to stay frame-safe.
	var iter_limit : int = min(max(_MAX_ITERATIONS, tile_dist * 12), 2500)

	# Step 9 | A* search
	var tile_path : Array = _run_astar(start_tile, goal_tile, iter_limit)

	if not tile_path.is_empty():
		_path.clear()
		for t in tile_path:
			_path.append(tilemap_node.to_global(tilemap_node.map_to_local(t)))


# ──────────────────────────────────────────────────────────────
#  PATH FOLLOWING
# ──────────────────────────────────────────────────────────────
func _follow_path() -> void:
	if _path.is_empty():
		if player_node:
			var dir : Vector2 = (player_node.global_position - global_position).normalized()
			velocity = dir * _current_speed
			move_and_slide()
			# FIX 3 — When beelining with no path and we collide, trigger an
			# immediate repath rather than sliding along the wall indefinitely.
			if get_slide_collision_count() > 0 and _repath_cooldown <= 0.0:
				_do_repath()
		return

	var target    : Vector2 = _path[0]
	var direction : Vector2 = (target - global_position).normalized()
	velocity = direction * _current_speed
	move_and_slide()

	# FIX 3 — Collision-deflection check: if move_and_slide() bent our heading
	# more than ~60° from the intended direction, the path is physically blocked.
	# Repath immediately instead of waiting for the 0.5 s scheduled cycle.
	if get_slide_collision_count() > 0 and _repath_cooldown <= 0.0:
		var post_dir : Vector2 = velocity.normalized()
		if post_dir.length() > 0.1 and post_dir.dot(direction) < 0.5:
			_do_repath()

	# ── Waypoint arrival ────────────────────────────────────────
	if global_position.distance_to(target) <= _waypoint_dist:
		_path.pop_front()
		_waypoint_stuck_frames = 0
	else:
		# FIX 1 — Stuck-on-waypoint safety valve.
		# If the dog has been trying to reach this same waypoint for too many
		# frames (e.g. pinned against a wall in a 1-tile corridor), skip it
		# and request a fresh path so A* can find a different approach.
		_waypoint_stuck_frames += 1
		if _waypoint_stuck_frames >= _WAYPOINT_STUCK_LIMIT:
			_waypoint_stuck_frames = 0
			_path.pop_front()
			if _repath_cooldown <= 0.0:
				_do_repath()


# ──────────────────────────────────────────────────────────────
#  A* ALGORITHM
# ──────────────────────────────────────────────────────────────
# FIX 4 — iter_limit is now passed in from _recalculate_path() so
# long-range searches get a proportionally larger budget.
func _run_astar(start: Vector2i, goal: Vector2i, iter_limit: int = _MAX_ITERATIONS) -> Array:
	var open_list  : Array      = []
	var closed_map : Dictionary = {}

	open_list.append(AStarNode.new(start, 0.0, _manhattan(start, goal)))

	var iterations : int = 0

	while not open_list.is_empty():
		iterations += 1
		if iterations > iter_limit:
			break

		var best_idx : int = 0
		for i in range(1, open_list.size()):
			if open_list[i].f < open_list[best_idx].f:
				best_idx = i

		var current : AStarNode = open_list[best_idx]
		open_list.remove_at(best_idx)

		if current.tile_pos == goal:
			return _reconstruct_path(current)

		closed_map[current.tile_pos] = current

		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nb_pos : Vector2i = current.tile_pos + d

			if closed_map.has(nb_pos):
				continue
			if not _is_walkable(nb_pos):
				continue

			var tentative_g   : float     = current.g + 1.0
			var found         : bool      = false
			var existing_node : AStarNode

			for node in open_list:
				if node.tile_pos == nb_pos:
					found         = true
					existing_node = node
					break

			if found:
				if tentative_g < existing_node.g:
					existing_node.g      = tentative_g
					existing_node.f      = tentative_g + existing_node.h
					existing_node.parent = current
			else:
				open_list.append(
					AStarNode.new(nb_pos, tentative_g, _manhattan(nb_pos, goal), current))

	return []


func _reconstruct_path(end_node: AStarNode) -> Array:
	var path : Array     = []
	var node : AStarNode = end_node
	while node != null:
		path.push_front(node.tile_pos)
		node = node.parent
	return path


func _manhattan(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


func _is_walkable(tile_pos: Vector2i) -> bool:
	if not tilemap_node:
		return true
	var tile_data = tilemap_node.get_cell_tile_data(tile_pos)
	if tile_data == null:
		return false
	return tile_data.get_custom_data("walkable")


func _nearest_walkable(origin: Vector2i) -> Vector2i:
	var queue   : Array      = [origin]
	var visited : Dictionary = {origin: true}
	var limit   : int        = 40

	while not queue.is_empty() and limit > 0:
		limit -= 1
		var cur : Vector2i = queue.pop_front()
		if _is_walkable(cur):
			return cur
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nb : Vector2i = cur + d
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	return origin


# ──────────────────────────────────────────────────────────────
#  DEBUG VISUALIZER
#  Comment out the entire block below when not debugging
# ──────────────────────────────────────────────────────────────
#func _process(_delta: float) -> void:
	#queue_redraw()
#
#func _draw() -> void:
	#if _path.size() > 1:
		#for i in range(_path.size() - 1):
			#var point_a = to_local(_path[i])
			#var point_b = to_local(_path[i + 1])
			#draw_line(point_a, point_b, Color.RED, 32.0)
			#draw_circle(point_b, 3.0, Color.YELLOW)
