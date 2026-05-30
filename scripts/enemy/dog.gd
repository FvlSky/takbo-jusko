# ==============================================================
#  Hunter AI - A* Pathfinding with Predictive Targeting
# ==============================================================
extends CharacterBody2D


# ──────────────────────────────────────────────────────────────
#  INNER CLASS: a single node in the A* search tree
# ──────────────────────────────────────────────────────────────
class AStarNode:
	var tile_pos : Vector2i   # position on the tile grid
	var g        : float      # actual cost from the start node
	var h        : float      # Manhattan heuristic cost to goal
	var f        : float      # total cost  (g + h)
	var parent                # AStarNode or null – used to trace the path back

	func _init(pos: Vector2i, g_val: float, h_val: float, par = null) -> void:
		tile_pos = pos
		g        = g_val
		h        = h_val
		f        = g_val + h_val
		parent   = par


# ──────────────────────────────────────────────────────────────
#  INSPECTOR-EXPOSED SETTINGS
#  Adjust these in the Godot Inspector – no code changes needed.
# ──────────────────────────────────────────────────────────────

## Movement speed of the dog in pixels per second.
@export var move_speed       : float = 160.0

## Predictive-targeting look-ahead coefficient (k).
## Formula: Target = Player_pos + (Player_direction × k × tile_size)
## Higher = dog tries to cut off the player further ahead.
@export var lookahead_k      : float = 5.0

## How often (in seconds) the dog recalculates its path.
## Lower = more responsive but more CPU work.
@export var repath_interval  : float = 0.50

## Direct node references – drag and drop in the Inspector
## after you instance this scene into your Main scene.
@export var player_node  : CharacterBody2D
@export var tilemap_node : TileMapLayer

# ──────────────────────────────────────────────────────────────
#  PRIVATE STATE  (do not edit here – change exports instead)
# ──────────────────────────────────────────────────────────────
var _path           : Array[Vector2] = []    # current world-space waypoints
var _repath_timer   : float          = 0.0
var _is_active      : bool           = false  # dog waits until player moves
var _prev_player_pos: Vector2        = Vector2.ZERO
var _player_vel_est : Vector2        = Vector2.ZERO

## Pixels – the dog moves to the next waypoint when it gets this close.
const _WAYPOINT_DIST  : float = 6.0
## Safety cap on A* iterations to prevent freezes on unsolvable maps.
const _MAX_ITERATIONS : int   = 800


# ──────────────────────────────────────────────────────────────
#  LIFECYCLE
# ──────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("dog")

	# Fallback: find nodes by group if they weren't set in the Inspector.
	if not player_node:
		player_node = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not tilemap_node:
		tilemap_node = get_tree().get_first_node_in_group("ground_layer") as TileMapLayer

	if player_node:
		_prev_player_pos = player_node.global_position

	# ─── QUICK DEBUG TEST ─────────────────────────────
	print("--- DOG DEBUG START ---")
	print("Player node found: ", player_node)
	print("Tilemap node found: ", tilemap_node)
	print("--- DOG DEBUG END ---")


func _physics_process(delta: float) -> void:
	if not player_node:
		return

	# ── Activation gate: dog stays still until the player first moves ──
	if not _is_active:
		if player_node.velocity.length() > 1.0:
			_is_active = true
			_recalculate_path()   # compute first path immediately on activation
		return

	# ── Periodic path recalculation ────────────────────────────────────
	_repath_timer += delta
	if _repath_timer >= repath_interval:
		_repath_timer = 0.0
		_recalculate_path()

	# ── Move along the current path ─────────────────────────────────────
	_follow_path()


# ──────────────────────────────────────────────────────────────
#  PATH RECALCULATION
# ──────────────────────────────────────────────────────────────
func _recalculate_path() -> void:
	if not tilemap_node or not player_node:
		return

	# Estimate player velocity from positional delta
	_player_vel_est  = (player_node.global_position - _prev_player_pos) / repath_interval
	_prev_player_pos = player_node.global_position

	# ── Predictive targeting ──────────────────────────────────────────
	# Target = Player_pos + (Player_direction × k × tile_size)
	# The dog aims ahead of the player rather than directly at them,
	# creating an interception behaviour that punishes predictable movement.
	var tile_size       : float   = float(tilemap_node.tile_set.tile_size.x)
	var predicted_world : Vector2 = player_node.global_position \
								  + _player_vel_est.normalized() * lookahead_k * tile_size

	# ── World → tile coordinates ──────────────────────────────────────
	var start_tile : Vector2i = tilemap_node.local_to_map(
									tilemap_node.to_local(global_position))
	var goal_tile  : Vector2i = tilemap_node.local_to_map(
									tilemap_node.to_local(predicted_world))

	# Snap goal to the nearest walkable tile if it landed on a wall
	if not _is_walkable(goal_tile):
		goal_tile = _nearest_walkable(goal_tile)

	# ── Run A* ────────────────────────────────────────────────────────
	var tile_path : Array = _run_astar(start_tile, goal_tile)

	# ── Convert tile positions → world positions ──────────────────────
	_path.clear()
	for t in tile_path:
		_path.append(tilemap_node.to_global(tilemap_node.map_to_local(t)))


