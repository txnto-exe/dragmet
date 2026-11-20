extends CharacterBody3D
## Игрок от первого лица: WASD, мышь, покачивание головы, шаги, луч «на что смотрю».

signal focus_changed(target)

const BASE_SENS := 0.0022
const REACH := 2.0

var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var enabled := true
var focus: Interactable = null
var _bob := 0.0
var _step := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = float(Settings.get_v("fov"))
	cam.near = 0.03
	cam.far = 50
	head.add_child(cam)
	cam.current = true
	Settings.changed.connect(func(): cam.fov = float(Settings.get_v("fov")))


func look_at_point(p: Vector3) -> void:
	var d := p - head.global_position
	yaw = atan2(-d.x, -d.z)
	pitch = atan2(d.y, Vector2(d.x, d.z).length())


## Мышь читаем в _input (до интерфейса), чтобы никакой элемент экрана не съел движение.
func _input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or G.auto_test):
		var mm := e as InputEventMouseMotion
		# screen_relative — в настоящих пикселях экрана, не зависит от растяжения картинки
		var s := BASE_SENS * float(Settings.get_v("sens"))
		var inv := -1.0 if bool(Settings.get_v("invert_y")) else 1.0
		yaw -= mm.screen_relative.x * s
		pitch = clampf(pitch - mm.screen_relative.y * s * inv, -1.4, 1.4)


func _physics_process(dt: float) -> void:
	rotation.y = yaw
	head.rotation.x = pitch
	var dir := Vector3.ZERO
	if enabled:
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if inp.length() > 0.01:
			dir = (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
	var speed := 3.1 if Input.is_action_pressed("sprint") else 1.8
	var k := 1.0 - exp(-dt * 10.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, k)
	velocity.z = lerpf(velocity.z, dir.z * speed, k)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.8 * dt
	move_and_slide()

	var hv := Vector2(velocity.x, velocity.z).length()
	if hv > 0.3 and is_on_floor():
		_bob += dt * hv * 3.4
		_step += hv * dt
		if _step > 0.72:
			_step = 0.0
			Sfx.play("step%d" % (randi() % 4), -13.0, randf_range(0.85, 1.1))
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, k)
	var bob_k := 1.0 if bool(Settings.get_v("head_bob")) else 0.0
	cam.position.y = sin(_bob * 2.0) * 0.03 * bob_k
	cam.position.x = cos(_bob) * 0.018 * bob_k

	var f: Interactable = _find_focus() if enabled else null
	if f != focus:
		focus = f
		focus_changed.emit(f)


## Что под прицелом. Отдельно ищем точку взаимодействия (зоны) и стену/предмет (тела):
## зона считается, если тело не загораживает её заметно ближе. Так куча мусора своей
## коллизией больше не «съедает» подсказку «порыться».
func _find_focus() -> Interactable:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var qa := PhysicsRayQueryParameters3D.create(from, to, 2)
	qa.collide_with_areas = true
	qa.collide_with_bodies = false
	var ha := space.intersect_ray(qa)
	if ha.is_empty():
		return null
	var it := ha["collider"] as Interactable
	if it == null or not it.active:
		return null
	var qb := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hb := space.intersect_ray(qb)
	if not hb.is_empty():
		var da := from.distance_to(ha["position"])
		var db := from.distance_to(hb["position"])
		if db < da - 0.6:
			return null
	return it
