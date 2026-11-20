extends Node3D
## Главный сценарий: собирает подвал, игрока, интерфейс; связывает станции, гостей и долг.
## 3D-мир рисуется в отдельном SubViewport в пониженном разрешении (пиксельный вид),
## а интерфейс — поверх в полном разрешении, чтобы текст был чётким.

const DOOR_POS := Vector3(1.5, 1.4, 4.5)
const PHONE_POS := Vector3(1.6, 1.3, -4.35)

const SPEAKERS := {
	"Палыч": [Color(0.95, 0.75, 0.35), 1.05],
	"Колян": [Color(0.55, 0.72, 1.0), 0.9],
	"Скупщик": [Color(0.8, 0.78, 0.6), 0.72],
	"Хозяин": [Color(0.9, 0.25, 0.2), 0.55],
	"": [Color(0.7, 0.68, 0.62), 1.0],
}

var sub: SubViewport
var view: TextureRect
var world: Basement
var player: CharacterBody3D
var ui: CanvasLayer
var cine: Camera3D
var search: BinSearch
var bin: TrashBin
var bin_busy := false
var it_bin: Interactable
var it_acid: Interactable
var it_furnace: Interactable
var _mg_hit := false
var _goal_t := 0.0
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
var _settings_from := ""
var _menu_t := 0.0


## Где стоит «корень» Коляна, чтобы в позе сидя таз пришёлся ровно на табурет.
static func kolyan_seat() -> Vector3:
	return Vector3(Basement.SEAT_X - Basement.SIT_BACK, 0, Basement.STALL_Z[0])


func _ready() -> void:
	randomize()
	# --- 3D-мир в отдельном вьюпорте
	var bg := CanvasLayer.new()
	bg.layer = 0
	add_child(bg)
	sub = SubViewport.new()
	sub.own_world_3d = true
	sub.audio_listener_enable_3d = true
	sub.msaa_3d = Viewport.MSAA_DISABLED
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.positional_shadow_atlas_size = 4096
	add_child(sub)
	view = TextureRect.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.texture = sub.get_texture()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/post.gdshader")
	view.material = sm
	bg.add_child(view)
	Sfx.world_root = sub

	world = Basement.new()
	sub.add_child(world)
	world.build()

	player = preload("res://scripts/player.gd").new()
	sub.add_child(player)
	player.position = Vector3(1.5, 0, 3.4)
	player.focus_changed.connect(_on_focus)

	cine = Camera3D.new()
	cine.near = 0.02
	sub.add_child(cine)

	ui = preload("res://scripts/ui.gd").new()
	add_child(ui)
	ui.menu_action.connect(_on_menu_action)

	search = BinSearch.new()
	sub.add_child(search)
	search.finished.connect(_on_search_done)

	ambience = AudioStreamPlayer.new()
	ambience.stream = Sfx.looped("ambience")
	ambience.volume_db = -9.0
	ambience.bus = "Ambience"
	add_child(ambience)
	ambience.play()

	_make_interactables()
	_new_bin()
	if G.upgrades["acid"] > 0:
		world.open_acid()
	if G.upgrades["furnace"] > 0:
		world.open_furnace()
	_refresh_station_prompts()
	_spawn_buyer()
	if G.flags.get("kolyan_in", false):
		_spawn_kolyan(kolyan_seat(), Vector3(-1, 0, 0))
		kolyan.play("Sitting_Idle", 0.0)
		world.stall_lights[0].light_energy = 1.1
		it_kolyan.active = true
	G.deadline_missed.connect(_on_deadline_missed)
	G.changed.connect(_update_board)
	_update_board()

	get_window().size_changed.connect(_apply_view)
	Settings.changed.connect(_apply_view)
	_apply_view()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--auto="):
			_shot_dir = a.substr(7)
	if _shot_dir != "":
		_auto_test()
	elif G.has_meta("skip_menu"):
		G.remove_meta("skip_menu")
		_start_game()
	else:
		_main_menu()


## Размер 3D-картинки: окно / целый множитель (чтобы пиксели были ровные).
func _apply_view() -> void:
	var win := Vector2(get_window().size)
	if win.x < 8 or win.y < 8:
		return
	var ph := Settings.pixel_height()
	var f := 1.0
	if ph > 0:
		f = maxf(1.0, round(win.y / ph))
	var s := Vector2i(maxi(1, int(win.x / f)), maxi(1, int(win.y / f)))
	sub.size = s
	var m := view.material as ShaderMaterial
	m.set_shader_parameter("low_res", Vector2(s))
	m.set_shader_parameter("brightness", float(Settings.get_v("brightness")))
	var q := int(Settings.get_v("quality"))
	sub.positional_shadow_atlas_size = [1024, 2048, 4096][clampi(q, 0, 2)]
	world.apply_quality(q)


# ---------- ввод: пересылаем в 3D-вьюпорт ----------

