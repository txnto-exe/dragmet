extends CanvasLayer
## Интерфейс в полном разрешении (база 1280×720, растягивается под экран):
## прицел и подсказки, деньги/мешок/долг, всплывашки, субтитры, диалоги с кнопками,
## лавка, главное меню, пауза, настройки, затемнение.

signal advanced
signal chosen(index: int)
signal shop_closed
signal menu_action(action: String)

const C_TEXT := Color(0.9, 0.87, 0.78)
const C_DIM := Color(0.62, 0.58, 0.5)
const C_GOLD := Color(0.96, 0.78, 0.38)
const C_RED := Color(0.92, 0.38, 0.32)
const C_GREEN := Color(0.55, 0.85, 0.45)

var f_text: Font
var f_bold: Font
var f_head: Font
var theme_main: Theme

var root: Control
var crosshair: ColorRect
var prompt: Label
var money_lbl: Label
var bag_lbl: Label
var debt_lbl: Label
var left_lbl: Label
var hud_box: Control
var gold_lbl: Label
var goal_lbl: Label
var quest_lbl: RichTextLabel
var top_hint: Label
var mg: PanelContainer
var mg_title: Label
var mg_hint: Label
var mg_bg: ColorRect
var mg_zone: ColorRect
var mg_needle: ColorRect
var mg_fill: ColorRect
var mg_info: Label
var toasts: VBoxContainer
var subtitle: Label
var dlg: PanelContainer
var dlg_name: Label
var dlg_money: Label
var dlg_text: Label
var dlg_choices: VBoxContainer
var dlg_hint: Label
var inv: PanelContainer
var finds_box: VBoxContainer
var legend: HBoxContainer
var ring: Control
var _ring_v := -1.0
var prompt_box: HBoxContainer
var prompt_key: Label
var shop: PanelContainer
var menu_layer: Control
var fade_rect: ColorRect
var big: Label
var peep: ColorRect
var flash_rect: ColorRect

var menu_open := ""        # "", "main", "pause", "settings"
var _typing := false
var _choosing := false
var _choice_cancel := -1
var _sub_t := 0.0
var _shop_title := ""
var _shop_sub := ""
var _shop_items: Callable
var _shop_buy: Callable


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	# пиксельные шрифты без сглаживания: Handjet — текст, Press Start 2P — заголовки и деньги
	var fallback: FontFile = load("res://assets/fonts/FiraSans-Regular.ttf")
	var hj: FontFile = _pixel_font("res://assets/fonts/Handjet.ttf", fallback)
	f_text = _weight(hj, 450)
	f_bold = _weight(hj, 700)
	f_head = _pixel_font("res://assets/fonts/PressStart2P.ttf", fallback)
	theme_main = _make_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.theme = theme_main
	add_child(root)
	_build_hud()
	_build_dialog()
	_build_overlays()
	G.changed.connect(refresh)
	G.toast.connect(toast)
	refresh()


# ---------- тема ----------

func _pixel_font(path: String, fallback: Font) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.fallbacks = [fallback]
	return f


func _weight(base: FontFile, w: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	return v


## Размер под пиксельные шрифты: Handjet узкий — крупнее, Press Start 2P широкий — мельче.
func _fs(size: int, font: Font = null) -> int:
	if font == f_head:
		return maxi(8, int(round(size * 0.6 / 2.0)) * 2)
	return int(round(size * 1.3))


## Пиксельная панель из текстуры (9-патч): margin — рамка в пикселях текстуры, pad — отступ содержимого.
func _tex(name: String, margin: int, pad_x: int, pad_y: int, tile := true) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/%s.png" % name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


func _box(bg: Color, border: Color, bw := 1, radius := 3, pad := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = f_text
	t.default_font_size = _fs(20)
	t.set_color("font_color", "Label", C_TEXT)
	t.set_stylebox("panel", "PanelContainer", _tex("panel_metal", 24, 32, 24))
	var bn := _tex("btn_normal", 9, 16, 8)
	var bh := _tex("btn_hover", 9, 16, 8)
	var bp := _tex("btn_pressed", 9, 16, 8)
	var bd := _tex("btn_disabled", 9, 16, 8)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("focus", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("disabled", cls, bd)
		t.set_color("font_color", cls, C_TEXT)
		t.set_color("font_hover_color", cls, Color(1, 0.92, 0.7))
		t.set_color("font_focus_color", cls, Color(1, 0.92, 0.7))
		t.set_color("font_pressed_color", cls, Color(1, 0.95, 0.8))
		t.set_color("font_disabled_color", cls, Color(0.42, 0.39, 0.34))
		t.set_font_size("font_size", cls, _fs(20))
		t.set_font("font", cls, f_bold)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 10)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.14, 0.125, 0.1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.7, 0.52, 0.22)
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var empty := StyleBoxEmpty.new()
	for cls in ["CheckButton"]:
		t.set_stylebox("normal", cls, empty)
		t.set_stylebox("hover", cls, empty)
		t.set_stylebox("pressed", cls, empty)
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), C_GOLD, 1, 3, 2))
	t.set_font("font", "PopupMenu", f_text)
	t.set_font_size("font_size", "PopupMenu", _fs(19))
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.92, 0.7))
	t.set_stylebox("panel", "PopupMenu", _tex("panel_metal", 24, 14, 14))
	t.set_stylebox("hover", "PopupMenu", _tex("btn_hover", 9, 8, 4))
	return t


