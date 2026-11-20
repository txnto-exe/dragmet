extends CanvasLayer
## Весь интерфейс: прицел, подсказка «E — …», деньги/мешок/долг, всплывашки, субтитры,
## диалоги с выбором, затемнение, крупный текст, глазок, пауза.

signal advanced
signal chosen(index: int)

var font: Font
var root: Control
var crosshair: ColorRect
var prompt: Label
var hud_left: Label
var hud_right: Label
var toasts: VBoxContainer
var subtitle: Label
var dlg: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_choices: VBoxContainer
var fade_rect: ColorRect
var big: Label
var peep: ColorRect
var pause_box: PanelContainer
var flash_rect: ColorRect

var _typing := false
var _choosing := false
var _choice_count := 0
var _blip_pitch := 1.0
var _sub_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ff: FontFile = load("res://assets/fonts/PixelifySans.ttf")
	ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var fb := SystemFont.new()
	fb.font_names = PackedStringArray(["Segoe UI", "Arial"])
	ff.fallbacks = [fb]
	font = ff
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 12
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	peep = ColorRect.new()
	peep.set_anchors_preset(Control.PRESET_FULL_RECT)
	peep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/peephole.gdshader")
	peep.material = sm
	peep.visible = false
	root.add_child(peep)

	crosshair = ColorRect.new()
	crosshair.color = Color(0.9, 0.88, 0.8, 0.7)
	crosshair.size = Vector2(2, 2)
	crosshair.position = Vector2(319, 179)
	root.add_child(crosshair)

	prompt = _label(13, Color(0.95, 0.92, 0.82))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(0, 214)
	prompt.size = Vector2(640, 20)
	root.add_child(prompt)

	hud_left = _label(12, Color(0.9, 0.86, 0.72))
	hud_left.position = Vector2(10, 7)
	root.add_child(hud_left)
	hud_right = _label(12, Color(0.92, 0.45, 0.38))
	hud_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_right.position = Vector2(330, 7)
	hud_right.size = Vector2(300, 40)
	root.add_child(hud_right)

	toasts = VBoxContainer.new()
	toasts.position = Vector2(400, 60)
	toasts.size = Vector2(230, 200)
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	subtitle = _label(13, Color(0.95, 0.95, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(20, 300)
	subtitle.size = Vector2(600, 40)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(subtitle)

	dlg = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.025, 0.88)
	sb.border_color = Color(0.35, 0.3, 0.22)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	dlg.add_theme_stylebox_override("panel", sb)
	dlg.position = Vector2(40, 236)
	dlg.size = Vector2(560, 112)
	dlg.custom_minimum_size = Vector2(560, 112)
	dlg.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	dlg.add_child(v)
	dlg_name = _label(13, Color(0.95, 0.75, 0.35))
	v.add_child(dlg_name)
	dlg_text = _label(13, Color(0.92, 0.9, 0.84))
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(536, 0)
	v.add_child(dlg_text)
	dlg_choices = VBoxContainer.new()
	dlg_choices.add_theme_constant_override("separation", 1)
	v.add_child(dlg_choices)
	root.add_child(dlg)

	big = _label(20, Color(0.92, 0.88, 0.8))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big.modulate.a = 0.0

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0.6, 0.0, 0.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)

	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	root.add_child(big)

	pause_box = PanelContainer.new()
	pause_box.add_theme_stylebox_override("panel", sb.duplicate())
	pause_box.position = Vector2(220, 110)
	pause_box.custom_minimum_size = Vector2(200, 120)
	pause_box.visible = false
	root.add_child(pause_box)

	G.changed.connect(refresh)
	G.toast.connect(toast)
	refresh()


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(dt: float) -> void:
	if _sub_t > 0.0:
		_sub_t -= dt
		if _sub_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(subtitle, "modulate:a", 0.0, 0.5)
	refresh_time()


func refresh() -> void:
	hud_left.text = "%s\nМешок: %d / %d" % [G.rub(G.money), G.bag_count(), G.bag_cap()]
	refresh_time()


func refresh_time() -> void:
	if G.debt > 0:
		hud_right.text = "Долг: %s\nСрок: %s" % [G.rub(G.debt), G.left_text()]
	else:
		hud_right.text = "Долг закрыт"


func set_prompt(t: String) -> void:
	prompt.text = t


func show_hud(on: bool) -> void:
	for n in [crosshair, prompt, hud_left, hud_right]:
		n.visible = on


