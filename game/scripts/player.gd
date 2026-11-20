extends CharacterBody3D
## Игрок от первого лица: WASD, мышь, покачивание головы, шаги, луч «на что смотрю».

signal focus_changed(target)

var head: Node3D
var cam: Camera3D
var ray: RayCast3D
var yaw := 0.0
var pitch := 0.0
var sens := 0.0022
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
	cam.fov = 72
	cam.near = 0.03
	cam.far = 50
	head.add_child(cam)
	cam.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -1.9)
	ray.collision_mask = 3
	ray.collide_with_areas = true
	cam.add_child(ray)


func look_at_point(p: Vector3) -> void:
	var d := p - head.global_position
	yaw = atan2(-d.x, -d.z)
	pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _unhandled_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * sens
		pitch = clampf(pitch - mm.relative.y * sens, -1.4, 1.4)


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
	cam.position.y = sin(_bob * 2.0) * 0.03
	cam.position.x = cos(_bob) * 0.018

	var f: Interactable = null
	if enabled and ray.is_colliding():
		var c := ray.get_collider()
		if c is Interactable and (c as Interactable).active:
			f = c
	if f != focus:
		focus = f
		focus_changed.emit(f)
