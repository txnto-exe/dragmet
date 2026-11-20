extends Node
## Состояние игры (автозагрузка G): деньги, мешок, долг, время, прокачки, флаги сюжета.
## Здесь же числа баланса и список предметов. Сохраняется в user://save.json.

signal changed
signal toast(text: String, color: Color)
signal deadline_missed

# ---------- Предметы (из старой игры) ----------
# gold — граммы золота в штуке; цена у скупщика = gold * PRICE_PER_G
const ITEMS := {
	"resist": {"name": "Резисторы", "gold": 0.005, "tier": 0},
	"caps": {"name": "Конденсаторы", "gold": 0.008, "tier": 0},
	"trans": {"name": "Транзисторы", "gold": 0.015, "tier": 0},
	"chips": {"name": "Микросхемы", "gold": 0.02, "tier": 1},
	"hdd": {"name": "Жёсткий диск", "gold": 0.04, "tier": 1},
	"phones": {"name": "Старый телефон", "gold": 0.045, "tier": 1},
	"ram": {"name": "Планка ОЗУ", "gold": 0.07, "tier": 1},
	"connect": {"name": "Разъёмы", "gold": 0.09, "tier": 2},
	"silverWire": {"name": "Серебряная проволока", "gold": 0.12, "tier": 3},
	"cpus": {"name": "Процессор", "gold": 0.18, "tier": 2},
	"rare": {"name": "Советская плата", "gold": 0.25, "tier": 3},
}
const TIER_COLORS := [Color(0.62, 0.6, 0.55), Color(0.85, 0.82, 0.72), Color(0.45, 0.75, 1.0), Color(1.0, 0.75, 0.3)]

# Что лежит в мусорке (вес — как часто попадается)
const LOOT := {"resist": 18, "caps": 16, "trans": 12, "chips": 26, "phones": 16, "ram": 9, "hdd": 6,
	"connect": 3, "cpus": 2, "silverWire": 1.5, "rare": 1}

const PRICE_PER_G := 2600.0
const DAY_SEC := 240.0          # сколько реальных секунд длится игровой день
const BAG_START := 12

# ---------- Прокачки у Коляна ----------
const UPGRADES := {
	"gloves": {"name": "Рабочие перчатки", "desc": "разгребать хлам быстрее", "base": 250, "mult": 1.8, "max": 3},
	"bag": {"name": "Мешок побольше", "desc": "+6 мест в мешке", "base": 300, "mult": 1.7, "max": 4},
	"lamp": {"name": "Фонарик на лоб", "desc": "чаще попадается ценное", "base": 500, "mult": 2.0, "max": 3},
}

# ---------- Состояние ----------
var money := 0
var bag := {}
var debt := 3000
var debt_round := 1
var time := 0.0                 # секунд с начала
var deadline := 3.0 * DAY_SEC   # к какому моменту надо отдать долг
var round_len := 3.0 * DAY_SEC
var upgrades := {"gloves": 0, "bag": 0, "lamp": 0}
var flags := {}
var digs := 0
var mode := "intro"             # intro / walk / dig / dialog / peep / pause
var paused_time := false

var SAVE_PATH := "user://save.json"
var auto_test := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--auto"):
			auto_test = true
			SAVE_PATH = "user://save_auto.json"
			reset_game()
	load_game()


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "use": [KEY_E], "pause": [KEY_ESCAPE], "fullscreen": [KEY_F11],
		"choice_1": [KEY_1], "choice_2": [KEY_2], "choice_3": [KEY_3], "choice_4": [KEY_4], "choice_5": [KEY_5],
		"advance": [KEY_SPACE, KEY_ENTER],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	if mode == "pause" or mode == "intro" or paused_time:
		return
	time += delta
	if debt > 0 and time >= deadline:
		_miss_deadline()


# ---------- Мешок ----------

func bag_cap() -> int:
	return BAG_START + upgrades["bag"] * 6


func bag_count() -> int:
	var n := 0
	for k in bag:
		n += bag[k]
	return n


func bag_full() -> bool:
	return bag_count() >= bag_cap()


func add_item(key: String) -> void:
	bag[key] = bag.get(key, 0) + 1
	digs += 1
	changed.emit()
	save_game()


func item_price(key: String) -> int:
	return maxi(5, int(round(ITEMS[key]["gold"] * PRICE_PER_G)))


