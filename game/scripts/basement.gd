class_name Basement
extends Node3D
## Подвал по схеме игрока (вид сверху: верх = север, -Z):
##   центр — мусорка; слева (запад, -X) — кислота, печь, окошко скупщика;
##   справа (восток, +X) — точки-прилавки для бригады; сверху — ящик долга; снизу — дверь.
## Всё строится кодом: стены из фото-текстур Poly Haven, мебель и хлам — модели Poly Haven.

const W := 6.0       # полуширина комнаты по X
const D := 4.5       # полуглубина по Z
const H := 2.8       # высота потолка
const BAND := 1.15   # высота нижней крашеной полосы стен
const DOOR_X := 1.5
const DOOR_W := 0.9
const DOOR_H := 2.05

const STALL_Z := [-3.6, -2.0, -0.4, 1.2, 2.8]
const STALL_LEN := 1.0    # длина прилавка вдоль стены (между прилавками проход 0.6 м)
const STALL_X := 4.55     # центр прилавка
const SEAT_X := 5.35      # где табурет продавца (под тазом)
const SIT_BACK := 0.34    # в позе сидя таз на столько позади корня персонажа (замерено по анимации)
const LIFT := Vector3(0, 0, -0.2)     # где стоит бак (центр проёма в полу)
const HOLE := Vector2(1.5, 1.1)        # размер проёма
const LIFT_DOWN := -2.1                # насколько опускается платформа
const DEBT_BOX := Vector3(-1.4, 0, -4.5 + 0.22)

var mats := {}
var bulb_pivot: Node3D
var bulb_light: OmniLight3D
var bulb_glass: MeshInstance3D
var booth_light: OmniLight3D
var debt_light: OmniLight3D
var debt_label: Label3D
var door_pivot: Node3D
var stall_lights: Array[OmniLight3D] = []
var acid_block: Node3D
var lift: Node3D
var hatch_l: Node3D
var hatch_r: Node3D
var beacon: OmniLight3D
var beacon_mesh: MeshInstance3D
var _beacon_on := false
var furnace_block: Node3D
var acid_mat: StandardMaterial3D
var acid_glow: OmniLight3D
var acid_basket: Node3D
var furnace_light: OmniLight3D
var bellows: Node3D
var crucible_mat: StandardMaterial3D
var env: Environment
var rat: Node3D
var _t := 0.0
var _flicker := 0.0
var _next_flicker := 3.0
var _rat_timer := 40.0


func build() -> void:
	_make_materials()
	_room()
	_west_side()
	_north_side()
	_east_stalls()
	_lift_pit()
	_door_and_corridor()
	_clutter()
	_pipes()
	_lights()
	_environment()
	_drips()
	for l in find_children("*", "OmniLight3D", true, false):
		l.set_meta("shadow", (l as OmniLight3D).shadow_enabled)


# ---------- материалы ----------

func surf(name: String, scale := 0.45, rough := 0.9, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, scale, tint]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_diff.jpg" % name)
	m.albedo_color = tint
	var nor := "res://assets/tex/%s_nor.jpg" % name
	if ResourceLoader.exists(nor):
		m.normal_enabled = true
		m.normal_texture = load(nor)
		m.normal_scale = 0.8
	var r := "res://assets/tex/%s_rough.jpg" % name
	if ResourceLoader.exists(r):
		m.roughness_texture = load(r)
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mats[key] = m
	return m


func _make_materials() -> void:
	surf("floor", 0.42, 1.0, Color(0.8, 0.78, 0.72))
	surf("wall_low", 0.5, 1.0, Color(0.55, 0.75, 0.6))
	surf("wall_top", 0.4, 1.0, Color(0.85, 0.83, 0.76))
	surf("ceiling", 0.4, 1.0, Color(0.6, 0.58, 0.54))


