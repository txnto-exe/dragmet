extends Node3D
## Главный сценарий: собирает подвал, игрока, интерфейс; связывает станции, гостей и долг.

const DOOR_POS := Vector3(1.5, 1.4, 4.5)
const PHONE_POS := Vector3(1.6, 1.3, -4.35)
const KOLYAN_SEAT := Vector3(Basement.SEAT_X, 0, -3.5)

const SPEAKERS := {
	"Палыч": [Color(0.95, 0.75, 0.35), 1.05],
	"Колян": [Color(0.55, 0.72, 1.0), 0.9],
	"Скупщик": [Color(0.8, 0.78, 0.6), 0.72],
	"Хозяин": [Color(0.9, 0.25, 0.2), 0.55],
	"": [Color(0.7, 0.68, 0.62), 1.0],
}

var world: Basement
var player: CharacterBody3D
var ui: CanvasLayer
var cine: Camera3D
var post: ColorRect
var dig: DigGame
var buyer: Npc
var kolyan: Npc
var ambience: AudioStreamPlayer

var it_door: Interactable
var it_phone: Interactable
var it_kolyan: Interactable

var knocking := false
var knock_timer := 0.0
var knock_count := 0
var visitor_cooldown := 0.0
var phone_ringing := false
var ring_timer := 0.0
var _board_t := 0.0
var _prev_mode := "walk"
var _shot_dir := ""


func _ready() -> void:
	randomize()
	world = Basement.new()
	add_child(world)
	world.build()

	player = preload("res://scripts/player.gd").new()
	add_child(player)
	player.position = Vector3(1.5, 0, 3.4)
	player.focus_changed.connect(_on_focus)

	cine = Camera3D.new()
	cine.near = 0.02
	add_child(cine)

	var pl := CanvasLayer.new()
	pl.layer = 5
	add_child(pl)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/post.gdshader")
	post.material = sm
	pl.add_child(post)

	ui = preload("res://scripts/ui.gd").new()
	add_child(ui)

	dig = DigGame.new()
	add_child(dig)
	dig.finished.connect(_on_dig_done)

	ambience = AudioStreamPlayer.new()
	ambience.stream = Sfx.looped("ambience")
	ambience.volume_db = -9.0
	add_child(ambience)
	ambience.play()

	_make_interactables()
	_spawn_buyer()
	if G.flags.get("kolyan_in", false):
		_spawn_kolyan(KOLYAN_SEAT, Vector3(-1, 0, 0))
		kolyan.play("Sitting_Idle", 0.0)
		world.stall_lights[0].light_energy = 1.1
		it_kolyan.active = true
	G.deadline_missed.connect(_on_deadline_missed)
	G.changed.connect(_update_board)
	_update_board()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--auto="):
			_shot_dir = a.substr(7)
	if _shot_dir != "":
		_auto_test()
	else:
		_intro()


# ---------- режимы и камера ----------

func set_mode(m: String) -> void:
	G.mode = m
	player.enabled = m == "walk"
	ui.show_hud(m == "walk")
	if m != "walk":
		ui.set_prompt("")
	elif player.focus:
		ui.set_prompt(player.focus.prompt)
	if not G.auto_test:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if m == "walk" else Input.MOUSE_MODE_VISIBLE


func look_xf(from: Vector3, to: Vector3) -> Transform3D:
	return Transform3D(Basis(), from).looking_at(to, Vector3.UP)


