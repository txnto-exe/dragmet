class_name BinSearch
extends Node
## Мини-игра «Поиск в баке». Хлам лежит слоями внутри бака (без физики — ничего не проваливается).
## Клик по хламу — он вылетает из бака. Когда над находкой ничего не лежит, она блестит — кликни, чтобы забрать.
## Битое стекло режет руку (теряешь время). Иногда из хлама выскакивает крыса.

signal finished(emptied: bool)

const LAYER_H := 0.075
const LAYERS := 7
# мелкий хлам-модели (CC0, Poly Haven): [id, наибольший размер в метрах]. Свои — у каждого типа бака.
const SMALL := [["can_rusted", 0.13], ["cardboard_box_01", 0.2], ["plastic_bottle_gallon", 0.24],
	["russian_food_cans_01", 0.12], ["trashbag", 0.26], ["cigarette_pack", 0.07]]
const SMALL_BY_TYPE := {
	"home": [["multi_cleaner_bottle", 0.24], ["all_purpose_cleaner", 0.24], ["drain_cleaner", 0.24], ["bleach_bottle", 0.26],
		["long_life_food", 0.22], ["wine_bottles_01", 0.3], ["rubber_duck_toy", 0.09], ["dirty_football", 0.2],
		["gamepad", 0.15], ["alarm_clock_01", 0.12], ["lightbulb_led", 0.11], ["lightbulb_01", 0.11],
		["plastic_thermos", 0.26], ["garden_gloves_01", 0.22], ["mousetrap", 0.1], ["round_spectacles", 0.13],
		["postcard_set_01", 0.16]],
	"office": [["office_notepads", 0.22], ["binder_notebook", 0.24], ["clipboard", 0.3], ["vintage_stapler", 0.16],
		["stationery_supplies", 0.18], ["postcard_set_01", 0.16], ["digital_wrist_watch", 0.1],
		["portable_cassette_player", 0.13], ["lightbulb_led", 0.11], ["vintage_lighter", 0.06], ["round_spectacles", 0.13],
		["gamepad", 0.15]],
	"repair": [["screwdriver", 0.2], ["pliers", 0.18], ["combination_wrench", 0.2], ["measuring_tape_01", 0.08],
		["lubricant_spray", 0.22], ["spray_paint_bottles", 0.22], ["small_oil_can_01", 0.18], ["oil_tin", 0.2],
		["cleaner_tin_01", 0.16], ["leather_cleaner_can", 0.14], ["medical_tape", 0.08], ["small_plastic_torch", 0.17],
		["lightbulb_01", 0.11]],
	"military": [["oil_tin", 0.2], ["cleaner_tin_01", 0.16], ["small_plastic_torch", 0.17], ["medical_tape", 0.08],
		["can_rusted", 0.13], ["vintage_lighter", 0.06], ["garden_gloves_01", 0.22], ["combination_wrench", 0.2],
		["russian_food_cans_01", 0.12], ["digital_wrist_watch", 0.1]],
}

var bin: TrashBin
var cam: Camera3D
var ui: Node
var base: Basement
var running := false
var pieces: Array = []        # [{body, r, top, glass}]
var finds: Array = []         # [{area, key, r, y, revealed, glint, vis}]
var _hover: Node3D = null
var _overlay: StandardMaterial3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.albedo_color = Color(1.0, 0.92, 0.7, 0.22)
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


# ---------- наполнение бака ----------

func fill(b: TrashBin, basement: Basement, n_finds: int) -> void:
	bin = b
	base = basement
	pieces.clear()
	finds.clear()
	_rng.randomize()
	# находки — под хламом (в нижних 4 слоях), не вплотную друг к другу
	var spots: Array[Vector2] = []
	for i in n_finds:
		var p := Vector2.ZERO
		for tries in 30:
			p = Vector2(_rng.randf_range(-TrashBin.IN_X + 0.14, TrashBin.IN_X - 0.14), _rng.randf_range(-TrashBin.IN_Z + 0.12, TrashBin.IN_Z - 0.12))
			var ok := true
			for q in spots:
				if q.distance_to(p) < 0.24:
					ok = false
			if ok:
				break
		spots.append(p)
		var layer := _rng.randi_range(0, LAYERS - 3)
		_make_find(G.roll_loot(bin.type), Vector3(p.x, TrashBin.FLOOR_Y + 0.015 + layer * LAYER_H, p.y))
	# слои хлама
	var glass_left := 2
	for L in LAYERS:
		var y := TrashBin.FLOOR_Y + 0.03 + L * LAYER_H
		var count := 13 if L < LAYERS - 1 else 11
		for i in count:
			var p := Vector3(_rng.randf_range(-TrashBin.IN_X + 0.1, TrashBin.IN_X - 0.1), y + _rng.randf_range(0.0, 0.04),
				_rng.randf_range(-TrashBin.IN_Z + 0.08, TrashBin.IN_Z - 0.08))
			var glass := glass_left > 0 and L >= 2 and _rng.randf() < 0.12
			if glass:
				glass_left -= 1
			_make_piece(p, glass)
	_settle(true)
	_update_reveal(false)