func box(size: Vector3, pos: Vector3, mat: Material, collide := true, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


func cyl(r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, sides := 8, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


## Стена по прямой (вдоль X или Z) от y0 до y1, сама делится на нижнюю крашеную и верхнюю побелённую часть.
func wall(x0: float, z0: float, x1: float, z1: float, y0 := 0.0, y1 := H, t := 0.3) -> void:
	var along_x := absf(x1 - x0) > absf(z1 - z0)
	var len := absf(x1 - x0) if along_x else absf(z1 - z0)
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	for part in [[y0, minf(y1, BAND), "wall_low"], [maxf(y0, BAND), y1, "wall_top"]]:
		var a: float = part[0]
		var b: float = part[1]
		if b - a <= 0.001:
			continue
		var size := Vector3(len, b - a, t) if along_x else Vector3(t, b - a, len)
		box(size, Vector3(cx, (a + b) * 0.5, cz), surf(part[2], 0.5 if part[2] == "wall_low" else 0.4, 1.0,
			Color(0.55, 0.75, 0.6) if part[2] == "wall_low" else Color(0.85, 0.83, 0.76)))


# ---------- комната ----------

func _room() -> void:
	# пол с проёмом под подъёмник бака
	var fm := surf("floor", 0.42, 1.0, Color(0.8, 0.78, 0.72))
	var x0 := -W - 1.5
	var x1 := W + 1.5
	var z0 := -D - 0.7
	var z1 := D + 2.3
	var hx := LIFT.x - HOLE.x * 0.5
	var hx2 := LIFT.x + HOLE.x * 0.5
	var hz := LIFT.z - HOLE.y * 0.5
	var hz2 := LIFT.z + HOLE.y * 0.5
	box(Vector3(hx - x0, 0.2, z1 - z0), Vector3((x0 + hx) * 0.5, -0.1, (z0 + z1) * 0.5), fm)
	box(Vector3(x1 - hx2, 0.2, z1 - z0), Vector3((hx2 + x1) * 0.5, -0.1, (z0 + z1) * 0.5), fm)
	box(Vector3(HOLE.x, 0.2, hz - z0), Vector3(LIFT.x, -0.1, (z0 + hz) * 0.5), fm)
	box(Vector3(HOLE.x, 0.2, z1 - hz2), Vector3(LIFT.x, -0.1, (hz2 + z1) * 0.5), fm)
	box(Vector3(W * 2 + 3, 0.2, D * 2 + 4), Vector3(0, H + 0.1, 0.8), surf("ceiling", 0.4, 1.0, Color(0.6, 0.58, 0.54)))
	var t := 0.3
	# север и восток — глухие
	wall(-W - t, -D - t * 0.5, W + t, -D - t * 0.5)
	wall(W + t * 0.5, -D, W + t * 0.5, D)
	# юг — с дверным проёмом
	wall(-W - t, D + t * 0.5, DOOR_X - DOOR_W * 0.5, D + t * 0.5)
	wall(DOOR_X + DOOR_W * 0.5, D + t * 0.5, W + t, D + t * 0.5)
	wall(DOOR_X - DOOR_W * 0.5, D + t * 0.5, DOOR_X + DOOR_W * 0.5, D + t * 0.5, DOOR_H, H)
	# запад — с окошком скупщика (z 2.55..3.45, y 1.0..1.65)
	wall(-W - t * 0.5, -D, -W - t * 0.5, 2.55)
	wall(-W - t * 0.5, 3.45, -W - t * 0.5, D)
	wall(-W - t * 0.5, 2.55, -W - t * 0.5, 3.45, 0.0, 1.0)
	wall(-W - t * 0.5, 2.55, -W - t * 0.5, 3.45, 1.65, H)
	# ниши слева: перегородки
	for z in [-1.5, 1.5]:
		wall(-W, z, -W + 1.75, z, 0.0, H, 0.22)


# ---------- запад: кислота, печь, скупщик ----------

func _west_side() -> void:
	var metal := surf("metal", 1.2, 0.7)
	# --- ниша кислоты (z -4.5..-1.5): за сеткой ржавая ванна с кислотой, бутыли на ящике, зелёный свет
	_bathtub(Vector3(-5.4, 0, -3.55))
	Props.place(self, "wooden_military_crate", Vector3(-5.7, 0, -2.15), 90, {"scale": 1.0})
	Props.place(self, "bleach_bottle", Vector3(-5.75, 0.46, -2.55), 0, {"height": 0.3, "collide": false})
	Props.place(self, "plastic_bottle_gallon", Vector3(-5.68, 0.46, -2.2), 40, {"height": 0.32, "collide": false})
	Props.place(self, "plastic_bottle_gallon", Vector3(-5.75, 0.46, -1.85), -30, {"height": 0.3, "collide": false})
	Props.place(self, "plastic_bottle_gallon", Vector3(-4.75, 0, -4.2), 10, {"height": 0.32})
	acid_glow = OmniLight3D.new()
	acid_glow.light_color = Color(0.45, 1.0, 0.25)
	acid_glow.light_energy = 0.6
	acid_glow.omni_range = 2.4
	acid_glow.position = Vector3(-5.4, 0.9, -3.55)
	add_child(acid_glow)
	acid_block = Node3D.new()
	add_child(acid_block)
	_fence(acid_block, Vector3(-4.25, 0, -4.5), Vector3(-4.25, 0, -1.61))
	_sign(acid_block, Vector3(-4.2, 1.45, -3.05), Vector3(0, 90, 0), "ЗАКРЫТО")
	# --- ниша печи (z -1.5..1.5): буржуйка с трубой в стену, завалена кирпичом и досками
	Props.place(self, "barrel_stove", Vector3(-5.45, 0, 0.0), 90, {"scale": 1.0})
	var pipe_mat := surf("metal", 1.4, 0.6, Color(0.35, 0.32, 0.3))
	cyl(0.075, 1.3, Vector3(-5.45, 0.86 + 0.65, 0.0), pipe_mat, Vector3.ZERO, 10)
	cyl(0.075, 0.5, Vector3(-5.7, 2.16, 0.0), pipe_mat, Vector3(0, 0, 90), 10)
	cyl(0.085, 0.16, Vector3(-5.45, 2.16, 0.0), pipe_mat, Vector3.ZERO, 10)   # колено
	Props.place(self, "propane_tank", Vector3(-5.7, 0, 1.05), 0, {"height": 0.6})
	furnace_block = Node3D.new()
	add_child(furnace_block)
	_rubble(furnace_block, Vector3(-4.6, 0, 0.0), 1.1, 1.3)
	_acid_basket()
	_furnace_parts()
	# --- ниша скупщика (z 1.5..4.5): окошко в стене, за ним будка с лампой
	var bars := surf("metal", 1.5, 0.6, Color(0.7, 0.7, 0.7))
	for i in 5:
		cyl(0.012, 0.65, Vector3(-W - 0.12, 1.325, 2.6 + i * 0.2), bars, Vector3.ZERO, 6)
	box(Vector3(0.6, 0.05, 1.0), Vector3(-W - 0.05, 0.985, 3.0), surf("planks", 0.8, 0.9))  # подоконник-прилавок
	# будка
	var bx := -W - 1.0
	box(Vector3(1.4, 0.1, 1.6), Vector3(bx, -0.05, 3.0), surf("floor"))
	box(Vector3(1.4, 0.1, 1.6), Vector3(bx, 2.5, 3.0), surf("ceiling"))
	box(Vector3(0.1, 2.5, 1.6), Vector3(bx - 0.7, 1.25, 3.0), surf("wall_top", 0.4, 1.0, Color(0.6, 0.62, 0.55)))
	box(Vector3(1.4, 2.5, 0.1), Vector3(bx, 1.25, 2.2), surf("wall_top", 0.4, 1.0, Color(0.6, 0.62, 0.55)))
	box(Vector3(1.4, 2.5, 0.1), Vector3(bx, 1.25, 3.8), surf("wall_top", 0.4, 1.0, Color(0.6, 0.62, 0.55)))
	box(Vector3(0.5, 0.9, 1.2), Vector3(-W - 0.45, 0.45, 3.0), surf("planks", 0.8, 0.9))  # стол скупщика
	Props.place(self, "retro_multimeter", Vector3(-W - 0.45, 0.9, 3.35), 60, {"height": 0.07, "collide": false})
	Props.place(self, "cigarette_pack", Vector3(-W - 0.4, 0.9, 2.7), 20, {"scale": 1.0, "collide": false})
	booth_light = OmniLight3D.new()
	booth_light.light_color = Color(0.75, 0.9, 1.0)
	booth_light.light_energy = 1.4
	booth_light.omni_range = 3.2
	booth_light.shadow_enabled = true
	booth_light.position = Vector3(bx + 0.1, 2.25, 3.0)
	add_child(booth_light)
	var desk_lamp := OmniLight3D.new()
	desk_lamp.light_color = Color(1.0, 0.8, 0.55)
	desk_lamp.light_energy = 0.8
	desk_lamp.omni_range = 1.6
	desk_lamp.position = Vector3(-W - 0.35, 1.25, 3.0)
	add_child(desk_lamp)
	Props.place(self, "mounted_fluorescent_lights", Vector3(bx + 0.1, 2.5 - 0.035, 3.0), 90, {"scale": 0.8, "collide": false})
	Props.place(self, "metal_jerrycan", Vector3(-5.65, 0, 4.15), 20, {"height": 0.42})


## Корзина-сетка, в которой платы опускают в кислоту (видна только во время травления).
func _acid_basket() -> void:
	acid_basket = Node3D.new()
	acid_basket.position = Vector3(-5.4, 1.15, -3.55)
	acid_basket.visible = false
	add_child(acid_basket)
	var wire := surf("metal", 2.0, 0.5, Color(0.7, 0.7, 0.68))
	var bw := 0.5
	var bd := 0.36
	var bh := 0.2
	for s in [-1, 1]:
		box(Vector3(bw, bh, 0.012), Vector3(0, -bh * 0.5, s * bd * 0.5), wire, false, acid_basket)
		box(Vector3(0.012, bh, bd), Vector3(s * bw * 0.5, -bh * 0.5, 0), wire, false, acid_basket)
	box(Vector3(bw, 0.012, bd), Vector3(0, -bh, 0), wire, false, acid_basket)
	cyl(0.008, 0.9, Vector3(0, 0.45, 0), wire, Vector3.ZERO, 6, acid_basket)   # подвес
	# платы внутри
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.15, 0.45, 0.2)
	for i in 5:
		var b := box(Vector3(0.18, 0.008, 0.12), Vector3(randf_range(-0.12, 0.12), -bh + 0.02 + i * 0.025, randf_range(-0.08, 0.08)), green, false, acid_basket)
		b.rotation.y = randf() * TAU


## Печь: свет огня внутри, тигель сверху, мехи сбоку.
func _furnace_parts() -> void:
	furnace_light = OmniLight3D.new()
	furnace_light.light_color = Color(1.0, 0.45, 0.12)
	furnace_light.light_energy = 0.0
	furnace_light.omni_range = 2.6
	furnace_light.shadow_enabled = true
	furnace_light.position = Vector3(-5.1, 0.55, 0.0)
	add_child(furnace_light)
	var iron := surf("metal", 1.4, 0.7, Color(0.25, 0.23, 0.22))
	crucible_mat = StandardMaterial3D.new()
	crucible_mat.albedo_color = Color(0.3, 0.27, 0.25)
	crucible_mat.roughness = 0.8
	crucible_mat.emission_enabled = true
	crucible_mat.emission = Color(1.0, 0.4, 0.05)
	crucible_mat.emission_energy_multiplier = 0.0
	var cr := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.065
	cm.height = 0.13
	cm.radial_segments = 10
	cr.mesh = cm
	cr.material_override = crucible_mat
	cr.position = Vector3(-5.45, 0.86 + 0.065, 0.22)
	add_child(cr)
	# мехи: две доски и «кожа» между ними
	bellows = Node3D.new()
	bellows.position = Vector3(-4.95, 0.0, 0.62)
	bellows.rotation.y = deg_to_rad(-35)
	add_child(bellows)
	var wood := surf("planks", 1.0, 1.0, Color(0.55, 0.42, 0.3))
	box(Vector3(0.32, 0.03, 0.5), Vector3(0, 0.05, 0), wood, false, bellows)
	var top := box(Vector3(0.32, 0.03, 0.5), Vector3(0, 0.22, 0), wood, false, bellows)
	top.name = "Top"
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3, 0.2, 0.13)
	leather.roughness = 0.9
	var lb := box(Vector3(0.3, 0.16, 0.46), Vector3(0, 0.135, 0), leather, false, bellows)
	lb.name = "Leather"
	cyl(0.025, 0.25, Vector3(0, 0.12, -0.36), iron, Vector3(90, 0, 0), 8, bellows)


