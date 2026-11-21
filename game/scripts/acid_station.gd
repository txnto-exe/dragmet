class_name AcidStation
extends Station
## Травление руками:
## 1) перетащи находки с подноса в корзину  2) опусти корзину в кислоту  3) помешивай палочкой
## 4) вытащи корзину  5) влей осадитель  6) собери осадок ситом и ссыпь в банку.

const TUB := Vector3(-5.4, 0.0, -3.55)
const SURF_Y := 0.451                       # уровень кислоты
const IN_X := Vector2(-5.68, -5.12)         # внутренность ванны
const IN_Z := Vector2(-4.19, -2.91)
const BASKET_TOP := 0.92                    # корзина висит над ванной
const BASKET_IN := 0.52                     # корзина в кислоте
const BASKET_HALF := Vector2(0.25, 0.18)
const TRAY := Vector3(-5.68, 0.47, -1.96)
const BOTTLE_HOME := Vector3(-5.84, 0.47, -2.46)
const JAR := Vector3(-5.58, 0.47, -2.47)
const SIEVE_HOME := Vector3(-5.4, 0.66, -2.84)
const C_FRESH := Color(0.3, 0.75, 0.15)
const C_GOLD := Color(0.9, 0.66, 0.12)
const C_CLEAR := Color(0.42, 0.48, 0.3)

var visual_fn: Callable                     # модель находки по ключу (из BinSearch)
var built := false
var tray: Node3D
var bottle: Node3D
var bottle_stream: MeshInstance3D
var jar: Node3D
var jar_fill: MeshInstance3D
var sieve: Node3D
var sieve_pile: MeshInstance3D
var rod: Node3D
var flakes: Array = []                      # [MeshInstance3D]
var foam: MeshInstance3D
var slots: Array = []                       # [{key, node, count, label, home}]
var loaded := {}
var in_basket: Array = []
var lamp: OmniLight3D