func _label(size: int, col: Color, font: Font = null) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", _fs(size, font))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _hover_focus(b: Control) -> void:
	b.mouse_entered.connect(func():
		if b is BaseButton and (b as BaseButton).disabled:
			return
		b.grab_focus())


# ---------- HUD ----------

func _build_hud() -> void:
	peep = ColorRect.new()
	peep.set_anchors_preset(Control.PRESET_FULL_RECT)
	peep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/peephole.gdshader")
	peep.material = sm
	peep.visible = false
	root.add_child(peep)

	hud_box = Control.new()
	hud_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_box)

	crosshair = ColorRect.new()
	crosshair.color = Color(0.95, 0.92, 0.85, 0.8)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -2
	crosshair.offset_top = -2
	crosshair.offset_right = 2
	crosshair.offset_bottom = 2
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(crosshair)

	# подсказка у прицела: клавиша в рамке + название того, на что смотришь
	prompt_box = HBoxContainer.new()
	prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_box.add_theme_constant_override("separation", 8)
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.set_anchors_preset(Control.PRESET_CENTER)
	prompt_box.offset_left = -400
	prompt_box.offset_right = 400
	prompt_box.offset_top = 30
	prompt_box.offset_bottom = 62
	prompt_box.modulate.a = 0.85
	prompt_box.visible = false
	hud_box.add_child(prompt_box)
	var kp := _key_badge("E")
	prompt_key = kp.get_child(0)
	prompt_box.add_child(kp)
	# в углу — две клавиши, которые не видны на предметах
	# клавиши в углу — меняются по ситуации (ходьба, бак, мини-игры, мешок)
	legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 6)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	legend.offset_left = -700
	legend.offset_top = -48
	legend.offset_right = -24
	legend.offset_bottom = -18
	legend.alignment = BoxContainer.ALIGNMENT_END
	legend.modulate.a = 0.6
	root.add_child(legend)
	set_legend([["Tab", "Мешок"], ["T", "Фонарь"]])
	prompt = _label(17, C_TEXT, f_bold)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	prompt.add_theme_constant_override("outline_size", 4)
	prompt_box.add_child(prompt)

	var tl := VBoxContainer.new()
	tl.position = Vector2(26, 16)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_constant_override("separation", -4)
	hud_box.add_child(tl)
	money_lbl = _label(32, C_GOLD, f_head)
	tl.add_child(money_lbl)
	bag_lbl = _label(18, C_DIM)
	tl.add_child(bag_lbl)
	gold_lbl = _label(18, C_GOLD)
	tl.add_child(gold_lbl)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	tl.add_child(gap)
	goal_lbl = _label(17, Color(0.78, 0.74, 0.64))
	goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_lbl.custom_minimum_size = Vector2(380, 0)
	tl.add_child(goal_lbl)
	# поручение: что нужно и сколько уже есть
	quest_lbl = RichTextLabel.new()
	quest_lbl.bbcode_enabled = true
	quest_lbl.fit_content = true
	quest_lbl.scroll_active = false
	quest_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	quest_lbl.custom_minimum_size = Vector2(380, 0)
	quest_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_lbl.add_theme_font_override("normal_font", f_text)
	quest_lbl.add_theme_font_override("bold_font", f_bold)
	quest_lbl.add_theme_font_size_override("normal_font_size", _fs(17))
	quest_lbl.add_theme_font_size_override("bold_font_size", _fs(17))
	quest_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	quest_lbl.add_theme_constant_override("outline_size", 3)
	tl.add_child(quest_lbl)

	top_hint = _label(20, C_TEXT, f_bold)
	top_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_hint.offset_left = -600
	top_hint.offset_right = 600
	top_hint.offset_top = 22
	top_hint.offset_bottom = 60
	root.add_child(top_hint)
	_build_minigame()

	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -426
	tr.offset_right = -26
	tr.offset_top = 16
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_theme_constant_override("separation", -4)
	hud_box.add_child(tr)
	debt_lbl = _label(28, C_RED, f_head)
	debt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(debt_lbl)
	left_lbl = _label(18, Color(0.85, 0.62, 0.52))
	left_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(left_lbl)
	tr.visible = false   # долг и срок смотрят на табло над ящиком, не в углу экрана

	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toasts.offset_left = -486
	toasts.offset_right = -26
	toasts.offset_top = 22
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	subtitle = _label(23, Color(0.97, 0.95, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.offset_left = -520
	subtitle.offset_right = 520
	subtitle.offset_top = -150
	subtitle.offset_bottom = -60
	root.add_child(subtitle)


func refresh() -> void:
	money_lbl.text = G.rub(G.money)
	bag_lbl.text = "Мешок: %d / %d" % [G.bag_count(), G.bag_cap()]
	var parts: Array[String] = []
	if G.dust > 0.0001:
		parts.append("Порошок: " + G.grams(G.dust))
	if G.ingots > 0.0001:
		parts.append("Слитки: " + G.grams(G.ingots))
	gold_lbl.text = "   ·   ".join(parts)
	gold_lbl.visible = parts.size() > 0
	if dlg_money and dlg_money.text != "":
		dlg_money.text = "У тебя: " + G.rub(G.money)
	refresh_time()


func refresh_time() -> void:
	if G.debt > 0:
		debt_lbl.text = "Долг: " + G.rub(G.debt)
		left_lbl.text = "Срок: " + G.left_text()
	else:
		debt_lbl.text = "Долг закрыт"
		left_lbl.text = ""


func _process(dt: float) -> void:
	if _sub_t > 0.0:
		_sub_t -= dt
		if _sub_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(subtitle, "modulate:a", 0.0, 0.5)
	refresh_time()


func _key_badge(key: String) -> PanelContainer:
	var kp := PanelContainer.new()
	var ks := _tex("key", 9, 9, 3, false)
	ks.content_margin_bottom = 8
	kp.add_theme_stylebox_override("panel", ks)
	kp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(16, Color(0.1, 0.09, 0.08), f_bold)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.text = key
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kp.add_child(l)
	return kp


func set_legend(pairs: Array) -> void:
	for c in legend.get_children():
		legend.remove_child(c)
		c.queue_free()
	for pair in pairs:
		legend.add_child(_key_badge(pair[0]))
		var ll := _label(16, C_TEXT)
		ll.text = pair[1] + "   "
		ll.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		ll.add_theme_constant_override("outline_size", 4)
		legend.add_child(ll)
	legend.visible = not pairs.is_empty()


func set_prompt(t: String, key := "E") -> void:
	prompt.text = t
	prompt_key.text = key
	prompt_box.visible = t != ""


## rows: [[название, есть, нужно], ...]
func set_quest(title: String, rows: Array) -> void:
	if title == "":
		quest_lbl.text = ""
		return
	var t := "[b][color=#8fc7ff]%s[/color][/b]" % title
	for r in rows:
		var have = r[1]
		var need = r[2]
		var done: bool = float(have) >= float(need) - 0.00001
		var col := "#8cd86f" if done else "#d8cfb8"
		var cnt := ("%s / %s" % [G.grams(have), G.grams(need)]) if typeof(need) == TYPE_FLOAT else ("%d / %d" % [mini(int(have), int(need)), int(need)])
		t += "
[color=%s]   %s  %s%s[/color]" % [col, r[0], cnt, "  ✓" if done else ""]
	quest_lbl.text = t


func set_goal(t: String) -> void:
	goal_lbl.text = ("Цель: " + t) if t != "" else ""


func set_top_hint(t: String) -> void:
	top_hint.text = t


# ---------- полоса мини-игры (кислота, печь) ----------

func _build_minigame() -> void:
	mg = PanelContainer.new()
	mg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mg.offset_left = -380
	mg.offset_right = 380
	mg.offset_top = -210
	mg.offset_bottom = -40
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.visible = false
	root.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	mg_title = _label(26, C_GOLD, f_head)
	mg_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mg_title)
	mg_info = _label(20, C_TEXT, f_bold)
	top.add_child(mg_info)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(700, 34)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var frame := Panel.new()   # утопленная железная канавка вокруг полосы
	frame.add_theme_stylebox_override("panel", _tex("slot", 6, 0, 0))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -6
	frame.offset_top = -6
	frame.offset_right = 6
	frame.offset_bottom = 6
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(frame)
	mg_bg = ColorRect.new()
	mg_bg.color = Color(0.09, 0.085, 0.07)
	mg_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mg_bg)
	mg_zone = ColorRect.new()
	mg_zone.color = Color(0.35, 0.75, 0.3, 0.85)
	mg_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mg_zone)
	mg_needle = ColorRect.new()
	mg_needle.color = Color(1, 0.95, 0.85)
	mg_needle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mg_needle)
	mg_fill = ColorRect.new()
	mg_fill.color = C_GOLD
	mg_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(mg_fill)
	mg_hint = _label(17, C_DIM)
	mg_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mg_hint.custom_minimum_size = Vector2(700, 0)
	v.add_child(mg_hint)