func _make_piece(pos: Vector3, glass: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	bin.contents.add_child(body)
	body.position = pos
	body.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf() * TAU, _rng.randf_range(-0.15, 0.15))
	var size: Vector3
	var kind := _rng.randf()
	if glass:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.24, 0.015, 0.18)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.85, 0.6, 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.4
		m.emission_enabled = true
		m.emission = Color(0.15, 0.3, 0.18)
		mi.material_override = m
		body.add_child(mi)
		size = Vector3(0.24, 0.03, 0.18)
	elif kind < 0.16:
		size = _flat(body, Vector3(_rng.randf_range(0.26, 0.36), 0.012, _rng.randf_range(0.2, 0.26)),
			[Color(0.62, 0.6, 0.52), Color(0.7, 0.68, 0.6), Color(0.5, 0.52, 0.55)].pick_random(), 1.0)
	elif kind < 0.28:
		size = _flat(body, Vector3(_rng.randf_range(0.28, 0.38), 0.05, _rng.randf_range(0.22, 0.3)), Color(0.6, 0.46, 0.3), 1.0, base._cardboard())
	elif kind < 0.37:
		size = _model_piece(body, ["trashbag", _rng.randf_range(0.16, 0.24)])
	elif kind < 0.44:
		size = _lump(body, _rng.randf_range(0.08, 0.12), Color(0.45, 0.38, 0.32), 1.0, base.surf("carpet", 1.0, 1.0, Color(0.6, 0.52, 0.45)))
	elif kind < 0.5:
		size = _flat(body, Vector3(_rng.randf_range(0.4, 0.5), 0.03, 0.08), Color(0.45, 0.35, 0.24), 0.9, base.surf("planks", 1.2, 1.0, Color(0.6, 0.5, 0.4)))
	else:
		var pool: Array = SMALL_BY_TYPE.get(bin.type, [])
		var pick: Array = SMALL[_rng.randi() % SMALL.size()] if pool.is_empty() or _rng.randf() < 0.3 else pool[_rng.randi() % pool.size()]
		size = _model_piece(body, pick)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size.max(Vector3.ONE * 0.03)
	cs.shape = sh
	body.add_child(cs)
	var hh := maxf(size.y, 0.03) * 0.5
	pieces.append({"body": body, "r": maxf(size.x, size.z) * 0.42, "top": pos.y + hh, "y": pos.y, "hh": hh, "glass": glass})



## Хлам-модель: настоящий размер вещи, но не больше pick[1] (чтобы влезало в бак)
func _model_piece(body: Node3D, pick: Array) -> Vector3:
	var holder := Node3D.new()
	body.add_child(holder)
	Props.place(holder, pick[0], Vector3.ZERO, _rng.randf() * 360, {"collide": false, "max_size": pick[1]})
	var b := Props.aabb_of(holder)
	holder.position = -b.get_center()
	var size := b.size
	# высокие вещи (бутылки, банки, баллончики) в баке лежат на боку
	if size.y > maxf(size.x, size.z) * 1.15:
		body.rotation.x = PI * 0.5 * (1 if _rng.randf() < 0.5 else -1)
		size = Vector3(size.x, size.z, size.y)
	return size

func _flat(body: Node3D, size: Vector3, col: Color, rough: float, mat: Material = null) -> Vector3:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		mat = m
	mi.material_override = mat
	body.add_child(mi)
	return size


func _lump(body: Node3D, r: float, col: Color, rough: float, mat: Material = null) -> Vector3:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	if mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.metallic = 0.1
		mat = m
	mi.material_override = mat
	var sy := _rng.randf_range(0.35, 0.55)
	mi.scale = Vector3(1.0, sy, _rng.randf_range(0.8, 1.15))
	body.add_child(mi)
	return Vector3(r * 2.0, r * 2.0 * sy, r * 2.0)