func pump_bellows(v: float) -> void:
	## v 0..1 — насколько сжаты мехи
	var top := bellows.get_node("Top") as Node3D
	var lb := bellows.get_node("Leather") as Node3D
	var h := lerpf(0.22, 0.1, v)
	top.position.y = h
	lb.scale.y = (h - 0.05) / 0.17
	lb.position.y = 0.05 + (h - 0.05) * 0.5


func open_acid() -> void:
	if acid_block:
		acid_block.queue_free()
		acid_block = null


func open_furnace() -> void:
	if furnace_block:
		furnace_block.queue_free()
		furnace_block = null
	furnace_light.light_energy = 0.25


## Ржавая ванна с кислотой: корпус из досок-стенок, внутри светящаяся зелёная жижа.
func _bathtub(c: Vector3) -> void:
	var enamel := StandardMaterial3D.new()
	enamel.albedo_color = Color(0.72, 0.7, 0.62)
	enamel.roughness = 0.45
	var rust := surf("metal", 1.0, 0.9, Color(0.55, 0.38, 0.25))
	var L := 1.45
	var Wd := 0.72
	var Hh := 0.55
	var t := 0.06
	box(Vector3(Wd, 0.08, L), c + Vector3(0, 0.12, 0), rust, false)                       # дно
	box(Vector3(t, Hh, L), c + Vector3(-Wd * 0.5 + t * 0.5, Hh * 0.5 + 0.08, 0), enamel, false)
	box(Vector3(t, Hh, L), c + Vector3(Wd * 0.5 - t * 0.5, Hh * 0.5 + 0.08, 0), enamel, false)
	box(Vector3(Wd, Hh, t), c + Vector3(0, Hh * 0.5 + 0.08, -L * 0.5 + t * 0.5), enamel, false)
	box(Vector3(Wd, Hh, t), c + Vector3(0, Hh * 0.5 + 0.08, L * 0.5 - t * 0.5), enamel, false)
	# ножки
	for s in [-1, 1]:
		cyl(0.035, 0.1, c + Vector3(s * (Wd * 0.5 - 0.08), 0.05, -L * 0.5 + 0.12), rust, Vector3.ZERO, 6)
		cyl(0.035, 0.1, c + Vector3(s * (Wd * 0.5 - 0.08), 0.05, L * 0.5 - 0.12), rust, Vector3.ZERO, 6)
	var acid := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Wd - t * 2, L - t * 2)
	acid.mesh = pm
	var am := StandardMaterial3D.new()
	acid_mat = am
	am.albedo_color = Color(0.3, 0.75, 0.15)
	am.emission_enabled = true
	am.emission = Color(0.35, 0.9, 0.12)
	am.emission_energy_multiplier = 1.6
	am.roughness = 0.08
	am.metallic = 0.2
	acid.material_override = am
	acid.position = c + Vector3(0, Hh * 0.82, 0)
	add_child(acid)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(Wd, Hh + 0.1, L)
	cs.shape = sh
	cs.position = c + Vector3(0, (Hh + 0.1) * 0.5, 0)
	body.add_child(cs)
	add_child(body)