func mg_show(title: String, hint: String) -> void:
	mg_title.text = title
	mg_hint.text = hint
	mg_info.text = ""
	mg.visible = true
	show_hud(false)


func mg_hide() -> void:
	mg.visible = false


## needle, zone_a, zone_b — доли 0..1 по ширине; fill — тонкая полоска прогресса снизу (−1 — не показывать).
func mg_set(needle: float, zone_a: float, zone_b: float, zone_col: Color, fill := -1.0, info := "") -> void:
	var w := 700.0
	mg_zone.position = Vector2(zone_a * w, 0)
	mg_zone.size = Vector2(maxf(2.0, (zone_b - zone_a) * w), 34)
	mg_zone.color = zone_col
	mg_needle.position = Vector2(clampf(needle, 0.0, 1.0) * w - 3, -5)
	mg_needle.size = Vector2(6, 44)
	mg_fill.visible = fill >= 0.0
	mg_fill.position = Vector2(0, 30)
	mg_fill.size = Vector2(clampf(fill, 0.0, 1.0) * w, 4)
	if info != "":
		mg_info.text = info


func show_hud(on: bool) -> void:
	hud_box.visible = on


func toast(text: String, col := C_TEXT) -> void:
	var l := _label(20, col)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	toasts.add_child(l)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	while toasts.get_child_count() > 5:
		toasts.get_child(0).free()


