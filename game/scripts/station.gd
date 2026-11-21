class_name Station
extends Node3D
## Рабочее место «руками»: камера стоит, мышь свободна, предметы берёшь ЛКМ, тащишь и отпускаешь.
## Каждый шаг процесса — отдельное действие руками (загрузить, опустить, помешать, влить, собрать…).
## Автотест водит «мышь» сам (auto), через те же самые проверки, что и игрок.

const GRAB_LAYER := 16

var cam: Camera3D
var ui: Node
var base: Basement
var running := false
var ptr := Vector2.ZERO        # мышь в координатах 3D-вьюпорта
var down := false              # ЛКМ зажата
var pressed := false           # нажата в этом кадре
var released := false          # отпущена в этом кадре
var leave := false             # E / Esc в этом кадре
var auto := false
var step := ""
var _hover: Node3D = null
var _overlay: StandardMaterial3D


func _init() -> void:
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.albedo_color = Color(1.0, 0.85, 0.5, 0.22)


func begin(c: Camera3D, u: Node, b: Basement) -> void:
	cam = c
	ui = u
	base = b
	running = true
	auto = G.auto_test
	down = false
	pressed = false
	released = false
	leave = false
	ptr = Vector2(cam.get_viewport().get_visible_rect().size) * 0.5
	if not auto:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func end() -> void:
	running = false
	set_hover(null)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	ui.station_step("")


func _unhandled_input(e: InputEvent) -> void:
	if not running or auto:
		return
	if e is InputEventMouseMotion:
		ptr = (e as InputEventMouseMotion).position
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		ptr = (e as InputEventMouseButton).position
		if e.pressed:
			down = true
			pressed = true
		else:
			down = false
			released = true
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("use") or e.is_action_pressed("pause"):
		leave = true
		get_viewport().set_input_as_handled()


## Ждать кадр. Флаги «нажал/отпустил» живут ровно один кадр.
func tick() -> float:
	pressed = false
	released = false
	leave = false
	await get_tree().process_frame
	return get_process_delta_time()


# ---------- луч из-под мыши ----------

func on_plane(p: Plane) -> Vector3:
	var o := cam.project_ray_origin(ptr)
	var d := cam.project_ray_normal(ptr)
	var hit: Variant = p.intersects_ray(o, d)
	return hit if hit != null else Vector3.INF


func on_y(y: float) -> Vector3:
	return on_plane(Plane(Vector3.UP, y))


## Вертикальная плоскость через точку, повёрнутая к камере (для «тянуть вверх-вниз»).
func on_vertical(through: Vector3) -> Vector3:
	var n := cam.global_transform.basis.z
	n.y = 0.0
	return on_plane(Plane(n.normalized(), through))


## Что под мышкой из того, что можно взять.
func pick() -> Node3D:
	var o := cam.project_ray_origin(ptr)
	var q := PhysicsRayQueryParameters3D.create(o, o + cam.project_ray_normal(ptr) * 6.0, GRAB_LAYER)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var a := hit["collider"] as Node
	return a.get_meta("tool") if a and a.has_meta("tool") else null


## Сделать предмет «берущимся»: невидимая коробка под мышку.
func grabbable(n: Node3D, size: Vector3, offset := Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = GRAB_LAYER
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("tool", n)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = offset
	a.add_child(cs)
	n.add_child(a)
	return a


func set_hover(n: Node3D) -> void:
	if n == _hover:
		return
	if is_instance_valid(_hover):
		for mi in _hover.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = null
	_hover = n
	if is_instance_valid(n):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = _overlay
	if not auto:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if n else Input.CURSOR_ARROW)


func dragging_cursor(on: bool) -> void:
	if not auto:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG if on else Input.CURSOR_ARROW)


# ---------- автотест: «рука» сама водит мышью ----------

func a_move(world_pos: Vector3, sec := 0.35) -> void:
	var a := ptr
	var b := cam.unproject_position(world_pos)
	var t := 0.0
	while t < sec:
		t += get_process_delta_time()
		ptr = a.lerp(b, clampf(t / sec, 0.0, 1.0))
		await get_tree().process_frame
	ptr = b


func a_press() -> void:
	down = true
	pressed = true
	await get_tree().process_frame


func a_release() -> void:
	down = false
	released = true
	await get_tree().process_frame


func a_wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ---------- мелочи для построения предметов ----------

func mat(col: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	return m


func glow(col: Color, e: float) -> StandardMaterial3D:
	var m := mat(col)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = e
	return m


func boxm(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func cylm(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, sides := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func label3d(parent: Node3D, text: String, pos: Vector3, size := 24, col := Color(0.95, 0.92, 0.8)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/PressStart2P.ttf")
	l.font_size = size
	l.pixel_size = 0.0012
	l.modulate = col
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	return l


## Струя жидкости/порошка: тонкий цилиндр от a вниз до b.
func stream_set(s: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var h := maxf(0.01, a.y - b.y)
	(s.mesh as CylinderMesh).height = h
	s.global_position = Vector3(a.x, (a.y + b.y) * 0.5, a.z)
