class_name FurnaceStation
extends Station
## Плавка руками:
## 1) засыпь порошок из банки в тигель  2) поставь тигель на печь  3) качай мехи — держи жар в зелёной зоне градусника
## 4) перелей золото в форму, не мимо  5) дай остыть и выбей слиток.

const STOVE_TOP := Vector3(-5.45, 0.862, 0.05)
const TABLE := Vector3(-5.0, 0.0, -0.78)
const TABLE_Y := 0.56
const JAR_HOME := Vector3(-5.12, TABLE_Y, -0.95)
const CRUC_HOME := Vector3(-4.94, TABLE_Y, -0.86)
const MOLD := Vector3(-4.98, TABLE_Y, -0.6)
const T_LO := 0.55
const T_HI := 0.82

var built := false
var jar: Node3D
var jar_fill: MeshInstance3D
var cruc: Node3D
var cruc_mat: StandardMaterial3D
var cruc_fill: MeshInstance3D
var stream: MeshInstance3D
var mold: Node3D
var mold_fill: MeshInstance3D
var mold_mat: StandardMaterial3D
var ingot: MeshInstance3D
var thermo: MeshInstance3D
var thermo_mat: StandardMaterial3D
var spills: Array = []
var lamp: OmniLight3D


func build_props() -> void:
	if built:
		return
	built = true
	var brick := mat(Color(0.5, 0.25, 0.18), 0.0, 0.9)
	var iron := mat(Color(0.2, 0.19, 0.18), 0.7, 0.5)
	# стол: две стопки кирпичей и стальной лист
	for s in [-1, 1]:
		for i in 4:
			boxm(base, Vector3(0.12, 0.13, 0.25), TABLE + Vector3(0.0 if i % 2 == 0 else 0.01, 0.065 + i * 0.13, s * 0.2), brick)
	boxm(base, Vector3(0.36, 0.04, 0.62), TABLE + Vector3(0, TABLE_Y - 0.02, 0), mat(Color(0.46, 0.44, 0.4), 0.3, 0.7))
	# переноска над столом, чтобы форму и банку было видно
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.65)
	lamp.light_energy = 0.0
	lamp.omni_range = 1.6
	lamp.position = TABLE + Vector3(0.35, 1.25, 0.1)
	base.add_child(lamp)
	# банка с порошком
	jar = Node3D.new()
	base.add_child(jar)
	jar.position = JAR_HOME
	var glass := mat(Color(0.75, 0.85, 0.85, 0.35), 0.1, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cylm(jar, 0.05, 0.05, 0.12, Vector3(0, 0.06, 0), glass)
	jar_fill = cylm(jar, 0.046, 0.046, 0.1, Vector3(0, 0.055, 0), glow(Color(0.85, 0.62, 0.2), 0.15))
	grabbable(jar, Vector3(0.13, 0.16, 0.13), Vector3(0, 0.07, 0))
	# тигель (берётся «клещами»)
	cruc = Node3D.new()
	base.add_child(cruc)
	cruc.position = CRUC_HOME
	cruc_mat = mat(Color(0.32, 0.29, 0.27), 0.2, 0.8)
	cruc_mat.emission_enabled = true
	cruc_mat.emission = Color(1.0, 0.4, 0.05)
	cruc_mat.emission_energy_multiplier = 0.0
	cylm(cruc, 0.07, 0.05, 0.11, Vector3(0, 0.055, 0), cruc_mat)
	cruc_fill = cylm(cruc, 0.06, 0.06, 0.02, Vector3(0, 0.1, 0), glow(Color(0.85, 0.62, 0.2), 0.2))
	cruc_fill.visible = false
	grabbable(cruc, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.06, 0))
	stream = cylm(base, 0.008, 0.008, 0.2, Vector3.ZERO, glow(Color(1.0, 0.75, 0.25), 3.0), 6)
	stream.visible = false
	# изложница (форма для слитка)
	mold = Node3D.new()
	base.add_child(mold)
	mold.position = MOLD
	var cast_iron := mat(Color(0.36, 0.3, 0.26), 0.4, 0.6)
	boxm(mold, Vector3(0.2, 0.012, 0.12), Vector3(0, 0.006, 0), mat(Color(0.12, 0.1, 0.09), 0.2, 0.8))
	for s in [-1, 1]:
		boxm(mold, Vector3(0.2, 0.05, 0.02), Vector3(0, 0.025, s * 0.05), cast_iron)
		boxm(mold, Vector3(0.02, 0.05, 0.08), Vector3(s * 0.09, 0.025, 0), cast_iron)
	mold_mat = glow(Color(1.0, 0.7, 0.2), 3.0)
	mold_fill = boxm(mold, Vector3(0.158, 0.035, 0.078), Vector3(0, 0.03, 0), mold_mat)
	mold_fill.scale.y = 0.001
	mold_fill.visible = false
	grabbable(mold, Vector3(0.24, 0.08, 0.16), Vector3(0, 0.03, 0))
	ingot = boxm(base, Vector3(0.15, 0.03, 0.07), Vector3.ZERO, mat(Color(1.0, 0.78, 0.3), 1.0, 0.25))
	ingot.visible = false
	# градусник на трубе: синий — холодно, зелёный — плавится, красный — перегрев
	var th := Node3D.new()
	base.add_child(th)
	th.position = Vector3(-5.22, 0.98, -0.36)
	th.rotation_degrees = Vector3(0, 90, 0)
	var bands := [[0.0, T_LO, Color(0.25, 0.4, 0.8)], [T_LO, T_HI, Color(0.3, 0.8, 0.3)], [T_HI, 1.0, Color(0.85, 0.25, 0.2)]]
	boxm(th, Vector3(0.09, 0.46, 0.012), Vector3(0, 0, -0.008), mat(Color(0.85, 0.82, 0.74)))
	for b in bands:
		var a: float = b[0]
		var c: float = b[1]
		boxm(th, Vector3(0.03, (c - a) * 0.4, 0.004), Vector3(-0.028, -0.2 + (a + c) * 0.2, 0.0), glow(b[2], 0.4))
	thermo_mat = glow(Color(0.9, 0.15, 0.1), 1.0)
	thermo = boxm(th, Vector3(0.014, 0.4, 0.01), Vector3(0.012, 0.0, 0.003), thermo_mat)
	_thermo(0.0)