## «Нашёл …» крупно по центру снизу: название цветом редкости и цена.
func find_popup(title: String, value: String, col: Color) -> void:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _tex("tag_brass", 12, 22, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var n := _label(24, col, f_bold)
	n.text = title
	h.add_child(n)
	if value != "":
		var v := _label(22, Color(1.0, 0.86, 0.45), f_head)
		v.text = value
		h.add_child(v)
	finds_box.add_child(c)
	c.pivot_offset = Vector2(400, 20)
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_property(c, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(c.queue_free)
	while finds_box.get_child_count() > 3:
		finds_box.get_child(0).free()


func say_sub(who: String, text: String, sec := 3.5) -> void:
	subtitle.text = ("%s: %s" % [who, text]) if who != "" else text
	subtitle.modulate.a = 1.0
	_sub_t = sec


# ---------- затемнение, крупный текст ----------

func _build_overlays() -> void:
	shop = PanelContainer.new()
	shop.visible = false
	shop.add_theme_stylebox_override("panel", _tex("panel_wood", 18, 30, 24))   # лавка Коляна — фанерный щит
	root.add_child(shop)

	# находки — по центру снизу, на латунной табличке
	finds_box = VBoxContainer.new()
	finds_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	finds_box.offset_left = -400
	finds_box.offset_right = 400
	finds_box.offset_top = -250
	finds_box.offset_bottom = -70
	finds_box.alignment = BoxContainer.ALIGNMENT_END
	finds_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finds_box.add_theme_constant_override("separation", 6)
	root.add_child(finds_box)

	# кольцо «вынимаю осколок» у курсора
	ring = Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(1280, 720)
	ring.visible = false
	ring.draw.connect(func():
		var c := ring.get_local_mouse_position() + Vector2(26, -22)
		ring.draw_arc(c, 13.0, 0.0, TAU, 32, Color(0, 0, 0, 0.55), 6.0, true)
		ring.draw_arc(c, 13.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_ring_v, 0.0, 1.0), 32, Color(0.75, 0.95, 1.0, 0.95), 4.0, true))
	root.add_child(ring)

	inv = PanelContainer.new()
	inv.visible = false
	inv.add_theme_stylebox_override("panel", _tex("panel_cardboard", 18, 30, 26))
	inv.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(inv)
	G.changed.connect(func(): if inv.visible: _fill_inventory())

	menu_layer = Control.new()
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_layer)

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

	big = _label(50, C_TEXT, f_head)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big.modulate.a = 0.0
	root.add_child(big)


func fade(to: float, sec := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to, sec)
	await tw.finished


func big_text(t: String, hold := 2.5, col := C_TEXT) -> void:
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


# ---------- диалог ----------