func _make_find(key: String, pos: Vector3) -> void:
	var a := Area3D.new()
	a.collision_layer = 8
	a.collision_mask = 0
	a.monitoring = false
	bin.contents.add_child(a)
	a.position = pos
	a.rotation.y = _rng.randf() * TAU
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.2, 0.07, 0.2)
	cs.shape = sh
	cs.position.y = 0.02
	a.add_child(cs)
	var vis := _find_visual(key)
	a.add_child(vis)
	var glint := OmniLight3D.new()
	glint.light_color = G.TIER_COLORS[G.ITEMS[key]["tier"]].lerp(Color(1, 0.95, 0.8), 0.5)
	glint.light_energy = 0.0
	glint.omni_range = 0.55
	glint.position = Vector3(0, 0.12, 0)
	a.add_child(glint)
	finds.append({"area": a, "key": key, "r": 0.09, "y": pos.y, "revealed": false, "glint": glint, "vis": vis})


func _mat(col: Color, metal := 0.0, rough := 0.6, emis := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emis != Color.BLACK:
		m.emission_enabled = true
		m.emission = emis
	return m


func _boxm(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(n: Node3D, r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	n.add_child(mi)
	return mi


func _find_visual(key: String) -> Node3D:
	var n := Node3D.new()
	var gold := _mat(Color(0.95, 0.75, 0.3), 1.0, 0.25)
	match key:
		"phones":
			_boxm(n, Vector3(0.065, 0.016, 0.13), Vector3(0, 0.008, 0), _mat(Color(0.08, 0.08, 0.09), 0.2, 0.4))
			_boxm(n, Vector3(0.05, 0.003, 0.055), Vector3(0, 0.017, -0.028), _mat(Color(0.3, 0.45, 0.35), 0, 0.2, Color(0.15, 0.3, 0.2)))
			for i in 9:
				_boxm(n, Vector3(0.012, 0.004, 0.009), Vector3(-0.016 + (i % 3) * 0.016, 0.017, 0.012 + (i / 3) * 0.014), _mat(Color(0.6, 0.6, 0.6)))
		"hdd":
			_boxm(n, Vector3(0.1, 0.025, 0.145), Vector3(0, 0.0125, 0), _mat(Color(0.62, 0.62, 0.64), 0.85, 0.3))
			_boxm(n, Vector3(0.07, 0.002, 0.07), Vector3(0, 0.026, -0.02), _mat(Color(0.85, 0.85, 0.88), 1.0, 0.15))
		"ram":
			_boxm(n, Vector3(0.13, 0.004, 0.032), Vector3(0, 0.004, 0), _mat(Color(0.1, 0.4, 0.15), 0, 0.5))
			for i in 4:
				_boxm(n, Vector3(0.022, 0.006, 0.014), Vector3(-0.045 + i * 0.03, 0.009, 0), _mat(Color(0.05, 0.05, 0.05)))
			_boxm(n, Vector3(0.13, 0.0045, 0.006), Vector3(0, 0.004, 0.017), gold)
		"cpus":
			_boxm(n, Vector3(0.045, 0.006, 0.045), Vector3(0, 0.006, 0), _mat(Color(0.2, 0.5, 0.25), 0, 0.5))
			_boxm(n, Vector3(0.03, 0.004, 0.03), Vector3(0, 0.011, 0), _mat(Color(0.75, 0.75, 0.78), 1.0, 0.2))
			_boxm(n, Vector3(0.05, 0.002, 0.05), Vector3(0, 0.001, 0), gold)
		"connect":
			for i in 3:
				_boxm(n, Vector3(0.05, 0.012, 0.015), Vector3(-0.02 + i * 0.022, 0.006, -0.02 + i * 0.02), gold)
		"resist":
			for i in 5:
				var r := _cyl(n, 0.006, 0.026, Vector3(-0.03 + i * 0.015, 0.006, 0), _mat(Color(0.78, 0.66, 0.45), 0, 0.6))
				r.rotation.x = PI * 0.5
				for k in 3:
					var band := _cyl(n, 0.0065, 0.003, Vector3(-0.03 + i * 0.015, 0.006, -0.007 + k * 0.006),
						_mat([Color(0.6, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.9, 0.6, 0.1), Color(0.2, 0.3, 0.7)][(i + k) % 4]))
					band.rotation.x = PI * 0.5
				_boxm(n, Vector3(0.0015, 0.0015, 0.07), Vector3(-0.03 + i * 0.015, 0.006, 0), _mat(Color(0.75, 0.75, 0.75), 1.0, 0.3))
		"caps":
			var cols := [Color(0.1, 0.2, 0.55), Color(0.08, 0.08, 0.1), Color(0.15, 0.4, 0.2)]
			for i in 4:
				_cyl(n, 0.011 + (i % 2) * 0.004, 0.03 + (i % 3) * 0.008, Vector3(-0.03 + i * 0.022, 0.02, (i % 2) * 0.02 - 0.01), _mat(cols[i % 3], 0.2, 0.4))
				_cyl(n, 0.009, 0.002, Vector3(-0.03 + i * 0.022, 0.037 + (i % 3) * 0.004, (i % 2) * 0.02 - 0.01), _mat(Color(0.7, 0.7, 0.72), 1.0, 0.25))
		"trans":
			for i in 4:
				_boxm(n, Vector3(0.012, 0.014, 0.006), Vector3(-0.024 + i * 0.016, 0.02, 0), _mat(Color(0.06, 0.06, 0.07), 0, 0.5))
				for k in 3:
					_boxm(n, Vector3(0.0012, 0.016, 0.0012), Vector3(-0.028 + i * 0.016 + k * 0.004, 0.006, 0), _mat(Color(0.75, 0.75, 0.75), 1.0, 0.3))
		"silverWire":
			var t := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.03
			tm.outer_radius = 0.045
			t.mesh = tm
			t.material_override = _mat(Color(0.85, 0.86, 0.9), 1.0, 0.2)
			t.position.y = 0.008
			t.scale = Vector3(1, 0.5, 1)
			n.add_child(t)
		_:
			var holder := Node3D.new()
			n.add_child(holder)
			Props.place(holder, "circuit_board", Vector3.ZERO, 0, {"collide": false})
			var b := Props.aabb_of(holder)
			var target := 0.16 if key in ["chips", "rare"] else 0.11
			var s := target / maxf(maxf(b.size.x, b.size.z), 0.001)
			holder.scale = Vector3.ONE * s
			holder.position = Vector3(-b.get_center().x * s, -b.position.y * s, -b.get_center().z * s)
			if key == "rare":
				for mi in holder.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_overlay = _mat(Color(1.0, 0.7, 0.2, 0.35), 0.8, 0.3)
	return n


# ---------- игра ----------

func start(camera: Camera3D, ui_ref: Node) -> void:
	cam = camera
	ui = ui_ref
	running = true
	_t = 0.0
	if not G.auto_test:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_reveal(false)
	_hint()


func finds_left() -> int:
	return finds.size()


func _hint() -> void:
	if ui:
		ui.set_top_hint("Находок: %d" % finds.size())


func stop() -> void:
	running = false
	_set_hover(null)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if ui:
		ui.set_top_hint("")


func _unhandled_input(e: InputEvent) -> void:
	if not running:
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("use"):
		get_viewport().set_input_as_handled()
		stop()
		finished.emit(false)
		return
	if e is InputEventMouseMotion:
		var hit := _pick((e as InputEventMouseMotion).position)
		_set_hover(hit)
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		click((e as InputEventMouseButton).position)


func _ray(screen_pos: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 4 | 8)
	q.collide_with_areas = true
	return cam.get_world_3d().direct_space_state.intersect_ray(q)


## Что под мышкой: открытая находка (с запасом по экрану) или кусок хлама.
func _pick(screen_pos: Vector2) -> Node3D:
	var vh := float(cam.get_viewport().get_visible_rect().size.y)
	var best: Node3D = null
	var bd := vh * 0.06
	for f in finds:
		if f["revealed"]:
			var d := cam.unproject_position((f["area"] as Node3D).global_position).distance_to(screen_pos)
			if d < bd:
				bd = d
				best = f["area"]
	if best:
		return best
	var hit := _ray(screen_pos)
	if hit.is_empty():
		return null
	return hit["collider"] as Node3D


func _set_hover(n: Node3D) -> void:
	if n == _hover:
		return
	if is_instance_valid(_hover):
		for mi in _hover.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay == _overlay:
				(mi as MeshInstance3D).material_overlay = null
	_hover = n
	if is_instance_valid(n):
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_overlay == null:
				(mi as MeshInstance3D).material_overlay = _overlay
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if is_instance_valid(n) else Input.CURSOR_ARROW)


func click(screen_pos: Vector2) -> void:
	if not running:
		return
	var n := _pick(screen_pos)
	if n == null:
		return
	for f in finds:
		if f["area"] == n:
			if f["revealed"]:
				_collect(f)
			else:
				# находку видно краешком — откидываем то, что на ней лежит
				var c := _top_cover(f)
				if c.size() > 0:
					_toss(c)
			return
	for p in pieces:
		if p["body"] == n:
			_toss(p)
			return


func _covers(p: Dictionary, f: Dictionary) -> bool:
	var pb := p["body"] as Node3D
	var fa := f["area"] as Node3D
	if float(p["top"]) <= float(f["y"]) + 0.01:
		return false
	var d := Vector2(pb.position.x - fa.position.x, pb.position.z - fa.position.z).length()
	return d < float(p["r"]) + float(f["r"]) * 0.6


func _top_cover(f: Dictionary) -> Dictionary:
	var best := {}
	var by := -1.0
	for p in pieces:
		if _covers(p, f) and float(p["top"]) > by:
			by = float(p["top"])
			best = p
	return best


func _toss(p: Dictionary, chain := true) -> void:
	if not pieces.has(p):
		return
	pieces.erase(p)
	if p.has("tw") and is_instance_valid(p["tw"]):
		(p["tw"] as Tween).kill()
	var body := p["body"] as StaticBody3D
	body.collision_layer = 0
	if body == _hover:
		_set_hover(null)
	var away := Vector3(body.position.x, 0, body.position.z)
	if away.length() < 0.05:
		away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	away = away.normalized()
	var start := body.position
	var end := start + away * 0.9 + Vector3(0, 0.25, 0)
	var peak := start.lerp(end, 0.5) + Vector3(0, 0.55, 0)
	var r0 := body.rotation
	var spin := Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-4, 4), _rng.randf_range(-6, 6))
	var tw := create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(body):
			var a := start.lerp(peak, v)
			var b := peak.lerp(end, v)
			body.position = a.lerp(b, v)
			body.rotation = r0 + spin * v
			body.scale = Vector3.ONE * lerpf(1.0, 0.5, v * v), 0.0, 1.0, 0.42)
	tw.tween_callback(body.queue_free)
	Sfx.play("rustle%d" % (randi() % 3), -6.0, _rng.randf_range(0.85, 1.15))
	if p["glass"]:
		Sfx.play("glass", -4.0, _rng.randf_range(0.9, 1.1))
		Sfx.play("hurt", -6.0)
		G.time += 25.0
		if ui:
			ui.flash(0.45)
			ui.toast("Порезался о стекло", Color(1, 0.45, 0.4))
	elif _rng.randf() < 0.02:
		_rat_jump(start)
	# перчатки: заодно откидываются соседние куски
	if chain:
		var extra := G.gloves_extra()
		if extra > 0:
			var near: Array = []
			for q in pieces:
				var qb := q["body"] as Node3D
				if not q["glass"] and float(q["top"]) >= float(p["top"]) - 0.07 and qb.position.distance_to(start) < 0.28:
					near.append(q)
			near.sort_custom(func(a, b): return (a["body"] as Node3D).position.distance_to(start) < (b["body"] as Node3D).position.distance_to(start))
			for i in mini(extra, near.size()):
				_toss(near[i], false)
		_settle(false)
	_update_reveal(true)