func _thermo(t: float) -> void:
	thermo.scale.y = maxf(0.02, t)
	thermo.position.y = -0.2 + 0.2 * maxf(0.02, t)


func run(c: Camera3D, u: Node, b: Basement) -> Dictionary:
	base = b
	build_props()
	begin(c, u, b)
	if base.crucible_mesh:
		base.crucible_mesh.visible = false
	var have := G.dust
	hide_ingot()
	jar.global_position = JAR_HOME
	jar.rotation = Vector3.ZERO
	jar_fill.scale.y = 1.0
	cruc.global_position = CRUC_HOME
	cruc.rotation = Vector3.ZERO
	cruc_fill.visible = false
	mold_fill.scale.y = 0.001
	mold_fill.visible = false
	mold_mat.emission_energy_multiplier = 3.0
	mold.rotation = Vector3.ZERO
	lamp.light_energy = 1.0
	ingot.visible = false
	if auto:
		_auto_drive()
	var res := {"done": false}
	var fire := _loop("fire", Vector3(-5.3, 0.5, 0.0), -14.0)
	# 1. порошок в тигель
	step = "fill"
	ui.set_legend([["Тащить ЛКМ", "Сыпать над тиглем"], ["E", "Отойти"]])
	var in_cruc := 0.0
	var holding := false
	while true:
		var dt := await tick()
		if leave and not holding and in_cruc <= 0.0:
			fire.queue_free()
			_restore()
			lamp.light_energy = 0.0
			end()
			return res
		if holding:
			var p := on_y(0.8)
			if p != Vector3.INF:
				jar.global_position = jar.global_position.lerp(p, minf(1.0, dt * 16.0))
			var over := Vector2(jar.global_position.x - cruc.global_position.x, jar.global_position.z - cruc.global_position.z).length() < 0.09
			jar.rotation.z = lerpf(jar.rotation.z, deg_to_rad(120.0) if over else 0.0, minf(1.0, dt * 8.0))
			var pouring := over and jar.rotation.z > deg_to_rad(85.0) and in_cruc < have
			if pouring:
				in_cruc = minf(have, in_cruc + have * dt / 1.6)
				var mouth := jar.global_position + Vector3(-0.07, 0.0, 0.0)
				stream_set(stream, mouth, cruc.global_position + Vector3(0, 0.1, 0))
				cruc_fill.visible = true
				cruc_fill.scale = Vector3.ONE * clampf(in_cruc / maxf(have, 0.0001), 0.2, 1.0)
				jar_fill.scale.y = maxf(0.01, 1.0 - in_cruc / maxf(have, 0.0001))
				if randf() < dt * 8.0:
					Sfx.play3d("rustle0", mouth, -16.0, 1.8)
			stream.visible = pouring
			if released or in_cruc >= have:
				holding = false
				stream.visible = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(jar, "global_position", JAR_HOME, 0.3)
				back.parallel().tween_property(jar, "rotation:z", 0.0, 0.3)
				if in_cruc >= have:
					break
		else:
			var h := pick()
			var ok := h == jar or (h == cruc and in_cruc > 0.0)
			set_hover(h if ok else null)
			if pressed and h == jar:
				holding = true
				set_hover(null)
				dragging_cursor(true)
			elif pressed and h == cruc and in_cruc > 0.0:
				break
		ui.station_step("Засыпь порошок в тигель", in_cruc / maxf(have, 0.0001))
	await get_tree().create_timer(0.2).timeout
	# 2. тигель на печь
	step = "place"
	ui.station_step("Поставь тигель на печь")
	ui.set_legend([["Тащить ЛКМ", "На печь"]])
	holding = false
	while true:
		var dt := await tick()
		if holding:
			var p := on_y(1.05)
			if p != Vector3.INF:
				cruc.global_position = cruc.global_position.lerp(p, minf(1.0, dt * 14.0))
			if released:
				holding = false
				dragging_cursor(false)
				if Vector2(cruc.global_position.x - STOVE_TOP.x, cruc.global_position.z - STOVE_TOP.z).length() < 0.3:
					var tw := create_tween()
					tw.tween_property(cruc, "global_position", STOVE_TOP, 0.25)
					await tw.finished
					Sfx.play3d("clank", STOVE_TOP, -8.0, 1.4)
					break
				var back := create_tween()
				back.tween_property(cruc, "global_position", CRUC_HOME, 0.3)
		else:
			var h := pick()
			set_hover(h if h == cruc else null)
			if pressed and h == cruc:
				holding = true
				set_hover(null)
				dragging_cursor(true)
	# 3. мехи
	step = "heat"
	ui.set_legend([["Зажать ЛКМ на мехах", "Качать вверх-вниз"]])
	var bel := base.bellows
	var bel_area := grabbable(bel, Vector3(0.4, 0.3, 0.6), Vector3(0, 0.15, 0))
	var t := 0.15
	var prog := 0.0
	var loss := 0.0
	var v := 0.0
	var pumping := false
	var anchor_y := 0.0
	var v_prev := 0.0
	var spark_cd := 0.0
	while prog < 1.0:
		var dt := await tick()
		if pumping:
			var p := on_vertical(bel.global_position)
			if p != Vector3.INF:
				v = clampf((anchor_y - p.y) / 0.16, 0.0, 1.0)
			if released:
				pumping = false
				dragging_cursor(false)
		else:
			v = maxf(0.0, v - dt * 3.0)
			var h := pick()
			set_hover(h if h == bel else null)
			if pressed and h == bel:
				pumping = true
				var p := on_vertical(bel.global_position)
				anchor_y = (p.y if p != Vector3.INF else 0.3) + v * 0.16
				set_hover(null)
				dragging_cursor(true)
		var dv := v - v_prev
		if dv > 0.0:
			t += dv * 0.16
			if v_prev < 0.15 and v >= 0.15:
				Sfx.play("bellows", -6.0, randf_range(0.9, 1.1))
		v_prev = v
		t = clampf(t - dt * 0.07, 0.12, 1.0)
		base.pump_bellows(v)
		if t >= T_LO and t <= T_HI:
			prog = minf(1.0, prog + dt / 6.5)
		var hot := t > T_HI + 0.04
		if hot:
			loss = minf(0.5, loss + dt * 0.12)
			spark_cd -= dt
			if spark_cd <= 0.0:
				spark_cd = 0.15
				_spark()
		_thermo(t)
		base.furnace_light.light_energy = 0.3 + t * 3.2
		cruc_mat.emission_energy_multiplier = t * 4.0
		cruc_mat.emission = Color(1.0, 0.35, 0.05).lerp(Color(1.0, 0.95, 0.75), clampf((t - 0.6) * 2.5, 0.0, 1.0))
		fire.volume_db = -16.0 + t * 12.0
		var txt := "Перегрев — золото кипит!" if hot else ("Плавится — держи жар" if t >= T_LO else "Раздувай мехи")
		ui.station_step(txt, prog, Color(1.0, 0.45, 0.35) if hot else Color(0.95, 0.8, 0.4))
	if is_instance_valid(bel_area):
		bel_area.queue_free()
	base.pump_bellows(0.0)
	set_hover(null)
	dragging_cursor(false)
	Sfx.play("good", -6.0)
	(cruc_fill.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0
	# 4. разлив
	step = "cast"
	ui.station_step("Перелей в форму")
	ui.set_legend([["Тащить ЛКМ", "Лить над формой"]])
	var left := 1.0
	var spilled := 0.0
	holding = false
	var wob := 0.0
	while left > 0.0:
		var dt := await tick()
		wob += dt
		if holding:
			var p := on_y(0.82)
			if p != Vector3.INF:
				# тяжёлый тигель в клещах чуть гуляет
				var sway := Vector3(sin(wob * 2.3) * 0.018, 0, cos(wob * 1.7) * 0.014)
				cruc.global_position = cruc.global_position.lerp(p + sway, minf(1.0, dt * 9.0))
			var near := Vector2(cruc.global_position.x - MOLD.x, cruc.global_position.z - MOLD.z).length() < 0.16
			cruc.rotation.z = lerpf(cruc.rotation.z, deg_to_rad(105.0) if near else 0.0, minf(1.0, dt * 6.0))
			var pouring := near and cruc.rotation.z > deg_to_rad(70.0)
			if pouring:
				var mouth := cruc.global_position + Vector3(-0.08, 0.0, 0.0)
				var land := Vector3(mouth.x, MOLD.y + 0.04, mouth.z)
				stream_set(stream, mouth, land)
				var d := dt / 2.4
				left = maxf(0.0, left - d)
				if absf(land.x - MOLD.x) < 0.08 and absf(land.z - MOLD.z) < 0.04:
					mold_fill.visible = true
					mold_fill.scale.y = clampf(1.0 - left, 0.001, 1.0)
				else:
					spilled += d
					if randf() < dt * 6.0:
						_spill(land)
				if randf() < dt * 5.0:
					Sfx.play3d("sizzle", land, -10.0, randf_range(1.3, 1.7))
			stream.visible = pouring
			cruc_fill.scale = Vector3.ONE * maxf(0.05, left)
			if released:
				holding = false
				stream.visible = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(cruc, "global_position", STOVE_TOP, 0.3)
				back.parallel().tween_property(cruc, "rotation:z", 0.0, 0.3)
		else:
			var h := pick()
			set_hover(h if h == cruc else null)
			if pressed and h == cruc:
				holding = true
				set_hover(null)
				dragging_cursor(true)
		ui.station_step("Перелей в форму — мимо не лей" if spilled < 0.02 else "Мимо! Держи над формой", 1.0 - left,
			Color(0.95, 0.8, 0.4) if spilled < 0.02 else Color(1.0, 0.45, 0.35))
	stream.visible = false
	holding = false
	dragging_cursor(false)
	var put := create_tween()
	put.tween_property(cruc, "global_position", CRUC_HOME, 0.4)
	put.parallel().tween_property(cruc, "rotation:z", 0.0, 0.3)
	cruc_fill.visible = false
	# 5. остывает, выбить
	step = "cool"
	ui.set_legend([])
	var cool := 0.0
	while cool < 2.6:
		var dt := await tick()
		cool += dt
		mold_mat.emission_energy_multiplier = lerpf(3.0, 0.1, cool / 2.6)
		ui.station_step("Остывает…", cool / 2.6)
	step = "knock"
	ui.station_step("Выбей слиток")
	ui.set_legend([["ЛКМ", "По форме"]])
	while true:
		await tick()
		var h := pick()
		set_hover(h if h == mold else null)
		if pressed and h == mold:
			break
	set_hover(null)
	var flip := create_tween()
	flip.tween_property(mold, "rotation:x", PI, 0.3)
	await flip.finished
	Sfx.play3d("clank", MOLD, -2.0, 1.2)
	mold_fill.scale.y = 0.001
	mold_fill.visible = false
	ingot.global_position = MOLD + Vector3(0, 0.015, 0.0)
	ingot.visible = true
	var back_m := create_tween()
	back_m.tween_property(mold, "rotation:x", 0.0, 0.3)
	await get_tree().create_timer(0.7).timeout
	fire.queue_free()
	base.furnace_light.light_energy = 0.25
	cruc_mat.emission_energy_multiplier = 0.0
	_thermo(0.0)
	var eff := (1.0 - loss) * (1.0 - clampf(spilled, 0.0, 1.0))
	lamp.light_energy = 0.0
	end()
	return {"done": true, "grams": in_cruc, "eff": eff, "loss": loss, "spilled": spilled}


func _restore() -> void:
	jar.global_position = JAR_HOME
	cruc.global_position = CRUC_HOME
	cruc_fill.visible = false
	stream.visible = false


## Слиток лежит на столе, пока не подойдёшь к печи снова.
func hide_ingot() -> void:
	if ingot:
		ingot.visible = false
	for s in spills:
		if is_instance_valid(s):
			(s as Node3D).queue_free()
	spills = []


func _spark() -> void:
	var d := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	sm.radial_segments = 4
	sm.rings = 2
	d.mesh = sm
	d.material_override = glow(Color(1.0, 0.8, 0.3), 4.0)
	base.add_child(d)
	d.global_position = cruc.global_position + Vector3(0, 0.12, 0)
	var to := d.global_position + Vector3(randf_range(-0.2, 0.2), randf_range(0.15, 0.35), randf_range(-0.2, 0.2))
	var tw := d.create_tween()
	tw.tween_property(d, "global_position", to, 0.3)
	tw.tween_callback(d.queue_free)
	if randf() < 0.3:
		Sfx.play3d("sizzle", d.global_position, -8.0, 1.8)


func _spill(at: Vector3) -> void:
	var s := cylm(base, 0.02, 0.02, 0.004, Vector3.ZERO, glow(Color(1.0, 0.7, 0.2), 1.5), 8)
	s.global_position = Vector3(at.x + randf_range(-0.02, 0.02), TABLE_Y + 0.003, at.z + randf_range(-0.02, 0.02))
	spills.append(s)


func _loop(name: String, pos: Vector3, vol: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = Sfx.looped(name)
	p.volume_db = vol
	p.bus = "SFX"
	p.unit_size = 3.0
	base.add_child(p)
	p.global_position = pos
	p.play()
	return p


# ---------- автотест ----------

func _auto_drive() -> void:
	await a_wait(0.5)
	await a_move(JAR_HOME + Vector3(0, 0.07, 0), 0.3)
	await a_press()
	await a_move(CRUC_HOME + Vector3(0.02, 0.8 - CRUC_HOME.y, 0), 0.4)
	while step == "fill":
		await get_tree().process_frame
	await a_release()
	await a_wait(0.5)
	await a_move(CRUC_HOME + Vector3(0, 0.06, 0), 0.3)
	await a_press()
	await a_move(Vector3(STOVE_TOP.x, 1.05, STOVE_TOP.z), 0.5)
	await a_wait(0.2)
	await a_release()
	while step == "place":
		await get_tree().process_frame
	await a_wait(0.3)
	# мехи: качаем, когда градусник ниже середины зелёной зоны
	var bel := base.bellows.global_position
	await a_move(bel + Vector3(0, 0.22, 0), 0.3)
	await a_press()
	var phase := 0.0
	while step == "heat":
		var dt := get_process_delta_time()
		var need := thermo.scale.y < (T_LO + T_HI) * 0.5
		phase += dt * (5.0 if need else 0.0)
		ptr = cam.unproject_position(bel + Vector3(0, 0.22 - (0.5 - 0.5 * cos(phase)) * 0.15, 0))
		await get_tree().process_frame
	await a_release()
	await a_wait(0.4)
	await a_move(STOVE_TOP + Vector3(0, 0.06, 0), 0.3)
	await a_press()
	await a_move(MOLD + Vector3(0.06, 0.82 - MOLD.y, 0), 0.6)
	while step == "cast":
		await get_tree().process_frame
	await a_release()
	while step == "cool":
		await get_tree().process_frame
	await a_move(MOLD + Vector3(0, 0.03, 0), 0.3)
	await a_press()
	await a_release()