func bag_value() -> int:
	var v := 0
	for k in bag:
		v += item_price(k) * bag[k]
	return v


func sell_all() -> int:
	var v := bag_value()
	money += v
	bag.clear()
	changed.emit()
	save_game()
	return v


func roll_loot() -> String:
	var weights := LOOT.duplicate()
	var lamp: int = upgrades["lamp"]
	if lamp > 0:
		for k in weights:
			var tier: int = ITEMS[k]["tier"]
			weights[k] = weights[k] * pow(1.0 + 0.6 * lamp, tier) / (1.0 + 0.15 * lamp * (1 - mini(tier, 1)))
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "chips"


func dig_need() -> int:
	## Сколько кусков хлама надо раскидать, чтобы добраться до находки.
	return maxi(2, 5 - upgrades["gloves"])


# ---------- Прокачки ----------

func upgrade_cost(key: String) -> int:
	var u: Dictionary = UPGRADES[key]
	return int(round(u["base"] * pow(u["mult"], upgrades[key]) / 10.0)) * 10


func upgrade_maxed(key: String) -> bool:
	return upgrades[key] >= UPGRADES[key]["max"]


func buy_upgrade(key: String) -> bool:
	if upgrade_maxed(key):
		return false
	var c := upgrade_cost(key)
	if money < c:
		return false
	money -= c
	upgrades[key] += 1
	changed.emit()
	save_game()
	return true


# ---------- Долг ----------

func time_left() -> float:
	return maxf(0.0, deadline - time)


func rot() -> float:
	## 0 — только начался срок, 1 — срок на исходе. Подвал «гниёт» вместе с этим.
	if debt <= 0:
		return 0.0
	return clampf(1.0 - time_left() / round_len, 0.0, 1.0)


func pay_debt() -> int:
	var paid := mini(money, debt)
	money -= paid
	debt -= paid
	if debt <= 0:
		debt = 0
	changed.emit()
	save_game()
	return paid


func start_next_debt() -> void:
	debt_round += 1
	debt = int(3000 * pow(2.6, debt_round - 1) / 100.0) * 100
	round_len = (3.0 + debt_round) * DAY_SEC
	deadline = time + round_len
	changed.emit()
	save_game()


func _miss_deadline() -> void:
	debt = int(debt * 1.5 / 100.0) * 100
	round_len = 2.0 * DAY_SEC
	deadline = time + round_len
	deadline_missed.emit()
	changed.emit()
	save_game()


func clock_text() -> String:
	var day := int(time / DAY_SEC) + 1
	var hour := int(fmod(time, DAY_SEC) / DAY_SEC * 24.0)
	return "День %d · %02d:00" % [day, hour]


func left_text() -> String:
	var s := time_left()
	var d := int(s / DAY_SEC)
	var h := int(fmod(s, DAY_SEC) / DAY_SEC * 24.0)
	if d > 0:
		return "%d дн %d ч" % [d, h]
	return "%d ч" % h


static func rub(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out + " ₽"


# ---------- Сохранение ----------

func save_game() -> void:
	var d := {"money": money, "bag": bag, "debt": debt, "debt_round": debt_round, "time": time,
		"deadline": deadline, "round_len": round_len, "upgrades": upgrades, "flags": flags, "digs": digs}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	money = int(d.get("money", 0))
	debt = int(d.get("debt", 3000))
	debt_round = int(d.get("debt_round", 1))
	time = float(d.get("time", 0.0))
	deadline = float(d.get("deadline", 3.0 * DAY_SEC))
	round_len = float(d.get("round_len", 3.0 * DAY_SEC))
	digs = int(d.get("digs", 0))
	bag = {}
	var b = d.get("bag", {})
	if typeof(b) == TYPE_DICTIONARY:
		for k in b:
			if ITEMS.has(k):
				bag[k] = int(b[k])
	var u = d.get("upgrades", {})
	if typeof(u) == TYPE_DICTIONARY:
		for k in upgrades:
			upgrades[k] = clampi(int(u.get(k, 0)), 0, UPGRADES[k]["max"])
	var fl = d.get("flags", {})
	if typeof(fl) == TYPE_DICTIONARY:
		flags = fl


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	money = 0
	bag = {}
	debt = 3000
	debt_round = 1
	time = 0.0
	deadline = 3.0 * DAY_SEC
	round_len = deadline
	upgrades = {"gloves": 0, "bag": 0, "lamp": 0}
	flags = {}
	digs = 0