func _build_dialog() -> void:
	dlg = PanelContainer.new()
	dlg.visible = false
	dlg.gui_input.connect(_on_dlg_input)
	root.add_child(dlg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	dlg_name = _label(26, C_GOLD, f_head)
	dlg_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(dlg_name)
	dlg_money = _label(22, C_GOLD, f_head)
	top.add_child(dlg_money)
	dlg_text = _label(22, C_TEXT)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(840, 0)
	v.add_child(dlg_text)
	dlg_choices = VBoxContainer.new()
	dlg_choices.add_theme_constant_override("separation", 6)
	v.add_child(dlg_choices)
	dlg_hint = _label(15, C_DIM)
	dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(dlg_hint)


func _place_dialog() -> void:
	await get_tree().process_frame
	dlg.reset_size()
	var vs := root.size
	dlg.position = Vector2(round((vs.x - dlg.size.x) * 0.5), vs.y - dlg.size.y - 30)


## Реплика: печатается, ждёт нажатия (ЛКМ / E / пробел).
func say(who: String, text: String, col := C_GOLD, pitch := 1.0) -> void:
	dlg.visible = true
	subtitle.modulate.a = 0.0
	_sub_t = 0.0
	dlg_name.text = who
	dlg_name.visible = who != ""
	dlg_name.add_theme_color_override("font_color", col)
	dlg_money.text = ""
	dlg_text.text = text
	dlg_text.visible = text != ""
	dlg_text.visible_characters = 0
	dlg_hint.text = ""
	_clear_choices()
	_place_dialog()
	_typing = true
	var n := text.length()
	var i := 0
	while i < n and _typing:
		i += 1
		dlg_text.visible_characters = i
		if i % 2 == 0 and text[i - 1] != " ":
			Sfx.play("blip", -14.0, pitch * randf_range(0.92, 1.08))
		await get_tree().create_timer(0.018).timeout
	dlg_text.visible_characters = -1
	_typing = false
	dlg_hint.text = "▸"
	await advanced
	dlg_hint.text = ""


## Варианты ответа кнопками. Возвращает номер выбранного.
## cancel — номер варианта, который срабатывает на Esc; disabled — номера неактивных кнопок.
func choose(options: Array, text := "", who := "", show_money := false, cancel := -1, disabled: Array = []) -> int:
	dlg.visible = true
	if who != "":
		dlg_name.text = who
		dlg_name.visible = true
	elif text != "":
		# новый вопрос без говорящего — имя прошлого собеседника не оставляем
		dlg_name.visible = false
	if text != "":
		dlg_text.text = text
		dlg_text.visible = true
		dlg_text.visible_characters = -1
	dlg_money.text = ("У тебя: " + G.rub(G.money)) if show_money else ""
	dlg_hint.text = ""
	_clear_choices()
	var first: Button = null
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 44)
		b.focus_mode = Control.FOCUS_ALL
		b.disabled = i in disabled
		b.pressed.connect(func(): _pick(i))
		_hover_focus(b)
		dlg_choices.add_child(b)
		if first == null and not b.disabled:
			first = b
	_choosing = true
	_choice_cancel = cancel
	if not G.auto_test:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_place_dialog()
	await get_tree().process_frame
	if first:
		first.grab_focus()
	var r: int = await chosen
	_choosing = false
	_clear_choices()
	return r


func _pick(i: int) -> void:
	if _choosing:
		Sfx.play("blip", -9.0, 0.7)
		chosen.emit(i)


func close_dialog() -> void:
	dlg.visible = false
	_clear_choices()


func _clear_choices() -> void:
	for c in dlg_choices.get_children():
		c.queue_free()


func _on_dlg_input(e: InputEvent) -> void:
	if _choosing:
		return
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		dlg.accept_event()
		_advance()


func _advance() -> void:
	if _typing:
		_typing = false
	else:
		advanced.emit()