func _input(e: InputEvent) -> void:
	var ev := e
	if e is InputEventMouse:
		ev = e.duplicate()
		var vs := get_viewport().get_visible_rect().size
		(ev as InputEventMouse).position = (e as InputEventMouse).position / vs * Vector2(sub.size)
		(ev as InputEventMouse).global_position = (ev as InputEventMouse).position
	sub.push_input(ev, true)


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


# ---------- главное меню ----------

func _main_menu() -> void:
	set_mode("menu")
	cine.global_transform = look_xf(Vector3(3.6, 1.75, 3.7), Vector3(-0.3, 0.6, -0.8))
	cine.fov = 62.0
	cine.current = true
	ui.show_main_menu(G.flags.get("intro_done", false))
	await ui.fade(0.0, 1.6)


func _start_game() -> void:
	ui.clear_menus()
	set_mode("intro")
	await ui.fade(1.0, 0.5)
	player.cam.current = true
	_intro()


func _on_menu_action(a: String) -> void:
	match a:
		"continue":
			_start_game()
		"new":
			if G.flags.get("intro_done", false):
				ui.show_confirm("Начать заново? Текущее сохранение пропадёт.", "new_yes", "to_main")
			else:
				_on_menu_action("new_yes")
		"new_yes":
			G.reset_game()
			G.set_meta("skip_menu", true)
			ui.clear_menus()
			await ui.fade(1.0, 0.4)
			get_tree().paused = false
			get_tree().reload_current_scene()
		"to_main":
			ui.show_main_menu(G.flags.get("intro_done", false))
		"settings":
			_settings_from = ui.menu_open
			ui.show_settings()
		"settings_back":
			if _settings_from == "pause":
				ui.show_pause_menu()
			else:
				ui.show_main_menu(G.flags.get("intro_done", false))
		"back":
			match ui.menu_open:
				"settings":
					_on_menu_action("settings_back")
				"pause":
					_pause(false)
				"confirm":
					_on_menu_action("to_main")
		"resume":
			_pause(false)
		"to_menu":
			G.save_game()
			ui.clear_menus()
			await ui.fade(1.0, 0.3)
			get_tree().paused = false
			get_tree().reload_current_scene()
		"quit":
			G.save_game()
			get_tree().quit()


# ---------- вступление ----------

func _intro() -> void:
	set_mode("intro")
	if not G.flags.get("intro_done", false):
		await wait(0.6)
		await ui.big_text("Ты должен Хозяину.", 1.4)
		await ui.big_text("3 000 ₽. Три дня.", 1.4)
		await ui.big_text("Из подвала не выпустят,\nпока не отдашь.", 1.8)
		G.flags["intro_done"] = true
		G.save_game()
	await ui.fade(0.0, 2.0)
	set_mode("walk")


# ---------- точки взаимодействия ----------

func _make_interactables() -> void:
	it_bin = Interactable.make(world, Basement.LIFT + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 1.25), "Бак", _use_bin)
	Interactable.make(world, Vector3(-Basement.W + 0.1, 1.3, 3.0), Vector3(0.5, 0.8, 1.0), "Скупщик", _use_buyer)
	Interactable.make(world, Basement.DEBT_BOX + Vector3(0, 0.6, 0.05), Vector3(0.75, 1.3, 0.55), "Ящик для долга", _use_debt)
	it_phone = Interactable.make(world, PHONE_POS, Vector3(0.5, 0.9, 0.4), "Телефон", _answer_phone)
	it_phone.active = false
	it_door = Interactable.make(world, Vector3(1.5, 1.1, 4.42), Vector3(1.0, 2.0, 0.3), "Дверь", _use_door)
	it_acid = Interactable.make(world, Vector3(-4.6, 1.0, -3.05), Vector3(1.0, 2.0, 2.8), "Сетка", _use_acid)
	it_furnace = Interactable.make(world, Vector3(-4.6, 0.8, 0.0), Vector3(1.2, 1.6, 2.6), "Завал", _use_furnace)
	it_kolyan = Interactable.make(world, Vector3(Basement.STALL_X, 1.1, Basement.STALL_Z[0]), Vector3(0.9, 1.4, 1.1), "Колян", _use_kolyan)
	it_kolyan.active = false