func cine_to(xf: Transform3D, fov := 60.0, sec := 0.6) -> void:
	if not cine.current:
		cine.global_transform = player.cam.global_transform
		cine.fov = player.cam.fov
		cine.current = true
	var a := cine.global_transform
	var f0 := cine.fov
	var tw := create_tween()
	tw.tween_method(func(v: float):
		cine.global_transform = a.interpolate_with(xf, v)
		cine.fov = lerpf(f0, fov, v), 0.0, 1.0, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func cine_back(sec := 0.5) -> void:
	if not cine.current:
		return
	await cine_to(player.cam.global_transform, player.cam.fov, sec)
	player.cam.current = true


func talk(who: String, text: String) -> void:
	var sp: Array = SPEAKERS.get(who, SPEAKERS[""])
	await ui.say(who, text, sp[0], sp[1])


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ---------- вступление ----------

func _intro() -> void:
	set_mode("intro")
	if not G.flags.get("intro_done", false):
		await wait(0.8)
		await ui.big_text("Ты должен Хозяину.", 1.4)
		await ui.big_text("3 000 ₽. Три дня.", 1.4)
		await ui.big_text("Из подвала не выпустят,\nпока не отдашь.", 1.8)
		G.flags["intro_done"] = true
		G.save_game()
	await ui.fade(0.0, 2.2)
	set_mode("walk")
	ui.say_sub("", "WASD — ходить · мышь — смотреть · E — действие · Esc — пауза", 7.0)


# ---------- точки взаимодействия ----------

func _make_interactables() -> void:
	Interactable.make(world, Vector3(0, 0.55, -0.2), Vector3(2.5, 1.1, 2.5), "E — порыться в мусоре", _use_trash)
	Interactable.make(world, Vector3(-Basement.W + 0.1, 1.3, 3.0), Vector3(0.5, 0.8, 1.0), "E — окошко скупщика", _use_buyer)
	Interactable.make(world, Vector3(0, 1.3, -4.25), Vector3(0.8, 0.9, 0.4), "E — ящик для долга", _use_debt)
	it_phone = Interactable.make(world, PHONE_POS, Vector3(0.5, 0.9, 0.4), "E — снять трубку", _answer_phone)
	it_phone.active = false
	it_door = Interactable.make(world, Vector3(1.5, 1.1, 4.42), Vector3(1.0, 2.0, 0.3), "E — дверь", _use_door)
	Interactable.make(world, Vector3(-4.25, 1.2, -3.05), Vector3(0.35, 2.0, 2.9), "E — сетка", _use_acid)
	Interactable.make(world, Vector3(-4.45, 0.8, 0.0), Vector3(1.0, 1.6, 2.8), "E — завал", _use_furnace)
	it_kolyan = Interactable.make(world, Vector3(Basement.STALL_X, 1.1, -3.5), Vector3(0.9, 1.4, 1.1), "E — Колян", _use_kolyan)
	it_kolyan.active = false


func _on_focus(target) -> void:
	if G.mode != "walk":
		return
	ui.set_prompt(target.prompt if target else "")


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if e.is_action_pressed("pause"):
		if G.mode == "walk":
			_pause(true)
		elif G.mode == "pause":
			_pause(false)
		return
	if G.mode == "walk":
		if e.is_action_pressed("use") and player.focus:
			player.focus.use()
		elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not G.auto_test:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause(on: bool) -> void:
	if on:
		_prev_mode = G.mode
		set_mode("pause")
		get_tree().paused = true
		ui.show_pause(true, func(): _pause(false), func():
			get_tree().paused = false
			G.reset_game()
			get_tree().reload_current_scene(), func(): get_tree().quit())
	else:
		get_tree().paused = false
		ui.show_pause(false, Callable(), Callable(), Callable())
		set_mode(_prev_mode)


# ---------- мусорка ----------

func _use_trash() -> void:
	if G.bag_full():
		ui.toast("Мешок полон. Неси скупщику.", Color(1, 0.7, 0.4))
		return
	set_mode("dig")
	await cine_to(look_xf(DigGame.SPOT + Vector3(0, 0.62, 0.52), DigGame.SPOT), 52.0, 0.6)
	ui.say_sub("", "Кликай по хламу — раскидать. Под ним что-то блестит. E — отойти.", 3.5)
	dig.start(cine, G.roll_loot(), ui)


func _on_dig_done(item: String) -> void:
	if item != "":
		G.add_item(item)
		var d: Dictionary = G.ITEMS[item]
		ui.toast("Нашёл: %s (≈%s)" % [d["name"], G.rub(G.item_price(item))], G.TIER_COLORS[d["tier"]])
		if G.bag_full():
			ui.toast("Мешок полон. Неси скупщику.", Color(1, 0.7, 0.4))
	await cine_back(0.5)
	set_mode("walk")


# ---------- скупщик ----------

func _spawn_buyer() -> void:
	buyer = Npc.new()
	world.add_child(buyer)
	buyer.setup("buyer", "Hair_SimpleParted", false)
	buyer.position = Vector3(-Basement.W - 0.95, 0, 3.0)
	buyer.face(Vector3(1, 0, 0))
	buyer.play("Idle_FoldArms", 0.0)


func _bag_summary() -> String:
	var parts: Array[String] = []
	for k in G.bag:
		parts.append("%s ×%d" % [G.ITEMS[k]["name"].to_lower(), G.bag[k]])
	return ", ".join(parts)


func _use_buyer() -> void:
	set_mode("dialog")
	buyer.play("Idle_Talking")
	await cine_to(look_xf(Vector3(-Basement.W + 0.75, 1.55, 3.0), Vector3(-Basement.W - 0.95, 1.5, 3.0)), 55.0, 0.6)
	if G.bag_count() == 0:
		await talk("Скупщик", ["Пустой? Не трать моё время.", "Принесёшь — поговорим.", "Чего встал? Иди копай."].pick_random())
	else:
		var v := G.bag_value()
		await talk("Скупщик", "Так-так… %s. Даю %s." % [_bag_summary(), G.rub(v)])
		ui.dlg_name.text = "Скупщик"
		var c: int = await ui.choose(["Отдать за %s" % G.rub(v), "Не, пока оставлю"])
		if c == 0:
			G.sell_all()
			Sfx.play("coins", -4.0)
			ui.toast("+%s" % G.rub(v), Color(0.95, 0.85, 0.4))
			await talk("Скупщик", ["Приятно иметь дело.", "Тащи ещё. Мне всё сгодится.", "Хозяину привет."].pick_random())
			if not G.flags.get("sold_once", false):
				G.flags["sold_once"] = true
				G.flags["sold_at"] = G.time
				G.save_game()
	ui.close_dialog()
	buyer.play("Idle_FoldArms")
	await cine_back()
	set_mode("walk")


# ---------- долг и таксофон ----------

func _update_board() -> void:
	if G.debt > 0:
		world.set_debt_text("ДОЛГ\n%s\n%s" % [G.rub(G.debt), G.left_text()])
	else:
		world.set_debt_text("ДОЛГ\nзакрыт")


func _use_debt() -> void:
	if G.debt <= 0:
		ui.toast("Долг закрыт. Пока.")
		return
	set_mode("dialog")
	await cine_to(look_xf(Vector3(0, 1.5, -3.4), Vector3(0, 1.4, -4.4)), 55.0, 0.6)
	await talk("", "Железный ящик с прорезью. Над ним красной краской: ДОЛГ %s. Осталось %s." % [G.rub(G.debt), G.left_text()])
	var give := mini(G.money, G.debt)
	ui.dlg_name.text = ""
	var c: int = await ui.choose(["Сунуть в щель %s" % G.rub(give) if give > 0 else "Совать нечего", "Отойти"])
	if c == 0 and give > 0:
		G.pay_debt()
		Sfx.play("slot", -2.0)
		ui.toast("−%s в ящик" % G.rub(give), Color(0.95, 0.5, 0.4))
		if G.debt == 0:
			await talk("", "Последняя купюра провалилась в щель. Где-то наверху хлопнула дверь.")
			get_tree().create_timer(5.0).timeout.connect(_start_ring)
	ui.close_dialog()
	await cine_back()
	set_mode("walk")


func _start_ring() -> void:
	phone_ringing = true
	ring_timer = 0.0
	it_phone.active = true
	ui.toast("Звонит таксофон", Color(0.9, 0.85, 0.6))


func _answer_phone() -> void:
	phone_ringing = false
	it_phone.active = false
	set_mode("dialog")
	await cine_to(look_xf(Vector3(1.55, 1.55, -3.75), Vector3(1.6, 1.35, -4.4)), 50.0, 0.5)
	await talk("Хозяин", "Слышу, отдал. Молодец, Палыч.")
	G.start_next_debt()
	await talk("Хозяин", "Следующий взнос — %s. Срок — %s. Не подведи." % [G.rub(G.debt), G.left_text()])
	await talk("Хозяин", "И помни: из подвала выйдешь, только когда я скажу.")
	ui.close_dialog()
	Sfx.play("thud", -10.0)
	await cine_back()
	set_mode("walk")


func _on_deadline_missed() -> void:
	Sfx.play("bad", 0.0)
	ui.flash(0.7)
	ui.big_text("СРОК ВЫШЕЛ\nХозяин недоволен. Теперь должен %s." % G.rub(G.debt), 2.5, Color(0.95, 0.35, 0.3))


# ---------- дверь и гости ----------

func _use_door() -> void:
	if knocking:
		_peephole()
	else:
		ui.toast("Заперто снаружи. Не выпустят, пока не отдашь долг.")
		Sfx.play3d("thud", DOOR_POS, -8.0, 1.3)


func _start_knocking() -> void:
	knocking = true
	knock_timer = 0.0
	knock_count = 0


func _process(dt: float) -> void:
	var m := post.material as ShaderMaterial
	m.set_shader_parameter("rot", G.rot())
	m.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	_board_t -= dt
	if _board_t <= 0.0:
		_board_t = 2.0
		_update_board()
	if visitor_cooldown > 0.0:
		visitor_cooldown -= dt
	if not G.flags.get("kolyan_in", false) and not knocking and visitor_cooldown <= 0.0 and kolyan == null \
			and G.flags.get("sold_once", false) and G.time - float(G.flags.get("sold_at", 0.0)) > 18.0 and G.mode == "walk":
		_start_knocking()
	if knocking and G.mode == "walk":
		knock_timer -= dt
		if knock_timer <= 0.0:
			knock_timer = 7.0
			knock_count += 1
			Sfx.play3d("knock", DOOR_POS, 4.0)
			if knock_count == 1:
				ui.toast("Кто-то стучит в дверь", Color(0.9, 0.85, 0.6))
				ui.say_sub("Голос за дверью", "Палыч! Открой, свои!", 4.0)
			elif knock_count % 3 == 0:
				ui.say_sub("Голос за дверью", "Палыч, ну ты там живой?", 3.0)
	if phone_ringing:
		ring_timer -= dt
		if ring_timer <= 0.0:
			ring_timer = 2.6
			Sfx.play3d("ring", PHONE_POS, 2.0)


func _spawn_kolyan(pos: Vector3, facing: Vector3) -> void:
	kolyan = Npc.new()
	world.add_child(kolyan)
	kolyan.setup("kolyan", "", true, Color(0.18, 0.28, 0.55))
	kolyan.position = pos
	kolyan.face(facing)


func _peephole() -> void:
	knocking = false
	set_mode("peep")
	if kolyan == null:
		_spawn_kolyan(Vector3(1.5, 0, 5.55), Vector3(0, 0, -1))
	kolyan.play("Idle_Talking", 0.0)
	var p := Vector3(1.5, 1.62, 4.63)
	await cine_to(look_xf(p, p + Vector3(0, -0.12, 1)), 110.0, 0.7)
	ui.set_peep(true)
	await talk("Колян", "Палыч, ты? Это я, Колян. С радиозавода, помнишь?")
	await talk("Палыч", "Колян? Ты как меня нашёл?")
	await talk("Колян", "Да весь район знает, что ты Хозяину должен. А у меня завод закрыли — денег ноль.")
	await talk("Колян", "Пусти к себе, а? Руки у меня золотые: перчатки, мешок, фонарь — всё сделаю.")
	ui.dlg_name.text = "Колян"
	var c: int = await ui.choose(["Открыть дверь", "Не сейчас"])
	ui.set_peep(false)
	ui.close_dialog()
	if c == 1:
		await talk("Колян", "Ну… я ещё зайду.")
		ui.close_dialog()
		kolyan.queue_free()
		kolyan = null
		visitor_cooldown = 60.0
		await cine_back()
		set_mode("walk")
		return
	await cine_back(0.5)
	set_mode("walk")
	_kolyan_enters()


func _kolyan_enters() -> void:
	world.open_door(true)
	await wait(1.0)
	kolyan.play("Walk")
	await kolyan.walk_path([Vector3(1.5, 0, 3.9)])
	world.open_door(false)
	await kolyan.walk_path([Vector3(3.3, 0, 2.4), Vector3(4.15, 0, -2.75), Vector3(Basement.SEAT_X, 0, -2.75), KOLYAN_SEAT])
	kolyan.face(Vector3(-1, 0, 0))
	kolyan.sit()
	world.light_stall(0, true)
	G.flags["kolyan_in"] = true
	G.save_game()
	it_kolyan.active = true
	ui.say_sub("Колян", "Ну, обживусь. Подходи, если что надо.", 4.0)


func _use_kolyan() -> void:
	set_mode("dialog")
	kolyan.play("Sitting_Talking")
	await cine_to(look_xf(Vector3(3.95, 1.4, -3.5), Vector3(Basement.SEAT_X, 1.05, -3.5)), 55.0, 0.6)
	var lines := ["Чем подсобить, Палыч?", "Говори, чего надо.", "Руки чешутся — давай работу."]
	var intro_line: String = lines.pick_random()
	while true:
		var keys := G.UPGRADES.keys()
		var opts: Array = []
		for k in keys:
			var u: Dictionary = G.UPGRADES[k]
			if G.upgrade_maxed(k):
				opts.append("%s — уже лучше некуда" % u["name"])
			else:
				opts.append("%s (%s) — %s" % [u["name"], u["desc"], G.rub(G.upgrade_cost(k))])
		opts.append("Поболтать")
		opts.append("Пока")
		ui.dlg_name.text = "Колян"
		ui.dlg_name.add_theme_color_override("font_color", SPEAKERS["Колян"][0])
		var c: int = await ui.choose(opts, intro_line)
		if c < keys.size():
			var k: String = keys[c]
			if G.upgrade_maxed(k):
				intro_line = "Лучше уже не сделаю, Палыч."
			elif G.buy_upgrade(k):
				Sfx.play("coins", -6.0, 0.8)
				ui.toast("%s — уровень %d" % [G.UPGRADES[k]["name"], G.upgrades[k]], Color(0.6, 0.85, 1.0))
				intro_line = ["Сделаем! Держи.", "Во, как новое.", "Готово. С тебя пузырь… шучу."].pick_random()
			else:
				intro_line = "Денег не хватает, Палыч. Тут %s надо." % G.rub(G.upgrade_cost(k))
		elif c == keys.size():
			await talk("Колян", ["Ещё по одной… плате.", "Спина болит, но держусь.", "На заводе хоть обед был.",
				"Хозяин этот… ты его видел вообще?", "Слышишь, как трубы гудят? Как живые."].pick_random())
		else:
			break
	ui.close_dialog()
	kolyan.play("Sitting_Idle")
	await cine_back()
	set_mode("walk")


# ---------- закрытые ниши ----------

func _use_acid() -> void:
	set_mode("dialog")
	await talk("", "За сеткой — ржавая ванна, бутыли с кислотой, противогаз. Тут бы платы травить… Сетка на замке.")
	ui.close_dialog()
	set_mode("walk")


func _use_furnace() -> void:
	set_mode("dialog")
	await talk("", "Старая буржуйка, заваленная кирпичом и досками. Расчистить бы — будет где плавить.")
	ui.close_dialog()
	set_mode("walk")


# ---------- автотест со скриншотами ----------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_dir.path_join(name + ".png"))


func _auto_test() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	ui.fade_rect.color.a = 0.0
	set_mode("walk")
	player.look_at_point(Vector3(0, 0.6, -0.2))
	await wait(2.0)
	await _shot("01_start")
	# проверка мыши: движение в центре экрана должно поворачивать камеру
	var yaw0: float = player.yaw
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(320, 180)
	mm.relative = Vector2(120, 0)
	mm.screen_relative = Vector2(120, 0)
	Input.parse_input_event(mm)
	await wait(0.2)
	print("MOUSE_TEST yaw_change=%.3f %s" % [player.yaw - yaw0, "OK" if absf(player.yaw - yaw0) > 0.2 else "FAIL"])
	player.look_at_point(Vector3(0, 0.6, -0.2))
	player.position = Vector3(1.0, 0, 1.7)
	player.look_at_point(Vector3(0, 0.5, -0.2))
	await wait(0.6)
	await _shot("02_pile")
	_use_trash()
	await wait(1.6)
	await _shot("03_dig")
	for i in 5:
		dig.toss_next()
		await wait(0.3)
	await wait(0.4)
	await _shot("04_dig_found")
	dig.toss_next()
	await wait(1.4)
	G.bag["chips"] = 3
	G.bag["phones"] = 1
	G.changed.emit()
	player.position = Vector3(-4.4, 0, 3.0)
	player.look_at_point(Vector3(-6.5, 1.4, 3.0))
	await wait(0.6)
	await _shot("05_buyer_view")
	_use_buyer()
	await wait(2.8)
	await _shot("06_buyer_dialog")
	ui.advanced.emit()
	await wait(0.6)
	ui.chosen.emit(0)
	await wait(2.0)
	ui.advanced.emit()
	await wait(1.2)
	player.position = Vector3(2.2, 0, 0.2)
	player.look_at_point(Vector3(5.0, 1.0, -1.5))
	await wait(0.5)
	await _shot("07_stalls")
	player.position = Vector3(0.6, 0, -2.0)
	player.look_at_point(Vector3(0, 1.4, -4.4))
	await wait(0.5)
	await _shot("08_debt")
	player.position = Vector3(-2.5, 0, -0.5)
	player.look_at_point(Vector3(-5.0, 1.0, -1.5))
	await wait(0.5)
	await _shot("08b_west")
	player.position = Vector3(1.5, 0, 3.3)
	player.look_at_point(Vector3(1.5, 1.4, 4.5))
	_start_knocking()
	await wait(0.5)
	_peephole()
	await wait(2.6)
	await _shot("09_peephole")
	for i in 3:
		ui.advanced.emit()
		await wait(3.8)
	ui.advanced.emit()
	await wait(0.8)
	ui.chosen.emit(0)
	await wait(4.5)
	player.position = Vector3(2.0, 0, 0.5)
	player.look_at_point(kolyan.global_position + Vector3(0, 1.0, 0))
	await wait(0.3)
	await _shot("10_kolyan_walk")
	await wait(9.0)
	player.position = Vector3(3.3, 0, -2.6)
	player.look_at_point(KOLYAN_SEAT + Vector3(0, 1.0, 0))
	await wait(1.5)
	await _shot("11_kolyan_seated")
	_use_kolyan()
	await wait(1.2)
	await _shot("12_kolyan_menu")
	get_tree().quit()