func _move_focus(down: bool) -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return
	var n := f.find_next_valid_focus() if down else f.find_prev_valid_focus()
	if n:
		n.grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	# меню (главное / пауза / настройки)
	if menu_open != "":
		if e.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			menu_action.emit("back")
		elif e.is_action_pressed("use"):
			var f := get_viewport().gui_get_focus_owner()
			if f is Button:
				get_viewport().set_input_as_handled()
				(f as Button).pressed.emit()
		elif _ws(e) != 0:
			get_viewport().set_input_as_handled()
			_move_focus(_ws(e) > 0)
		return
	if shop.visible:
		if e.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			close_shop()
		elif e.is_action_pressed("use"):
			var f := get_viewport().gui_get_focus_owner()
			if f is Button and not (f as Button).disabled:
				get_viewport().set_input_as_handled()
				(f as Button).pressed.emit()
		elif _ws(e) != 0:
			get_viewport().set_input_as_handled()
			_move_focus(_ws(e) > 0)
		return
	if not dlg.visible:
		return
	if _choosing:
		if e.is_action_pressed("pause") and _choice_cancel >= 0:
			get_viewport().set_input_as_handled()
			_pick(_choice_cancel)
		elif e.is_action_pressed("use"):
			var f := get_viewport().gui_get_focus_owner()
			if f is Button and f.get_parent() == dlg_choices and not (f as Button).disabled:
				get_viewport().set_input_as_handled()
				(f as Button).pressed.emit()
		elif _ws(e) != 0:
			get_viewport().set_input_as_handled()
			_move_focus(_ws(e) > 0)
		return
	var go: bool = e.is_action_pressed("use") or e.is_action_pressed("advance") \
		or (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if go:
		get_viewport().set_input_as_handled()
		_advance()


## W/S (и стрелки) для перемещения по кнопкам: +1 вниз, −1 вверх, 0 — не то.
func _ws(e: InputEvent) -> int:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_S:
			return 1
		if k == KEY_W:
			return -1
	return 0


# ---------- лавка ----------

## items_fn() -> [{key, name, desc, level, max, cost}]; buy_fn(key) -> bool (купил или нет).
func open_shop(title: String, sub: String, items_fn: Callable, buy_fn: Callable) -> void:
	_shop_title = title
	_shop_sub = sub
	_shop_items = items_fn
	_shop_buy = buy_fn
	close_dialog()
	shop.visible = true
	if not G.auto_test:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill_shop()
	await shop_closed


# ---------- инвентарь (Tab) ----------

func hold_ring(v: float) -> void:
	_ring_v = v
	ring.visible = v >= 0.0
	ring.queue_redraw()


func toggle_inventory(on: bool) -> void:
	inv.visible = on
	if on:
		_fill_inventory()


func _fill_inventory() -> void:
	for c in inv.get_children():
		inv.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(620, 0)
	inv.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := _label(30, C_GOLD, f_head)
	t.text = "Мешок  %d / %d" % [G.bag_count(), G.bag_cap()]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var m := _label(26, C_GOLD, f_head)
	m.text = G.rub(G.money)
	top.add_child(m)
	var rows := 0
	var keys: Array = G.bag.keys()
	keys.sort_custom(func(a, b): return G.ITEMS[a]["gold"] > G.ITEMS[b]["gold"])
	for k in keys:
		var d: Dictionary = G.ITEMS[k]
		_inv_row(v, d["name"], "×%d" % G.bag[k], G.rub(G.item_price(k) * G.bag[k]), G.TIER_COLORS[d["tier"]], k)
		rows += 1
	if G.dust > 0.0001:
		_inv_row(v, "Золотой порошок", G.grams(G.dust), G.rub(G.dust_value()), Color(1.0, 0.82, 0.4), "dust")
		rows += 1
	if G.ingots > 0.0001:
		_inv_row(v, "Золотые слитки", G.grams(G.ingots), G.rub(G.ingot_value()), Color(1.0, 0.72, 0.25), "")
		rows += 1
	if G.flags.get("key", false):
		_inv_row(v, "Ключ от сетки", "", "", Color(0.6, 0.95, 0.5), "")
		rows += 1
	if G.flags.get("crowbar", false):
		_inv_row(v, "Лом", "", "", Color(1.0, 0.7, 0.4), "")
		rows += 1
	if rows == 0:
		var e := _label(20, C_DIM)
		e.text = "Пусто"
		v.add_child(e)
	var sep := HSeparator.new()
	v.add_child(sep)
	var p := _label(16, Color(0.17, 0.11, 0.06), f_bold)   # тёмная надпись по картону — читается
	p.text = "Грамм золота:  сырьём %s  ·  порошком %s  ·  слитком %s" % [G.rub(G.gram_price("raw")), G.rub(G.gram_price("dust")), G.rub(G.gram_price("ingot"))]
	v.add_child(p)
	inv.reset_size()
	inv.position = (Vector2(1280, 720) - inv.size) * 0.5


func _inv_row(parent: Control, name: String, count: String, value: String, col: Color, lock_key: String) -> void:
	var row := PanelContainer.new()
	var locked := lock_key != "" and G.is_locked(lock_key)
	row.add_theme_stylebox_override("panel", _tex("slot_locked" if locked else "slot", 6, 14, 6))
	parent.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var n := _label(20, col, f_bold)
	n.text = name
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var c := _label(19, C_TEXT)
	c.text = count
	c.custom_minimum_size = Vector2(80, 0)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(c)
	var val := _label(19, C_GOLD)
	val.text = value
	val.custom_minimum_size = Vector2(110, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	if lock_key != "":
		var b := CheckButton.new()
		b.text = "Отложить"
		b.button_pressed = locked
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", f_text)
		b.add_theme_font_size_override("font_size", _fs(16))
		b.toggled.connect(func(on: bool):
			Sfx.play("blip", -6.0)
			G.set_locked(lock_key, on))
		h.add_child(b)
	else:
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(128, 0)
		h.add_child(sp)


func shop_say(text: String) -> void:
	_shop_sub = text


func _fill_shop() -> void:
	for c in shop.get_children():
		shop.remove_child(c)
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(1060, 0)
	shop.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := _label(34, C_GOLD, f_head)
	t.text = _shop_title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var m := _label(30, C_GOLD, f_head)
	m.text = "У тебя: " + G.rub(G.money)
	top.add_child(m)
	var s := _label(20, C_TEXT)
	s.text = "«%s»" % _shop_sub
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	var first: Button = null
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for it in _shop_items.call():
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _tex("slot", 6, 16, 10))
		row.custom_minimum_size = Vector2(525, 0)
		grid.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 3)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var n := _label(20, C_TEXT, f_bold)
		n.text = it["name"]
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(n)
		var d := _label(16, C_DIM)
		d.text = it["desc"]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(d)
		var lv := HBoxContainer.new()
		lv.add_theme_constant_override("separation", 4)
		info.add_child(lv)
		for i in int(it["max"]):
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(22, 6)
			dot.color = C_GOLD if i < int(it["level"]) else Color(0.22, 0.2, 0.16)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lv.add_child(dot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(178, 54)
		b.add_theme_font_size_override("font_size", _fs(17))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.focus_mode = Control.FOCUS_ALL
		var cost: int = int(it["cost"])
		if it.has("done"):
			b.text = it["done"]
			b.disabled = true
		elif it.has("locked"):
			b.text = it["locked"]
			b.disabled = true
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", _fs(16))
		elif int(it["level"]) >= int(it["max"]):
			b.text = "Максимум"
			b.disabled = true
		elif G.money < cost:
			b.text = "Не хватает\n%s" % G.rub(cost)
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", Color(0.75, 0.38, 0.32))
		else:
			b.text = "Купить
%s" % G.rub(cost)
			b.add_theme_color_override("font_color", C_GREEN)
		var key: String = it["key"]
		b.pressed.connect(func():
			_shop_buy.call(key)
			_fill_shop())
		_hover_focus(b)
		h.add_child(b)
		if first == null and not b.disabled:
			first = b
	var close := Button.new()
	close.text = "Уйти"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(close_shop)
	_hover_focus(close)
	v.add_child(close)
	if first == null:
		first = close
	_center_later(shop)
	await get_tree().process_frame
	if is_instance_valid(first):
		first.grab_focus()


func close_shop() -> void:
	if shop.visible:
		Sfx.play("blip", -9.0, 0.7)
		shop.visible = false
		shop_closed.emit()


# ---------- меню: главное, пауза, настройки ----------

func clear_menus() -> void:
	for c in menu_layer.get_children():
		menu_layer.remove_child(c)
		c.queue_free()
	menu_open = ""
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _menu_panel(width := 420.0, dim_a := 0.6) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, dim_a)
	menu_layer.add_child(dim)
	var p := PanelContainer.new()
	menu_layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(width, 0)
	p.add_child(v)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_center_later(p)
	return v


