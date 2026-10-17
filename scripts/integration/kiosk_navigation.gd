extends RefCounted
## Godot NavigationServer2D handles pathfinding around authored, padded
## kiosk furniture. Canonical P1/P4 determines WHEN to sample this path.
## A path is derived data: no actor simulation clock, no scene GameState.
var map_rid: RID
var region_rid: RID
var geometry: Dictionary = {}

static func _whole(v: Variant, low: int, high: int) -> bool:
    return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v) == float(int(v)) and int(v) >= low and int(v) <= high

func configure(raw: Variant, room: Dictionary, homes: Array, destinations: Array) -> Dictionary:
    if typeof(raw) != TYPE_DICTIONARY or raw.size() != 5 or raw.get("schema") != 1 or raw.get("room_id") != "kiosk":
        return {"ok":false,"code":"INVALID_NAV_MESH"}
    var xs: Variant = raw.get("x_edges")
    var ys: Variant = raw.get("y_edges")
    var blocked: Variant = raw.get("blocked_cells")
    if typeof(xs) != TYPE_ARRAY or typeof(ys) != TYPE_ARRAY or typeof(blocked) != TYPE_ARRAY or xs.size() < 3 or ys.size() < 3 or xs.size() > 16 or ys.size() > 16 or blocked.is_empty():
        return {"ok":false,"code":"INVALID_NAV_MESH"}
    for edges in [xs,ys]:
        for i in range(edges.size()):
            if not _whole(edges[i],0,2000) or (i > 0 and int(edges[i]) <= int(edges[i-1])):
                return {"ok":false,"code":"INVALID_NAV_MESH"}
    if int(xs[0]) < 0 or int(ys[0]) < 0 or int(xs.back()) > int(room["width"]) or int(ys.back()) > int(room["height"]):
        return {"ok":false,"code":"INVALID_NAV_MESH"}
    var excluded: Dictionary = {}
    for cell in blocked:
        if typeof(cell) != TYPE_ARRAY or cell.size() != 2 or not _whole(cell[0],0,xs.size()-2) or not _whole(cell[1],0,ys.size()-2):
            return {"ok":false,"code":"INVALID_NAV_MESH"}
        var id: String = str(int(cell[0]))+":"+str(int(cell[1]))
        if excluded.has(id): return {"ok":false,"code":"INVALID_NAV_MESH"}
        excluded[id] = true
    var poly: NavigationPolygon = NavigationPolygon.new()
    var verts: PackedVector2Array = PackedVector2Array()
    for y in ys:
        for x in xs:
            verts.append(Vector2(float(x),float(y)))
    poly.vertices = verts
    for j in range(ys.size()-1):
        for i in range(xs.size()-1):
            if excluded.has(str(i)+":"+str(j)): continue
            var k: int = j*xs.size()+i
            poly.add_polygon(PackedInt32Array([k,k+1,k+xs.size()+1,k+xs.size()]))
    # Reject off-mesh endpoints rather than silently snapping a visitor
    # into a counter, a table or through a wall.
    for p in homes + destinations:
        if not _contains(p,xs,ys,excluded):
            return {"ok":false,"code":"NAV_ENDPOINT_BLOCKED"}
    dispose()
    map_rid = NavigationServer2D.map_create()
    region_rid = NavigationServer2D.region_create()
    NavigationServer2D.map_set_cell_size(map_rid,poly.cell_size)
    NavigationServer2D.map_set_active(map_rid,true)
    NavigationServer2D.region_set_transform(region_rid,Transform2D.IDENTITY)
    NavigationServer2D.region_set_enabled(region_rid,true)
    NavigationServer2D.region_set_navigation_polygon(region_rid,poly)
    NavigationServer2D.region_set_map(region_rid,map_rid)
    NavigationServer2D.map_force_update(map_rid)
    for home in homes:
        for goal in destinations:
            var route: PackedVector2Array = NavigationServer2D.map_get_path(map_rid,home,goal,true)
            if route.size() < 2:
                var diagnostic: Dictionary = {"ok":false,"code":"NAV_ROUTE_UNREACHABLE","from":str(home),
                    "to":str(goal),"waypoints":route.size(),"polygons":poly.get_polygon_count(),
                    "map_active":NavigationServer2D.map_is_active(map_rid),
                    "regions":NavigationServer2D.map_get_regions(map_rid).size(),
                    "closest_start":str(NavigationServer2D.map_get_closest_point(map_rid,home)),
                    "closest_target":str(NavigationServer2D.map_get_closest_point(map_rid,goal)),
                    "mesh_faces":poly.get_navigation_mesh().get_polygon_count()}
                dispose()
                return diagnostic
    geometry = raw.duplicate(true)
    return {"ok":true}

static func _contains(p: Vector2, xs: Array, ys: Array, excluded: Dictionary) -> bool:
    # Points on cell boundaries are accepted if any adjacent cell is walkable.
    for j in range(ys.size()-1):
        for i in range(xs.size()-1):
            if excluded.has(str(i)+":"+str(j)): continue
            if p.x >= float(xs[i]) and p.x <= float(xs[i+1]) and p.y >= float(ys[j]) and p.y <= float(ys[j+1]):
                return true
    return false

func path_between(origin: Vector2, goal: Vector2) -> PackedVector2Array:
    if not map_rid.is_valid(): return PackedVector2Array()
    return NavigationServer2D.map_get_path(map_rid,origin,goal,true)

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
    if region_rid.is_valid():
        NavigationServer2D.free_rid(region_rid)
        region_rid = RID()
    if map_rid.is_valid():
        NavigationServer2D.free_rid(map_rid)
        map_rid = RID()
    geometry = {}
