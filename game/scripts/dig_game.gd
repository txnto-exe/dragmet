class_name DigGame
extends Node3D
## Мини-игра «Порыться»: камера смотрит на верх кучи, мышкой раскидываешь хлам
## (настоящая физика), под ним — находка. Осторожно: бывает битое стекло.

signal finished(item: String)

const SPOT := Vector3(0, 0.93, -0.2)
const SMALL := [["can_rusted", 0.13], ["cardboard_box_01", 0.16], ["plastic_bottle_gallon", 0.2],
	["russian_food_cans_01", 0.1], ["trashbag", 0.22], ["cigarette_pack", 0.03]]

var cam: Camera3D
var ui: Node
var item := ""
var running := false
var revealed := false
var pieces: Array[RigidBody3D] = []
var covers_left := 0
var find_node: Area3D
var glint: OmniLight3D
var _floor: StaticBody3D
var _t := 0.0


func start(camera: Camera3D, item_key: String, ui_ref: Node) -> void:
	cam = camera
	ui = ui_ref
	item = item_key
	running = true
	revealed = false
	_t = 0.0
	pieces.clear()
	_floor = StaticBody3D.new()
	_floor.collision_layer = 4
	_floor.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.1, 0.04, 0.9)
	cs.shape = sh
	_floor.add_child(cs)
	add_child(_floor)
	_floor.position = SPOT - Vector3(0, 0.02, 0)
	_make_find()
	var need := G.dig_need()
	covers_left = need
	for i in need:
		var off := Vector3(randf_range(-0.05, 0.05), 0.04 + i * 0.07, randf_range(-0.05, 0.05))
		_spawn_piece(SPOT + off, true, i == need - 1 and randf() < 0.18)
	for i in 2:
		var side := Vector3(randf_range(0.3, 0.38) * (1 if i == 0 else -1), 0.05, randf_range(-0.12, 0.12))
		_spawn_piece(SPOT + side, false, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _make_find() -> void:
	find_node = Area3D.new()
	find_node.collision_layer = 8
	find_node.collision_mask = 0
	find_node.monitoring = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, 0.06, 0.2)
	cs.shape = sh
	find_node.add_child(cs)
	add_child(find_node)
	find_node.position = SPOT + Vector3(0, 0.012, 0)
	var vis: Node3D
	match item:
		"phones":
			vis = _phone()
		"hdd":
			vis = _hdd()
		_:
			vis = Node3D.new()
			find_node.add_child(vis)
			Props.place(vis, "circuit_board", Vector3.ZERO, randf() * 360, {"height": 0.02, "collide": false})
			var b := Props.aabb_of(vis)
			var s := 0.17 / maxf(maxf(b.size.x, b.size.z), 0.001)
			vis.scale = Vector3.ONE * s
			vis.position.y = -b.position.y * s - 0.01
	glint = OmniLight3D.new()
	glint.light_color = Color(1.0, 0.95, 0.8)
	glint.light_energy = 0.0
	glint.omni_range = 0.7
	glint.position = Vector3(0, 0.12, 0.05)
	find_node.add_child(glint)


func _phone() -> Node3D:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.014, 0.12)
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09)
	m.roughness = 0.4
	n.material_override = m
	find_node.add_child(n)
	var scr := MeshInstance3D.new()
	var qm := BoxMesh.new()
	qm.size = Vector3(0.048, 0.002, 0.05)
	scr.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.3, 0.45, 0.35)
	sm.emission_enabled = true
	sm.emission = Color(0.2, 0.35, 0.25)
	scr.material_override = sm
	scr.position = Vector3(0, 0.008, -0.025)
	n.add_child(scr)
	n.rotation.y = randf() * TAU
	return n


func _hdd() -> Node3D:
	var n := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.025, 0.145)
	n.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.6, 0.62)
	m.metallic = 0.8
	m.roughness = 0.35
	n.material_override = m
	find_node.add_child(n)
	n.rotation.y = randf() * TAU
	return n