func _fence(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var metal := surf("metal", 1.5, 0.6, Color(0.75, 0.72, 0.68))
	var len := a.distance_to(b)
	var n := int(len / 1.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		cyl(0.025, H - 0.05, p + Vector3(0, (H - 0.05) * 0.5, 0), metal, Vector3.ZERO, 6, parent)
	# сетка-рабица: прозрачная текстура ромбиками
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 32:
		for w in 2:
			img.set_pixel((i + w) % 32, i, Color(0.6, 0.58, 0.55, 1))
			img.set_pixel((31 - i + w) % 32, i, Color(0.6, 0.58, 0.55, 1))
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.6
	m.roughness = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(len * 6, H * 6, 1)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(len, H - 0.1)
	q.mesh = qm
	q.material_override = m
	q.position = (a + b) * 0.5 + Vector3(0, (H - 0.1) * 0.5, 0)
	q.rotation.y = atan2(b.x - a.x, b.z - a.z) + PI * 0.5
	parent.add_child(q)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(len, H, 0.08)
	cs.shape = sh
	body.add_child(cs)
	q.add_child(body)


func _rubble(parent: Node3D, center: Vector3, width: float, height: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var brick := surf("brick", 1.6, 1.0, Color(0.85, 0.75, 0.7))
	var planks := surf("planks", 0.9, 1.0, Color(0.8, 0.75, 0.7))
	for i in 80:
		var hh := pow(rng.randf(), 1.4) * height
		var k := 1.0 - hh / height
		var p := center + Vector3(rng.randf_range(-0.45, 0.35) * (0.4 + k * 0.6), hh, rng.randf_range(-width, width) * (0.55 + k * 0.45))
		var mi := box(Vector3(0.24, 0.07, 0.12), p, brick, false, parent)
		mi.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * 3, rng.randf_range(-0.5, 0.5))
	# доски прислонены к куче (наклон вдоль X, чтобы не пробивали перегородки)
	for i in 6:
		var len := rng.randf_range(0.9, 1.35)
		var mi := box(Vector3(0.05, len, 0.16), center + Vector3(rng.randf_range(0.05, 0.3), len * 0.45, rng.randf_range(-width * 0.8, width * 0.8)), planks, false, parent)
		mi.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.4, 0.4), rng.randf_range(0.25, 0.5))
	Props.place(parent, "cement_bag", center + Vector3(0.35, 0, -0.75), 30, {"height": 0.25, "collide": false})
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, height + 0.3, width * 2.0)
	cs.shape = sh
	cs.position = center + Vector3(0, (height + 0.3) * 0.5, 0)
	body.add_child(cs)
	parent.add_child(body)


func _sign(parent: Node3D, pos: Vector3, rot: Vector3, text: String) -> Label3D:
	var board := box(Vector3(0.7, 0.32, 0.02), pos, _cardboard(), false, parent)
	board.rotation_degrees = rot
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Oswald.ttf")
	l.font_size = 64
	l.pixel_size = 0.0028
	l.modulate = Color(0.15, 0.1, 0.08)
	l.outline_size = 0
	l.position = Vector3(0, 0, 0.012)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	board.add_child(l)
	return l


func _cardboard() -> StandardMaterial3D:
	if mats.has("_card"):
		return mats["_card"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.48, 0.3)
	m.roughness = 1.0
	mats["_card"] = m
	return m


# ---------- север: ящик долга и таксофон ----------

func _north_side() -> void:
	# стол вплотную к стене, табурет перед ним
	Props.place(self, "metal_office_desk", Vector3(0.0, 0, -D + 0.48), 180, {"scale": 1.0})
	Props.place(self, "folding_wooden_stool", Vector3(0.25, 0, -3.3), 15, {"scale": 1.0})
	Props.place(self, "russian_food_cans_01", Vector3(0.45, 0.79, -4.15), 30, {"scale": 1.0, "collide": false})
	Props.place(self, "cigarette_pack", Vector3(-0.3, 0.79, -4.0), 70, {"scale": 1.0, "collide": false})
	# ящик для долга — железный шкаф на полу у стены, надпись краской на стене над ним
	Props.place(self, "utility_box_01", DEBT_BOX + Vector3(0, 0, 0), 0, {"scale": 1.0})
	debt_label = Label3D.new()
	debt_label.font = load("res://assets/fonts/Oswald.ttf")
	debt_label.font_size = 72
	debt_label.pixel_size = 0.0034
	debt_label.line_spacing = -10
	debt_label.modulate = Color(0.72, 0.08, 0.06)
	debt_label.outline_size = 0
	debt_label.position = Vector3(DEBT_BOX.x, 1.72, -D + 0.012)
	debt_label.text = "ДОЛГ"
	add_child(debt_label)
	debt_light = OmniLight3D.new()
	debt_light.light_color = Color(1.0, 0.25, 0.15)
	debt_light.light_energy = 0.6
	debt_light.omni_range = 2.6
	debt_light.position = Vector3(DEBT_BOX.x + 0.2, 2.35, -3.9)
	add_child(debt_light)
	# таксофон висит на стене
	Props.place(self, "korean_public_payphone_01", Vector3(1.6, 0.95, -D + 0.15), 0, {"scale": 1.0, "collide": false})


# ---------- восток: прилавки ----------

