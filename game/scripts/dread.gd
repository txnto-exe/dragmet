class_name Dread
extends Node
## Страх: чем ближе срок долга, тем гуще гул, под конец стучит сердце.
## Не отдал долг — приходят люди Хозяина, и игра начинается заново.
## И пара скримеров: «белочка» Коляна за спиной, лицо в глазке (крыса в баке — в BinSearch).

const DOOR := Vector3(1.5, 0.0, 4.5)

var m: Node                     # main
var drone: AudioStreamPlayer
var heart: AudioStreamPlayer
var doom_pending := false
var busy := false
var ghost_knock := false        # тихий стук — за дверью «никого»
var _ghost_knock_t := 0.0
var _scare_cd := 30.0


func setup(main: Node) -> void:
	m = main
	drone = AudioStreamPlayer.new()
	drone.stream = Sfx.looped("drone")
	drone.volume_db = -60.0
	drone.bus = "Ambience"
	add_child(drone)
	drone.play()
	heart = AudioStreamPlayer.new()
	heart.stream = Sfx.looped("heart")
	heart.volume_db = -60.0
	heart.bus = "SFX"
	add_child(heart)
	heart.play()


func _process(dt: float) -> void:
	if m == null:
		return
	var active: bool = G.debt > 0 and not (G.mode in ["menu", "intro"])
	var rot := G.rot()
	var left := G.time_left()
	var dv := lerpf(-40.0, -4.0, smoothstep(0.45, 1.0, rot)) if active else -60.0
	drone.volume_db = lerpf(drone.volume_db, dv, minf(1.0, dt * 2.0))
	var hv := -60.0
	var near := G.DAY_SEC * 0.3
	if active and left < near:
		var k := 1.0 - left / near
		hv = lerpf(-14.0, 2.0, k)
		heart.pitch_scale = lerpf(1.0, 1.4, k)
	heart.volume_db = lerpf(heart.volume_db, hv, minf(1.0, dt * 2.0))
	if doom_pending and G.mode == "walk" and not busy:
		doom_pending = false
		doom()
		return
	_random_scares(dt)


# ---------- случайные скримеры (по разу за игру) ----------

func _random_scares(dt: float) -> void:
	if G.auto_test or busy or G.mode != "walk" or m.knocking or m.phone_ringing:
		return
	_scare_cd -= dt
	if _scare_cd > 0.0:
		return
	_scare_cd = 6.0
	if not G.flags.get("kolyan_in", false) or m.kolyan == null:
		return
	# «белочка»: Колян за спиной, когда ты далеко от его прилавка
	if not G.flags.get("scare_belka", false) and G.bins >= 5 and G.time > 420.0 and randf() < 0.25:
		var kp: Vector3 = m.kolyan.global_position
		if m.player.global_position.distance_to(kp) > 4.0:
			belochka()
			return
	# тихий стук — за дверью никого… а потом лицо в глазке
	if not G.flags.get("scare_peep", false) and G.bins >= 9 and G.time > 700.0 and randf() < 0.2:
		_start_ghost_knock()


func _start_ghost_knock() -> void:
	ghost_knock = true
	G.flags["scare_peep"] = true
	for i in 3:
		get_tree().create_timer(i * 0.55).timeout.connect(func(): Sfx.play3d("knock", DOOR + Vector3(0, 1.4, 0), 2.0, 0.8, 30.0))
	get_tree().create_timer(30.0).timeout.connect(func(): ghost_knock = false)


# ---------- «Белочка пришла» ----------

