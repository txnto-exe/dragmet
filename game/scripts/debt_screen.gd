class_name DebtScreen
extends Node3D
## Электронное табло над ящиком долга: сумма, сколько осталось, полоска срока.
## Картинка рисуется 2D-интерфейсом во внутреннем вьюпорте и натягивается на «стекло» с пикселями-строками.

const RES := Vector2i(192, 112)
const SIZE := Vector2(0.72, 0.42)    # стекло в метрах

var vp: SubViewport
var lbl_title: Label
var lbl_sum: Label
var lbl_left: Label
var lbl_left_t: Label
var bar_bg: ColorRect
var bar: ColorRect
var glass_mat: ShaderMaterial
var light: OmniLight3D
var _urgent := false
var _t := 0.0
var _paid := false


func build(base: Basement) -> void:
	# корпус
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.09, 0.1)
	dark.roughness = 0.5
	dark.metallic = 0.6
	base.box(Vector3(SIZE.x + 0.1, SIZE.y + 0.1, 0.07), Vector3(0, 0, 0.035), dark, false, self)
	# кронштейн и провод вниз к ящику
	base.box(Vector3(0.04, 0.42, 0.02), Vector3(0.24, -0.39, 0.012), dark, false, self)
	# изображение
	vp = SubViewport.new()
	vp.size = RES
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.012, 0.01)
	bg.size = Vector2(RES)
	vp.add_child(bg)
	var font: Font = load("res://assets/fonts/PressStart2P.ttf")
	lbl_title = _lbl(font, 8, Color(0.75, 0.2, 0.15), Vector2(0, 7))
	lbl_title.text = "ДОЛГ"
	lbl_sum = _lbl(font, 16, Color(1.0, 0.25, 0.15), Vector2(0, 20))
	lbl_left_t = _lbl(font, 8, Color(0.75, 0.4, 0.2), Vector2(0, 46))
	lbl_left_t.text = "ОСТАЛОСЬ"
	lbl_left = _lbl(font, 16, Color(0.95, 0.55, 0.25), Vector2(0, 59))
	bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.05, 0.03)
	bar_bg.position = Vector2(16, 92)
	bar_bg.size = Vector2(RES.x - 32, 8)
	vp.add_child(bar_bg)
	bar = ColorRect.new()
	bar.color = Color(1.0, 0.35, 0.15)
	bar.position = bar_bg.position
	bar.size = bar_bg.size
	vp.add_child(bar)
	# стекло
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = SIZE
	q.mesh = qm
	q.position = Vector3(0, 0, 0.072)
	glass_mat = ShaderMaterial.new()
	glass_mat.shader = load("res://shaders/screen.gdshader")
	glass_mat.set_shader_parameter("tex", vp.get_texture())
	glass_mat.set_shader_parameter("res", Vector2(RES))
	q.material_override = glass_mat
	add_child(q)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.18)
	light.light_energy = 0.22
	light.omni_range = 1.3
	light.position = Vector3(0, 0, 0.4)
	add_child(light)


func _lbl(font: Font, size: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(RES.x, size + 4)
	vp.add_child(l)
	return l


func show_debt(debt: int, left_sec: float, round_len: float) -> void:
	_paid = debt <= 0
	if _paid:
		lbl_title.text = "ДОЛГ"
		lbl_sum.text = "ВЫПЛАЧЕН"
		lbl_sum.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45))
		lbl_left_t.text = ""
		lbl_left.text = "ЖДИ ЗВОНКА"
		lbl_left.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		bar.visible = false
		bar_bg.visible = false
		light.light_color = Color(0.35, 1.0, 0.4)
		_urgent = false
		return
	lbl_sum.text = _money(debt)
	lbl_sum.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
	var d := int(left_sec / G.DAY_SEC)
	var h := int(fmod(left_sec, G.DAY_SEC) / G.DAY_SEC * 24.0)
	var m := int(fmod(left_sec, G.DAY_SEC / 24.0) / (G.DAY_SEC / 24.0) * 60.0)
	lbl_left_t.text = "ОСТАЛОСЬ"
	lbl_left.text = ("%dД %02dЧ" % [d, h]) if d > 0 else ("%02d:%02d" % [h, m])
	lbl_left.add_theme_color_override("font_color", Color(0.95, 0.55, 0.25))
	bar.visible = true
	bar_bg.visible = true
	bar.size.x = bar_bg.size.x * clampf(left_sec / maxf(round_len, 1.0), 0.0, 1.0)
	light.light_color = Color(1.0, 0.3, 0.18)
	_urgent = left_sec < G.DAY_SEC * 0.5


func _money(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out + " Р"


func _process(dt: float) -> void:
	_t += dt
	# мало времени — табло мигает
	var blink := _urgent and fmod(_t, 1.0) < 0.5
	lbl_sum.visible = not blink
	glass_mat.set_shader_parameter("time", _t)
	light.light_energy = (0.1 if blink else 0.22) + 0.02 * sin(_t * 7.0)