func _east_stalls() -> void:
	var planks := surf("planks", 0.9, 0.95, Color(0.75, 0.7, 0.62))
	var top_mat := surf("planks", 0.9, 0.9, Color(0.62, 0.55, 0.46))
	var metal := surf("metal", 1.5, 0.6)
	var L: float = STALL_LEN
	var depth := 0.6
	var x0 := STALL_X - depth * 0.5     # передний край (к игроку)
	var x1 := STALL_X + depth * 0.5     # задний край (к продавцу)
	var tarp_cols := [Color(0.25, 0.35, 0.5), Color(0.45, 0.3, 0.2), Color(0.3, 0.38, 0.28), Color(0.4, 0.4, 0.4), Color(0.5, 0.25, 0.22)]
	for i in STALL_Z.size():
		var z: float = STALL_Z[i]
		# прилавок: столешница + передняя и боковые стенки, сзади открыт (там ноги продавца)
		box(Vector3(depth + 0.06, 0.045, L + 0.06), Vector3(STALL_X, 0.92, z), top_mat, false)
		box(Vector3(0.03, 0.88, L), Vector3(x0 + 0.015, 0.45, z), planks, false)
		for s in [-1, 1]:
			box(Vector3(depth, 0.88, 0.03), Vector3(STALL_X, 0.45, z + s * (L * 0.5 - 0.015)), planks, false)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(depth, 0.95, L)
		cs.shape = sh
		cs.position = Vector3(STALL_X, 0.475, z)
		body.add_child(cs)
		add_child(body)
		# табурет продавца (под тазом сидящего) и полка на стене выше головы
		Props.place(self, "folding_wooden_stool", Vector3(SEAT_X, 0, z), 90, {"height": 0.44, "collide": false})
		_wall_shelf(z, L, i)
		# каркас навеса: две стойки спереди, перекладины до стены, брезент сверху
		var ph := 2.12
		for s in [-1, 1]:
			var pz: float = z + s * (L * 0.5 + 0.02)
			cyl(0.022, ph, Vector3(x0 - 0.04, ph * 0.5, pz), metal, Vector3.ZERO, 6)
			cyl(0.018, W - x0 + 0.04, Vector3((x0 - 0.04 + W) * 0.5, ph, pz), metal, Vector3(0, 0, 90), 6)
		cyl(0.018, L + 0.04, Vector3(x0 - 0.04, ph, z), metal, Vector3(90, 0, 0), 6)
		var tarp := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var tw := W - x0 + 0.2
		qm.size = Vector2(tw, L + 0.14)
		tarp.mesh = qm
		var tm := StandardMaterial3D.new()
		tm.albedo_color = tarp_cols[i]
		tm.cull_mode = BaseMaterial3D.CULL_DISABLED
		tm.roughness = 1.0
		tarp.material_override = tm
		tarp.position = Vector3((x0 - 0.2 + W) * 0.5, ph + 0.08, z)
		tarp.rotation = Vector3(-PI * 0.5, 0, -0.1)
		add_child(tarp)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 0.0
		l.omni_range = 2.4
		l.shadow_enabled = true
		l.position = Vector3(STALL_X + 0.25, 1.9, z)
		add_child(l)
		stall_lights.append(l)
		if i == 0:
			# точка Коляна: инструмент на прилавке
			Props.place(self, "bench_vice_01", Vector3(STALL_X + 0.05, 0.94, z - 0.3), 90, {"height": 0.15, "collide": false})
			Props.place(self, "retro_multimeter", Vector3(STALL_X - 0.05, 0.94, z + 0.25), 60, {"height": 0.07, "collide": false})
		else:
			# пустые точки накрыты тряпкой
			var cloth := box(Vector3(depth + 0.1, 0.02, L + 0.12), Vector3(STALL_X, 0.955, z), _cloth(i), false)
			var flap := box(Vector3(0.015, 0.5, L + 0.12), Vector3(x0 - 0.04, 0.72, z), _cloth(i), false)
			cloth.rotation.y = 0.02 * i
			flap.rotation.z = 0.05
			if i % 2 == 1:
				Props.place(self, "cardboard_box_01", Vector3(STALL_X, 0.965, z + 0.15), 15 * i, {"height": 0.3, "collide": false})
	Props.place(self, "wooden_crate_01", Vector3(W - 0.45, 0, 4.25), 0, {"scale": 1.0})
	Props.place(self, "wooden_crate_02", Vector3(W - 0.45, 0.35, 4.25), -8, {"height": 0.35})


## Две доски-полки на кронштейнах на восточной стене, выше головы сидящего продавца.
func _wall_shelf(z: float, L: float, i: int) -> void:
	var planks := surf("planks", 0.9, 0.95, Color(0.7, 0.64, 0.55))
	var metal := surf("metal", 1.5, 0.6, Color(0.5, 0.48, 0.45))
	for y in [1.62, 1.98]:
		box(Vector3(0.3, 0.03, L - 0.1), Vector3(W - 0.15, y, z), planks, false)
		for s in [-1, 1]:
			box(Vector3(0.24, 0.025, 0.025), Vector3(W - 0.13, y - 0.05, z + s * (L * 0.5 - 0.15)), metal, false)
			box(Vector3(0.025, 0.16, 0.025), Vector3(W - 0.012, y - 0.1, z + s * (L * 0.5 - 0.15)), metal, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + i
	var stuff := ["can_rusted", "cardboard_box_01", "plastic_bottle_gallon", "russian_food_cans_01", "metal_jerrycan"]
	for y in [1.635, 1.995]:
		var zz := z - L * 0.5 + 0.18
		while zz < z + L * 0.5 - 0.15:
			var id: String = stuff[rng.randi() % stuff.size()]
			var opt := {"collide": false}
			if id == "russian_food_cans_01":
				opt["scale"] = 1.0
			else:
				opt["height"] = rng.randf_range(0.12, 0.24)
			Props.place(self, id, Vector3(W - 0.15, y, zz), rng.randf() * 360, opt)
			zz += rng.randf_range(0.22, 0.34)


func _cloth(i: int) -> StandardMaterial3D:
	var key := "_cloth%d" % (i % 3)
	if mats.has(key):
		return mats[key]
	var m := surf("carpet", 1.0, 1.0, [Color(0.45, 0.42, 0.36), Color(0.35, 0.3, 0.32), Color(0.4, 0.38, 0.3)][i % 3]).duplicate()
	mats[key] = m
	return m


func light_stall(i: int, on: bool) -> void:
	var l := stall_lights[i]
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 1.1 if on else 0.0, 1.2)


# ---------- центр: подъёмник с баком ----------

func _hazard_mat() -> StandardMaterial3D:
	if mats.has("_hazard"):
		return mats["_hazard"]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, Color(0.85, 0.65, 0.1) if ((x + y) / 4) % 2 == 0 else Color(0.06, 0.06, 0.05))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	m.roughness = 0.8
	mats["_hazard"] = m
	return m