## Оседание: всё, под чем больше ничего нет, падает вниз до опоры (другой хлам, находка или дно бака).
func _settle(instant: bool) -> void:
	var items: Array = []
	for p in pieces:
		items.append({"d": p, "find": false, "bottom": float(p["y"]) - float(p["hh"]), "h": float(p["hh"]) * 2.0,
			"r": float(p["r"]), "pos": (p["body"] as Node3D).position})
	for f in finds:
		items.append({"d": f, "find": true, "bottom": float(f["y"]), "h": 0.035, "r": float(f["r"]),
			"pos": (f["area"] as Node3D).position})
	items.sort_custom(func(a, b): return float(a["bottom"]) < float(b["bottom"]))
	var done: Array = []
	for it in items:
		var support := TrashBin.FLOOR_Y
		var pa: Vector3 = it["pos"]
		for o in done:
			var pb: Vector3 = o["pos"]
			var dist := Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if dist < (float(it["r"]) + float(o["r"])) * 0.72:
				var otop := float(o["bottom"]) + float(o["h"])
				if otop <= float(it["bottom"]) + 0.02:
					support = maxf(support, otop)
		var drop := float(it["bottom"]) - support
		if drop > 0.004:
			it["bottom"] = support
			_drop_to(it, support, instant)
		done.append(it)