# ──────────────────────────────────────────────────────────────
#  PATH FOLLOWING
# ──────────────────────────────────────────────────────────────
func _follow_path() -> void:
	if _path.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target    : Vector2 = _path[0]
	var direction : Vector2 = (target - global_position).normalized()

	velocity = direction * move_speed
	move_and_slide()

	# Pop the waypoint once the dog is close enough
	if global_position.distance_to(target) <= _WAYPOINT_DIST:
		_path.pop_front()


# ──────────────────────────────────────────────────────────────
#  A* ALGORITHM  —  Manual Implementation
#  (no Godot built-ins such as AStar2D are used here)
#
#  f(n)  = g(n) + h(n)
#  g(n)  = movement cost from start to node n (uniform = 1.0 per tile)
#  h(n)  = Manhattan Distance heuristic to goal
#        = |x_current − x_goal| + |y_current − y_goal|
#
#  Diagonal movement is explicitly excluded (4-directional only).
# ──────────────────────────────────────────────────────────────
func _run_astar(start: Vector2i, goal: Vector2i) -> Array:
	var open_list  : Array      = []   # candidate nodes to explore
	var closed_map : Dictionary = {}   # tile_pos (Vector2i) → AStarNode

	# Seed the open list with the starting node
	open_list.append(AStarNode.new(start, 0.0, _manhattan(start, goal)))

	var iterations : int = 0

	while not open_list.is_empty():
		iterations += 1
		if iterations > _MAX_ITERATIONS:
			break   # safety exit – return whatever partial result exists

		# ── 1. Select the node with the lowest f(n) ───────────
		var best_idx : int = 0
		for i in range(1, open_list.size()):
			if open_list[i].f < open_list[best_idx].f:
				best_idx = i

		var current : AStarNode = open_list[best_idx]
		open_list.remove_at(best_idx)

		# ── 2. Goal reached – reconstruct and return path ─────
		if current.tile_pos == goal:
			return _reconstruct_path(current)

		closed_map[current.tile_pos] = current

		# ── 3. Expand 4-directional cardinal neighbors ────────
		#       (diagonals excluded per design document)
		for d in [Vector2i(0, -1),   # North
				  Vector2i(0,  1),   # South
				  Vector2i(-1, 0),   # West
				  Vector2i( 1, 0)]:  # East

			var nb_pos : Vector2i = current.tile_pos + d

			# Skip: already fully evaluated
			if closed_map.has(nb_pos):
				continue

			# Skip: wall or out-of-bounds
			if not _is_walkable(nb_pos):
				continue

			var tentative_g : float = current.g + 1.0

			# Check if this neighbour is already queued in open_list
			var found         : bool       = false
			var existing_node : AStarNode
			for node in open_list:
				if node.tile_pos == nb_pos:
					found         = true
					existing_node = node
					break

			if found:
				# Found a cheaper route to an already-queued node → update it
				if tentative_g < existing_node.g:
					existing_node.g      = tentative_g
					existing_node.f      = tentative_g + existing_node.h
					existing_node.parent = current
			else:
				# New node – add to open list
				open_list.append(
					AStarNode.new(nb_pos, tentative_g, _manhattan(nb_pos, goal), current)
				)

	return []   # no path found (e.g. goal is completely enclosed)


# ── Reconstruct the path by tracing parent pointers back to start ──
func _reconstruct_path(end_node: AStarNode) -> Array:
	var path : Array     = []
	var node : AStarNode = end_node
	while node != null:
		path.push_front(node.tile_pos)
		node = node.parent
	return path


# ── Manhattan Distance heuristic ─────────────────────────────────
# Appropriate for 4-directional (cardinal-only) grid movement.
# h(n) = |x_current − x_target| + |y_current − y_target|
func _manhattan(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


# ── Walkability check ─────────────────────────────────────────────
func _is_walkable(tile_pos: Vector2i) -> bool:
	if not tilemap_node:
		return true
		
	var tile_data = tilemap_node.get_cell_tile_data(tile_pos)
	
	if tile_data == null:
		return false
		
	return tile_data.get_custom_data("walkable")


# ── BFS: find the nearest walkable tile to a blocked position ─────
# Used when the predictive target lands inside a wall.
func _nearest_walkable(origin: Vector2i) -> Vector2i:
	var queue   : Array      = [origin]
	var visited : Dictionary = {origin: true}
	var limit   : int        = 40          # search up to 40 tiles out

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
	return origin   # fallback: return the original (still on a wall, but won't crash)
	
func _process(_delta: float) -> void:
	# VISUALIZER FUNCTION
	queue_redraw()

func _draw() -> void:
	# Draw a line connecting all waypoints in the path
	if _path.size() > 1:
		for i in range(_path.size() - 1):
			# Convert global path coordinates to local coordinates for drawing
			var point_a = to_local(_path[i])
			var point_b = to_local(_path[i + 1])
			draw_line(point_a, point_b, Color.RED, 32.0)
			draw_circle(point_b, 3.0, Color.YELLOW) # Draw a dot at each waypoint