func belochka() -> void:
	busy = true
	G.flags["scare_belka"] = true
	var p: CharacterBody3D = m.player
	var cam: Camera3D = p.cam
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var ghost := Npc.new()
	m.world.add_child(ghost)
	ghost.setup("kolyan", "", true, Color(0.18, 0.28, 0.55))
	var behind := p.global_position - fwd * 1.1
	behind.x = clampf(behind.x, -Basement.W + 0.4, Basement.W - 0.4)
	behind.z = clampf(behind.z, -Basement.D + 0.4, Basement.D - 0.4)
	ghost.global_position = behind
	ghost.face_to(p.global_position)
	ghost.play("Zombie_Idle", 0.0)
	# шаги за спиной — обернись
	for i in 3:
		Sfx.play3d("step%d" % (i % 4), behind + fwd * 0.3, 2.0, 0.85)
		await get_tree().create_timer(0.45).timeout
	var t := 0.0
	var whispered := false
	while t < 12.0:
		t += get_process_delta_time()
		var to := ghost.global_position + Vector3(0, 1.5, 0) - cam.global_position
		if (-cam.global_transform.basis.z).dot(to.normalized()) > 0.72:
			break
		if t > 5.0 and not whispered:
			whispered = true
			Sfx.play3d("step1", ghost.global_position, 4.0, 0.7)
			m.ui.say_sub("", "…Па-а-алыч…", 2.0)
		if G.mode != "walk":
			ghost.queue_free()
			busy = false
			return
		await get_tree().process_frame
	# если так и не обернулся — свет мигнул, и он уже перед лицом
	p.enabled = false
	var face_dir := -cam.global_transform.basis.z
	face_dir.y = 0.0
	face_dir = face_dir.normalized()
	if t >= 12.0:
		m.world.dim = 0.0
		await get_tree().create_timer(0.35).timeout
		m.world.dim = 1.0
	ghost.play("Idle", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var jump := cam.global_position + face_dir * 0.62
	jump.y = cam.global_position.y - _face_h(ghost)
	ghost.face_to(cam.global_position)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "global_position", jump, 0.09)
	p.look_at_point(Vector3(jump.x, cam.global_position.y, jump.z))
	set_meta("face_in", true)
	Sfx.play("scream", 2.0)
	Sfx.play("scare", -1.0)
	m.ui.flash(0.55)
	m.ui.say_sub("Колян", "БЕЛОЧКА ПРИШЛА-А-А!!!", 2.2)
	await shake(cam, 0.9, 0.06)
	m.world.dim = 0.0
	ghost.queue_free()
	set_meta("face_in", false)
	await get_tree().create_timer(0.5).timeout
	m.world.dim = 1.0
	m.world.flicker(0.6)
	p.enabled = G.mode == "walk"
	m.ui.say_sub("Палыч", "…Колян сидит у себя за прилавком. Показалось?", 3.5)
	G.flags["belka_talk"] = true
	G.save_game()
	busy = false


# ---------- лицо в глазке ----------

func peep_scare() -> void:
	busy = true
	ghost_knock = false
	m.set_mode("peep")
	var p := Vector3(1.5, 1.62, 4.63)
	await m.cine_to(m.look_xf(p, p + Vector3(0, -0.12, 1)), 110.0, 0.7)
	var face := Npc.new()
	m.world.add_child(face)
	face.setup("suit", "Hair_Buzzed", false)
	face.global_position = Vector3(1.5, -5.0, 6.4)
	face.face(Vector3(0, 0, -1))
	face.play("Idle", 0.0)
	m.ui.set_peep(true)
	await get_tree().create_timer(2.4).timeout
	face.global_position = Vector3(1.5, p.y - 0.1 - _face_h(face), 5.6)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.62)
	lamp.light_energy = 1.4
	lamp.omni_range = 1.2
	lamp.shadow_enabled = false
	m.world.add_child(lamp)
	lamp.global_position = Vector3(1.5, p.y + 0.35, 4.72)
	var tw := face.create_tween()
	tw.tween_property(face, "global_position", Vector3(1.5, p.y - 0.1 - _face_h(face), 5.0), 0.12)
	set_meta("face_in", true)
	Sfx.play("scare", 0.0)
	Sfx.play3d("door_bash", DOOR + Vector3(0, 1.4, 0), 4.0)
	m.ui.flash(0.5)
	await shake(m.cine, 0.6, 0.05)
	await m.ui.fade(1.0, 0.15)
	face.queue_free()
	lamp.queue_free()
	set_meta("face_in", false)
	m.ui.set_peep(false)
	await get_tree().create_timer(0.6).timeout
	await m.cine_back(0.01)
	await m.ui.fade(0.0, 0.6)
	m.set_mode("walk")
	m.ui.say_sub("Палыч", "За дверью пусто. Ступеньки, лампа… Никого.", 3.5)
	G.save_game()
	busy = false


# ---------- срок вышел: за тобой пришли ----------