func _lift_pit() -> void:
	var c := LIFT
	var wall_m := surf("metal", 1.0, 0.8, Color(0.35, 0.33, 0.3))
	var depth := 2.3
	# шахта под полом
	for s in [-1, 1]:
		box(Vector3(0.06, depth, HOLE.y), c + Vector3(s * (HOLE.x * 0.5 + 0.03), -depth * 0.5, 0), wall_m, false)
		box(Vector3(HOLE.x, depth, 0.06), c + Vector3(0, -depth * 0.5, s * (HOLE.y * 0.5 + 0.03)), wall_m, false)
	box(Vector3(HOLE.x, 0.06, HOLE.y), c + Vector3(0, -depth, 0), wall_m, false)
	# окантовка проёма жёлто-чёрной полосой
	var hz := _hazard_mat()
	var t := 0.11
	box(Vector3(HOLE.x + t * 2, 0.012, t), c + Vector3(0, 0.006, -HOLE.y * 0.5 - t * 0.5), hz, false)
	box(Vector3(HOLE.x + t * 2, 0.012, t), c + Vector3(0, 0.006, HOLE.y * 0.5 + t * 0.5), hz, false)
	box(Vector3(t, 0.012, HOLE.y), c + Vector3(-HOLE.x * 0.5 - t * 0.5, 0.006, 0), hz, false)
	box(Vector3(t, 0.012, HOLE.y), c + Vector3(HOLE.x * 0.5 + t * 0.5, 0.006, 0), hz, false)
	# невидимый пол над проёмом — чтобы не провалиться, пока бак внизу
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(HOLE.x, 0.1, HOLE.y)
	cs.shape = sh
	cs.position = c + Vector3(0, -0.05, 0)
	body.add_child(cs)
	add_child(body)
	# створки люка (открыты — висят вниз по бокам шахты)
	var door_m := surf("metal", 1.4, 0.6, Color(0.45, 0.43, 0.4))
	hatch_l = Node3D.new()
	hatch_l.position = c + Vector3(-HOLE.x * 0.5, -0.03, 0)
	add_child(hatch_l)
	box(Vector3(HOLE.x * 0.5, 0.04, HOLE.y - 0.02), Vector3(HOLE.x * 0.25, 0, 0), door_m, false, hatch_l)
	hatch_r = Node3D.new()
	hatch_r.position = c + Vector3(HOLE.x * 0.5, -0.03, 0)
	add_child(hatch_r)
	box(Vector3(HOLE.x * 0.5, 0.04, HOLE.y - 0.02), Vector3(-HOLE.x * 0.25, 0, 0), door_m, false, hatch_r)
	_set_hatch(1.0)
	# платформа подъёмника
	lift = Node3D.new()
	lift.position = c
	add_child(lift)
	box(Vector3(HOLE.x - 0.08, 0.06, HOLE.y - 0.06), Vector3(0, -0.03, 0), surf("grate", 1.6, 0.6, Color(0.6, 0.6, 0.6)), false, lift)
	box(Vector3(0.3, 2.2, 0.3), Vector3(0, -1.16, 0), wall_m, false, lift)   # поршень
	# мигалка у края проёма
	var post := surf("metal", 1.5, 0.6, Color(0.3, 0.3, 0.3))
	cyl(0.04, 0.12, c + Vector3(HOLE.x * 0.5 + 0.06, 0.06, -HOLE.y * 0.5 - 0.06), post, Vector3.ZERO, 8)
	beacon_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	beacon_mesh.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.5, 0.1)
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.45, 0.05)
	bm.emission_energy_multiplier = 0.2
	beacon_mesh.material_override = bm
	beacon_mesh.position = c + Vector3(HOLE.x * 0.5 + 0.06, 0.16, -HOLE.y * 0.5 - 0.06)
	add_child(beacon_mesh)
	beacon = OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.5, 0.1)
	beacon.light_energy = 0.0
	beacon.omni_range = 3.0
	beacon.position = beacon_mesh.position + Vector3(0, 0.1, 0)
	add_child(beacon)


## 0 — люк закрыт, 1 — открыт.
func _set_hatch(v: float) -> void:
	hatch_l.rotation.z = -deg_to_rad(95.0) * v
	hatch_r.rotation.z = deg_to_rad(95.0) * v


func hatch(open: bool, sec := 0.7) -> void:
	var from := 0.0 if open else 1.0
	var tw := create_tween()
	tw.tween_method(_set_hatch, from, 1.0 - from, sec).set_trans(Tween.TRANS_SINE)
	await tw.finished
	Sfx.play3d("clank", LIFT + Vector3(0, 0.1, 0), -4.0, 1.2 if open else 0.9)