func _on_focus(target) -> void:
	if G.mode != "walk":
		return
	ui.set_prompt(target.prompt if target else "")


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("fullscreen"):
		Settings.set_v("window", 2 if int(Settings.get_v("window")) == 0 else 0)
		return
	if e.is_action_pressed("pause"):
		if G.mode == "walk":
			_pause(true)
		return
	if G.mode == "mini":
		if e.is_action_pressed("use") or (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
			_mg_hit = true
		return
	if G.mode == "walk":
		if e.is_action_pressed("use") and player.focus:
			player.focus.use()
		elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not G.auto_test:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	# свернул игру / переключился на другое окно — ставим на паузу
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and G.mode == "walk" and not G.auto_test:
		_pause(true)


func _pause(on: bool) -> void:
	if on:
		_prev_mode = G.mode
		set_mode("pause")
		get_tree().paused = true
		ui.show_pause_menu()
	else:
		ui.clear_menus()
		get_tree().paused = false
		set_mode(_prev_mode)
		G.save_game()


# ---------- бак на подъёмнике ----------

func _new_bin() -> void:
	bin = TrashBin.new()
	world.lift.add_child(bin)
	bin.build(G.roll_bin_type(), world)
	search.fill(bin, world, G.finds_per_bin())


func _use_bin() -> void:
	if bin_busy:
		return
	if G.bag_full():
		ui.toast("Мешок полон", Color(1, 0.7, 0.4))
		return
	set_mode("dig")
	var c := Basement.LIFT
	# смотрим почти сверху: передняя стенка не загораживает хлам у переднего края
	await cine_to(look_xf(c + Vector3(0, 2.3, 0.32), c + Vector3(0, 0.45, -0.03)), 46.0, 0.6)
	search.start(cine, ui)


func _on_search_done(emptied: bool) -> void:
	await cine_back(0.5)
	set_mode("walk")
	if emptied:
		G.bins += 1
		G.save_game()
		ui.toast("Бак пуст", Color(0.9, 0.85, 0.6))
		_cycle_bin()


## Пустой бак уезжает вниз, люк закрывается, снизу выезжает новый.
func _cycle_bin() -> void:
	bin_busy = true
	it_bin.active = false
	world.set_beacon(true)
	await wait(0.6)
	await world.lift_move(false)
	await world.hatch(false)
	bin.queue_free()
	_new_bin()
	await wait(0.9)
	await world.hatch(true)
	await world.lift_move(true)
	world.set_beacon(false)
	bin_busy = false
	it_bin.active = true
	var info: Dictionary = G.BIN_TYPES[bin.type]
	if bin.type == "military":
		Sfx.play("good", -2.0, 0.8)
		ui.toast("Бак: %s" % String(info["name"]).to_lower(), G.TIER_COLORS[3])
	else:
		ui.toast("Бак: %s" % String(info["name"]).to_lower(), (info["color"] as Color).lightened(0.5))


# ---------- скупщик ----------

func _spawn_buyer() -> void:
	buyer = Npc.new()
	world.add_child(buyer)
	buyer.setup("buyer", "Hair_SimpleParted", false)
	buyer.position = Vector3(-Basement.W - 1.05, 0, 3.0)
	buyer.face(Vector3(1, 0, 0))
	buyer.play("Idle_FoldArms", 0.0)


func _bag_summary() -> String:
	var parts: Array[String] = []
	for k in G.bag:
		parts.append("%s ×%d" % [G.ITEMS[k]["name"].to_lower(), G.bag[k]])
	if G.dust > 0.0001:
		parts.append("золотой порошок %s" % G.grams(G.dust))
	if G.ingots > 0.0001:
		parts.append("слитки %s" % G.grams(G.ingots))
	return ", ".join(parts)


func _use_buyer() -> void:
	set_mode("dialog")
	buyer.play("Idle_Talking")
	await cine_to(look_xf(Vector3(-Basement.W + 0.75, 1.55, 3.0), Vector3(-Basement.W - 0.95, 1.5, 3.0)), 55.0, 0.6)
	if not G.has_goods():
		await talk("Скупщик", ["Пустой? Не трать моё время.", "Принесёшь — поговорим.", "Чего встал? Иди копай."].pick_random())
	else:
		var v := G.sell_value()
		await talk("Скупщик", "Так-так… %s. Даю %s." % [_bag_summary(), G.rub(v)])
		if G.bag_count() > 0 and G.upgrades["acid"] > 0 and not G.flags.get("buyer_hint", false):
			G.flags["buyer_hint"] = true
			await talk("Скупщик", "Сырьё беру дёшево. Вытравишь золото кислотой — дам больше.")
		var c: int = await ui.choose(["Отдать за %s" % G.rub(v), "Не, пока оставлю"], "", "Скупщик", true, 1)
		if c == 0:
			G.sell_all()
			G.flags["sales"] = G.sales() + 1
			G.save_game()
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
		world.set_debt_text("ДОЛГ\nЗАКРЫТ")


func _use_debt() -> void:
	if G.debt <= 0:
		ui.toast("Долг закрыт. Пока.")
		return
	set_mode("dialog")
	var b := Basement.DEBT_BOX
	await cine_to(look_xf(Vector3(b.x + 0.2, 1.55, -3.3), Vector3(b.x, 1.15, -4.4)), 55.0, 0.6)
	await talk("", "Железный шкаф с прорезью. Над ним красной краской: ДОЛГ %s. Осталось %s." % [G.rub(G.debt), G.left_text()])
	var give := mini(G.money, G.debt)
	var opts := ["Сунуть в щель %s" % G.rub(give) if give > 0 else "Совать нечего", "Отойти"]
	var c: int = await ui.choose(opts, "", "", true, 1, [] if give > 0 else [0])
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
	# страховка: если игрок как-то оказался за дверью или провалился — возвращаем в подвал
	if player.position.z > Basement.D - 0.05 or player.position.y < -0.5:
		player.position = Vector3(Basement.DOOR_X, 0.05, Basement.D - 0.6)
		player.velocity = Vector3.ZERO
	var m := view.material as ShaderMaterial
	m.set_shader_parameter("rot", G.rot())
	m.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
	if G.mode == "menu" and cine.current:
		_menu_t += dt
		cine.global_transform = look_xf(Vector3(3.6 + sin(_menu_t * 0.12) * 0.4, 1.75 + sin(_menu_t * 0.2) * 0.05, 3.7),
			Vector3(-0.3 + sin(_menu_t * 0.09) * 0.8, 0.6, -0.8))
	_goal_t -= dt
	if _goal_t <= 0.0:
		_goal_t = 0.5
		ui.set_goal(_goal_text())
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
	var c: int = await ui.choose(["Открыть дверь", "Не сейчас"], "", "Колян", false, 1)
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
	var seat := kolyan_seat()
	var gap_z: float = (Basement.STALL_Z[0] + Basement.STALL_Z[1]) * 0.5
	await kolyan.walk_path([Vector3(3.4, 0, 2.0), Vector3(3.85, 0, gap_z), Vector3(seat.x - 0.05, 0, gap_z), seat])
	kolyan.face(Vector3(-1, 0, 0))
	kolyan.sit()
	world.light_stall(0, true)
	G.flags["kolyan_in"] = true
	G.save_game()
	it_kolyan.active = true
	ui.say_sub("Колян", "Ну, обживусь. Подходи, если что надо.", 4.0)


func _upgrade_items() -> Array:
	var out: Array = []
	for k in G.UPGRADES:
		var u: Dictionary = G.UPGRADES[k]
		if u.get("quest", false):
			continue
		var it := {"key": k, "name": u["name"], "desc": String(u["desc"]).substr(0, 1).to_upper() + String(u["desc"]).substr(1),
			"level": G.upgrades[k], "max": u["max"], "cost": G.upgrade_cost(k)}
		if G.upgrade_locked(k):
			it["locked"] = "Сначала: " + String(G.UPGRADES[u["needs"]]["name"]).to_lower()
		if int(u["max"]) == 1 and G.upgrades[k] >= 1:
			it["done"] = "Сделано"
		out.append(it)
	return out


func _buy_upgrade(k: String) -> bool:
	if G.upgrade_maxed(k):
		ui.shop_say("Лучше уже не сделаю, Палыч.")
		return false
	if G.buy_upgrade(k):
		Sfx.play("coins", -6.0, 0.8)
		match k:
			"acid":
				Sfx.play3d("snip", Vector3(-4.25, 1.2, -3.0), 2.0)
				world.open_acid()
				ui.toast("Сетка открыта", Color(0.6, 0.95, 0.5))
				ui.shop_say("Перекусил. Только руки в ванну не суй.")
			"furnace":
				Sfx.play3d("thud", Vector3(-4.6, 0.6, 0.0), 2.0)
				world.open_furnace()
				ui.toast("Печь свободна", Color(1.0, 0.7, 0.4))
				ui.shop_say("Разгрёб. Буржуйка живая, мехи нашёл.")
			_:
				ui.toast("%s — уровень %d" % [G.UPGRADES[k]["name"], G.upgrades[k]], Color(0.6, 0.85, 1.0))
				ui.shop_say(["Сделаем! Держи.", "Во, как новое.", "Готово. С тебя пузырь… шучу."].pick_random())
		_refresh_station_prompts()
		return true
	ui.shop_say("Денег не хватает, Палыч.")
	return false


func _use_kolyan() -> void:
	set_mode("dialog")
	kolyan.play("Sitting_Talking")
	var z: float = Basement.STALL_Z[0]
	await cine_to(look_xf(Vector3(3.75, 1.45, z + 0.15), Vector3(Basement.SEAT_X - 0.15, 1.0, z)), 55.0, 0.6)
	var line: String = ["Чем подсобить, Палыч?", "Говори, чего надо.", "Руки чешутся — давай работу."].pick_random()
	await _kolyan_offer_quest()
	while true:
		var q := _active_quest()
		var opts: Array = []
		var disabled: Array = []
		if q != "":
			opts.append(_quest_option(q))
			if not _quest_ready(q):
				disabled.append(0)
		var off := opts.size()
		opts.append_array(["Что можешь сделать?", "Как жизнь?", "Пока"])
		var c: int = await ui.choose(opts, line, "Колян", true, opts.size() - 1, disabled)
		if q != "" and c == 0:
			await _complete_quest(q)
			line = "Ну, чем ещё помочь?"
			continue
		c -= off
		if c == 0:
			await ui.open_shop("Точка Коляна", "Выбирай, что улучшить. Деньги вперёд.", _upgrade_items, _buy_upgrade)
			line = ["Ещё чего?", "Заходи, если что.", "Ну, работаем."].pick_random()
		elif c == 1:
			await talk("Колян", ["Ещё по одной… плате.", "Спина болит, но держусь.", "На заводе хоть обед был.",
				"Хозяин этот… ты его видел вообще?", "Слышишь, как трубы гудят? Как живые."].pick_random())
			line = "Ну так что?"
		else:
			break
	ui.close_dialog()
	kolyan.play("Sitting_Idle")
	await cine_back()
	set_mode("walk")


# ---------- поручения Коляна: ключ от сетки и лом для завала ----------

func _kolyan_offer_quest() -> void:
	if G.upgrades["acid"] == 0 and G.quest_stage("acid") == 0 and G.sales() >= 5:
		G.flags["q_acid"] = 1
		G.save_game()
		await talk("Колян", "Слышь, Палыч… Я тут под прилавком ключ нашёл. Похоже, от замка на сетке, где кислота.")
		await talk("Колян", "Отдам, не жалко. Только подгони мне старый телефон и пару микросхем — радио себе соберу.")
	elif G.upgrades["acid"] > 0 and G.upgrades["furnace"] == 0 and G.quest_stage("furnace") == 0 and G.sales() >= 10:
		G.flags["q_furnace"] = 1
		G.save_game()
		await talk("Колян", "За буржуйкой лом валялся, я припрятал. Им завал у печи за пять минут разгребёшь.")
		await talk("Колян", "Уважь только: принеси щепоть золотого порошка, грамм 0,1. Коронку себе отолью.")


func _active_quest() -> String:
	if G.upgrades["acid"] == 0 and G.quest_stage("acid") == 1:
		return "acid"
	if G.upgrades["furnace"] == 0 and G.quest_stage("furnace") == 1:
		return "furnace"
	return ""


func _quest_ready(q: String) -> bool:
	if q == "acid":
		return int(G.bag.get("phones", 0)) >= 1 and int(G.bag.get("chips", 0)) >= 2
	return G.dust >= 0.0999


func _quest_option(q: String) -> String:
	if q == "acid":
		var ph := mini(int(G.bag.get("phones", 0)), 1)
		var ch := mini(int(G.bag.get("chips", 0)), 2)
		return "Отдать телефон (%d/1) и микросхемы (%d/2) — за ключ от сетки" % [ph, ch]
	return "Отдать 0,10 г золотого порошка (есть %s) — за лом" % G.grams(G.dust)


func _take_item(k: String, n: int) -> void:
	G.bag[k] = int(G.bag.get(k, 0)) - n
	if G.bag[k] <= 0:
		G.bag.erase(k)


func _complete_quest(q: String) -> void:
	if q == "acid":
		_take_item("phones", 1)
		_take_item("chips", 2)
		G.flags["q_acid"] = 2
		G.upgrades["acid"] = 1
		G.changed.emit()
		G.save_game()
		await talk("Колян", "Во, то что надо. Держи ключ. Только руки в ванну не суй.")
		ui.close_dialog()
		Sfx.play3d("snip", Vector3(-4.25, 1.2, -3.0), 2.0)
		world.open_acid()
		ui.toast("Сетка открыта", Color(0.6, 0.95, 0.5))
	else:
		G.dust = maxf(0.0, G.dust - 0.1)
		G.flags["q_furnace"] = 2
		G.upgrades["furnace"] = 1
		G.changed.emit()
		G.save_game()
		await talk("Колян", "Блестит… Красота. Лом за печкой, бери. Завал сам разгребёшь — я спину берегу.")
		ui.close_dialog()
		await ui.fade(1.0, 0.4)
		for i in 3:
			Sfx.play3d("thud", Vector3(-4.6, 0.6, 0.0), 2.0, randf_range(0.8, 1.1))
			await wait(0.35)
		world.open_furnace()
		await ui.fade(0.0, 0.5)
		ui.toast("Печь свободна", Color(1.0, 0.7, 0.4))
	_refresh_station_prompts()


# ---------- кислота и печь ----------

func _refresh_station_prompts() -> void:
	it_acid.prompt = "Кислота" if G.upgrades["acid"] > 0 else "Сетка"
	it_furnace.prompt = "Печь" if G.upgrades["furnace"] > 0 else "Завал"


func _use_acid() -> void:
	if G.upgrades["acid"] <= 0:
		set_mode("dialog")
		var extra := " Ключ у Коляна — просил телефон и пару микросхем." if G.quest_stage("acid") == 1 else ""
		await talk("", "За сеткой — ржавая ванна с кислотой. Тут бы платы травить… Сетка на замке." + extra)
		ui.close_dialog()
		set_mode("walk")
		return
	if G.bag_count() == 0:
		ui.toast("Мешок пустой", Color(1, 0.7, 0.4))
		return
	set_mode("mini")
	var tub := Vector3(-5.4, 0.5, -3.55)
	await cine_to(look_xf(Vector3(-4.45, 1.5, -2.85), tub), 55.0, 0.6)
	var basket := world.acid_basket
	basket.position.y = 1.2
	basket.visible = true
	var tw := create_tween()
	tw.tween_property(basket, "position:y", 0.62, 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished
	Sfx.play3d("sizzle", tub, 2.0)
	var loop := _loop3d("bubbles", tub, -6.0)
	ui.mg_show("Травление", "Вытащи, пока стрелка в зелёном.")
	var total := 0.0
	var rounds := 3
	for r in rounds:
		var zc := randf_range(0.58, 0.82)
		var zw := 0.17 - r * 0.035
		var speed := 0.32 + r * 0.1
		var x := 0.0
		_mg_hit = false
		var q := 0.3
		while true:
			var dt := get_process_delta_time()
			x += dt * speed * (1.0 + 0.5 * sin(x * 9.0 + r))
			if G.auto_test and absf(x - zc) < 0.015:
				_mg_hit = true
			world.acid_mat.emission_energy_multiplier = 1.6 + x * 3.0
			world.acid_glow.light_energy = 0.6 + x * 1.2
			ui.mg_set(x, zc - zw * 0.5, zc + zw * 0.5, Color(0.35, 0.75, 0.3, 0.85), -1.0, "Окунание %d из %d" % [r + 1, rounds])
			if randf() < dt * (1.0 + x * 3.0):
				Sfx.play3d("sizzle", tub, -6.0, randf_range(0.8, 1.3))
			if _mg_hit or x >= 1.0:
				var d := absf(x - zc)
				if d <= zw * 0.5:
					q = 1.0 - d / (zw * 0.5) * 0.12
					Sfx.play("good", -6.0)
				else:
					q = clampf(0.88 - (d - zw * 0.5) * 2.8, 0.3, 0.88)
					Sfx.play("thud", -8.0, 1.3)
				break
			await get_tree().process_frame
		total += q
		ui.mg_set(x, zc - zw * 0.5, zc + zw * 0.5, Color(0.35, 0.75, 0.3, 0.85), -1.0, "Окунание %d: %d%%" % [r + 1, int(q * 100)])
		var up := create_tween()
		up.tween_property(basket, "position:y", 0.9, 0.25)
		up.tween_property(basket, "position:y", 0.62, 0.35)
		await up.finished
	var quality := total / rounds
	loop.queue_free()
	world.acid_mat.emission_energy_multiplier = 1.6
	world.acid_glow.light_energy = 0.6
	var out := create_tween()
	out.tween_property(basket, "position:y", 1.2, 0.6)
	await out.finished
	basket.visible = false
	ui.mg_hide()
	var g := G.etch_bag(quality)
	var verdict := "Идеально!" if quality >= 0.95 else ("Неплохо." if quality >= 0.8 else "Много ушло в кислоту.")
	ui.toast("Вытравил %s золота (качество %d%%). %s" % [G.grams(g), int(quality * 100), verdict], Color(0.95, 0.85, 0.4))
	Sfx.play("coins", -6.0, 1.2)
	await cine_back()
	set_mode("walk")


func _use_furnace() -> void:
	if G.upgrades["furnace"] <= 0:
		set_mode("dialog")
		var extra := " Колян говорил про лом — за щепоть порошка." if G.quest_stage("furnace") == 1 else ""
		await talk("", "Старая буржуйка, заваленная кирпичом и досками. Расчистить бы — будет где плавить." + extra)
		ui.close_dialog()
		set_mode("walk")
		return
	if G.dust <= 0.0001:
		ui.toast("Нет порошка", Color(1, 0.7, 0.4))
		return
	set_mode("mini")
	await cine_to(look_xf(Vector3(-4.2, 1.35, 0.95), Vector3(-5.3, 0.6, 0.1)), 58.0, 0.6)
	var fire := _loop3d("fire", Vector3(-5.3, 0.5, 0.0), -10.0)
	ui.mg_show("Плавка", "Держи жар в жёлтом.")
	var temp := 0.15
	var prog := 0.0
	var loss := 0.0
	var t := 0.0
	var pumping := false
	while prog < 1.0:
		var dt := get_process_delta_time()
		t += dt
		var zc := 0.55 + 0.14 * sin(t * 0.9) + 0.05 * sin(t * 2.3)
		var zw := 0.2
		var hold := Input.is_action_pressed("use") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if G.auto_test:
			hold = temp < zc
		if hold and not pumping:
			Sfx.play("bellows", -6.0, randf_range(0.9, 1.1))
		pumping = hold
		temp = clampf(temp + (0.5 if hold else -0.3) * dt, 0.0, 1.0)
		world.pump_bellows((0.5 + 0.5 * sin(t * 12.0)) if hold else 0.0)
		if absf(temp - zc) <= zw * 0.5:
			prog += dt / 6.0
		if temp > 0.9:
			loss = minf(0.5, loss + dt * 0.12)
			if randf() < dt * 3.0:
				ui.flash(0.15)
		world.furnace_light.light_energy = 0.3 + temp * 3.2
		world.crucible_mat.emission_energy_multiplier = temp * 4.0
		fire.volume_db = -14.0 + temp * 12.0
		ui.mg_set(temp, zc - zw * 0.5, zc + zw * 0.5, Color(0.95, 0.75, 0.25, 0.85), prog,
			"Расплавлено %d%%   ·   потери %d%%" % [int(prog * 100), int(loss * 100)])
		await get_tree().process_frame
	fire.queue_free()
	world.pump_bellows(0.0)
	world.furnace_light.light_energy = 0.25
	world.crucible_mat.emission_energy_multiplier = 0.0
	ui.mg_hide()
	var g := G.melt_dust(1.0 - loss)
	Sfx.play("clank", -4.0, 1.4)
	Sfx.play("coins", -6.0, 1.1)
	ui.toast("Отлил слиток: %s золота%s" % [G.grams(g), " — без потерь!" if loss < 0.01 else ""], Color(1.0, 0.8, 0.35))
	await cine_back()
	set_mode("walk")


func _loop3d(name: String, pos: Vector3, vol: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = Sfx.looped(name)
	p.volume_db = vol
	p.bus = "SFX"
	p.unit_size = 3.0
	world.add_child(p)
	p.global_position = pos
	p.play()
	return p


# ---------- цель в углу экрана ----------

func _goal_text() -> String:
	if phone_ringing:
		return "сними трубку таксофона"
	if knocking:
		return "кто-то стучит — подойди к двери"
	if not G.flags.get("sold_once", false):
		if G.bag_count() == 0:
			return "поройся в баке в центре подвала"
		return "отнеси находки скупщику — окошко у левой стены"
	if G.debt > 0 and G.money >= G.debt:
		return "отдай долг — железный шкаф у дальней стены"
	if _active_quest() == "acid":
		return "Колян отдаст ключ от сетки за старый телефон и 2 микросхемы"
	if _active_quest() == "furnace":
		return "Колян отдаст лом за 0,10 г золотого порошка"
	if G.flags.get("kolyan_in", false) and G.upgrades["acid"] == 0 and G.sales() >= 5 and G.quest_stage("acid") == 0:
		return "Колян хотел что-то сказать — загляни к нему"
	if G.upgrades["furnace"] == 0 and G.upgrades["acid"] > 0 and G.sales() >= 10 and G.quest_stage("furnace") == 0:
		return "Колян хотел что-то сказать — загляни к нему"
	if G.upgrades["acid"] > 0 and G.bag_count() >= 3:
		return "протрави находки в кислоте — золото дороже сырья"
	if G.dust > 0.0001 and G.upgrades["furnace"] > 0:
		return "переплавь порошок в печи — слиток ещё дороже"
	if G.has_goods() and (G.bag_full() or G.dust > 0.0001 or G.ingots > 0.0001):
		return "продай всё скупщику"
	if G.debt > 0:
		return "собери %s к сроку" % G.rub(G.debt)
	return "копи и вкладывайся в точку Коляна"


# ---------- автотест со скриншотами ----------

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_dir.path_join(name + ".png"))


func _adv() -> void:
	for i in 400:
		if ui.dlg.visible and not ui._typing and not ui._choosing:
			break
		await get_tree().process_frame
	await wait(0.2)
	ui.advanced.emit()


func _pick(i: int) -> void:
	for k in 600:
		if ui._choosing:
			break
		await get_tree().process_frame
	await wait(0.3)
	ui.chosen.emit(i)


func _auto_test() -> void:
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	_main_menu()
	await wait(2.0)
	await _shot("00_menu")
	ui.clear_menus()
	ui.fade_rect.color.a = 0.0
	player.cam.current = true
	set_mode("walk")
	# проверка мыши
	var yaw0: float = player.yaw
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(640, 360)
	mm.relative = Vector2(120, 0)
	mm.screen_relative = Vector2(120, 0)
	Input.parse_input_event(mm)
	await wait(0.2)
	print("MOUSE_TEST yaw_change=%.3f %s" % [player.yaw - yaw0, "OK" if absf(player.yaw - yaw0) > 0.18 * float(Settings.get_v("sens")) else "FAIL"])
	player.position = Vector3(1.1, 0, 1.6)
	player.look_at_point(Basement.LIFT + Vector3(0, 0.6, 0))
	await wait(0.8)
	print("FOCUS_TEST bin=%s" % [player.focus.prompt if player.focus else "NONE"])
	await _shot("01_bin")
	_use_bin()
	await wait(1.4)
	await _shot("02_bin_inside")
	var steps := 0
	while search.running and steps < 120:
		search.auto_step()
		steps += 1
		await wait(0.12)
		if steps == 12:
			await _shot("03_bin_digging")
	print("BIN_TEST steps=%d bag=%d left=%d" % [steps, G.bag_count(), search.finds_left()])
	await wait(1.2)
	player.position = Vector3(1.6, 0, 1.4)
	player.look_at_point(Basement.LIFT)
	await wait(2.6)
	await _shot("04_bin_down")
	await wait(4.5)
	await _shot("05_bin_new")
	print("BIN_CYCLE busy=%s type=%s" % [bin_busy, bin.type])
	# скупщик
	G.bag["chips"] = 3
	G.bag["phones"] = 1
	G.changed.emit()
	player.position = Vector3(-4.4, 0, 3.0)
	player.look_at_point(Vector3(-6.5, 1.4, 3.0))
	_use_buyer()
	await wait(2.0)
	await _adv()
	await wait(0.6)
	await _shot("06_buyer_dialog")
	await _pick(0)
	await wait(1.5)
	await _adv()
	await wait(1.0)
	# Колян приходит
	player.position = Vector3(1.5, 0, 3.3)
	player.look_at_point(Vector3(1.5, 1.4, 4.5))
	_start_knocking()
	await wait(0.3)
	_peephole()
	for i in 4:
		await _adv()
	await _pick(0)
	await wait(14.0)
	# дверь открыта — пытаемся выбежать в коридор
	world.open_door(true)
	await wait(1.0)
	player.position = Vector3(Basement.DOOR_X, 0.05, Basement.D - 0.5)
	player.look_at_point(Vector3(Basement.DOOR_X, 1.4, Basement.D + 3.0))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await wait(2.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("DOOR_TEST z=%.2f %s" % [player.position.z, "OK" if player.position.z < Basement.D else "FAIL"])
	world.open_door(false)
	await wait(0.6)
	player.position = Vector3(3.2, 0, -2.5)
	player.look_at_point(kolyan_seat() + Vector3(0.3, 0.9, 0))
	await wait(1.5)
	await _shot("07_kolyan_seated")
	player.position = Vector3(4.0, 0, -1.2)
	player.look_at_point(kolyan_seat() + Vector3(0.3, 0.7, 0))
	await wait(0.5)
	await _shot("07b_kolyan_side")
	G.money = 3000
	G.flags["sales"] = 5
	G.bag = {"phones": 1, "chips": 2}
	G.changed.emit()
	_use_kolyan()
	await _adv()
	await _adv()
	for k in 300:
		if ui._choosing:
			break
		await get_tree().process_frame
	await wait(0.4)
	await _shot("08_kolyan_quest")
	await _pick(0)
	await _adv()
	await wait(1.0)
	await _pick(0)
	await wait(0.6)
	await _shot("09_kolyan_shop")
	ui.close_shop()
	await _pick(2)
	await wait(1.5)
	print("QUEST_ACID acid=%d bag=%d" % [G.upgrades["acid"], G.bag_count()])
	# кислота
	G.bag = {"chips": 4, "ram": 2, "phones": 2}
	G.changed.emit()
	player.position = Vector3(-3.6, 0, -3.0)
	player.look_at_point(Vector3(-5.4, 0.6, -3.5))
	await wait(0.6)
	await _shot("10_acid_open")
	_use_acid()
	await wait(2.6)
	await _shot("11_acid_game")
	while G.mode == "mini":
		await wait(0.2)
	await wait(1.0)
	print("ACID_TEST dust=%.3f" % G.dust)
	G.flags["sales"] = 10
	_use_kolyan()
	await _adv()
	await _adv()
	await _pick(0)
	await _adv()
	await wait(2.5)
	await _pick(2)
	await wait(1.5)
	print("QUEST_FURNACE furnace=%d dust=%.3f" % [G.upgrades["furnace"], G.dust])
	# печь
	player.position = Vector3(-3.4, 0, 0.6)
	player.look_at_point(Vector3(-5.4, 0.6, 0.0))
	_use_furnace()
	await wait(4.0)
	await _shot("12_furnace_game")
	while G.mode == "mini":
		await wait(0.2)
	await wait(1.0)
	print("FURNACE_TEST ingots=%.3f" % G.ingots)
	player.position = Vector3(-2.0, 0, 1.5)
	player.look_at_point(Vector3(-5.0, 0.8, -1.0))
	await wait(0.6)
	await _shot("13_west_open")
	player.position = Vector3(-4.4, 0, 3.0)
	player.look_at_point(Vector3(-6.5, 1.4, 3.0))
	_use_buyer()
	await wait(2.0)
	await _adv()
	await wait(0.6)
	await _shot("14_sell_gold")
	await _pick(0)
	await wait(1.5)
	await _adv()
	await wait(1.0)
	player.position = Vector3(1.5, 0, 2.6)
	player.look_at_point(Vector3(0, 0.5, -0.5))
	await wait(0.6)
	await _shot("15_hud_goal")
	# обстановка: южная стена и северо-восточный угол
	player.position = Vector3(0.6, 0, 1.6)
	player.look_at_point(Vector3(0.6, 0.5, Basement.D))
	await wait(0.6)
	await _shot("16_south_wall")
	player.position = Vector3(2.4, 0, -2.4)
	player.look_at_point(Vector3(3.6, 0.5, -Basement.D))
	await wait(0.6)
	await _shot("17_ne_corner")
	get_tree().quit()
