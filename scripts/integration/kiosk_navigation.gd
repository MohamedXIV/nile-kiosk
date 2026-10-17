extends RefCounted
## Use Godot's native AStarGrid2D for the small tile-aligned kiosk.
## The P1/P4 world clock still owns route timing; every NPC pose samples
## this immutable path rather than maintaining another moving-state clock.
## AStarGrid2D is synchronous (even in native headless WorldKernel tests).
const CELL: float = 5.0
const ACTOR_RADIUS: float = 4.0

var grid: AStarGrid2D
var geometry: Dictionary = {}

static func _whole(v: Variant, low: int, high: int) -> bool:
    return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v) == float(int(v)) and int(v) >= low and int(v) <= high

func configure(raw: Variant, room: Dictionary, homes: Array, destinations: Array) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY or raw.size() != 5 or raw.get("schema") != 1 or raw.get("room_id") != "kiosk":
        return {"ok":false,"code":"INVALID_NAV_GRID"}
    var xs: Variant = raw.get("x_edges")
    var ys: Variant = raw.get("y_edges")
    var blocked: Variant = raw.get("blocked_cells")
    if typeof(xs) != TYPE_ARRAY or typeof(ys) != TYPE_ARRAY or typeof(blocked) != TYPE_ARRAY or xs.size() < 3 or ys.size() < 3 or xs.size() > 16 or ys.size() > 16 or blocked.is_empty():
        return {"ok":false,"code":"INVALID_NAV_GRID"}
    for edges in [xs,ys]:
        for i in range(edges.size()):
            if not _whole(edges[i],0,2000) or (i > 0 and int(edges[i]) <= int(edges[i-1])):
                return {"ok":false,"code":"INVALID_NAV_GRID"}
    if int(xs[0]) < 0 or int(ys[0]) < 0 or int(xs.back()) > int(room["width"]) or int(ys.back()) > int(room["height"]):
        return {"ok":false,"code":"INVALID_NAV_GRID"}
    var excluded: Dictionary = {}
    for cell in blocked:
        if typeof(cell) != TYPE_ARRAY or cell.size() != 2 or not _whole(cell[0],0,xs.size()-2) or not _whole(cell[1],0,ys.size()-2):
            return {"ok":false,"code":"INVALID_NAV_GRID"}
        var id: String = str(int(cell[0]))+":"+str(int(cell[1]))
        if excluded.has(id): return {"ok":false,"code":"INVALID_NAV_GRID"}
        excluded[id] = true
    for p in homes + destinations:
        if not _contains(p,xs,ys,excluded):
            return {"ok":false,"code":"NAV_ENDPOINT_BLOCKED"}
    var candidate: AStarGrid2D = AStarGrid2D.new()
    candidate.region = Rect2i(Vector2i.ZERO,Vector2i(int(room["width"]/CELL)+1,int(room["height"]/CELL)+1))
    candidate.cell_size = Vector2(CELL,CELL)
    candidate.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    candidate.update()
    var obstacles: Array[Rect2] = []
    for cell in blocked:
        var x: int = int(cell[0])
        var y: int = int(cell[1])
        var rect: Rect2 = Rect2(Vector2(xs[x],ys[y]),Vector2(xs[x+1]-xs[x],ys[y+1]-ys[y]))
        obstacles.append(rect)
        for iy in range(candidate.region.size.y):
            for ix in range(candidate.region.size.x):
                var id: Vector2i = Vector2i(ix,iy)
                if rect.grow(ACTOR_RADIUS).has_point(candidate.get_point_position(id)):
                    candidate.set_point_solid(id,true)
    for home in homes:
        for goal in destinations:
            # Validate both directions: AStarGrid2D is responsible for routing,
            # but its grid only marks cell centers. Authored off-grid endpoints
            # and the return journey must also clear the actor's physical radius.
            var outward: PackedVector2Array = _path(candidate,home,goal)
            var returning: PackedVector2Array = _path(candidate,goal,home)
            if outward.size() < 2 or returning.size() < 2:
                return {"ok":false,"code":"NAV_ROUTE_UNREACHABLE"}
            if not _path_has_clearance(outward,obstacles) or not _path_has_clearance(returning,obstacles):
                return {"ok":false,"code":"NAV_CLEARANCE_BLOCKED"}
    grid = candidate
    geometry = raw.duplicate(true)
    return {"ok":true}

# Uses Godot's native Geometry2D intersections rather than custom pathfinding.
# Reject the authored navigation atomically if a route clips solid furniture.
static func _path_has_clearance(path: PackedVector2Array, obstacles: Array[Rect2]) -> bool:
    for solid in obstacles:
        var padded: Rect2 = solid.grow(ACTOR_RADIUS)
        var corners: PackedVector2Array = PackedVector2Array([
            padded.position,Vector2(padded.end.x,padded.position.y),
            padded.end,Vector2(padded.position.x,padded.end.y)])
        for p in path:
            if padded.has_point(p):
                return false
        for i in range(1,path.size()):
            for corner in range(4):
                if Geometry2D.segment_intersects_segment(
                        path[i-1],path[i],corners[corner],corners[(corner+1)%4]) != null:
                    return false
    return true

static func _contains(p: Vector2, xs: Array, ys: Array, excluded: Dictionary) -> bool:
    for j in range(ys.size()-1):
        for i in range(xs.size()-1):
            if excluded.has(str(i)+":"+str(j)): continue
            if p.x >= float(xs[i]) and p.x <= float(xs[i+1]) and p.y >= float(ys[j]) and p.y <= float(ys[j+1]):
                return true
    return false

static func _path(nav: AStarGrid2D,origin: Vector2,goal: Vector2) -> PackedVector2Array:
    var start: Vector2i = Vector2i(roundi(origin.x/CELL),roundi(origin.y/CELL))
    var end: Vector2i = Vector2i(roundi(goal.x/CELL),roundi(goal.y/CELL))
    if not nav.is_in_boundsv(start) or not nav.is_in_boundsv(end):
        return PackedVector2Array()
    if nav.is_point_solid(start) or nav.is_point_solid(end):
        return PackedVector2Array()
    var points: PackedVector2Array = nav.get_point_path(start,end)
    if points.is_empty(): return points
    if not points[0].is_equal_approx(origin):
        points.insert(0,origin)
    if not points[points.size()-1].is_equal_approx(goal):
        points.append(goal)
    return points

func path_between(origin: Vector2,goal: Vector2) -> PackedVector2Array:
    if grid == null: return PackedVector2Array()
    return _path(grid,origin,goal)

func obstacle_rects() -> Array[Rect2]:
    var rects: Array[Rect2] = []
    if geometry.is_empty(): return rects
    var xs: Array = geometry["x_edges"]
    var ys: Array = geometry["y_edges"]
    for cell in geometry["blocked_cells"]:
        var i: int = int(cell[0])
        var j: int = int(cell[1])
        rects.append(Rect2(Vector2(xs[i],ys[j]),Vector2(xs[i+1]-xs[i],ys[j+1]-ys[j])))
    return rects

func dispose() -> void:
    grid = null
    geometry = {}