func lift_move(up: bool, sec := 2.4) -> void:
	Sfx.play3d("lift", LIFT + Vector3(0, -0.3, 0), 0.0, 1.0 if up else 0.9)
	var tw := create_tween()
	tw.tween_property(lift, "position:y", LIFT.y if up else LIFT_DOWN, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	Sfx.play3d("clank", LIFT + Vector3(0, 0.1, 0), -2.0)


func set_beacon(on: bool) -> void:
	_beacon_on = on
	if not on:
		beacon.light_energy = 0.0
		(beacon_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.2


# ---------- юг: дверь и коридор за ней ----------

func _door_and_corridor() -> void:
	var door_mat := surf("door", 1.6, 0.6, Color(0.75, 0.6, 0.5))
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(DOOR_X - DOOR_W * 0.5, 0, D + 0.05)
	add_child(door_pivot)
	var door := box(Vector3(DOOR_W, DOOR_H, 0.06), Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0), door_mat, true, door_pivot)
	cyl(0.012, 0.03, Vector3(0, 1.6 - DOOR_H * 0.5, -0.04), surf("metal", 2.0, 0.3, Color(0.5, 0.5, 0.5)), Vector3(90, 0, 0), 8, door)
	var handle := box(Vector3(0.12, 0.025, 0.03), Vector3(DOOR_W * 0.35, 1.0 - DOOR_H * 0.5, -0.05), surf("metal", 2.0, 0.3), false, door)
	# невидимая преграда в проёме: игрок не выйдет из подвала, даже когда дверь открыта (гости проходят — они без физики)
	var block := StaticBody3D.new()
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(DOOR_W + 0.1, DOOR_H, 0.08)
	bcs.shape = bsh
	bcs.position = Vector3(DOOR_X, DOOR_H * 0.5, D + 0.02)
	block.add_child(bcs)
	add_child(block)
	# коридор: пол, стены, лестница вверх, тусклая лампа
	var cz := D + 1.3
	box(Vector3(1.6, 0.1, 2.2), Vector3(DOOR_X, -0.05, cz), surf("floor"))
	box(Vector3(1.6, 0.1, 2.2), Vector3(DOOR_X, H + 0.05, cz), surf("ceiling"))
	box(Vector3(0.1, H, 2.2), Vector3(DOOR_X - 0.8, H * 0.5, cz), surf("wall_top", 0.4, 1.0, Color(0.55, 0.55, 0.5)))
	box(Vector3(0.1, H, 2.2), Vector3(DOOR_X + 0.8, H * 0.5, cz), surf("wall_top", 0.4, 1.0, Color(0.55, 0.55, 0.5)))
	for i in 6:
		box(Vector3(1.5, 0.18, 0.3), Vector3(DOOR_X, 0.09 + i * 0.18, D + 1.55 + i * 0.28), surf("floor"))
	box(Vector3(1.6, H, 0.1), Vector3(DOOR_X, H * 0.5, D + 2.45), surf("wall_top", 0.4, 1.0, Color(0.5, 0.5, 0.45)))
	var cl := OmniLight3D.new()
	cl.light_color = Color(0.85, 0.9, 1.0)
	cl.light_energy = 0.7
	cl.omni_range = 3.0
	cl.position = Vector3(DOOR_X, 2.4, D + 0.9)
	cl.shadow_enabled = true
	add_child(cl)
	Props.place(self, "lightbulb_01", Vector3(DOOR_X, 2.62, D + 0.9), 0, {"height": 0.12, "collide": false})


func open_door(open: bool) -> void:
	var tw := create_tween()
	tw.tween_property(door_pivot, "rotation:y", deg_to_rad(-105.0) if open else 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	if open:
		Sfx.play3d("creak", door_pivot.global_position + Vector3(0.45, 1.2, 0), 0.0)
	else:
		tw.tween_callback(func(): Sfx.play3d("door_shut", door_pivot.global_position + Vector3(0.45, 1.2, 0), 2.0))


# ---------- хлам по углам ----------

func _top(n: Node3D) -> float:
	return (n.transform * Props.aabb_of(n)).end.y


func _clutter() -> void:
	# всё стоит у стен и в углах — посреди прохода ничего не валяется
	Props.place(self, "Barrel_01", Vector3(-3.65, 0, -4.15), 30, {"height": 0.9})
	Props.place(self, "barrel_03", Vector3(-3.0, 0, -4.18), 0, {"height": 0.85})
	Props.place(self, "wooden_military_crate", Vector3(2.85, 0, -D + 0.27), 0, {"scale": 1.0})
	Props.place(self, "metal_toolbox", Vector3(2.65, 0.46, -D + 0.27), 10, {"height": 0.2, "collide": false})
	Props.place(self, "power_box_01", Vector3(3.2, 0.46, -D + 0.22), 0, {"scale": 1.0, "collide": false})
	# покрышки лежат стопкой у южной стены
	Props.place(self, "old_tyre", Vector3(3.4, 0, D - 0.36), 0, {"size": 0.6, "tilt": Vector3(90, 0, 0)})
	Props.place(self, "old_tyre", Vector3(3.42, 0.2, D - 0.37), 0, {"size": 0.6, "tilt": Vector3(90, 0, 0), "collide": false})
	Props.place(self, "rubber_boots", Vector3(0.5, 0, D - 0.16), 0, {"scale": 1.0, "collide": false})
	Props.place(self, "wooden_bucket_01", Vector3(-2.2, 0, -2.4), 0, {"height": 0.3})
	# кровать Палыча у южной стены
	Props.place(self, "old_bed_frame", Vector3(-2.5, 0, D - 0.47), 90, {"scale": 1.0})
	# ещё барахло по углам (CC0, Poly Haven)
	Props.place(self, "hand_truck", Vector3(2.5, 0, D - 0.3), 180, {"height": 1.1})
	Props.place(self, "wooden_broom", Vector3(2.12, 0, D - 0.12), 0, {"height": 1.25, "tilt": Vector3(10, 0, 0), "collide": false})
	Props.place(self, "dustpan", Vector3(2.15, 0, D - 0.42), 160, {"max_size": 0.32, "collide": false})
	Props.place(self, "korean_fire_extinguisher_01", Vector3(4.3, 0, D - 0.14), 200, {"height": 0.5})
	var sc := Props.place(self, "vintage_suitcase", Vector3(-0.85, 0, D - 0.25), 5, {"max_size": 0.65})
	if sc:
		Props.place(self, "boombox", Vector3(-0.85, _top(sc), D - 0.25), 170, {"max_size": 0.42, "collide": false})
	Props.place(self, "portable_generator", Vector3(-2.3, 0, -D + 0.35), 0, {"max_size": 0.65})
	var cr := Props.place(self, "plastic_crate_02", Vector3(3.95, 0, -D + 0.28), 0, {"max_size": 0.5})
	if cr:
		Props.place(self, "Television_01", Vector3(3.95, _top(cr), -D + 0.28), 180, {"max_size": 0.45, "collide": false})
	Props.place(self, "vintage_radio_transceiver", Vector3(-0.1, 0.79, -4.25), 180, {"max_size": 0.34, "collide": false})
	# лужи
	for p in [Vector3(-2.2, 0, -2.4), Vector3(2.4, 0, 1.6), Vector3(-1.2, 0, 2.6), Vector3(0.9, 0, -3.0)]:
		var pd := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = randf_range(0.35, 0.7)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.004
		cm.radial_segments = 12
		pd.mesh = cm
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.12, 0.12, 0.1, 0.4)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.roughness = 0.04
		pm.metallic = 0.2
		pd.material_override = pm
		pd.position = p + Vector3(randf_range(-0.3, 0.3), 0.003, randf_range(-0.3, 0.3))
		pd.scale = Vector3(1.0, 1.0, randf_range(0.6, 1.0))
		add_child(pd)
	rat = Props.place(self, "street_rat", Vector3(-20, 0, 0), 0, {"height": 0.09, "collide": false})


func _pipes() -> void:
	var metal := surf("metal", 1.4, 0.55, Color(0.8, 0.75, 0.7))
	cyl(0.07, W * 2, Vector3(0, H - 0.22, -D + 0.25), metal, Vector3(0, 0, 90), 8)
	cyl(0.045, W * 2, Vector3(0, H - 0.4, -D + 0.22), metal, Vector3(0, 0, 90), 8)
	cyl(0.06, D * 2, Vector3(W - 0.3, H - 0.25, 0), metal, Vector3(90, 0, 0), 8)
	cyl(0.05, D * 2, Vector3(-1.2, H - 0.18, 0), metal, Vector3(90, 0, 0), 8)
	cyl(0.05, H - 0.4, Vector3(-W + 0.25, (H - 0.4) * 0.5, -D + 0.25), metal, Vector3.ZERO, 8)
	# кронштейны: от стены к трубам и подвесы к потолку
	for x in [-4.0, -1.5, 2.0, 4.5]:
		box(Vector3(0.04, 0.04, 0.3), Vector3(x, H - 0.22, -D + 0.14), metal, false)
		box(Vector3(0.04, 0.04, 0.24), Vector3(x, H - 0.4, -D + 0.11), metal, false)
		box(Vector3(0.03, 0.15, 0.03), Vector3(x, H - 0.075, -D + 0.25), metal, false)
	for z in [-3.0, -0.5, 2.0, 4.0]:
		box(Vector3(0.03, 0.2, 0.03), Vector3(W - 0.3, H - 0.1, z), metal, false)
		box(Vector3(0.03, 0.13, 0.03), Vector3(-1.2, H - 0.065, z), metal, false)


## Качество графики: 0 — низкое, 1 — среднее, 2 — высокое.
func apply_quality(q: int) -> void:
	if env:
		env.ssao_enabled = q >= 1
		env.ssr_enabled = q >= 2
		env.volumetric_fog_enabled = q >= 1
		env.glow_enabled = q >= 1
	for l in find_children("*", "OmniLight3D", true, false):
		var ol := l as OmniLight3D
		if ol == bulb_light:
			ol.shadow_enabled = true
		elif ol.has_meta("shadow"):
			ol.shadow_enabled = bool(ol.get_meta("shadow")) and q >= 1



# ---------- свет ----------

func _lights() -> void:
	bulb_pivot = Node3D.new()
	bulb_pivot.position = Vector3(0, H, -0.2)
	add_child(bulb_pivot)
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.05, 0.05, 0.05)
	cyl(0.006, 0.62, Vector3(0, -0.31, 0), cord_mat, Vector3.ZERO, 4, bulb_pivot)
	var bulb := Props.place(bulb_pivot, "lightbulb_01", Vector3(0, -0.74, 0), 0, {"height": 0.12, "collide": false})
	bulb_glass = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	bulb_glass.mesh = sm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1, 0.85, 0.6)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.75, 0.45)
	gm.emission_energy_multiplier = 6.0
	bulb_glass.material_override = gm
	bulb_glass.position = Vector3(0, -0.68, 0)
	bulb_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb_pivot.add_child(bulb_glass)
	bulb_light = OmniLight3D.new()
	bulb_light.light_color = Color(1.0, 0.76, 0.48)
	bulb_light.light_energy = 2.6
	bulb_light.omni_range = 9.0
	bulb_light.omni_attenuation = 1.4
	bulb_light.shadow_enabled = true
	bulb_light.shadow_bias = 0.05
	bulb_light.light_volumetric_fog_energy = 1.6
	bulb_light.position = Vector3(0, -0.76, 0)
	bulb_pivot.add_child(bulb_light)


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.33, 0.3)
	env.ambient_light_energy = 0.14
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.2
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.055, 0.045)
	env.fog_density = 0.035
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.78)
	env.volumetric_fog_length = 16.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.82
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------- капли ----------