func doom(test := false) -> void:
	busy = true
	m.knocking = false
	m.phone_ringing = false
	m.ui.close_dialog()
	m.ui.station_step("")
	m.set_mode("cutscene")
	var eye: Vector3 = m.player.cam.global_position
	var look := Vector3(DOOR.x, 1.3, DOOR.z)
	await m.cine_to(m.look_xf(eye, look), 62.0, 0.8)
	m.world.flicker(2.0)
	await get_tree().create_timer(0.6).timeout
	m.ui.say_sub("Голос за дверью", "Палыч! Время вышло. Открывай.", 3.0)
	for i in 3:
		Sfx.play3d("door_bash", DOOR + Vector3(0, 1.2, 0), 8.0, randf_range(0.85, 1.0), 40.0)
		m.world.flicker(0.3)
		await shake(m.cine, 0.25, 0.03)
		await get_tree().create_timer(0.7 - i * 0.15).timeout
	Sfx.play3d("door_break", DOOR + Vector3(0, 1.2, 0), 10.0, 1.0, 40.0)
	Sfx.play3d("door_bash", DOOR + Vector3(0, 1.2, 0), 8.0, 0.7, 40.0)
	m.world.slam_door()
	m.world.dim = 0.25
	shake(m.cine, 0.4, 0.05)
	var men: Array = []
	for i in 2:
		var n := Npc.new()
		m.world.add_child(n)
		n.setup("suit", "Hair_Buzzed", false)
		n.global_position = Vector3(DOOR.x - 0.25 + i * 0.5, 0.0, DOOR.z + 0.9 + i * 0.6)
		n.face(Vector3(0, 0, -1))
		men.append(n)
	await get_tree().create_timer(0.3).timeout
	var fl := Vector3(eye.x, 0.0, eye.z)
	var dir := (Vector3(DOOR.x, 0, DOOR.z) - fl)
	dir.y = 0.0
	var target := fl + dir.normalized() * 0.75 if dir.length() > 1.0 else fl + Vector3(0, 0, 0.75)
	var lead: Npc = men[0]
	var second: Npc = men[1]
	second.walk_path([Vector3(DOOR.x, 0, DOOR.z - 0.6), target + dir.normalized() * 0.9 + Vector3(0.5, 0, 0)], 2.4)
	m.ui.say_sub("", "", 0.1)
	await lead.walk_path([Vector3(DOOR.x, 0, DOOR.z - 0.6), target], 2.6)
	lead.face_to(Vector3(eye.x, 0, eye.z))
	m.cine.global_transform = m.look_xf(eye, lead.global_position + Vector3(0, 1.55, 0))
	m.ui.say_sub("Человек Хозяина", "Хозяин передаёт привет.", 1.6)
	await get_tree().create_timer(1.1).timeout
	lead.play("Punch_Cross", 0.05)
	await get_tree().create_timer(0.32).timeout
	Sfx.play("hit", 2.0)
	Sfx.play("scare2", -2.0)
	m.ui.flash(0.9)
	await shake(m.cine, 0.25, 0.08)
	m.ui.fade_rect.color.a = 1.0
	m.world.dim = 1.0
	for n in men:
		(n as Node3D).queue_free()
	await get_tree().create_timer(1.2).timeout
	var days := int(G.time / G.DAY_SEC) + 1
	var rec := G.record_run(days)
	await m.ui.big_text("ТЫ НЕ ОТДАЛ ДОЛГ.", 1.6, Color(0.95, 0.3, 0.25))
	await m.ui.big_text("Продержался дней: %d.  Долгов отдано: %d.\nЛучший результат: %d дн." % [days, G.debt_round - 1, int(rec["best_days"])], 2.4)
	await m.ui.big_text("Хозяин нашёл нового должника.", 1.8)
	if test:
		busy = false
		return
	G.reset_game()
	G.set_meta("skip_menu", true)
	get_tree().reload_current_scene()


## Высота лица над ногами персонажа (по кости головы, в текущей позе).
func _face_h(n: Npc) -> float:
	return n.head_attach.global_position.y - n.global_position.y + 0.1


## Тряска камеры.
func shake(cam: Camera3D, sec: float, amp: float) -> void:
	var t := 0.0
	while t < sec:
		t += get_process_delta_time()
		var k := amp * (1.0 - t / sec)
		cam.h_offset = randf_range(-k, k)
		cam.v_offset = randf_range(-k, k)
		await get_tree().process_frame
	cam.h_offset = 0.0
	cam.v_offset = 0.0