func _center_later(p: Control) -> void:
	p.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.reset_size()
	p.position = ((root.size - p.size) * 0.5).round()
	p.modulate.a = 1.0


func _menu_button(v: Container, text: String, action: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play("blip", -9.0, 0.7)
		menu_action.emit(action))
	_hover_focus(b)
	v.add_child(b)
	return b


func show_main_menu(can_continue: bool) -> void:
	clear_menus()
	menu_open = "main"
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.3)
	menu_layer.add_child(dim)
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.85))
	gr.set_color(1, Color(0, 0, 0, 0.0))
	grad.gradient = gr
	grad.fill_to = Vector2(1, 0)
	shade.texture = grad
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760
	menu_layer.add_child(shade)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 110
	v.offset_top = -230
	v.custom_minimum_size = Vector2(400, 0)
	menu_layer.add_child(v)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := _label(110, Color(0.82, 0.2, 0.14), f_head)
	t.text = "ДРАГМЕТ"
	v.add_child(t)
	var s := _label(22, C_DIM)
	s.text = "Подвал. Мусор. Долг."
	v.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	v.add_child(gap)
	var first: Button = null
	if can_continue:
		first = _menu_button(v, "Продолжить", "continue")
	var nb := _menu_button(v, "Новая игра", "new")
	if first == null:
		first = nb
	_menu_button(v, "Настройки", "settings")
	_menu_button(v, "Выйти", "quit")
	await get_tree().process_frame
	if is_instance_valid(first):
		first.grab_focus()


func show_pause_menu() -> void:
	clear_menus()
	menu_open = "pause"
	var v := _menu_panel()
	var t := _label(38, C_GOLD, f_head)
	t.text = "Пауза"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var first := _menu_button(v, "Продолжить", "resume")
	_menu_button(v, "Настройки", "settings")
	_menu_button(v, "В главное меню", "to_menu")
	_menu_button(v, "Выйти из игры", "quit")
	await get_tree().process_frame
	if is_instance_valid(first):
		first.grab_focus()