func _spawn_piece(pos: Vector3, cover: bool, glass: bool) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 4
	rb.collision_mask = 4
	rb.mass = 0.4
	rb.set_meta("cover", cover)
	rb.set_meta("glass", glass)
	add_child(rb)
	rb.position = pos
	rb.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
	var size: Vector3
	if glass:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.22, 0.015, 0.16)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.8, 0.55, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.3
		mi.material_override = m
		rb.add_child(mi)
		size = Vector3(0.22, 0.02, 0.16)
	elif randf() < 0.45:
		# газета / тряпка / доска
		var kind := randi() % 3
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.roughness = 1.0
		match kind:
			0:
				size = Vector3(0.3, 0.012, 0.22)
				m.albedo_color = Color(0.62, 0.6, 0.52)
			1:
				size = Vector3(0.26, 0.03, 0.2)
				m.albedo_color = Color(0.35, 0.28, 0.22)
			_:
				size = Vector3(0.36, 0.025, 0.07)
				m.albedo_color = Color(0.4, 0.3, 0.2)
		bm.size = size
		mi.mesh = bm
		mi.material_override = m
		rb.add_child(mi)
	else:
		var pick: Array = SMALL[randi() % SMALL.size()]
		var holder := Node3D.new()
		rb.add_child(holder)
		var opt := {"collide": false}
		if pick[0] == "cigarette_pack":
			opt["scale"] = 1.0
		else:
			opt["height"] = pick[1]
		Props.place(holder, pick[0], Vector3.ZERO, randf() * 360, opt)
		var b := Props.aabb_of(holder)
		holder.position = -b.get_center()
		size = b.size
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size.max(Vector3.ONE * 0.02)
	cs.shape = sh
	rb.add_child(cs)
	pieces.append(rb)


func _unhandled_input(e: InputEvent) -> void:
	if not running:
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("use"):
		get_viewport().set_input_as_handled()
		_end("")
		return
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		click((e as InputEventMouseButton).position)


func click(screen_pos: Vector2) -> void:
	if not running:
		return
	# находка открыта — достаточно кликнуть рядом с ней (не надо попадать пиксель в пиксель)
	if revealed:
		var sp := cam.unproject_position(find_node.global_position)
		var vh := float(get_viewport().get_visible_rect().size.y)
		if sp.distance_to(screen_pos) < vh * 0.14:
			_collect()
			return
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 4 | 8)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var c: Object = hit["collider"]
	if c is RigidBody3D and (c as RigidBody3D) in pieces:
		_toss(c)
	elif c == find_node and revealed:
		_collect()


func toss_next() -> void:
	## для автотеста: убрать верхний кусок
	if revealed:
		_collect()
		return
	var best: RigidBody3D = null
	var bd := 1e9
	for rb in pieces:
		var d := rb.global_position.distance_to(SPOT)
		if d < bd:
			bd = d
			best = rb
	if best:
		_toss(best)


func _toss(rb: RigidBody3D) -> void:
	pieces.erase(rb)
	var away := rb.global_position - SPOT
	away.y = 0
	if away.length() < 0.02:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	away = away.normalized()
	rb.collision_mask = 0
	rb.collision_layer = 0
	rb.apply_central_impulse((away * 1.1 + Vector3(0, 1.4, 0)) * rb.mass)
	rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02)
	Sfx.play("rustle%d" % (randi() % 3), -6.0, randf_range(0.85, 1.15))
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(rb.queue_free)
	if rb.get_meta("glass"):
		Sfx.play("hurt", -2.0)
		if ui:
			ui.flash(0.45)
			ui.toast("Порезался о битое стекло", Color(1, 0.4, 0.35))
	if rb.get_meta("cover"):
		covers_left -= 1


## Находка открыта, когда над ней не лежит ни один кусок хлама (куски могут скатываться сами).
func _check_reveal() -> void:
	if revealed or not running or find_node == null:
		return
	var fp := find_node.global_position
	for rb in pieces:
		if not is_instance_valid(rb):
			continue
		var d := Vector2(rb.global_position.x - fp.x, rb.global_position.z - fp.z).length()
		if d < 0.15 and rb.global_position.y > fp.y - 0.02:
			return
	revealed = true
	covers_left = 0
	Sfx.play("pickup", -10.0, 1.4)
	if ui:
		ui.say_sub("", "Есть! Кликни по находке, чтобы забрать.", 3.0)
	var g := create_tween()
	g.tween_property(glint, "light_energy", 0.9, 0.3)


func _collect() -> void:
	running = false
	Sfx.play("pickup", -4.0)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(find_node, "global_position", cam.global_position + (-cam.global_transform.basis.z) * 0.25, 0.35)
	tw.tween_property(find_node, "scale", Vector3.ONE * 0.3, 0.35)
	await tw.finished
	_end(item)


func _process(dt: float) -> void:
	_t += dt
	if running:
		# куски, упавшие с кучи, убираем
		for rb in pieces.duplicate():
			if not is_instance_valid(rb) or rb.global_position.y < SPOT.y - 0.4:
				pieces.erase(rb)
				if is_instance_valid(rb):
					rb.queue_free()
		if _t > 0.6:
			_check_reveal()
	if revealed and running and glint:
		glint.light_energy = 0.7 + 0.3 * sin(_t * 9.0)


func _end(result: String) -> void:
	running = false
	for rb in pieces:
		rb.queue_free()
	pieces.clear()
	if find_node:
		find_node.queue_free()
	if _floor:
		_floor.queue_free()
	finished.emit(result)
