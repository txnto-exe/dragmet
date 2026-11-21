class_name TrashBin
extends Node3D
## Мусорный бак на колёсиках: открытый верх, откинутая крышка, табличка с типом.
## Внутри — узел contents, куда BinSearch складывает хлам и находки.

const OUT := Vector3(1.3, 0.95, 0.9)    # наружные размеры
const IN_X := 0.59                      # полуширина внутри
const IN_Z := 0.4                       # полуглубина внутри
const FLOOR_Y := 0.34                   # фальш-дно внутри (хлам лежит почти до краёв)

var type := "home"
var contents: Node3D
var lid: Node3D
const LID_OPEN := -104.0


func build(t: String, base: Basement, lid_open := true) -> void:
	type = t
	var info: Dictionary = G.BIN_TYPES[t]
	var col: Color = info["color"]
	var metal := base.surf("metal", 1.3, 0.55, col.lightened(0.25))
	var dark := base.surf("metal", 1.3, 0.7, col.darkened(0.35))
	var w := 0.04
	var h := OUT.y - 0.1
	var cy := 0.1 + h * 0.5
	# стенки и дно
	base.box(Vector3(OUT.x, h, w), Vector3(0, cy, OUT.z * 0.5 - w * 0.5), metal, false, self)
	base.box(Vector3(OUT.x, h, w), Vector3(0, cy, -OUT.z * 0.5 + w * 0.5), metal, false, self)
	# боковины и дно — между передней и задней стенкой, без наложения граней в углах
	base.box(Vector3(w, h, OUT.z - w * 2), Vector3(OUT.x * 0.5 - w * 0.5, cy, 0), metal, false, self)
	base.box(Vector3(w, h, OUT.z - w * 2), Vector3(-OUT.x * 0.5 + w * 0.5, cy, 0), metal, false, self)
	base.box(Vector3(OUT.x - w * 2, 0.05, OUT.z - w * 2), Vector3(0, FLOOR_Y - 0.025, 0), dark, false, self)
	# отбортовка сверху
	base.box(Vector3(OUT.x + 0.05, 0.05, 0.06), Vector3(0, OUT.y - 0.02, OUT.z * 0.5), dark, false, self)
	base.box(Vector3(OUT.x + 0.05, 0.05, 0.06), Vector3(0, OUT.y - 0.02, -OUT.z * 0.5), dark, false, self)
	base.box(Vector3(0.06, 0.05, OUT.z - 0.06), Vector3(OUT.x * 0.5, OUT.y - 0.02, 0), dark, false, self)
	base.box(Vector3(0.06, 0.05, OUT.z - 0.06), Vector3(-OUT.x * 0.5, OUT.y - 0.02, 0), dark, false, self)
	# рёбра жёсткости спереди
	for x in [-0.4, 0.0, 0.4]:
		base.box(Vector3(0.05, h * 0.8, 0.02), Vector3(x, cy, OUT.z * 0.5 + 0.01), dark, false, self)
	# колёса
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	rubber.roughness = 0.9
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			base.cyl(0.055, 0.05, Vector3(sx * (OUT.x * 0.5 - 0.12), 0.055, sz * (OUT.z * 0.5 - 0.1)), rubber, Vector3(0, 0, 90), 10, self)
	# крышка откинута назад
	var hinge := Node3D.new()
	lid = hinge
	hinge.position = Vector3(0, OUT.y, -OUT.z * 0.5 - 0.02)
	add_child(hinge)
	base.box(Vector3(OUT.x + 0.04, 0.035, OUT.z + 0.04), Vector3(0, 0, OUT.z * 0.5), dark, false, hinge)
	hinge.rotation.x = deg_to_rad(LID_OPEN if lid_open else 0.0)
	# табличка с типом
	var plate := base.box(Vector3(0.62, 0.15, 0.012), Vector3(0, 0.62, OUT.z * 0.5 + 0.026), _plate_mat(), false, self)
	var l := Label3D.new()
	l.text = info["name"]
	l.font = load("res://assets/fonts/Oswald.ttf")
	l.font_size = 64
	l.pixel_size = 0.0019
	l.modulate = Color(0.95, 0.92, 0.82)
	l.outline_size = 0
	l.position = Vector3(0, 0, 0.013)   # надпись над табличкой с зазором — без мерцания
	plate.add_child(l)
	if t == "military":
		var star := Label3D.new()
		star.text = "★"
		star.font_size = 96
		star.pixel_size = 0.004
		star.modulate = Color(0.75, 0.15, 0.1)
		star.outline_size = 0
		star.position = Vector3(0.45, 0.35, OUT.z * 0.5 + 0.03)
		add_child(star)
	# коллизия всего бака (чтобы игрок не проходил насквозь)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = OUT
	cs.shape = sh
	cs.position = Vector3(0, OUT.y * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	contents = Node3D.new()
	contents.name = "Contents"
	add_child(contents)


## Открыть/закрыть крышку (закрытая лежит на баке и не торчит за его габариты).
func set_lid(open: bool, sec := 0.55) -> void:
	var tw := create_tween()
	tw.tween_property(lid, "rotation:x", deg_to_rad(LID_OPEN if open else 0.0), sec) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if not open else Tween.EASE_OUT)
	await tw.finished
	Sfx.play3d("clank", global_position + Vector3(0, OUT.y, 0), -8.0 if open else -3.0, 1.3 if open else 1.0)


func _plate_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.08)
	m.roughness = 0.6
	return m