func show_confirm(text: String, yes_action: String, no_action: String) -> void:
	clear_menus()
	menu_open = "confirm"
	var v := _menu_panel(520)
	var t := _label(22, C_TEXT)
	t.text = text
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var y := _menu_button(h, "Да", yes_action)
	y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := _menu_button(h, "Нет", no_action)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	await get_tree().process_frame
	if is_instance_valid(n):
		n.grab_focus()


func show_settings() -> void:
	clear_menus()
	menu_open = "settings"
	var v := _menu_panel(700, 0.7)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := _label(38, C_GOLD, f_head)
	t.text = "Настройки"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(700, 0)
	tabs.add_theme_font_override("font", f_bold)
	tabs.add_theme_font_size_override("font_size", _fs(19))
	tabs.add_theme_stylebox_override("panel", _tex("slot", 6, 18, 14))
	tabs.add_theme_stylebox_override("tab_selected", _tex("btn_hover", 9, 14, 6))
	tabs.add_theme_stylebox_override("tab_unselected", _tex("btn_normal", 9, 14, 6))
	tabs.add_theme_stylebox_override("tab_hovered", _tex("btn_pressed", 9, 14, 6))
	tabs.add_theme_color_override("font_selected_color", Color(1, 0.92, 0.7))
	tabs.add_theme_color_override("font_unselected_color", C_DIM)
	tabs.add_theme_color_override("font_hovered_color", C_TEXT)
	v.add_child(tabs)

	var a := _tab(tabs, "Управление")
	_slider_row(a, "Чувствительность мыши", "sens", 0.2, 3.0, 0.05, func(x): return "%.2f" % x)
	_check_row(a, "Инвертировать мышь по вертикали", "invert_y")
	_slider_row(a, "Поле зрения (FOV)", "fov", 55.0, 100.0, 1.0, func(x): return "%d°" % int(x))
	_check_row(a, "Покачивание камеры при ходьбе", "head_bob")
	var keys := _label(17, C_DIM)
	keys.text = "WASD — ходить   ·   Shift — бежать   ·   E — действие   ·   Tab — мешок   ·   T — фонарик   ·   Esc — пауза   ·   F11 — полный экран"
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.add_child(keys)

	var b := _tab(tabs, "Звук")
	_slider_row(b, "Общая громкость", "vol_master", 0.0, 1.0, 0.01, func(x): return "%d%%" % int(round(x * 100)))
	_slider_row(b, "Эффекты и голоса", "vol_sfx", 0.0, 1.0, 0.01, func(x): return "%d%%" % int(round(x * 100)))
	_slider_row(b, "Фон подвала", "vol_amb", 0.0, 1.0, 0.01, func(x): return "%d%%" % int(round(x * 100)))

	var c := _tab(tabs, "Изображение")
	_option_row(c, "Режим экрана", "window", Settings.WINDOW_NAMES)
	_option_row(c, "Пиксельность картинки", "pixel", Settings.PIXEL_NAMES)
	_option_row(c, "Качество теней и света", "quality", Settings.QUALITY_NAMES)
	_slider_row(c, "Яркость", "brightness", 0.6, 1.8, 0.02, func(x): return "%d%%" % int(round(x * 100)))
	_check_row(c, "Вертикальная синхронизация", "vsync")

	var back := _menu_button(v, "Назад", "settings_back")
	await get_tree().process_frame
	if is_instance_valid(back):
		back.grab_focus()


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = title
	v.add_theme_constant_override("separation", 12)
	tabs.add_child(v)
	return v


func _row(v: VBoxContainer, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 40)
	v.add_child(h)
	var l := _label(20, C_TEXT)
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


func _slider_row(v: VBoxContainer, text: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var h := _row(v, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(240, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	h.add_child(s)
	var val := _label(19, C_GOLD, f_bold)
	val.custom_minimum_size = Vector2(64, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.text = fmt.call(s.value)
	h.add_child(val)
	s.value_changed.connect(func(x):
		val.text = fmt.call(x)
		Settings.set_v(key, x))


func _check_row(v: VBoxContainer, text: String, key: String) -> void:
	var h := _row(v, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_v(key))
	c.focus_mode = Control.FOCUS_ALL
	h.add_child(c)
	c.toggled.connect(func(on): Settings.set_v(key, on))


func _option_row(v: VBoxContainer, text: String, key: String, names: Array) -> void:
	var h := _row(v, text)
	var o := OptionButton.new()
	for n in names:
		o.add_item(n)
	o.selected = int(Settings.get_v(key))
	o.custom_minimum_size = Vector2(240, 40)
	o.focus_mode = Control.FOCUS_ALL
	h.add_child(o)
	o.item_selected.connect(func(i): Settings.set_v(key, i))