func toast(text: String, col := Color(0.9, 0.88, 0.8)) -> void:
	var l := _label(12, col)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(230, 0)
	toasts.add_child(l)
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	while toasts.get_child_count() > 5:
		toasts.get_child(0).free()


func say_sub(who: String, text: String, sec := 3.5) -> void:
	subtitle.text = ("%s: %s" % [who, text]) if who != "" else text
	subtitle.modulate.a = 1.0
	_sub_t = sec


func fade(to: float, sec := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to, sec)
	await tw.finished


func big_text(t: String, hold := 2.5, col := Color(0.92, 0.88, 0.8)) -> void:
	big.text = t
	big.add_theme_color_override("font_color", col)
	var tw := create_tween()
	tw.tween_property(big, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(big, "modulate:a", 0.0, 0.8)
	await tw.finished


func flash(strength := 0.5) -> void:
	flash_rect.color.a = strength
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.6)


func set_peep(on: bool) -> void:
	peep.visible = on


# ---------- диалоги ----------

## Показать реплику и дождаться, пока игрок нажмёт (E / пробел / клик).
func say(who: String, text: String, col := Color(0.95, 0.75, 0.35), pitch := 1.0) -> void:
	dlg.visible = true
	subtitle.modulate.a = 0.0
	_sub_t = 0.0
	dlg_name.text = who
	dlg_name.add_theme_color_override("font_color", col)
	dlg_text.text = text
	dlg_text.visible_characters = 0
	_clear_choices()
	_fit_dialog()
	_blip_pitch = pitch
	_typing = true
	var n := text.length()
	var i := 0
	while i < n and _typing:
		i += 1
		dlg_text.visible_characters = i
		if i % 2 == 0 and text[i - 1] != " ":
			Sfx.play("blip", -14.0, pitch * randf_range(0.92, 1.08))
		await get_tree().create_timer(0.022).timeout
	dlg_text.visible_characters = -1
	_typing = false
	await advanced


## Показать варианты ответа, вернуть номер выбранного (0..).
func choose(options: Array, text := "") -> int:
	dlg.visible = true
	if text != "":
		dlg_text.text = text
		dlg_text.visible_characters = -1
	_clear_choices()
	for i in options.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, options[i]]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_constant_override("v_separation", 0)
		b.custom_minimum_size = Vector2(0, 15)
		b.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
		b.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.4))
		b.add_theme_color_override("font_focus_color", Color(1, 0.85, 0.4))
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(func(): _pick(i))
		dlg_choices.add_child(b)
	_choosing = true
	_choice_count = options.size()
	_fit_dialog()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var r: int = await chosen
	_choosing = false
	_clear_choices()
	return r


## Окно диалога растёт вверх от низа экрана, чтобы варианты всегда влезали.
func _fit_dialog() -> void:
	await get_tree().process_frame
	dlg.reset_size()
	var h := maxf(dlg.get_combined_minimum_size().y, 112.0)
	dlg.size = Vector2(560, h)
	dlg.position.y = 352.0 - h


func _pick(i: int) -> void:
	if _choosing:
		Sfx.play("blip", -10.0, 0.7)
		chosen.emit(i)


func close_dialog() -> void:
	dlg.visible = false
	_clear_choices()


func _clear_choices() -> void:
	for c in dlg_choices.get_children():
		c.queue_free()


func _unhandled_input(e: InputEvent) -> void:
	if not dlg.visible:
		return
	if _choosing:
		for i in mini(_choice_count, 5):
			if e.is_action_pressed("choice_%d" % (i + 1)):
				_pick(i)
				get_viewport().set_input_as_handled()
				return
		return
	var go: bool = e.is_action_pressed("use") or e.is_action_pressed("advance") or (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if go:
		get_viewport().set_input_as_handled()
		if _typing:
			_typing = false
		else:
			advanced.emit()


# ---------- пауза ----------

func show_pause(on: bool, on_continue: Callable, on_reset: Callable, on_quit: Callable) -> void:
	for c in pause_box.get_children():
		c.queue_free()
	pause_box.visible = on
	if not on:
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pause_box.add_child(v)
	var t := _label(16, Color(0.95, 0.8, 0.45))
	t.text = "ПАУЗА"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for pair in [["Продолжить", on_continue], ["Начать заново", on_reset], ["Выйти из игры", on_quit]]:
		var b := Button.new()
		b.text = pair[0]
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pair[1])
		v.add_child(b)