func build_props() -> void:
	if built:
		return
	built = true
	var steel := mat(Color(0.22, 0.22, 0.24), 0.7, 0.45)
	# рабочая лампа над ящиком — поднос и инструменты хорошо видно
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.65)
	lamp.light_energy = 0.0
	lamp.omni_range = 1.8
	lamp.position = Vector3(-5.45, 1.35, -2.25)
	base.add_child(lamp)
	# поднос на ящике
	tray = Node3D.new()
	base.add_child(tray)
	tray.position = TRAY
	boxm(tray, Vector3(0.36, 0.015, 0.44), Vector3(0, 0.008, 0), steel)
	for s in [-1, 1]:
		boxm(tray, Vector3(0.36, 0.03, 0.012), Vector3(0, 0.02, s * 0.214), steel)
		boxm(tray, Vector3(0.012, 0.03, 0.416), Vector3(s * 0.174, 0.02, 0), steel)
	# бутыль осадителя
	bottle = Node3D.new()
	base.add_child(bottle)
	bottle.position = BOTTLE_HOME
	var white := mat(Color(0.86, 0.86, 0.82), 0.0, 0.5)
	cylm(bottle, 0.045, 0.048, 0.2, Vector3(0, 0.1, 0), white)
	cylm(bottle, 0.016, 0.03, 0.05, Vector3(0, 0.225, 0), white)
	cylm(bottle, 0.018, 0.018, 0.02, Vector3(0, 0.26, 0), mat(Color(0.75, 0.15, 0.1)))
	var tag := Label3D.new()
	tag.text = "ОСАДИТЕЛЬ"
	tag.font = load("res://assets/fonts/PressStart2P.ttf")
	tag.font_size = 10
	tag.pixel_size = 0.0012
	tag.modulate = Color(0.15, 0.12, 0.1)
	tag.outline_size = 0
	tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tag.position = Vector3(0.047, 0.11, 0)
	tag.rotation_degrees = Vector3(0, 90, 0)
	bottle.add_child(tag)
	grabbable(bottle, Vector3(0.12, 0.3, 0.12), Vector3(0, 0.14, 0))
	bottle_stream = cylm(base, 0.006, 0.006, 0.3, Vector3.ZERO, glow(Color(0.85, 0.9, 0.95), 0.4), 6)
	bottle_stream.visible = false
	# стеклянная банка для порошка
	jar = Node3D.new()
	base.add_child(jar)
	jar.position = JAR
	var glass := mat(Color(0.75, 0.85, 0.85, 0.35), 0.1, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cylm(jar, 0.05, 0.05, 0.12, Vector3(0, 0.06, 0), glass)
	jar_fill = cylm(jar, 0.046, 0.046, 0.1, Vector3(0, 0.005, 0), glow(Color(0.85, 0.62, 0.2), 0.15))
	jar_fill.scale.y = 0.001
	# сито с ручкой — лежит на торце ванны
	sieve = Node3D.new()
	base.add_child(sieve)
	sieve.position = SIEVE_HOME
	var wire := mat(Color(0.65, 0.65, 0.62), 0.8, 0.4)
	var ring := cylm(sieve, 0.07, 0.06, 0.035, Vector3.ZERO, wire, 12)
	ring.name = "Ring"
	cylm(sieve, 0.008, 0.008, 0.3, Vector3(0, 0.03, 0.2), mat(Color(0.35, 0.22, 0.12)), 6).rotation_degrees = Vector3(70, 0, 0)
	sieve_pile = cylm(sieve, 0.055, 0.055, 0.02, Vector3(0, -0.005, 0), glow(Color(0.8, 0.58, 0.2), 0.15), 10)
	sieve_pile.scale = Vector3(0.01, 1, 0.01)
	grabbable(sieve, Vector3(0.18, 0.12, 0.45), Vector3(0, 0.02, 0.12))
	# стеклянная палочка для помешивания
	rod = Node3D.new()
	base.add_child(rod)
	var rm := cylm(rod, 0.007, 0.007, 0.62, Vector3(0, 0.31, 0), glass, 6)
	rm.name = "Glass"
	_rod_rest()
	# пена (когда перелил осадитель)
	foam = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(IN_X.y - IN_X.x, IN_Z.y - IN_Z.x)
	foam.mesh = pm
	var fm := mat(Color(0.95, 0.95, 0.9, 0.0), 0.0, 0.9)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.material_override = fm
	foam.position = Vector3(TUB.x, SURF_Y + 0.012, TUB.z)
	base.add_child(foam)
	# хлопья осадка на дне (видны, когда раствор осветлился)
	var fl := glow(Color(0.55, 0.38, 0.12), 0.05)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 36:
		var f := boxm(base, Vector3(0.05, 0.006, 0.04), Vector3(rng.randf_range(IN_X.x + 0.04, IN_X.y - 0.04), 0.17,
			rng.randf_range(IN_Z.x + 0.05, IN_Z.y - 0.05)), fl)
		f.rotation.y = rng.randf() * TAU
		f.visible = false
		flakes.append(f)


func _rod_rest() -> void:
	rod.global_position = Vector3(-5.62, 0.18, -4.12)
	rod.rotation_degrees = Vector3(18, 0, -14)


# ---------- главный процесс ----------

func run(c: Camera3D, u: Node, b: Basement) -> Dictionary:
	base = b
	build_props()
	begin(c, u, b)
	lamp.light_energy = 1.1
	loaded = {}
	in_basket = []
	var basket := base.acid_basket
	basket.position = Vector3(TUB.x, BASKET_TOP, TUB.z)
	basket.visible = true
	var basket_area := grabbable(basket, Vector3(0.56, 0.3, 0.42), Vector3(0, -0.08, 0))
	var handle_area := grabbable(basket, Vector3(0.24, 0.14, 0.14), Vector3(0, 0.9, 0))
	_fill_tray()
	_set_acid(C_FRESH, 1.0)
	if auto:
		_auto_drive()
	var res := {"done": false}
	# 1-2. загрузка и опускание корзины
	step = "load"
	ui.station_step("Перетащи находки с подноса в корзину")
	ui.set_legend([["ЛКМ", "Тащить"], ["E", "Отойти"]])
	var held: Node3D = null
	var held_slot: Dictionary = {}
	var basket_drag := false
	var grab_dy := 0.0
	while true:
		var dt := await tick()
		if leave and not basket_drag and step == "load":
			_cleanup(basket_area, handle_area)
			lamp.light_energy = 0.0
			end()
			return res
		if held:
			var p := on_y(0.84)
			if p != Vector3.INF:
				held.global_position = held.global_position.lerp(p, minf(1.0, dt * 18.0))
			if released:
				dragging_cursor(false)
				if _over_basket(held.global_position):
					_drop_in_basket(held, held_slot)
				else:
					var back := create_tween()
					back.tween_property(held, "global_position", held_slot["home"] + Vector3(0, 0.04, 0), 0.2)
					back.tween_callback(held.queue_free)
				held = null
			continue
		if basket_drag:
			var p := on_vertical(basket.global_position)
			if p != Vector3.INF:
				basket.position.y = clampf(p.y - grab_dy, BASKET_IN, BASKET_TOP)
			if basket.position.y <= BASKET_IN + 0.01:
				break
			if released:
				basket_drag = false
				dragging_cursor(false)
			continue
		var h := pick()
		set_hover(h)
		if pressed and h:
			if h == basket:
				if loaded.is_empty():
					_shake(basket)
					ui.toast("Сначала положи что-нибудь в корзину", Color(1, 0.75, 0.45))
				else:
					step = "dunk"
					ui.station_step("Опусти корзину в кислоту")
					ui.set_legend([["Тянуть ЛКМ", "Вниз"]])
					basket_drag = true
					var p := on_vertical(basket.global_position)
					grab_dy = (p.y - basket.position.y) if p != Vector3.INF else 0.0
					set_hover(null)
					dragging_cursor(true)
			else:
				for s in slots:
					if s["node"] == h and int(s["count"]) > 0:
						held = visual_fn.call(s["key"])
						base.add_child(held)
						held.global_position = (s["home"] as Vector3) + Vector3(0, 0.05, 0)
						held_slot = s
						Sfx.play("pickup", -10.0, 1.3)
						set_hover(null)
						dragging_cursor(true)
						break
	# корзина в кислоте
	dragging_cursor(false)
	basket.position.y = BASKET_IN
	Sfx.play3d("sizzle", TUB + Vector3(0, 0.5, 0), 4.0)
	var bubbles := _loop("bubbles", -10.0)
	# 3. помешивание
	step = "stir"
	ui.set_legend([["Зажать ЛКМ и водить", "Мешать"]])
	var prog := 0.0
	var splash := 0.0
	var tip := Vector3(-5.5, 0.3, -4.0)
	var speed := 0.0
	var splash_cd := 0.0
	var sizzle_cd := 0.0
	while prog < 1.0:
		var dt := await tick()
		var rate := 0.025                       # само тоже понемногу растворяется
		var target := tip
		if down:
			var p := on_y(0.33)
			if p != Vector3.INF:
				target = _clamp_tub(p, true)
		var new_tip := tip.lerp(target, minf(1.0, dt * 14.0))
		speed = lerpf(speed, new_tip.distance_to(tip) / maxf(dt, 0.001), minf(1.0, dt * 6.0))
		tip = new_tip
		rod.global_position = tip
		rod.global_transform.basis = Basis(Quaternion(Vector3.UP, Vector3(0.3, 1.0, 0.25).normalized()))
		var warn := false
		if down and speed > 0.12:
			if speed < 1.5:
				rate = 0.05 + 0.12 * minf(speed, 1.0)
			else:
				rate = 0.14
				warn = true
				splash = minf(0.5, splash + dt * 0.12)
				splash_cd -= dt
				if splash_cd <= 0.0:
					splash_cd = 0.12
					_splash(tip)
		prog = minf(1.0, prog + rate * dt)
		bubbles.volume_db = -14.0 + minf(speed, 2.0) * 5.0
		_set_acid(C_FRESH.lerp(C_GOLD, prog), 1.0)
		base.acid_glow.light_energy = 0.6 + prog * 0.6 + minf(speed, 2.0) * 0.3
		for n in in_basket:
			(n as Node3D).scale = Vector3.ONE * lerpf(1.0, 0.3, prog)
		sizzle_cd -= dt
		if sizzle_cd <= 0.0 and down and speed > 0.3:
			sizzle_cd = randf_range(0.4, 0.9)
			Sfx.play3d("sizzle", tip + Vector3(0, 0.15, 0), -8.0, randf_range(0.8, 1.3))
		ui.station_step("Тише — брызги летят!" if warn else "Помешивай: растворяется", prog,
			Color(1.0, 0.45, 0.35) if warn else Color(0.95, 0.8, 0.4))
	Sfx.play("good", -6.0)
	_rod_rest()
	# 4. вытащить корзину
	step = "lift"
	ui.station_step("Вытащи корзину")
	ui.set_legend([["Тянуть ЛКМ", "Вверх"]])
	basket_drag = false
	while true:
		var dt := await tick()
		if basket_drag:
			var p := on_vertical(basket.global_position)
			if p != Vector3.INF:
				basket.position.y = clampf(p.y - grab_dy, BASKET_IN, BASKET_TOP + 0.05)
			if basket.position.y >= BASKET_TOP - 0.01:
				break
			if released:
				basket_drag = false
				dragging_cursor(false)
			continue
		var h := pick()
		set_hover(h if h == basket else null)
		if pressed and h == basket:
			basket_drag = true
			var p := on_vertical(basket.global_position)
			grab_dy = (p.y - basket.position.y) if p != Vector3.INF else 0.0
			set_hover(null)
			dragging_cursor(true)
	dragging_cursor(false)
	# пустые остатки плат — в сторону
	var away := create_tween()
	away.tween_property(basket, "position:y", 1.5, 0.5)
	await away.finished
	_cleanup(basket_area, handle_area)
	# 5. осадитель
	step = "pour"
	ui.set_legend([["Тащить ЛКМ", "Лить над ванной"]])
	var poured := 0.0
	var foam_loss := 0.0
	var holding := false
	var pour_snd: AudioStreamPlayer3D = null
	while true:
		var dt := await tick()
		if holding:
			var p := on_y(0.86)
			if p != Vector3.INF:
				bottle.global_position = bottle.global_position.lerp(p, minf(1.0, dt * 16.0))
			var over := _in_tub(bottle.global_position, 0.03)
			bottle.rotation.z = lerpf(bottle.rotation.z, deg_to_rad(115.0) if over else 0.0, minf(1.0, dt * 8.0))
			var pouring := over and bottle.rotation.z > deg_to_rad(80.0)
			if pouring:
				poured += dt * 0.32
				if poured > 1.2:
					foam_loss = minf(0.4, foam_loss + dt * 0.25)
				var mouth := bottle.global_position + Vector3(-0.2, 0.0, 0.0)
				stream_set(bottle_stream, mouth, Vector3(mouth.x, SURF_Y, mouth.z))
				if pour_snd == null:
					pour_snd = _loop("drip", -6.0)
					pour_snd.pitch_scale = 1.6
			elif pour_snd:
				pour_snd.queue_free()
				pour_snd = null
			bottle_stream.visible = pouring
			if released:
				holding = false
				dragging_cursor(false)
				bottle_stream.visible = false
				if pour_snd:
					pour_snd.queue_free()
					pour_snd = null
				var back := create_tween()
				back.tween_property(bottle, "global_position", BOTTLE_HOME, 0.3)
				back.parallel().tween_property(bottle, "rotation:z", 0.0, 0.3)
		else:
			var h := pick()
			var ok_tool := h == bottle or (h == sieve and poured >= 0.25)
			set_hover(h if ok_tool else null)
			if pressed and h == bottle:
				holding = true
				set_hover(null)
				dragging_cursor(true)
			elif pressed and h == sieve and poured >= 0.25:
				break
		var k := clampf(poured, 0.0, 1.0)
		_set_acid(C_GOLD.lerp(C_CLEAR, k), 1.0 - k * 0.45)
		var shown := int(k * flakes.size())
		for i in flakes.size():
			(flakes[i] as Node3D).visible = i < shown
		(foam.material_override as StandardMaterial3D).albedo_color.a = clampf((poured - 1.1) * 2.0, 0.0, 0.85)
		var over_txt := "Перелил — пенится!" if poured > 1.2 else ("Влей осадитель — белая бутыль" if poured < 1.0 else "Хватит — бери сито")
		ui.station_step(over_txt, minf(poured, 1.0), Color(1.0, 0.45, 0.35) if poured > 1.2 else Color(0.95, 0.8, 0.4))
	# 6. сбор осадка
	step = "collect"
	ui.set_legend([["Тащить ЛКМ", "Сито по дну"], ["К банке", "Ссыпать"]])
	var total := 0
	for f in flakes:
		if (f as Node3D).visible:
			total += 1
	var got := 0
	set_hover(null)
	dragging_cursor(true)
	var sv := sieve.global_position
	while true:
		var dt := await tick()
		if down:
			var p := on_y(0.2)
			if p != Vector3.INF:
				var inside := _in_tub(p, 0.0)
				var tgt := _clamp_tub(p, false) if inside else Vector3(p.x, 0.0, p.z)
				if not inside:
					var q := on_y(0.62)
					if q != Vector3.INF:
						tgt = q
				sv = sv.lerp(tgt, minf(1.0, dt * 14.0))
				sieve.global_position = sv
				sieve.rotation = Vector3.ZERO
			for f in flakes:
				var fn := f as Node3D
				if fn.visible and Vector2(fn.global_position.x - sv.x, fn.global_position.z - sv.z).length() < 0.085 and sv.y < 0.4:
					fn.visible = false
					got += 1
					sieve_pile.scale = Vector3.ONE * clampf(float(got) / maxf(total, 1) * 1.2 + 0.1, 0.1, 1.0)
					if randf() < 0.4:
						Sfx.play3d("drip", sv + Vector3(0, 0.2, 0), -10.0, randf_range(1.2, 1.6))
		if released or (auto and not down and got > 0):
			if Vector2(sv.x - JAR.x, sv.z - JAR.z).length() < 0.18:
				break
		ui.station_step("Собери осадок ситом и ссыпь в банку" if got < total else "Ссыпь в банку", float(got) / maxf(total, 1))
	# ссыпаем в банку
	dragging_cursor(false)
	var tw := create_tween()
	tw.tween_property(sieve, "global_position", JAR + Vector3(0, 0.22, 0), 0.25)
	tw.tween_property(sieve, "rotation:x", deg_to_rad(-120.0), 0.3)
	tw.parallel().tween_property(jar_fill, "scale:y", clampf(float(got) / maxf(total, 1), 0.15, 1.0), 0.5)
	tw.parallel().tween_property(sieve_pile, "scale", Vector3(0.01, 1, 0.01), 0.4)
	await tw.finished
	Sfx.play("coins", -8.0, 1.4)
	await get_tree().create_timer(0.5).timeout
	if bubbles:
		bubbles.queue_free()
	var frac := float(got) / maxf(total, 1)
	var quality := (1.0 - splash) * clampf(poured, 0.0, 1.0) * (1.0 - foam_loss) * frac
	_reset_after()
	lamp.light_energy = 0.0
	end()
	return {"done": true, "quality": quality, "loaded": loaded, "splash": splash, "poured": poured, "frac": frac}


# ---------- поднос и корзина ----------

func _fill_tray() -> void:
	for s in slots:
		if is_instance_valid(s["node"]):
			(s["node"] as Node3D).queue_free()
	slots = []
	var keys: Array = []
	for k in G.bag:
		if not G.is_locked(k) and int(G.bag[k]) > 0:
			keys.append(k)
	keys.sort_custom(func(a, b): return G.ITEMS[a]["gold"] > G.ITEMS[b]["gold"])
	for i in keys.size():
		var k: String = keys[i]
		var col := i % 2
		var row := i / 2
		var home := TRAY + Vector3(-0.08 + col * 0.16, 0.02, -0.16 + row * 0.11)
		var n: Node3D = visual_fn.call(k)
		base.add_child(n)
		n.global_position = home
		grabbable(n, Vector3(0.14, 0.08, 0.1), Vector3(0, 0.03, 0))
		var l := label3d(n, "×%d" % int(G.bag[k]), Vector3(0.0, 0.09, 0.0), 20)
		slots.append({"key": k, "node": n, "count": int(G.bag[k]), "label": l, "home": home})


func _over_basket(p: Vector3) -> bool:
	return absf(p.x - TUB.x) < BASKET_HALF.x + 0.05 and absf(p.z - TUB.z) < BASKET_HALF.y + 0.06


func _drop_in_basket(n: Node3D, s: Dictionary) -> void:
	var basket := base.acid_basket
	var gp := n.global_position
	n.get_parent().remove_child(n)
	basket.add_child(n)
	n.global_position = gp
	var k: String = s["key"]
	loaded[k] = int(loaded.get(k, 0)) + 1
	s["count"] = int(s["count"]) - 1
	(s["label"] as Label3D).text = "×%d" % int(s["count"])
	if int(s["count"]) <= 0:
		(s["node"] as Node3D).visible = false
	var spot := Vector3(randf_range(-0.16, 0.16), -0.18 + minf(in_basket.size(), 12) * 0.006, randf_range(-0.1, 0.1))
	var tw := create_tween()
	tw.tween_property(n, "position", spot, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	n.rotation.y = randf() * TAU
	in_basket.append(n)
	Sfx.play3d("clank", basket.global_position, -12.0, randf_range(1.5, 1.9))
	var cnt := 0
	for v in loaded.values():
		cnt += int(v)
	ui.station_step("Загрузи корзину — в ней %d. Потом тяни корзину вниз" % cnt)


func _cleanup(a1: Area3D, a2: Area3D) -> void:
	for n in in_basket:
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	in_basket = []
	for s in slots:
		if is_instance_valid(s["node"]):
			(s["node"] as Node3D).queue_free()
	slots = []
	if is_instance_valid(a1):
		a1.queue_free()
	if is_instance_valid(a2):
		a2.queue_free()
	base.acid_basket.visible = false
	base.acid_basket.position.y = BASKET_TOP


func _reset_after() -> void:
	_set_acid(C_FRESH, 1.0)
	base.acid_glow.light_energy = 0.6
	for f in flakes:
		(f as Node3D).visible = false
	(foam.material_override as StandardMaterial3D).albedo_color.a = 0.0
	bottle.global_position = BOTTLE_HOME
	bottle.rotation = Vector3.ZERO
	sieve.global_position = SIEVE_HOME
	sieve.rotation = Vector3.ZERO
	sieve_pile.scale = Vector3(0.01, 1, 0.01)
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_property(jar_fill, "scale:y", 0.001, 0.5)


# ---------- кислота и эффекты ----------

func _set_acid(c: Color, alpha: float) -> void:
	var m := base.acid_mat
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.emission = c * 1.1
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED


func _in_tub(p: Vector3, margin: float) -> bool:
	return p.x > IN_X.x + margin and p.x < IN_X.y - margin and p.z > IN_Z.x + margin and p.z < IN_Z.y - margin


## Точка внутри ванны; avoid_basket — палочка обходит корзину.
func _clamp_tub(p: Vector3, avoid_basket: bool) -> Vector3:
	var q := Vector3(clampf(p.x, IN_X.x + 0.03, IN_X.y - 0.03), p.y, clampf(p.z, IN_Z.x + 0.03, IN_Z.y - 0.03))
	if avoid_basket:
		var dx := q.x - TUB.x
		var dz := q.z - TUB.z
		if absf(dx) < BASKET_HALF.x + 0.02 and absf(dz) < BASKET_HALF.y + 0.02:
			q.z = TUB.z + signf(dz if absf(dz) > 0.001 else 1.0) * (BASKET_HALF.y + 0.03)
	return q


func _splash(at: Vector3) -> void:
	var dm := glow(Color(0.6, 1.0, 0.3), 1.5)
	for i in 3:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.012
		sm.height = 0.024
		sm.radial_segments = 6
		sm.rings = 3
		d.mesh = sm
		d.material_override = dm
		base.add_child(d)
		d.global_position = Vector3(at.x, SURF_Y + 0.01, at.z)
		var to := d.global_position + Vector3(randf_range(-0.25, 0.25), randf_range(0.2, 0.45), randf_range(-0.2, 0.2))
		var tw := d.create_tween()
		tw.tween_property(d, "global_position", to, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "global_position", Vector3(to.x, SURF_Y, to.z), 0.25).set_ease(Tween.EASE_IN)
		tw.tween_callback(d.queue_free)
	if randf() < 0.5:
		Sfx.play3d("sizzle", at + Vector3(0, 0.2, 0), -4.0, randf_range(1.1, 1.5))


func _shake(n: Node3D) -> void:
	var x := n.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(n, "position:x", x + (0.03 if i % 2 == 0 else -0.03), 0.05)
	tw.tween_property(n, "position:x", x, 0.05)
	Sfx.play3d("clank", n.global_position, -14.0, 2.0)


func _loop(name: String, vol: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = Sfx.looped(name)
	p.volume_db = vol
	p.bus = "SFX"
	p.unit_size = 3.0
	base.add_child(p)
	p.global_position = TUB + Vector3(0, 0.5, 0)
	p.play()
	return p


# ---------- автотест: проходит все шаги «руками» ----------

func _auto_drive() -> void:
	await a_wait(0.5)
	# три находки в корзину
	for i in 3:
		var s: Dictionary = {}
		for x in slots:
			if int(x["count"]) > 0:
				s = x
				break
		if s.is_empty():
			break
		await a_move((s["home"] as Vector3) + Vector3(0, 0.03, 0), 0.25)
		await a_press()
		await a_move(TUB + Vector3(0.05 * i, 0.84, 0.0), 0.35)
		await a_wait(0.15)
		await a_release()
		await a_wait(0.3)
	# корзину вниз
	await a_move(Vector3(TUB.x, BASKET_TOP - 0.05, TUB.z), 0.25)
	await a_press()
	await a_move(Vector3(TUB.x, BASKET_TOP - 0.6, TUB.z), 0.6)
	await a_release()
	await a_wait(0.3)
	# мешаем кругами по дальнему краю ванны
	await a_press()
	var t := 0.0
	while step == "stir" and t < 20.0:
		t += get_process_delta_time()
		var c := Vector3(-5.4, 0.33, -3.95)
		ptr = cam.unproject_position(c + Vector3(cos(t * 6.0) * 0.18, 0, sin(t * 6.0) * 0.12))
		await get_tree().process_frame
	await a_release()
	await a_wait(0.3)
	# корзину вверх
	await a_move(base.acid_basket.global_position + Vector3(0, 0.1, 0), 0.25)
	await a_press()
	await a_move(base.acid_basket.global_position + Vector3(0, 0.7, 0), 0.6)
	await a_release()
	while step == "lift":
		await get_tree().process_frame
	await a_wait(0.8)
	# осадитель
	await a_move(BOTTLE_HOME + Vector3(0, 0.14, 0), 0.3)
	await a_press()
	await a_move(Vector3(-5.3, 0.86, -3.4), 0.4)
	t = 0.0
	while t < 3.4:
		t += get_process_delta_time()
		await get_tree().process_frame
	await a_release()
	await a_wait(0.5)
	# сито: по всему дну змейкой, потом к банке
	await a_move(SIEVE_HOME + Vector3(0, 0.02, 0.1), 0.25)
	await a_press()
	for row in 7:
		var z := lerpf(IN_Z.x + 0.06, IN_Z.y - 0.06, row / 6.0)
		await a_move(Vector3(IN_X.x + 0.06 if row % 2 == 0 else IN_X.y - 0.06, 0.2, z), 0.12)
		await a_move(Vector3(IN_X.y - 0.06 if row % 2 == 0 else IN_X.x + 0.06, 0.2, z), 0.25)
	await a_move(JAR + Vector3(0, 0.62 - JAR.y, 0), 0.4)
	await a_wait(0.2)
	await a_release()