func _drips() -> void:
	for p in [Vector3(-2.2, H - 0.2, -2.4), Vector3(2.4, H - 0.25, 1.6), Vector3(-1.2, H - 0.18, 2.6), Vector3(0.9, H - 0.4, -4.28), Vector3(4.5, H - 0.2, -0.2)]:
		var d := Drip.new()
		d.position = p
		add_child(d)
	var acid := Drip.new()
	acid.acid = true
	acid.position = Vector3(-5.3, H - 0.1, -3.3)
	add_child(acid)


func _process(dt: float) -> void:
	_t += dt
	var rot := G.rot()
	# лампочка качается
	if bulb_pivot:
		bulb_pivot.rotation.z = sin(_t * 0.9) * 0.05 + sin(_t * 2.3) * 0.012
		bulb_pivot.rotation.x = sin(_t * 0.7 + 1.0) * 0.035
	# мигание: чем ближе срок долга, тем чаще
	_next_flicker -= dt
	if _next_flicker <= 0.0:
		_flicker = randf_range(0.08, 0.5)
		_next_flicker = randf_range(2.0, 12.0) * (1.0 - rot * 0.75)
		if randf() < 0.5:
			Sfx.play3d("buzz", bulb_light.global_position, -10.0, randf_range(0.9, 1.1))
	var e := 2.6
	if _flicker > 0.0:
		_flicker -= dt
		e *= 0.15 if fmod(_t * 23.0, 1.0) < 0.5 else 0.8
	bulb_light.light_energy = e * (1.0 - rot * 0.25)
	(bulb_glass.material_override as StandardMaterial3D).emission_energy_multiplier = e * 2.3
	if booth_light:
		booth_light.light_energy = 1.4 if fmod(_t * 7.3, 9.0) > 0.25 else 0.4
	if _beacon_on:
		var b := 1.0 if fmod(_t * 3.0, 1.0) < 0.5 else 0.0
		beacon.light_energy = 1.6 * b
		(beacon_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = 0.2 + 5.0 * b
	if debt_light:
		debt_light.light_energy = 0.45 + 0.15 * sin(_t * 1.7) + rot * 0.6
	# крыса иногда перебегает
	_rat_timer -= dt
	if _rat_timer <= 0.0 and rat:
		_rat_timer = randf_range(50.0, 110.0)
		_run_rat()


func _run_rat() -> void:
	var routes := [[Vector3(-3.0, 0, 4.3), Vector3(-0.8, 0, 1.4)], [Vector3(3.8, 0, -4.3), Vector3(1.3, 0, -1.2)],
		[Vector3(-4.0, 0, -1.4), Vector3(-1.4, 0, -0.6)]]
	var r: Array = routes[randi() % routes.size()]
	var a: Vector3 = r[0]
	var b: Vector3 = r[1]
	if randf() < 0.5:
		var tmp := a
		a = b
		b = tmp
	rat.position = a
	rat.rotation.y = atan2(b.x - a.x, b.z - a.z)
	var tw := create_tween()
	tw.tween_property(rat, "position", b, a.distance_to(b) / 2.2)
	tw.tween_callback(func(): rat.position = Vector3(-20, 0, 0))
	Sfx.play3d("squeak", a, -6.0, randf_range(0.9, 1.2))


func set_debt_text(t: String) -> void:
	if debt_label:
		debt_label.text = t


# ---------- класс капли ----------

class Drip extends Node3D:
	var acid := false
	var _wait := 1.0

	func _ready() -> void:
		_wait = randf_range(0.5, 3.0)

	func _process(dt: float) -> void:
		_wait -= dt
		if _wait > 0.0:
			return
		_wait = randf_range(1.4, 4.5) if not acid else randf_range(2.0, 4.0)
		var drop := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.008
		sm.height = 0.024
		sm.radial_segments = 4
		sm.rings = 2
		drop.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 1.0, 0.4) if acid else Color(0.6, 0.65, 0.7)
		m.emission_enabled = acid
		m.emission = Color(0.5, 1.0, 0.2)
		m.emission_energy_multiplier = 2.0
		m.roughness = 0.1
		drop.material_override = m
		add_child(drop)
		var fall := global_position.y - 0.03
		var tw := create_tween()
		tw.tween_property(drop, "position:y", -fall, sqrt(2.0 * fall / 9.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			Sfx.play3d("sizzle" if acid else "drip", drop.global_position, -4.0 if acid else -8.0, randf_range(0.85, 1.2), 12.0)
			drop.queue_free())