func _drop_to(it: Dictionary, bottom: float, instant: bool) -> void:
	var d: Dictionary = it["d"]
	var node: Node3D
	var target_y: float
	if it["find"]:
		d["y"] = bottom
		node = d["area"]
		target_y = bottom
	else:
		d["y"] = bottom + float(d["hh"])
		d["top"] = bottom + float(d["hh"]) * 2.0
		node = d["body"]
		target_y = float(d["y"])
	if instant or not is_instance_valid(node):
		if is_instance_valid(node):
			node.position.y = target_y
		return
	if d.has("tw") and is_instance_valid(d["tw"]):
		(d["tw"] as Tween).kill()
	var fall := maxf(node.position.y - target_y, 0.0)
	var tw := create_tween()
	tw.tween_property(node, "position:y", target_y, maxf(0.08, sqrt(2.0 * fall / 9.8))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	d["tw"] = tw


func _update_reveal(sound: bool) -> void:
	for f in finds:
		if f["revealed"]:
			continue
		var covered := false
		for p in pieces:
			if _covers(p, f):
				covered = true
				break
		if not covered:
			f["revealed"] = true
			var g := create_tween()
			g.tween_property(f["glint"], "light_energy", 1.0, 0.3)
			if sound:
				Sfx.play("good", -8.0, 1.0 + 0.1 * G.ITEMS[f["key"]]["tier"])


func _collect(f: Dictionary) -> void:
	if G.bag_full():
		Sfx.play("thud", -8.0, 1.4)
		if ui:
			ui.toast("Мешок полон", Color(1, 0.7, 0.4))
		return
	finds.erase(f)
	var a := f["area"] as Area3D
	a.collision_layer = 0
	if a == _hover:
		_set_hover(null)
	var key: String = f["key"]
	G.add_item(key)
	var d: Dictionary = G.ITEMS[key]
	if ui:
		ui.toast("Нашёл: %s (≈%s)" % [d["name"], G.rub(G.item_price(key))], G.TIER_COLORS[d["tier"]])
	Sfx.play("pickup", -4.0, 1.0 + 0.08 * d["tier"])
	if d["tier"] >= 2:
		Sfx.play("coins", -8.0, 1.3)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(a, "global_position", cam.global_position + (-cam.global_transform.basis.z) * 0.3, 0.35)
	tw.tween_property(a, "scale", Vector3.ONE * 0.3, 0.35)
	tw.chain().tween_callback(a.queue_free)
	_settle(false)
	_update_reveal(true)
	_hint()
	if finds.is_empty():
		running = false
		await get_tree().create_timer(0.7).timeout
		stop()
		finished.emit(true)


func _rat_jump(from_local: Vector3) -> void:
	var rat := Props.place(bin.contents, "street_rat", from_local, _rng.randf() * 360, {"height": 0.09, "collide": false})
	if rat == null:
		return
	Sfx.play("squeak", -2.0, _rng.randf_range(0.9, 1.2))
	if ui:
		ui.toast("Крыса!", Color(0.9, 0.8, 0.7))
	var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	var end := from_local + dir * 1.4 + Vector3(0, -0.6, 0)
	rat.rotation.y = atan2(dir.x, dir.z)
	var tw := create_tween()
	tw.tween_property(rat, "position", from_local.lerp(end, 0.4) + Vector3(0, 0.5, 0), 0.25)
	tw.tween_property(rat, "position", end, 0.3)
	tw.tween_callback(rat.queue_free)


func _process(dt: float) -> void:
	_t += dt
	for f in finds:
		if f["revealed"]:
			(f["glint"] as OmniLight3D).light_energy = 0.75 + 0.35 * sin(_t * 8.0 + float(f["y"]) * 40.0)


# ---------- для автотеста ----------

func auto_step() -> void:
	for f in finds:
		if f["revealed"]:
			_collect(f)
			return
	for f in finds:
		var c := _top_cover(f)
		if c.size() > 0:
			_toss(c)
			return
