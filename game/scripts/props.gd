class_name Props
extends RefCounted
## Помощник: расставлять модели Poly Haven (res://assets/ph/<id>/<id>.gltf),
## делать им «пиксельные» материалы и коробку-коллизию.

static var _scenes := {}
static var _mats := {}


static func scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		var p := "res://assets/ph/%s/%s.gltf" % [id, id]
		_scenes[id] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[id]


static func rel_xform(node: Node, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


static func aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var any := false
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := rel_xform(mi, root) * mi.mesh.get_aabb()
		if any:
			out = out.merge(box)
		else:
			out = box
			any = true
	return out


static func pixel_mat(m: Material) -> Material:
	if m == null or not (m is BaseMaterial3D):
		return m
	if _mats.has(m):
		return _mats[m]
	var d: BaseMaterial3D = m.duplicate()
	d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mats[m] = d
	return d


static func pixelate(root: Node) -> void:
	for c in root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			mi.set_surface_override_material(s, pixel_mat(m))


## Поставить модель. opts: height (подогнать высоту), size (подогнать самый большой размер), scale, collide (true), tilt (Vector3 градусы)
static func place(parent: Node3D, id: String, pos: Vector3, rot_y := 0.0, opts := {}) -> Node3D:
	var ps := scene(id)
	if ps == null:
		push_warning("нет модели " + id)
		return null
	var n: Node3D = ps.instantiate()
	parent.add_child(n)
	var box := aabb_of(n)
	var s := 1.0
	if opts.has("height"):
		s = float(opts["height"]) / maxf(box.size.y, 0.001)
	if opts.has("size"):
		s = float(opts["size"]) / maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.001))
	if opts.has("scale"):
		s = float(opts["scale"])
	n.scale = Vector3.ONE * s
	n.rotation_degrees = Vector3(0, rot_y, 0) + opts.get("tilt", Vector3.ZERO)
	# ставим дном на pos.y и центром (по X/Z) в pos — с учётом поворота и наклона
	var world_box := Transform3D(n.transform.basis, Vector3.ZERO) * box
	var c := world_box.get_center()
	n.position = pos - Vector3(c.x, world_box.position.y, c.z)
	pixelate(n)
	if opts.get("collide", true):
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size.max(Vector3.ONE * 0.02)
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
		n.add_child(body)
	return n
