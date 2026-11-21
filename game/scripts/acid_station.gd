class_name AcidStation
extends Station
## Травление руками — четыре простых действия, жёлтая стрелка всегда показывает, что брать и куда нести:
## 1) перетащи находки с подноса в корзину и нажми на корзину — она сама опустится в кислоту
## 2) зажми ЛКМ и мешай палочкой  3) перетащи белую бутыль на ванну — осадитель вольётся сам
## 4) ковшом собери три кучки осадка со дна и высыпь в банку.

const TUB := Vector3(-5.4, 0.0, -3.55)
const SURF_Y := 0.451                       # уровень кислоты
const RIM_Y := 0.62                         # над бортом: по этой высоте водится мышь
const BOTTOM_Y := 0.17                      # дно ванны
const IN_X := Vector2(-5.68, -5.12)         # внутренность ванны
const IN_Z := Vector2(-4.19, -2.91)
const BASKET_TOP := 0.92                    # корзина висит над ванной
const BASKET_IN := 0.52                     # корзина в кислоте
const BASKET_HALF := Vector2(0.25, 0.18)
const TRAY := Vector3(-5.68, 0.47, -1.96)
const BOTTLE_HOME := Vector3(-5.84, 0.47, -2.46)
const JAR := Vector3(-5.58, 0.47, -2.47)
const LADLE_HOME := Vector3(-5.4, 0.66, -2.84)
const POUR_AT := Vector3(-5.3, 0.86, -3.45)
# кучки осадка — в дальней половине дна, чтобы их было видно поверх ближнего борта
const PILES := [Vector3(-5.5, BOTTOM_Y, -3.28), Vector3(-5.47, BOTTOM_Y, -3.6), Vector3(-5.52, BOTTOM_Y, -3.96)]
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
var ladle: Node3D
var ladle_pile: MeshInstance3D
var rod: Node3D
var piles: Array = []                       # [MeshInstance3D]
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
	grabbable(bottle, Vector3(0.14, 0.32, 0.14), Vector3(0, 0.14, 0))
	bottle_stream = cylm(base, 0.007, 0.007, 0.3, Vector3.ZERO, glow(Color(0.85, 0.9, 0.95), 0.4), 6)
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
	jar_fill.visible = false
	# ковш с ручкой — лежит на торце ванны
	ladle = Node3D.new()
	base.add_child(ladle)
	ladle.position = LADLE_HOME
	var wire := mat(Color(0.8, 0.8, 0.76), 0.6, 0.4)
	cylm(ladle, 0.07, 0.06, 0.035, Vector3.ZERO, wire, 12)
	# длинная ручка — торчит из кислоты, даже когда ковш на дне
	cylm(ladle, 0.01, 0.01, 0.55, Vector3(0, 0.178, 0.225), mat(Color(0.45, 0.28, 0.14)), 6).rotation_degrees = Vector3(55, 0, 0)
	ladle_pile = cylm(ladle, 0.055, 0.055, 0.02, Vector3(0, 0.0, 0), glow(Color(0.95, 0.68, 0.2), 1.2), 10)
	ladle_pile.visible = false
	grabbable(ladle, Vector3(0.2, 0.12, 0.32), Vector3(0, 0.03, 0.08))
	# стеклянная палочка для помешивания
	rod = Node3D.new()
	base.add_child(rod)
	cylm(rod, 0.007, 0.007, 0.62, Vector3(0, 0.31, 0), glass, 6)
	_rod_rest()
	# кучки осадка на дне (появляются после осадителя)
	var gold := glow(Color(0.9, 0.62, 0.18), 0.7)
	for p in PILES:
		var pm := cylm(base, 0.03, 0.08, 0.04, (p as Vector3) + Vector3(0, 0.02, 0), gold, 10)
		pm.visible = false
		piles.append(pm)


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
	var basket_area := grabbable(basket, Vector3(0.56, 0.34, 0.42), Vector3(0, -0.06, 0))
	_fill_tray()
	_set_acid(C_FRESH, 1.0)
	if auto:
		_auto_drive()
	var basket_mark := Vector3(TUB.x, BASKET_TOP - 0.2, TUB.z)   # стрелка внутрь корзины

	# 1. загрузка: тащи находки в корзину, потом нажми на корзину
	step = "load"
	var held: Node3D = null
	var held_slot: Dictionary = {}
	while true:
		var dt := await tick()
		var cnt := _loaded_count()
		if held:
			follow(held, 0.84, dt, 18.0)
			mark(basket_mark)
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
		if leave and cnt == 0:
			_cleanup(basket_area)
			lamp.light_energy = 0.0
			end()
			return {"done": false}
		if cnt > 0 and _tray_left() == 0:
			break                               # всё в корзине — опускаем сами
		if cnt == 0:
			ui.station_step("Перетащи находки с подноса в корзину")
			legend("load0", [["ЛКМ", "Тащить в корзину"], ["E", "Отойти"]])
			mark(_first_slot_pos())
		else:
			ui.station_step("В корзине %d. Ещё — или нажми на корзину" % cnt)
			legend("load1", [["ЛКМ", "Тащить в корзину"], ["ЛКМ на корзине", "Опустить"]])
			mark(basket_mark)
		var h := pick()
		var slot := _slot_of(h)
		set_hover(h if (h == basket and cnt > 0) or not slot.is_empty() else null)
		if pressed and h == basket and cnt > 0:
			break
		if pressed and not slot.is_empty():
			held = visual_fn.call(slot["key"])
			base.add_child(held)
			held.global_position = (slot["home"] as Vector3) + Vector3(0, 0.05, 0)
			held_slot = slot
			Sfx.play("pickup", -10.0, 1.3)
			set_hover(null)
			dragging_cursor(true)
	set_hover(null)
	mark(Vector3.INF)
	if is_instance_valid(basket_area):
		basket_area.queue_free()
	_hide_tray()
	ui.station_step("Корзина в кислоте")
	legend("none", [])
	var dunk := create_tween()
	dunk.tween_property(basket, "position:y", BASKET_IN, 0.7).set_trans(Tween.TRANS_SINE)
	await dunk.finished
	Sfx.play3d("sizzle", TUB + Vector3(0, 0.5, 0), 4.0)
	var bubbles := _loop("bubbles", -10.0)

	# 2. помешивание: зажми ЛКМ и води кругами
	step = "stir"
	legend("stir", [["Зажать ЛКМ", "Мешать кругами"]])
	var prog := 0.0
	var tip := Vector3(-5.5, 0.3, -4.0)
	var speed := 0.0
	var started := false
	var splash_cd := 0.0
	var sizzle_cd := 0.0
	while prog < 1.0:
		var dt := await tick()
		var target := tip
		if down:
			started = true
			var p := on_y(0.33)
			if p != Vector3.INF:
				target = _clamp_tub(p, true)
		var new_tip := tip.lerp(target, minf(1.0, dt * 14.0))
		speed = lerpf(speed, new_tip.distance_to(tip) / maxf(dt, 0.001), minf(1.0, dt * 6.0))
		tip = new_tip
		rod.global_position = tip
		rod.global_transform.basis = Basis(Quaternion(Vector3.UP, Vector3(0.3, 1.0, 0.25).normalized()))
		mark(Vector3.INF if started else Vector3(-5.45, SURF_Y + 0.15, -3.95))
		var too_fast := down and speed > 1.8
		var rate := 0.0
		if down and not too_fast:
			rate = 0.17 * clampf(speed / 0.45, 0.0, 1.0)
		if too_fast:
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
		var txt := "Зажми ЛКМ и мешай кругами"
		if too_fast:
			txt = "Тише — брызги летят!"
		elif started:
			txt = "Мешай — платы растворяются"
		ui.station_step(txt, prog, Color(1.0, 0.45, 0.35) if too_fast else Color(0.95, 0.8, 0.4))
	Sfx.play("good", -6.0)
	_rod_rest()
	# корзина сама поднимается — пустые остатки плат в сторону
	ui.station_step("Платы растворились")
	legend("none", [])
	var away := create_tween()
	away.tween_property(basket, "position:y", 1.5, 0.6)
	await away.finished
	_cleanup(null)

	# 3. осадитель: перетащи бутыль на ванну — дальше она льёт сама
	step = "pour"
	legend("pour", [["ЛКМ", "Тащить бутыль на ванну"]])
	var holding := false
	while true:
		var dt := await tick()
		if holding:
			follow(bottle, 0.86, dt)
			mark(Vector3(TUB.x, SURF_Y + 0.12, TUB.z))
			if _in_tub(bottle.global_position, 0.0):
				break
			if released:
				holding = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(bottle, "global_position", BOTTLE_HOME, 0.3)
			continue
		ui.station_step("Перетащи белую бутыль на ванну")
		mark(BOTTLE_HOME + Vector3(0, 0.3, 0))
		var h := pick()
		set_hover(h if h == bottle else null)
		if pressed and h == bottle:
			holding = true
			set_hover(null)
			dragging_cursor(true)
	set_hover(null)
	mark(Vector3.INF)
	dragging_cursor(false)
	legend("none", [])
	var tilt := create_tween()
	tilt.tween_property(bottle, "global_position", POUR_AT, 0.25)
	tilt.parallel().tween_property(bottle, "rotation:z", deg_to_rad(115.0), 0.35)
	await tilt.finished
	var pour_snd := _loop("drip", -6.0)
	pour_snd.pitch_scale = 1.6
	var poured := 0.0
	while poured < 1.0:
		var dt := await tick()
		poured = minf(1.0, poured + dt / 2.0)
		var mouth := bottle.global_transform * Vector3(0, 0.26, 0)
		stream_set(bottle_stream, mouth, Vector3(mouth.x, SURF_Y, mouth.z))
		bottle_stream.visible = true
		_set_acid(C_GOLD.lerp(C_CLEAR, poured), 1.0 - poured * 0.7)
		ui.station_step("Осадитель льётся…", poured)
	bottle_stream.visible = false
	pour_snd.queue_free()
	var home := create_tween()
	home.tween_property(bottle, "global_position", BOTTLE_HOME, 0.3)
	home.parallel().tween_property(bottle, "rotation:z", 0.0, 0.3)
	# золото выпадает и собирается в кучки на дне
	for pm in piles:
		var m := pm as MeshInstance3D
		m.visible = true
		m.scale = Vector3(0.05, 0.05, 0.05)
		var g := create_tween()
		g.tween_property(m, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ui.station_step("Золото оседает на дно…")
	await get_tree().create_timer(1.0).timeout

	# 4. ковш: собери кучки и высыпь в банку
	step = "collect"
	legend("collect", [["ЛКМ", "Тащить ковш"], ["Над кучкой", "Зачерпнуть"], ["Над банкой", "Высыпать"]])
	var total := piles.size()
	var in_ladle := 0
	var got := 0
	holding = false
	ladle_pile.visible = false
	while got < total:
		var dt := await tick()
		var left := total - got - in_ladle
		if holding:
			var q := on_y(RIM_Y)
			if q != Vector3.INF:
				var tgt := q
				if _in_tub(q, -0.06):
					# над ванной ковш опускается на дно — точка дна под мышкой, но всегда внутри ванны
					var bp := on_y(BOTTOM_Y + 0.03)
					tgt = _clamp_tub(bp if bp != Vector3.INF else q, false)
					tgt.y = BOTTOM_Y + 0.03
				ladle.global_position = ladle.global_position.lerp(tgt, minf(1.0, dt * 14.0))
			if ladle.global_position.y < 0.3:
				for pm in piles:
					var m := pm as MeshInstance3D
					if m.visible and xz_dist(m.global_position, ladle.global_position) < 0.12:
						m.visible = false
						in_ladle += 1
						ladle_pile.visible = true
						ladle_pile.scale = Vector3.ONE * (0.5 + 0.5 * float(in_ladle) / total)
						Sfx.play3d("drip", ladle.global_position + Vector3(0, 0.2, 0), -6.0, randf_range(1.2, 1.5))
			var np := _nearest_pile(ladle.global_position)
			mark(np + Vector3(0, 0.03, 0) if np != Vector3.INF else JAR + Vector3(0, 0.16, 0))
			if in_ladle > 0 and xz_dist(ladle.global_position, JAR) < 0.16 and ladle.global_position.y > 0.4:
				holding = false
				dragging_cursor(false)
				mark(Vector3.INF)
				await _dump_ladle(float(got + in_ladle) / total)
				got += in_ladle
				in_ladle = 0
				continue
			if released:
				holding = false
				dragging_cursor(false)
				var back := create_tween()
				back.tween_property(ladle, "global_position", LADLE_HOME, 0.3)
			ui.station_step("Высыпь в банку" if left == 0 else "Зачерпни кучки со дна: %d из %d" % [got + in_ladle, total],
				float(got + in_ladle) / total)
			continue
		ui.station_step("Возьми ковш и собери золото со дна", float(got + in_ladle) / total)
		mark(LADLE_HOME + Vector3(0, 0.08, 0.05))
		var h := pick()
		set_hover(h if h == ladle else null)
		if pressed and h == ladle:
			holding = true
			set_hover(null)
			dragging_cursor(true)
	set_hover(null)
	mark(Vector3.INF)
	Sfx.play("coins", -8.0, 1.4)
	ui.station_step("Порошок в банке", 1.0)
	await get_tree().create_timer(0.6).timeout
	if bubbles:
		bubbles.queue_free()
	_reset_after()
	lamp.light_energy = 0.0
	end()
	return {"done": true, "quality": 1.0, "loaded": loaded}


func _dump_ladle(fill: float) -> void:
	var tw := create_tween()
	tw.tween_property(ladle, "global_position", JAR + Vector3(0, 0.22, 0), 0.2)
	tw.tween_property(ladle, "rotation:x", deg_to_rad(-120.0), 0.25)
	jar_fill.visible = true
	tw.parallel().tween_property(jar_fill, "scale:y", clampf(fill, 0.15, 1.0), 0.4)
	tw.tween_callback(func(): ladle_pile.visible = false)
	tw.tween_property(ladle, "rotation:x", 0.0, 0.2)
	tw.tween_property(ladle, "global_position", LADLE_HOME, 0.3)
	Sfx.play3d("rustle0", JAR + Vector3(0, 0.2, 0), -12.0, 1.6)
	await tw.finished


func _nearest_pile(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := 99.0
	for pm in piles:
		var m := pm as MeshInstance3D
		if m.visible:
			var d := xz_dist(m.global_position, from)
			if d < bd:
				bd = d
				best = m.global_position
	return best


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
		grabbable(n, Vector3(0.15, 0.09, 0.11), Vector3(0, 0.03, 0))
		var l := label3d(n, "×%d" % int(G.bag[k]), Vector3(0.0, 0.09, 0.0), 20)
		slots.append({"key": k, "node": n, "count": int(G.bag[k]), "label": l, "home": home})


func _slot_of(h: Node3D) -> Dictionary:
	if h == null:
		return {}
	for s in slots:
		if s["node"] == h and int(s["count"]) > 0:
			return s
	return {}


func _first_slot_pos() -> Vector3:
	for s in slots:
		if int(s["count"]) > 0:
			return (s["home"] as Vector3) + Vector3(0, 0.12, 0)
	return Vector3.INF


func _tray_left() -> int:
	var n := 0
	for s in slots:
		n += int(s["count"])
	return n


func _loaded_count() -> int:
	var cnt := 0
	for v in loaded.values():
		cnt += int(v)
	return cnt


func _hide_tray() -> void:
	for s in slots:
		if is_instance_valid(s["node"]):
			(s["node"] as Node3D).queue_free()
	slots = []


func _over_basket(p: Vector3) -> bool:
	return absf(p.x - TUB.x) < BASKET_HALF.x + 0.1 and absf(p.z - TUB.z) < BASKET_HALF.y + 0.1


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


func _cleanup(a1: Area3D) -> void:
	for n in in_basket:
		if is_instance_valid(n):
			(n as Node3D).queue_free()
	in_basket = []
	_hide_tray()
	if is_instance_valid(a1):
		a1.queue_free()
	base.acid_basket.visible = false
	base.acid_basket.position.y = BASKET_TOP


func _reset_after() -> void:
	_set_acid(C_FRESH, 1.0)
	base.acid_glow.light_energy = 0.6
	for pm in piles:
		(pm as Node3D).visible = false
	bottle.global_position = BOTTLE_HOME
	bottle.rotation = Vector3.ZERO
	ladle.global_position = LADLE_HOME
	ladle.rotation = Vector3.ZERO
	ladle_pile.visible = false
	var t := create_tween()
	t.tween_interval(3.0)
	t.tween_property(jar_fill, "scale:y", 0.001, 0.5)
	t.tween_callback(func(): jar_fill.visible = false)


# ---------- кислота и эффекты ----------

func _set_acid(c: Color, alpha: float) -> void:
	var m := base.acid_mat
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.emission = c * (0.3 + 0.8 * alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED


func _in_tub(p: Vector3, margin: float) -> bool:
	return p.x > IN_X.x + margin and p.x < IN_X.y - margin and p.z > IN_Z.x + margin and p.z < IN_Z.y - margin


## Точка внутри ванны; avoid_basket — палочка обходит корзину.
func _clamp_tub(p: Vector3, avoid_basket: bool) -> Vector3:
	var q := Vector3(clampf(p.x, IN_X.x + 0.06, IN_X.y - 0.06), p.y, clampf(p.z, IN_Z.x + 0.06, IN_Z.y - 0.06))
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
	# нажать на корзину
	if step == "load":
		await a_move(Vector3(TUB.x, BASKET_TOP - 0.05, TUB.z), 0.25)
		await a_press()
		await a_release()
	while step != "stir":
		await get_tree().process_frame
	# мешаем кругами по дальнему краю ванны
	await a_press()
	var t := 0.0
	while step == "stir" and t < 20.0:
		t += get_process_delta_time()
		var c := Vector3(-5.4, 0.33, -3.95)
		ptr = cam.unproject_position(c + Vector3(cos(t * 5.0) * 0.16, 0, sin(t * 5.0) * 0.1))
		await get_tree().process_frame
	await a_release()
	while step != "pour":
		await get_tree().process_frame
	await a_wait(0.3)
	# бутыль на ванну
	await a_move(BOTTLE_HOME + Vector3(0, 0.14, 0), 0.3)
	await a_press()
	await a_move(Vector3(-5.35, 0.86, -3.4), 0.4)
	await a_release()
	while step != "collect":
		await get_tree().process_frame
	await a_wait(0.3)
	# ковш: по кучкам (сначала самая дальняя), потом к банке
	await a_move(LADLE_HOME + Vector3(0, 0.02, 0.1), 0.25)
	await a_press()
	for i in [2, 1, 0]:
		var p: Vector3 = PILES[i]
		await a_move(p + Vector3(0, 0.03, 0), 0.4)
		await a_wait(0.25)
		if i == 2:
			set_meta("shot", "11f_acid_ladle_far")
			await a_wait(0.3)
	await a_move(JAR + Vector3(0, RIM_Y - JAR.y, 0), 0.4)
	await a_wait(0.3)
	await a_release()
