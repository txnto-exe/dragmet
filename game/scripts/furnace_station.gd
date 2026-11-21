class_name FurnaceStation
extends Station
## Плавка руками, жёлтая стрелка показывает, что брать и куда нести:
## 1) поднеси банку к тиглю — порошок сыплется сам  2) поставь тигель на печь
## 3) держи ЛКМ на мехах — стрелка градусника в зелёном  4) поднеси тигель к форме — золото льётся само  5) выбей слиток.

const STOVE_TOP := Vector3(-5.45, 0.862, -0.2)   # сбоку от трубы, ближе к столу
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
	jar_fill.visible = true
	cruc.global_position = CRUC_HOME
	cruc.rotation = Vector3.ZERO
	cruc_fill.visible = false
	(cruc_fill.material_override as StandardMaterial3D).emission_energy_multiplier = 0.2
	cruc_mat.emission_energy_multiplier = 0.0
	mold_fill.scale.y = 0.001
	mold_fill.visible = false
	mold_mat.emission_energy_multiplier = 3.0
	mold.rotation = Vector3.ZERO
	lamp.light_energy = 1.0
	ingot.visible = false
	_thermo(0.12)
	if auto:
		_auto_drive()
	var fire := _loop("fire", Vector3(-5.3, 0.5, 0.0), -14.0)
	var holding := false

	# 1. порошок в тигель: поднеси банку к тиглю — дальше сыплется сам
	step = "fill"
	while true:
		var dt := await tick()
		if holding:
			follow(jar, TABLE_Y + 0.22, dt)
			mark(CRUC_HOME + Vector3(0, 0.14, 0))
			if xz_dist(jar.global_position, CRUC_HOME) < 0.15:
				break
			if released:
				holding = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(jar, "global_position", JAR_HOME, 0.3)
			continue
		if leave:
			fire.queue_free()
			_restore()
			lamp.light_energy = 0.0
			end()
			return {"done": false}
		ui.station_step("Поднеси банку с порошком к тиглю")
		legend("fill", [["ЛКМ", "Тащить банку к тиглю"], ["E", "Отойти"]])
		mark(JAR_HOME + Vector3(0, 0.16, 0))
		var h := pick()
		set_hover(h if h == jar else null)
		if pressed and h == jar:
			holding = true
			set_hover(null)
			dragging_cursor(true)
	set_hover(null)
	mark(Vector3.INF)
	dragging_cursor(false)
	legend("none", [])
	var tilt := create_tween()
	tilt.tween_property(jar, "global_position", CRUC_HOME + Vector3(0.1, 0.17, 0), 0.25)
	tilt.parallel().tween_property(jar, "rotation:z", deg_to_rad(120.0), 0.35)
	await tilt.finished
	var k := 0.0
	while k < 1.0:
		var dt := await tick()
		k = minf(1.0, k + dt / 1.3)
		var mouth := jar.global_transform * Vector3(0, 0.12, 0)
		stream_set(stream, mouth, CRUC_HOME + Vector3(0, 0.1, 0))
		stream.visible = true
		cruc_fill.visible = true
		cruc_fill.scale = Vector3.ONE * clampf(k, 0.2, 1.0)
		jar_fill.scale.y = maxf(0.01, 1.0 - k)
		jar_fill.visible = k < 0.97
		if randf() < dt * 8.0:
			Sfx.play3d("rustle0", mouth, -16.0, 1.8)
		ui.station_step("Сыплется…", k)
	stream.visible = false
	var back_j := create_tween()
	back_j.tween_property(jar, "global_position", JAR_HOME, 0.3)
	back_j.parallel().tween_property(jar, "rotation:z", 0.0, 0.3)

	# 2. тигель на печь
	step = "place"
	holding = false
	while true:
		var dt := await tick()
		if holding:
			follow(cruc, 0.98, dt, 14.0)
			mark(STOVE_TOP + Vector3(0, 0.16, 0))
			if xz_dist(cruc.global_position, STOVE_TOP) < 0.2:
				break
			if released:
				holding = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(cruc, "global_position", CRUC_HOME, 0.3)
			continue
		ui.station_step("Поставь тигель на печь")
		legend("place", [["ЛКМ", "Тащить тигель на печь"]])
		mark(CRUC_HOME + Vector3(0, 0.15, 0))
		var h := pick()
		set_hover(h if h == cruc else null)
		if pressed and h == cruc:
			holding = true
			set_hover(null)
			dragging_cursor(true)
	set_hover(null)
	mark(Vector3.INF)
	dragging_cursor(false)
	var put := create_tween()
	put.tween_property(cruc, "global_position", STOVE_TOP, 0.25)
	await put.finished
	Sfx.play3d("clank", STOVE_TOP, -8.0, 1.4)

	# 3. мехи: держи ЛКМ на мехах — жар растёт; отпусти — падает. Держи стрелку в зелёном.
	step = "heat"
	legend("heat", [["Держать ЛКМ на мехах", "Раздувать"], ["Отпустить", "Остудить"]])
	var bel := base.bellows
	var bel_area := grabbable(bel, Vector3(0.45, 0.35, 0.65), Vector3(0, 0.15, 0))
	var t := 0.12
	var prog := 0.0
	var loss := 0.0
	var pumping := false
	var phase := 0.0
	var v := 0.0
	var spark_cd := 0.0
	var ever := false
	while prog < 1.0:
		var dt := await tick()
		if not pumping:
			var h := pick()
			set_hover(h if h == bel else null)
			if pressed and h == bel:
				pumping = true
				ever = true
				set_hover(null)
		elif not down:
			pumping = false
		if pumping:
			var was := v
			phase += dt * 6.0
			v = 0.5 - 0.5 * cos(phase)
			if was < 0.5 and v >= 0.5:
				Sfx.play("bellows", -6.0, randf_range(0.9, 1.1))
			t += dt * 0.16
		else:
			v = maxf(0.0, v - dt * 3.0)
			t -= dt * 0.07
		t = clampf(t, 0.12, 1.0)
		base.pump_bellows(v)
		var hot := t > T_HI
		if t >= T_LO and not hot:
			prog = minf(1.0, prog + dt / 5.0)
		if hot:
			loss = minf(0.4, loss + dt * 0.08)
			spark_cd -= dt
			if spark_cd <= 0.0:
				spark_cd = 0.15
				_spark()
		mark(Vector3.INF if pumping or t >= T_LO else bel.global_position + Vector3(0, 0.36, 0))
		_thermo(t)
		base.furnace_light.light_energy = 0.3 + t * 3.2
		cruc_mat.emission_energy_multiplier = t * 4.0
		cruc_mat.emission = Color(1.0, 0.35, 0.05).lerp(Color(1.0, 0.95, 0.75), clampf((t - 0.6) * 2.5, 0.0, 1.0))
		fire.volume_db = -16.0 + t * 12.0
		var txt := "Держи ЛКМ на мехах — раздуй огонь"
		var col := Color(0.95, 0.8, 0.4)
		if hot:
			txt = "Перегрев! Отпусти мехи — золото горит"
			col = Color(1.0, 0.45, 0.35)
		elif t >= T_LO:
			txt = "Плавится! Держи стрелку в зелёном"
			col = Color(0.55, 0.95, 0.45)
		elif ever and not pumping:
			txt = "Остывает — раздувай ещё"
		ui.station_step(txt, prog, col)
	if is_instance_valid(bel_area):
		bel_area.queue_free()
	base.pump_bellows(0.0)
	set_hover(null)
	Sfx.play("good", -6.0)
	(cruc_fill.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0

	# 4. разлив: поднеси тигель к форме — золото льётся само
	step = "cast"
	holding = false
	while true:
		var dt := await tick()
		if holding:
			follow(cruc, 0.85, dt, 12.0)
			mark(MOLD + Vector3(0, 0.12, 0))
			if xz_dist(cruc.global_position, MOLD) < 0.15:
				break
			if released:
				holding = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(cruc, "global_position", STOVE_TOP, 0.3)
			continue
		ui.station_step("Золото готово — неси тигель к форме")
		legend("cast", [["ЛКМ", "Тащить тигель к форме"]])
		mark(STOVE_TOP + Vector3(0, 0.17, 0))
		var h := pick()
		set_hover(h if h == cruc else null)
		if pressed and h == cruc:
			holding = true
			set_hover(null)
			dragging_cursor(true)
	set_hover(null)
	mark(Vector3.INF)
	dragging_cursor(false)
	legend("none", [])
	var over := create_tween()
	over.tween_property(cruc, "global_position", MOLD + Vector3(0.11, 0.17, 0), 0.3)
	over.parallel().tween_property(cruc, "rotation:z", deg_to_rad(105.0), 0.4)
	await over.finished
	var left := 1.0
	while left > 0.0:
		var dt := await tick()
		left = maxf(0.0, left - dt / 1.8)
		var mouth := cruc.global_transform * Vector3(0, 0.11, 0)
		stream_set(stream, mouth, Vector3(mouth.x, MOLD.y + 0.04, mouth.z))
		stream.visible = true
		mold_fill.visible = true
		mold_fill.scale.y = clampf(1.0 - left, 0.001, 1.0)
		cruc_fill.scale = Vector3.ONE * maxf(0.05, left)
		if randf() < dt * 5.0:
			Sfx.play3d("sizzle", MOLD + Vector3(0, 0.05, 0), -10.0, randf_range(1.3, 1.7))
		ui.station_step("Льётся…", 1.0 - left)
	stream.visible = false
	cruc_fill.visible = false
	var home := create_tween()
	home.tween_property(cruc, "global_position", CRUC_HOME, 0.4)
	home.parallel().tween_property(cruc, "rotation:z", 0.0, 0.3)

	# 5. остывает, потом выбить
	step = "cool"
	var cool := 0.0
	while cool < 2.0:
		var dt := await tick()
		cool += dt
		mold_mat.emission_energy_multiplier = lerpf(3.0, 0.1, cool / 2.0)
		cruc_mat.emission_energy_multiplier = lerpf(cruc_mat.emission_energy_multiplier, 0.0, minf(1.0, dt * 2.0))
		ui.station_step("Остывает…", cool / 2.0)
	step = "knock"
	ui.station_step("Нажми на форму — выбей слиток")
	legend("knock", [["ЛКМ на форме", "Выбить слиток"]])
	while true:
		await tick()
		mark(MOLD + Vector3(0, 0.1, 0))
		var h := pick()
		set_hover(h if h == mold else null)
		if pressed and h == mold:
			break
	set_hover(null)
	mark(Vector3.INF)
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
	ui.station_step("Слиток готов", 1.0)
	await get_tree().create_timer(0.7).timeout
	fire.queue_free()
	base.furnace_light.light_energy = 0.25
	cruc_mat.emission_energy_multiplier = 0.0
	_thermo(0.0)
	lamp.light_energy = 0.0
	end()
	return {"done": true, "grams": have, "eff": 1.0 - loss, "loss": loss}


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
	await a_move(CRUC_HOME + Vector3(0.02, 0.22, 0), 0.4)
	await a_release()
	while step != "place":
		await get_tree().process_frame
	await a_wait(0.5)
	await a_move(CRUC_HOME + Vector3(0, 0.06, 0), 0.3)
	await a_press()
	await a_move(Vector3(STOVE_TOP.x, 0.98, STOVE_TOP.z), 0.5)
	await a_release()
	while step != "heat":
		await get_tree().process_frame
	await a_wait(0.3)
	# мехи: держим, пока градусник ниже середины зелёной зоны
	await a_move(base.bellows.global_position + Vector3(0, 0.22, 0), 0.3)
	while step == "heat":
		var need := thermo.scale.y < (T_LO + T_HI) * 0.5
		if need and not down:
			await a_press()
		elif not need and down:
			await a_release()
		await get_tree().process_frame
	if down:
		await a_release()
	await a_wait(0.4)
	await a_move(STOVE_TOP + Vector3(0, 0.06, 0), 0.3)
	await a_press()
	await a_move(MOLD + Vector3(0.02, 0.85 - MOLD.y, 0), 0.6)
	await a_release()
	while step != "knock":
		await get_tree().process_frame
	await a_wait(0.3)
	await a_move(MOLD + Vector3(0, 0.03, 0), 0.3)
	await a_press()
	await a_release()
