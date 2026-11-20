extends Node
## Настройки игры (автозагрузка Settings). Хранятся в user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const PIXEL_HEIGHTS := [0, 540, 360, 270]          # 0 — без пикселизации (разрешение окна)
const PIXEL_NAMES := ["Выкл", "Слабая", "Средняя", "Сильная"]
const WINDOW_NAMES := ["Полный экран", "Окно без рамки", "Окно"]
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое"]

var v := {
	"sens": 1.0,          # чувствительность мыши (множитель)
	"invert_y": false,
	"fov": 72.0,
	"vol_master": 0.8,
	"vol_sfx": 1.0,
	"vol_amb": 0.8,
	"window": 0,
	"pixel": 2,
	"brightness": 1.0,
	"vsync": true,
	"quality": 2,
	"head_bob": true,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	load_settings()
	apply()


func get_v(key: String) -> Variant:
	return v[key]


func set_v(key: String, value: Variant) -> void:
	v[key] = value
	apply()
	save_settings()


func apply() -> void:
	_vol("Master", v["vol_master"])
	_vol("SFX", v["vol_sfx"])
	_vol("Ambience", v["vol_amb"])
	if not G.auto_test:
		match int(v["window"]):
			0:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				var scr := DisplayServer.screen_get_size()
				DisplayServer.window_set_size(scr)
				DisplayServer.window_set_position(DisplayServer.screen_get_position())
			_:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v["vsync"] else DisplayServer.VSYNC_DISABLED)
	changed.emit()


func _vol(bus: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))
	AudioServer.set_bus_mute(i, lin <= 0.001)


func pixel_height() -> int:
	return PIXEL_HEIGHTS[clampi(int(v["pixel"]), 0, PIXEL_HEIGHTS.size() - 1)]


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in v:
		cf.set_value("game", k, v[k])
	cf.save(PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in v:
		if cf.has_section_key("game", k):
			var val = cf.get_value("game", k)
			if typeof(val) == typeof(v[k]) or (typeof(v[k]) == TYPE_FLOAT and typeof(val) == TYPE_INT):
				v[k] = val
