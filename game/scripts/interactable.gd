class_name Interactable
extends Area3D
## То, на что можно навестись и нажать E. Слой столкновений 2.

var prompt := ""
var on_use: Callable
var active := true


static func make(parent: Node3D, pos: Vector3, size: Vector3, text: String, cb: Callable) -> Interactable:
	var a := Interactable.new()
	a.prompt = text
	a.on_use = cb
	a.collision_layer = 2
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	parent.add_child(a)
	a.position = pos
	return a


func use() -> void:
	if active and on_use.is_valid():
		on_use.call()
